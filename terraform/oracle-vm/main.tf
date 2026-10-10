terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0"
    }
  }
}

provider "oci" {
  config_file_profile = var.oci_config_profile
  region              = var.region
}

locals {
  compartment_id = coalesce(var.compartment_ocid, var.tenancy_ocid)
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}
