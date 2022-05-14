resource "aws_security_group" "eks_loadbalancer" {
  name        = "eks_loadbalancer_${var.cluster_name}"
  description = "Security group for EKS load balancer"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "eks_loadbalancer_egress_all" {
  security_group_id = aws_security_group.eks_loadbalancer.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "eks_loadbalancer_ingress_tcp_80" {
  security_group_id = aws_security_group.eks_loadbalancer.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "eks_loadbalancer_ingress_tcp_443" {
  security_group_id = aws_security_group.eks_loadbalancer.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_lb" "eks_loadbalancer" {
  name               = "eks-${var.cluster_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks_loadbalancer.id]
  subnets = [
    aws_subnet.eks_lb_1.id,
    aws_subnet.eks_lb_2.id,
  ]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "https" {
  name        = "eks-${var.cluster_name}"
  port        = 32443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = "404"
    protocol            = "HTTPS"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.eks_loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.eks_loadbalancer.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.s01_wildcard.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-2019-08"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

// DNS and TLS
resource "aws_route53_record" "s01" {
  zone_id = data.aws_route53_zone.training.zone_id
  name    = "*.s01.${data.aws_route53_zone.training.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [
    aws_lb.eks_loadbalancer.dns_name,
  ]
}

resource "aws_acm_certificate" "s01_wildcard" {
  domain_name       = "*.s01.${data.aws_route53_zone.training.name}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "s01_wildcard_validation" {
  for_each = {
    for dvo in aws_acm_certificate.s01_wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.training.zone_id
}

resource "aws_acm_certificate_validation" "s01_wildcard" {
  certificate_arn         = aws_acm_certificate.s01_wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.s01_wildcard_validation : record.fqdn]
}
