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
# VPC NETWORK & SUBNETS
# ---------------------

resource "google_compute_network" "cloudcadi_vpc" {
  name                    = "cloudcadi"
  auto_create_subnetworks = false
  mtu                     = 1460
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet1" {
  name                     = "subnet-1"
  network                  = google_compute_network.cloudcadi_vpc.id
  region                   = "us-central1"
  ip_cidr_range            = "10.0.0.0/24"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

resource "google_compute_subnetwork" "subnet2" {
  name                     = "subnet-2"
  network                  = google_compute_network.cloudcadi_vpc.id
  region                   = "us-central1"
  ip_cidr_range            = "10.0.1.0/24"
  private_ip_google_access = true
  stack_type               = "IPV4_ONLY"
}

# ---------------------
# FIREWALL RULES
# ---------------------

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

# ---------------------
# VPC PEERING
# ---------------------

resource "google_compute_global_address" "private_ip_alloc" {
  name          = "cloudcadi-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.cloudcadi_vpc.id
}

resource "google_service_networking_connection" "private_vpc_peering" {
  network                 = google_compute_network.cloudcadi_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]
}

# ---------------------
# CLOUD SQL POSTGRES INSTANCE
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

# SQL User
resource "google_sql_user" "default" {
  name     = "postgres"
  instance = google_sql_database_instance.clouddb.name
  password = "Qwerty@123"
}

# ---------------------
# COMPUTE ENGINE VM
# ---------------------

resource "google_compute_instance" "vm_instance" {
  name         = "instance-20250225-064515"
  machine_type = "n4-highcpu-8"
  zone         = "us-central1-a"

  boot_disk {
    auto_delete = true
    device_name = "instance-20250225-064515"

    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-v20250212"
      size  = 20
      type  = "hyperdisk-balanced"
    }

    mode = "READ_WRITE"
  }

  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet1.id

    access_config {
      network_tier = "PREMIUM"
    }

    nic_type    = "GVNIC"
    queue_count = 0
    stack_type  = "IPV4_ONLY"
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "niveshs@amadis-gcp.iam.gserviceaccount.com"
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
}

# ---------------------
# OUTPUTS
# ---------------------

output "vpc_id" {
  value = google_compute_network.cloudcadi_vpc.id
}

output "private_vpc_peering_id" {
  value = google_service_networking_connection.private_vpc_peering.id
}

output "sql_instance_name" {
  value = google_sql_database_instance.clouddb.name
}

output "vm_name" {
  value = google_compute_instance.vm_instance.name
}


variable "project_id" {}
variable "region" {}
