// security group for control plane
resource "aws_security_group" "eks_control_plane" {
  name        = "eks_${var.cluster_name}"
  description = "Security group for EKS control plane"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "eks_control_plane_egress_all" {
  security_group_id = aws_security_group.eks_control_plane.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "eks_control_plane_ingress_nodes_all" {
  description              = "allow access from nodes as per https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_control_plane.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 0
  type                     = "ingress"
}

// security group for nodes
resource "aws_security_group" "eks_nodes" {
  name        = "eks_workers_${var.cluster_name}"
  description = "Security group for EKS control nodes"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "eks_nodes_egress_all" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "eks_nodes_ingress_control_plane_all" {
  description              = "allow access from nodes as per https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_control_plane.id
  to_port                  = 0
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_nodes_ingress_eks_loadbalancer_tcp_32443" {
  description              = "allow access to nginx ingress controller"
  from_port                = 32443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_loadbalancer.id
  to_port                  = 32443
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks_nodes_ingress_self_all" {
  description              = "allow access to nginx ingress controller"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_nodes.id
  to_port                  = 0
  type                     = "ingress"
}

// log group for control plane
resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
}

// kms key for envelop encryption
resource "aws_kms_key" "eks" {
  description             = "key for EKS cluster"
  deletion_window_in_days = 10

  tags = {
    Name = "eks_${var.cluster_name}"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks_${var.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

// IAM role for control plane
resource "aws_iam_role" "eks_control_plane" {
  name = "eks_control_plane_${var.cluster_name}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_control_plane_default_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_control_plane.name
}

resource "aws_iam_role_policy_attachment" "eks_control_plane_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_control_plane.name
}

// IAM role for nodes
resource "aws_iam_role" "eks_nodes" {
  name = "eks_nodes_${var.cluster_name}"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_nodes_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_container_registry_read_only_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_nodes_ssm_managed_instance_core_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_nodes.name
}

// eks cluster
resource "aws_eks_cluster" "control_plane" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_control_plane.arn

  enabled_cluster_log_types = [
    "audit",
    "authenticator"
  ]

  vpc_config {

    subnet_ids = [
      aws_subnet.eks_control_plane_1.id,
      aws_subnet.eks_control_plane_2.id,
    ]

    security_group_ids = [
      aws_security_group.eks_control_plane.id,
    ]

    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs = [
      "0.0.0.0/0"
    ]
  }

  encryption_config {

    resources = [
      "secrets",
    ]

    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_control_plane_default_policy,
    aws_iam_role_policy_attachment.eks_control_plane_service_policy,
    aws_cloudwatch_log_group.eks_control_plane,
  ]

  version = var.k8s_version
}

// auth configuration
locals {
  auth_data = {
    mapAccounts = yamlencode([])
    mapRoles = yamlencode([
      {
        groups   = ["system:bootstrappers", "system:nodes"]
        rolearn  = aws_iam_role.eks_nodes.arn
        username = "system:node:{{EC2PrivateDNSName}}"
      },
      {
        groups   = ["workshop:student"]
        rolearn  = aws_iam_role.eks_access_student.arn
        username = "workshop:student:{{SessionName}}"
      }
    ])
  }
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.auth_data

  lifecycle {
    ignore_changes = [
      data,
    ]
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  force = true

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = local.auth_data
  depends_on = [
    kubernetes_config_map.aws_auth,
  ]
}

// IRSA
data "tls_certificate" "control_plane" {
  url = aws_eks_cluster.control_plane.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "control_plane" {
  client_id_list = [
    "sts.amazonaws.com",
  ]
  thumbprint_list = [data.tls_certificate.control_plane.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.control_plane.identity[0].oidc[0].issuer
}

// CNI addon
resource "aws_iam_role" "eks_cni" {
  name = "eks_cni_${var.cluster_name}"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = [
          aws_iam_openid_connect_provider.control_plane.arn
        ]
      }
      Condition = {
        StringLike = {
          "${replace(aws_iam_openid_connect_provider.control_plane.url, "https://", "")}:sub" = [
            "system:serviceaccount:kube-system:aws-node",
          ]
        }
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_cni.name
}

resource "aws_eks_addon" "eks_cni" {
  cluster_name             = aws_eks_cluster.control_plane.name
  addon_name               = "vpc-cni"
  resolve_conflicts        = "OVERWRITE"
  service_account_role_arn = aws_iam_role.eks_cni.arn
}

// coredns addon
resource "aws_eks_addon" "eks_coredns" {
  cluster_name      = aws_eks_cluster.control_plane.name
  addon_name        = "coredns"
  resolve_conflicts = "OVERWRITE"
}

// kube-proxy addon
resource "aws_eks_addon" "eks_kube_proxy" {
  cluster_name      = aws_eks_cluster.control_plane.name
  addon_name        = "kube-proxy"
  resolve_conflicts = "OVERWRITE"
}

// compute
resource "aws_iam_instance_profile" "eks_nodes" {
  name = "eks_nodes_${var.cluster_name}"
  role = aws_iam_role.eks_nodes.name
}

data "aws_ami" "bottlerocket_ami" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${var.k8s_version}-${var.k8s_architecture}-*"]
  }
}

resource "aws_launch_template" "eks_nodes" {
  disable_api_termination = false
  ebs_optimized           = "true"
  image_id                = data.aws_ami.bottlerocket_ami.id
  instance_type           = "m5a.large"

  name = "eks_nodes"

  update_default_version = false
  user_data = base64encode(
    templatefile(
      "${path.module}/assets/bottlerocket.toml",
      {
        api_server          = aws_eks_cluster.control_plane.endpoint
        cluster_certificate = aws_eks_cluster.control_plane.certificate_authority[0].data
        cluster_name        = var.cluster_name
        max_pods            = 30 // fix this
      }
    )
  )

  vpc_security_group_ids = []

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = "true"
      encrypted             = "false"
      volume_size           = 2
      volume_type           = "gp2"
    }
  }

  block_device_mappings {
    device_name = "/dev/xvdb"

    ebs {
      delete_on_termination = "true"
      encrypted             = "false"
      volume_size           = 20
      volume_type           = "gp2"
    }
  }

  credit_specification {
    cpu_credits = "standard"
  }

  enclave_options {
    enabled = false
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_nodes.name
  }

  metadata_options {
    http_endpoint          = "enabled"
    http_protocol_ipv6     = "disabled"
    http_tokens            = "optional"
    instance_metadata_tags = "disabled"
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = "true"
    device_index                = 0
    ipv4_address_count          = 0
    ipv4_addresses              = []
    ipv6_address_count          = 0
    ipv6_addresses              = []
    network_card_index          = 0
    security_groups = [
      aws_security_group.eks_nodes.id,
    ]
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      "Name"                                                   = var.cluster_name
      "k8s.io/cluster-autoscaler/node-template/label/nodepool" = "main"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      "Name" = var.cluster_name
    }
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = {
      "Name"                                                   = var.cluster_name
      "k8s.io/cluster-autoscaler/node-template/label/nodepool" = "main"
    }
  }
}

resource "aws_autoscaling_group" "eks_nodes_az1" {
  max_size         = 3
  min_size         = 1
  desired_capacity = 2

  capacity_rebalance        = false
  default_cooldown          = 300
  enabled_metrics           = []
  force_delete              = false
  force_delete_warm_pool    = false
  health_check_grace_period = 300
  health_check_type         = "EC2"
  load_balancers            = []
  max_instance_lifetime     = 0
  metrics_granularity       = "1Minute"
  name                      = "${var.cluster_name}_1"

  protect_from_scale_in = false

  suspended_processes = [
    "AZRebalance",
  ]
  target_group_arns = [
    aws_lb_target_group.https.arn,
  ]

  termination_policies = []
  vpc_zone_identifier = [
    aws_subnet.eks_workers_1.id,
  ]

  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "${var.cluster_name}_1"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    propagate_at_launch = false
    value               = "true"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/nodepool"
    propagate_at_launch = true
    value               = "main"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    propagate_at_launch = false
    value               = "owned"
  }
  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    propagate_at_launch = true
    value               = "owned"
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}

resource "aws_autoscaling_group" "eks_nodes_az2" {
  max_size         = 3
  min_size         = 1
  desired_capacity = 2

  capacity_rebalance        = false
  default_cooldown          = 300
  enabled_metrics           = []
  force_delete              = false
  force_delete_warm_pool    = false
  health_check_grace_period = 300
  health_check_type         = "EC2"
  load_balancers            = []
  max_instance_lifetime     = 0
  metrics_granularity       = "1Minute"
  name                      = "${var.cluster_name}_2"

  protect_from_scale_in = false

  suspended_processes = [
    "AZRebalance",
  ]
  target_group_arns = [
    aws_lb_target_group.https.arn,
  ]

  termination_policies = []
  vpc_zone_identifier = [
    aws_subnet.eks_workers_2.id,
  ]

  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  tag {
    key                 = "Name"
    propagate_at_launch = true
    value               = "${var.cluster_name}_2"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    propagate_at_launch = false
    value               = "true"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/node-template/label/nodepool"
    propagate_at_launch = true
    value               = "main"
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    propagate_at_launch = false
    value               = "owned"
  }
  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    propagate_at_launch = true
    value               = "owned"
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}
