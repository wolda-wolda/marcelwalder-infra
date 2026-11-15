terraform {
  required_version = ">= 1.10.0"

  required_providers {
    porkbun = {
      source  = "jianyuan/porkbun"
      version = "~> 0.3.0"
    }
  }
}
