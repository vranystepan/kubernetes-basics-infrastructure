resource "kubernetes_namespace" "cluster_autoscaler" {
  metadata {
    name = "cluster-autoscaler"
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name = "eks_cluster_autoscaler_${var.cluster_name}"
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
            "system:serviceaccount:cluster-autoscaler:cluster-autoscaler-aws-cluster-autoscaler",
          ]
        }
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name = "eks_cluster_autoscaler_${var.cluster_name}"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes",
        ]
        Resource = [
          "*",
        ]
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  namespace        = kubernetes_namespace.cluster_autoscaler.metadata[0].name
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  atomic           = true
  wait             = true
  create_namespace = false

  values = [
    templatefile("${path.module}/assets/cluster_autoscaler_values.yaml", {
      cluster_name = aws_eks_cluster.control_plane.name
      region       = data.aws_region.current.name
      role_arn     = aws_iam_role.cluster_autoscaler.arn
    })
  ]
}
