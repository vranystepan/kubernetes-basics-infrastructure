resource "kubernetes_namespace" "metrics_server" {
  metadata {
    name = "metrics-server"
  }
}

resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  namespace        = kubernetes_namespace.metrics_server.metadata[0].name
  create_namespace = false
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "metrics-server"
  wait             = true
  atomic           = true
  version          = "5.11.3"

  values = [
    templatefile("${path.module}/assets/metrics_server_values.yaml", {})
  ]
}
