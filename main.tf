resource "google_compute_network" "vpc-network" {
  project                 = "iti-sherif"
  name                    = "vpc-network"
  auto_create_subnetworks = false
  mtu                     = 1460
}

resource "google_compute_subnetwork" "managment-subnetwork" {
  name          = "managment-subnetwork"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.vpc-network.id 
  depends_on = [
    google_compute_network.vpc-network
  ]
}

# resource "google_compute_firewall" "deny-egress-rule" {
#   project     = "iti-sherif"
#   name        = "deny-egress-rule"
#   description = "Creates firewall rule to deny egress for the restricted subnetwork"
#   network     = google_compute_network.vpc-network.id
#   priority    = 100
#   direction = "EGRESS"
#   source_ranges = [ "10.0.2.0/24" ]
#   deny {
#     protocol  = "all"
#   }
# }

resource "google_compute_subnetwork" "restricted-subnetwork" {
  name          = "restricted-subnetwork"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.vpc-network.id 
  depends_on = [
    google_compute_network.vpc-network
  ]
}

resource "google_project_iam_member" "instance-service-account-role" {
  project = "iti-sherif"
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.instance-service-account.email}"
}

resource "google_service_account" "instance-service-account" {
  account_id   = "instance-service-account"
  display_name = "instance-service-account"
}

resource "google_compute_instance" "private-instance" {
  allow_stopping_for_update = true
  name         = "private-instance"
  machine_type = "e2-micro"
  zone         = "us-central1-a"
  service_account {
    email = google_service_account.instance-service-account.email
    scopes = [ "https://www.googleapis.com/auth/cloud-platform" ]
  }
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      type = "pd-ssd"
      size = 50 
    }
  }
  network_interface {
    subnetwork = "managment-subnetwork"
  }
  tags = ["allow-ssh"]
  depends_on = [
    google_compute_subnetwork.managment-subnetwork,
    google_compute_firewall.allow-ssh-rule
  ]
  metadata_startup_script = <<-EOF
    sudo apt-get install  -y apt-transport-https ca-certificates gnupg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install google-cloud -y


    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    chmod +x kubectl
    mkdir -p ~/.local/bin
    mv ./kubectl ~/.local/bin/kubectl
    kubectl version --client
    sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
    gcloud container clusters get-credentials app-cluster --zone europe-west1-c --project eminent-subset-375011
  EOF
  
}

resource "google_compute_firewall" "allow-ssh-rule" {
  project     = "iti-sherif"
  name        = "allow-ssh-rule"
  description = "Creates firewall rule to allow ssh"
  network     = google_compute_network.vpc-network.id 
  priority    = 100
  direction   = "INGRESS"
  allow {
    protocol  = "tcp"
    ports     = ["22"]
  }
  target_tags = ["allow-ssh"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.vpc-network.id
  region = "us-central1"
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat"
  router                             = google_compute_router.router.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}


resource "google_service_account" "cluster-service-account" {
  account_id   = "cluster-service-account"
  display_name = "cluster-service-account"
}

 resource "google_container_cluster" "private-cluster" {
  name       = "private-cluster"
  location   = "us-central1-a"
  network    = google_compute_network.vpc-network.name
  subnetwork = google_compute_subnetwork.restricted-subnetwork.name 
  release_channel {
    channel = "REGULAR"
  }
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
  
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block = "192.168.0.0/16"
    services_ipv4_cidr_block = "10.96.0.0/16" 
  }

  master_authorized_networks_config {
    cidr_blocks {
      display_name = "management-subnet"
      cidr_block = "10.0.1.0/24"
    }
  }
}

resource "google_container_node_pool" "private-cluster-node-pool" {
  name       = "private-cluster-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.private-cluster.name
  node_count = 3

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    preemptible  = true
    machine_type = "e2-micro"
    disk_type    = "pd-standard"
    disk_size_gb = 10
    image_type   = "COS_CONTAINERD"
    tags = ["allow-ssh"]
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.cluster-service-account.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}