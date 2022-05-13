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
  subnets            = [
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
    protocol = "HTTPS"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.eks_loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}
