resource "helm_release" "ingress_gateway" {
  # The name and chart to be deployed via Helm
  name       = var.ingress_gateway_chart_name     # Helm release name for the Ingress Gateway
  chart      = var.ingress_gateway_chart_name     # Helm chart name for the Load Balancer Controller
  repository = var.ingress_gateway_chart_repo     # The Helm chart repository URL
  version    = var.ingress_gateway_chart_version  # Specific version of the Helm chart to use
  namespace  = "kube-system"                      # Namespace where the Load Balancer Controller will be installed

  # Set the EKS cluster name for the Load Balancer controller
  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.name  # The name of the EKS cluster
  }

  # Set to create a service account for the Load Balancer controller
  set {
    name  = "serviceAccount.create"
    value = true  # Ensures the creation of a service account for the Load Balancer controller
  }

  # Annotating the service account with the IAM role ARN for the Load Balancer controller permissions
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.lb_controller_role.arn  # IAM role ARN for the Load Balancer controller to interact with AWS resources
  }

  # Ensuring the helm release depends on IAM role, policy attachment, EKS cluster, and node groups being ready
  depends_on = [
    aws_iam_role.external_dns_role,                       # Wait for External DNS IAM role creation
    aws_iam_role_policy_attachment.external_dns_policy_attachment,  # Wait for policy attachment for External DNS
    aws_eks_cluster.cluster,                              # Wait for EKS cluster to be ready
    null_resource.node_groups_ready                       # Wait for node groups to be fully ready
  ]
}
