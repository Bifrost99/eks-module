resource "helm_release" "external_dns" {
  # The name and chart to be deployed via Helm
  name       = var.external_dns_chart_name     # Helm release name
  chart      = var.external_dns_chart_name     # Helm chart name for External DNS
  repository = var.external_dns_chart_repo     # The Helm chart repository URL
  version    = var.external_dns_chart_version  # Specific version of the Helm chart to use
  namespace  = "kube-system"                   # Namespace where External DNS will be installed

  # Set to create a service account for External DNS
  set {
    name  = "serviceAccount.create"
    value = true  # Ensures the creation of a service account for External DNS
  }

  # Annotating the service account with the IAM role ARN for External DNS permissions
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns_role.arn  # IAM role ARN for External DNS to interact with AWS Route 53
  }

  # Domain filters to limit the domains managed by External DNS
  set {
    name  = "domainFilters[0]"
    value = join(",", var.external_dns_domain_filters)  # Filters External DNS to specific domains
  }

  # Policy for managing DNS records, can be 'sync' or 'upsert-only'
  set {
    name  = "policy"
    value = var.external_dns_policy  # Specifies the policy for External DNS (sync or upsert-only)
  }

  # Provider for External DNS, in this case, AWS
  set {
    name  = "provider"
    value = "aws"  # Specifies AWS as the provider for DNS management
  }

  # Ensure Helm release depends on IAM role, policy attachment, EKS cluster, and node groups being ready
  depends_on = [
    aws_iam_role.external_dns_role,                       # Wait for IAM role creation
    aws_iam_role_policy_attachment.external_dns_policy_attachment,  # Wait for IAM role policy attachment
    aws_eks_cluster.cluster,                              # Wait for EKS cluster to be ready
    null_resource.node_groups_ready                       # Wait for EKS node groups to be ready
  ]
}
