# Resource for installing the EKS VPC CNI plugin as an addon
resource "aws_eks_addon" "eks_cni" {
  # The name of the EKS cluster where the addon will be installed
  cluster_name                = aws_eks_cluster.cluster.name  # Specifies the EKS cluster name

  # Addon name for the VPC CNI plugin, which manages networking in the EKS cluster
  addon_name                  = "vpc-cni"  # Addon for the VPC CNI plugin in EKS

  # Conflict resolution strategies for creation and updates
  resolve_conflicts_on_create = "OVERWRITE"  # Overwrite if there's a conflict during creation
  resolve_conflicts_on_update = "OVERWRITE"  # Overwrite if there's a conflict during updates

  # Configuration values for the VPC CNI plugin (in JSON format)
  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"  # Enables prefix delegation to support more IPs per node
      WARM_PREFIX_TARGET       = "1"     # Keeps 1 IP address ready for quicker scaling of pods
    }
  })

  # Tags for the addon, including default tags and custom name
  tags = merge(var.default_tags, {
    "Name"        = "${var.cluster_name}-${var.environment}-vpc-cni",  # Custom name tag for the VPC CNI addon
    "Environment" = var.environment  # Environment tag (e.g., dev, prod)
  })
}
