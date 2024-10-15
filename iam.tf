# Creates an IAM role for the EKS cluster, allowing it to assume the role for managing EKS services.
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com" # Allows the EKS service to assume this role
        }
      }
    ]
  })
}

# Creates an IAM role for the EKS node group, allowing EC2 instances (worker nodes) to assume the role.
resource "aws_iam_role" "eks_node_group" {
  name = "${var.cluster_name}-${var.environment}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # Allows EC2 instances to assume this role
        }
      }
    ]
  })
}

# Attaches the AmazonEKSWorkerNodePolicy to the EKS node group role, granting permissions required by worker nodes.
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" # Predefined AWS managed policy for EKS worker nodes
}

# Attaches the AmazonEKS_CNI_Policy to the EKS node group role, granting permissions to manage network interfaces (CNI).
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # Predefined policy for EKS CNI plugin
}

# Attaches the EC2 Container Registry Read-Only policy to allow the worker nodes to pull images from ECR.
resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" # Allows access to read from ECR
}

# Creates a custom IAM policy for the EKS cluster role with permissions to interact with EC2, ECR, and Auto Scaling services.
resource "aws_iam_policy" "eks_policy" {
  name = "${var.cluster_name}-${var.environment}-eks-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]
        Resource = "*" # Grants permissions to resources under EC2, ECR, and Auto Scaling
      }
    ]
  })
}

# Attaches the custom EKS policy to the cluster IAM role.
resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = aws_iam_policy.eks_policy.arn
}

# Creates a role for the Load Balancer (LB) controller to assume using Web Identity Federation (OIDC).
resource "aws_iam_role" "lb_controller_role" {
  name = "${var.cluster_name}-${var.environment}-lb-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.arn # Use OIDC provider for assuming the role
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.eks_oidc_provider.url}:sub" = "system:serviceaccount:kube-system:${var.ingress_gateway_chart_name}"
            # Assumes the role for the Load Balancer controller service account in the kube-system namespace
          }
        }
      }
    ]
  })
}

# Defines a custom policy for the Load Balancer controller with permissions to manage Elastic Load Balancers and related services.
resource "aws_iam_policy" "lb_controller_policy" {
  name = "${var.cluster_name}-${var.environment}-lb-controller-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:*",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "waf-regional:GetWebACLForResource",
          "waf-regional:GetWebACL",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:GetWebACL",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*" # Grants permissions to manage Elastic Load Balancers and associated resources
      }
    ]
  })
}

# Attaches the Load Balancer controller policy to the LB controller IAM role.
resource "aws_iam_role_policy_attachment" "lb_controller_policy_attachment" {
  role       = aws_iam_role.lb_controller_role.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}

# Creates a role for External DNS to assume using Web Identity Federation (OIDC).
resource "aws_iam_role" "external_dns_role" {
  name = "${var.cluster_name}-${var.environment}-external-dns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.arn # Use OIDC provider for assuming the role
        }
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.eks_oidc_provider.url}:sub" = "system:serviceaccount:kube-system:${var.external_dns_chart_name}"
            # Assumes the role for the External DNS service account in the kube-system namespace
          }
        }
      }
    ]
  })
}

# Defines a custom policy for External DNS with permissions to manage Route 53 DNS records.
resource "aws_iam_policy" "external_dns_policy" {
  name = "${var.cluster_name}-${var.environment}-external-dns-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*" # Grants permission to manage Route 53 DNS records
      }
    ]
  })
}

# Attaches the External DNS policy to the external_dns_role.
resource "aws_iam_role_policy_attachment" "external_dns_policy_attachment" {
  role       = aws_iam_role.external_dns_role.name
  policy_arn = aws_iam_policy.external_dns_policy.arn
}

# Creates a role for the EBS CSI driver controller to assume using Web Identity Federation (OIDC).
resource "aws_iam_role" "ebs_csi_driver_controller_role" {
  name = "${var.cluster_name}-${var.environment}-ebs-csi-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks_oidc_provider.url # OIDC provider URL
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${aws_iam_openid_connect_provider.eks_oidc_provider.url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller"
            # Assumes the role for the EBS CSI controller service account in the kube-system namespace
          }
        }
      }
    ]
  })
}

# Defines a custom policy for the EBS CSI driver controller with permissions to manage EC2 volumes and snapshots.
resource "aws_iam_policy" "ebs_csi_controller_policy" {
  name = "${var.cluster_name}-${var.environment}-ebs-csi-controller-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "ec2:AvailabilityZone" = "${var.region}*" # Restricts volume actions to specific availability zones
          }
        }
      }
    ]
  })
}

# Attaches the EBS CSI controller policy to the role.
resource "aws_iam_role_policy_attachment" "ebs_csi_controller_policy_attachment" {
  role       = aws_iam_role.ebs_csi_driver_controller_role.name
  policy_arn = aws_iam_policy.ebs_csi_controller_policy.arn
}

# Creates an IAM role for the Kubernetes Autoscaler, allowing it to interact with EKS and EC2.
resource "aws_iam_role" "eks_autoscaler_role" {
  name = "${var.cluster_name}-${var.environment}-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com" # Allows the Autoscaler service to assume this role
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Defines a custom policy for the Kubernetes Autoscaler with permissions to manage Auto Scaling groups.
resource "aws_iam_policy" "eks_autoscaler_policy" {
  name = "${var.cluster_name}-${var.environment}-autoscaler-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attaches the Autoscaler policy to the autoscaler role.
resource "aws_iam_role_policy_attachment" "autoscaler_policy_attachment" {
  role       = aws_iam_role.eks_autoscaler_role.name
  policy_arn = aws_iam_policy.eks_autoscaler_policy.arn
}
