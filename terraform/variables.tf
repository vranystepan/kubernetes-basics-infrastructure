variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type = string
}

variable "k8s_version" {
  type    = string
  default = "1.22"
}

variable "k8s_architecture" {
  type    = string
  default = "x86_64"
}
