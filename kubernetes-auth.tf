# Create Admins & Developers user maps
locals {
  admin_user_map_users = [
    for admin_user in var.admin_users : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${admin_user}"
      username = admin_user
      groups   = ["system:masters"]
    }
  ]

  developer_user_map_users = [
    for developer_user in var.developer_users : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${developer_user}"
      username = developer_user
      groups   = ["${var.cluster_name}-${var.environment}-developers"]
    }
  ]
}

# Add 'mapRoles' and 'mapUsers' sections to 'aws-auth' configmap with Admins & Developers
resource "time_sleep" "wait" {
  create_duration = "180s"
  triggers = {
    cluster_endpoint = aws_eks_cluster.cluster.endpoint
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = jsonencode([{
      rolearn  = aws_iam_role.eks_node_group.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }])

    mapUsers = yamlencode(concat(local.admin_user_map_users, local.developer_user_map_users))
  }

  force = true

  depends_on = [
    time_sleep.wait,
    aws_eks_cluster.cluster,
    aws_iam_role.eks_node_group
  ]
}

# Create Developers Role using RBAC
resource "kubernetes_cluster_role" "developers_cluster_role" {
  metadata {
    name = "${var.cluster_name}-${var.environment}-developers-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services"]
    verbs      = ["get", "list", "create", "update"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets", "daemonsets"]
    verbs      = ["get", "list", "create", "update"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "create", "update"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "create", "update"]
  }

  depends_on = [
    aws_eks_cluster.cluster
  ]
}

# Bind developer Users with their Cluster Role using RBAC
resource "kubernetes_cluster_role_binding" "developers_cluster_role_binding" {
  metadata {
    name = "${var.cluster_name}-${var.environment}-developers-rolebinding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.developers_cluster_role.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "${var.cluster_name}-${var.environment}-developers"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    aws_eks_cluster.cluster,
    kubernetes_cluster_role.developers_cluster_role
  ]
}
