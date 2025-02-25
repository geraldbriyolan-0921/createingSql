terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "amadis-gcp"
  region  = "us-central1"
}

module "vpc" {
  source = "./vpc"
}

module "sql" {
  source                 = "./sql"
  vpc_id                 = module.vpc.vpc_id
  private_vpc_peering_id = module.vpc.private_vpc_peering_id
}