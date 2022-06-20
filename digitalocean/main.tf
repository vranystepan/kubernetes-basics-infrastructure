resource "digitalocean_project" "main" {
  name        = "workshop"
  purpose     = "training"
  environment = "development"
  resources = [
    digitalocean_kubernetes_cluster.main.urn,
    digitalocean_loadbalancer.main.urn,
  ]
}

resource "digitalocean_kubernetes_cluster" "main" {
  name    = "workshop"
  region  = "fra1"
  version = "1.22.8-do.1"

  node_pool {
    name       = "main"
    size       = "s-2vcpu-2gb"
    node_count = 3
    tags       = ["k8s-workshop"]
  }
}

resource "digitalocean_loadbalancer" "main" {
  name   = "workshop"
  region = "fra1"

  forwarding_rule {
    entry_port     = 443
    entry_protocol = "tcp"

    target_port     = 32443
    target_protocol = "tcp"
  }

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "tcp"

    target_port     = 32080
    target_protocol = "tcp"
  }

  healthcheck {
    port     = 32443
    protocol = "tcp"
  }

  droplet_tag = "k8s-workshop"
}

resource "local_file" "kubeconfig" {
  content  = digitalocean_kubernetes_cluster.main.kube_config.0.raw_config
  filename = "${path.module}/kubeconfig.yaml"
}

