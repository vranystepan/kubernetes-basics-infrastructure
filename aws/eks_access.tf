resource "aws_iam_policy" "eks_kubeconfig" {
  name        = "eks_kubeconfig"
  path        = "/"
  description = "allow obtaining of kubeconfig for all EKS clusters"

  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = [
          "*",
        ]
      }
    ]
    Version = "2012-10-17"
  })
}

// role for students
resource "aws_iam_role" "eks_access_student" {
  name = "eks_access_${data.aws_region.current.name}_student"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
          ]
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_access_student_kubeconfig" {
  policy_arn = aws_iam_policy.eks_kubeconfig.arn
  role       = aws_iam_role.eks_access_student.name
}

// policies that allow sts:AssumeRole for the EKS groups
resource "aws_iam_policy" "eks_access_student_allow_assume" {
  name = "eks_${data.aws_region.current.name}_student_allow_assume"
  path = "/"

  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
        ]
        Resource = [
          aws_iam_role.eks_access_student.arn,
        ],
      }
    ]
    Version = "2012-10-17"
  })
}

// groups for the EKS access, user assigned to such group
// will be able to assume the role
resource "aws_iam_group" "eks_access_student" {
  name = "eks_${data.aws_region.current.name}_student"
}

resource "aws_iam_group_policy_attachment" "eks_access_student" {
  group      = aws_iam_group.eks_access_student.name
  policy_arn = aws_iam_policy.eks_access_student_allow_assume.arn
}

resource "kubernetes_cluster_role_binding" "student" {
  metadata {
    name = "workshop-student"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "Group"
    name      = "workshop:student"
    api_group = "rbac.authorization.k8s.io"
  }
}
