terraform {
  backend "s3" {
    bucket                      = "tfstate-marcelwalder-prod"
    key                         = "prod/terraform.tfstate"
    region                      = "eu-frankfurt-1"
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true

    endpoints = {
      s3 = "https://frlsvddoxbrh.compat.objectstorage.eu-frankfurt-1.oraclecloud.com"
    }
  }
}
