terraform {}

locals {
  parameters = yamldecode(file(find_in_parent_folders("parameters.yaml")))
  secrets = yamldecode(sops_decrypt_file(find_in_parent_folders("parameters.enc.yaml")))
}

inputs = {
    cluster_name = local.parameters.eks.cluster_name
}
