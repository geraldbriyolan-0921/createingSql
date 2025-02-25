terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}


# ---------------------
# VPC Configuration
# ---------------------
resource "google_compute_network" "cloudcadi_vpc" {
  name                    = "cloudcadi"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

# Create Subnet 1
resource "google_compute_subnetwork" "subnet1" {
  name                     = "subnet-1"
  network                  = google_compute_network.cloudcadi_vpc.id
  region                   = "us-central1"
  ip_cidr_range            = "10.0.0.0/24"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

# Create Subnet 2
resource "google_compute_subnetwork" "subnet2" {
  name                     = "subnet-2"
  network                  = google_compute_network.cloudcadi_vpc.id
  region                   = "us-central1"
  ip_cidr_range            = "10.0.1.0/24"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

# Firewall Rules
resource "google_compute_firewall" "allow_rdp" {
  name    = "allow-rdp"
  network = google_compute_network.cloudcadi_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }

  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"] # Modify for security
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.cloudcadi_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"] # Modify for security
}

# Reserve a private IP range for Google services
resource "google_compute_global_address" "private_ip_alloc" {
  name          = "cloudcadi-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.cloudcadi_vpc.id
}

# Create a private service connection for Google-managed services
resource "google_service_networking_connection" "private_vpc_peering" {
  network                 = google_compute_network.cloudcadi_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

# ---------------------
# Cloud SQL Configuration
# ---------------------
resource "google_sql_database_instance" "clouddb" {
  depends_on       = [google_service_networking_connection.private_vpc_peering] 
  name             = "clouddb"
  database_version = "POSTGRES_14"
  region           = "us-central1"

  settings {
    tier              = "db-custom-4-15360"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 64

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.cloudcadi_vpc.id
    }

    maintenance_window {
      day  = 1
      hour = 0
    }
  }

  deletion_protection = true
}

# Create a Cloud SQL User
resource "google_sql_user" "default" {
  name     = "postgres"
  instance = google_sql_database_instance.clouddb.name
  password = "Qwerty@123"
}

# ---------------------
# Outputs
# ---------------------
output "vpc_id" {
  value = google_compute_network.cloudcadi_vpc.id
}

output "private_vpc_peering_id" {
  value = google_service_networking_connection.private_vpc_peering.id
}


variable "project_id" {}
variable "region" {}
