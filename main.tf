resource "google_compute_network" "vpc-network" {
  project                 = "iti-sherif"
  name                    = "vpc-network"
  auto_create_subnetworks = true
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

resource "google_compute_subnetwork" "restricted-subnetwork" {
  name          = "restricted-subnetwork"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.vpc-network.id 
  depends_on = [
    google_compute_network.vpc-network
  ]
}

resource "google_compute_instance" "private-instance" {
  allow_stopping_for_update = true
  name         = "private-instance"
  machine_type = "e2-micro"
  zone         = "us-central1-a"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      type = "pd-standard"
      size = 10 
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
  source_ranges = ["35.235.240.0/20"]
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
