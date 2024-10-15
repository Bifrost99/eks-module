resource "helm_release" "ebs_csi_controller" {
  # The name and chart to be deployed via Helm
  name       = var.ebs_csi_controller_chart_name   # Helm release name
  chart      = var.ebs_csi_controller_chart_name   # Helm chart name for EBS CSI Controller
  repository = var.ebs_csi_controller_repository   # The Helm chart repository URL
  version    = var.ebs_csi_controller_version      # Specific version of the Helm chart to use
  namespace  = var.ebs_csi_controller_namespace    # Namespace where the Helm release will be installed

  # Set the EKS cluster name for the EBS CSI driver
  set {
    name  = "clusterName"
    value = aws_eks_cluster.cluster.name  # EKS cluster name to be used by the driver
  }

  # Set to create a service account for the controller
  set {
    name  = "controller.serviceAccount.create"
    value = "true"  # Ensures the creation of a service account for the controller
  }

  # Annotating the service account with the IAM role ARN for EBS CSI controller permissions
  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi_driver_controller_role.arn  # IAM role ARN for the EBS CSI controller
  }

  # Ensuring the helm release depends on the IAM role, policy, and EKS cluster to be created first
  depends_on = [
    aws_iam_role.ebs_csi_driver_controller_role,  # Wait for IAM role creation
    aws_iam_policy.ebs_csi_controller_policy,     # Wait for IAM policy creation
    aws_eks_cluster.cluster                       # Wait for EKS cluster to be ready
  ]
}
