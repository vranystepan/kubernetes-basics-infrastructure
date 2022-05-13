provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host = aws_eks_cluster.control_plane.endpoint
  //cluster_ca_certificate = aws_eks_cluster.dev-cluster.certificate_authority.0.data
  token    = data.aws_eks_cluster_auth.control_plane.token
  insecure = true
  experiments {
    manifest_resource = true
  }
}

provider "helm" {
  kubernetes {
    host     = aws_eks_cluster.control_plane.endpoint
    token    = data.aws_eks_cluster_auth.control_plane.token
    insecure = true
  }
}
