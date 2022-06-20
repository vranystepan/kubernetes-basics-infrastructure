terraform {}

locals {
  parameters = yamldecode(file(find_in_parent_folders("parameters.yaml")))
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("parameters.enc.yaml")))
}

inputs = {
  do_token = local.secrets.digitalocean.do_token
  lets_enrypt_email = local.secrets.lets_enrypt_email
  zone_id = local.secrets.aws.zone_id
}
