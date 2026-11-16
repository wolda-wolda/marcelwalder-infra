data "terraform_remote_state" "prod" {
  backend = "s3"

  config = {
    bucket                      = "tfstate-marcelwalder-prod"
    key                         = "prod/terraform.tfstate"
    region                      = "eu-frankfurt-1"
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true

    endpoints = {
      s3 = "https://frlsvddoxbrh.compat.objectstorage.eu-frankfurt-1.oraclecloud.com"
    }
  }
}

locals {
  mail_ip = data.terraform_remote_state.prod.outputs.instance_public_ips["mail"]

  base_records = {
    apex_a = {
      type    = "A"
      content = local.mail_ip
      ttl     = 600
    }
    www_a = {
      subdomain = "www"
      type      = "A"
      content   = local.mail_ip
      ttl       = 600
    }
    mail_a = {
      subdomain = "mail"
      type      = "A"
      content   = local.mail_ip
      ttl       = 300
    }
    status_a = {
      subdomain = "status"
      type      = "A"
      content   = local.mail_ip
      ttl       = 300
    }
    analytics_a = {
      subdomain = "analytics"
      type      = "A"
      content   = "10.66.66.1"
      ttl       = 600
    }
    kuma_a = {
      subdomain = "kuma"
      type      = "A"
      content   = "10.66.66.1"
      ttl       = 600
    }
    mta_sts_cname = {
      subdomain = "mta-sts"
      type      = "CNAME"
      content   = "mail.marcelwalder.eu"
      ttl       = 600
    }
    autoconfig_cname = {
      subdomain = "autoconfig"
      type      = "CNAME"
      content   = "mail.marcelwalder.eu"
      ttl       = 300
    }
    autodiscover_cname = {
      subdomain = "autodiscover"
      type      = "CNAME"
      content   = "mail.marcelwalder.eu"
      ttl       = 300
    }
    wildcard_cname = {
      subdomain = "*"
      type      = "CNAME"
      content   = "pixie.porkbun.com"
      ttl       = 600
    }
    dkim1_cname = {
      subdomain = "dkim1._domainkey"
      type      = "CNAME"
      content   = "dkim1.marcelwalder.eu.dkim.fra1.oracleemaildelivery.com"
      ttl       = 300
    }
    mx_primary = {
      type     = "MX"
      content  = "mail.marcelwalder.eu"
      ttl      = 300
      priority = 10
    }
    dmarc_txt = {
      subdomain = "_dmarc"
      type      = "TXT"
      content   = "v=DMARC1; p=reject; sp=reject; rua=mailto:dmarc@marcelwalder.eu; ruf=mailto:dmarc@marcelwalder.eu; adkim=r; aspf=r"
      ttl       = 600
    }
    spf_txt = {
      type    = "TXT"
      content = "v=spf1 ip4:${local.mail_ip} include:eu.rp.oracleemaildelivery.com ~all"
      ttl     = 300
    }
    tlsrpt_txt = {
      subdomain = "_smtp._tls"
      type      = "TXT"
      content   = "v=TLSRPTv1; rua=mailto:postmaster@marcelwalder.eu"
      ttl       = 600
    }
    mta_sts_txt = {
      subdomain = "_mta-sts"
      type      = "TXT"
      content   = "v=STSv1; id=20261111225000Z"
      ttl       = 600
    }
    bimi_txt = {
      subdomain = "default._bimi"
      type      = "TXT"
      content   = "v=BIMI1; l=https://mail.marcelwalder.eu/avatar.svg; a=;"
      ttl       = 600
    }
  }
}

module "dns" {
  source = "../../modules/dns"

  domain  = var.domain
  records = merge(local.base_records, var.extra_records)
}
