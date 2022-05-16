data "google_client_config" "main" {}

data "aws_route53_zone" "training" {
  zone_id = var.zone_id
}

data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = helm_release.nginx_ingress.metadata.0.namespace
  }
  depends_on = [
    helm_release.nginx_ingress,
    time_sleep.nginx_ingress_wait_30_seconds,
  ]
}
