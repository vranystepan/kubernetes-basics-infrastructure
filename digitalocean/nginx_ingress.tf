resource "kubernetes_namespace" "nginx_ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  namespace        = kubernetes_namespace.nginx_ingress.metadata[0].name
  create_namespace = false
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  wait             = true
  atomic           = true

  values = [
    templatefile("${path.module}/assets/nginx_ingress_values.yaml", {
      replica_count  = 2,
      memory_request = "256Mi",
      memory_limit   = "256Mi",
      cpu_request    = "100m",
      cpu_limit      = "100m",
    })
  ]
}

resource "time_sleep" "nginx_ingress_wait_30_seconds" {
  depends_on = [
    helm_release.nginx_ingress,
  ]

  create_duration = "60s"
}

resource "aws_route53_record" "s03" {
  zone_id = data.aws_route53_zone.training.zone_id
  name    = "*.s03.${data.aws_route53_zone.training.name}"
  type    = "A"
  ttl     = "300"
  records = [
    digitalocean_loadbalancer.main.ip,
  ]
}
