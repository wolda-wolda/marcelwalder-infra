instances = {
  mail = {
    display_name            = "Mail-Server"
    availability_domain     = "UiKL:EU-FRANKFURT-1-AD-1"
    fault_domain            = "FAULT-DOMAIN-3"
    shape                   = "VM.Standard.A1.Flex"
    ocpus                   = 1
    memory_in_gbs           = 3
    image_id                = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaifwipx5e5g2wak2wn3nhgd3ncm6ndkylrk3td7ebh2stshyn63iq"
    subnet_key              = "public"
    hostname_label          = "mail-server"
    private_ip              = "10.0.1.180"
    vnic_assign_public_ip   = true # Preserves console-created VNIC flag on imported Mail-Server
    reserved_public_ip_name = "Mail-Reserved-IP"
  }

  # Example: adding a second ARM Always Free VM in the future:
  # app = {
  #   display_name            = "App-Server"
  #   availability_domain     = "UiKL:EU-FRANKFURT-1-AD-1"
  #   shape                   = "VM.Standard.A1.Flex"
  #   ocpus                   = 2
  #   memory_in_gbs           = 12
  #   image_id                = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaifwipx5e5g2wak2wn3nhgd3ncm6ndkylrk3td7ebh2stshyn63iq"
  #   boot_volume_size_in_gbs = 50
  #   subnet_key              = "public"
  #   hostname_label          = "app-server"
  #   nsg_keys                = ["web_app"]
  #   reserved_public_ip_name = "App-Reserved-IP"
  # }
}
