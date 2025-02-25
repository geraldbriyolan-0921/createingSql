variable "vpc_id" {
  description = "VPC ID for Cloud SQL private network"
}

variable "private_vpc_peering_id" {
  description = "ID of the private VPC peering connection"
}

resource "google_sql_database_instance" "clouddb" {
  depends_on       = [var.private_vpc_peering_id] # Correctly using the variable
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
      private_network = var.vpc_id # Correctly referencing the VPC
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
