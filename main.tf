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
}

resource "google_compute_subnetwork" "restricted-subnetwork" {
  name          = "restricted-subnetwork"
  ip_cidr_range = "10.0.2.0/24"
  network       = google_compute_network.vpc-network.id 
}

resource "google_compute_instance" "private-instance" {
  allow_stopping_for_update = true
  name         = "private-instance"
  machine_type = "e2-micro"
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }
  network_interface {
    subnetwork = "managment-subnetwork"
  }
}