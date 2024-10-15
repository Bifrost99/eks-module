# Helm release for AWS Spot Node Termination Handler in EKS
resource "helm_release" "spot_termination_handler" {
  name       = "aws-node-termination-handler"          # Name of the Helm release
  repository = "https://aws.github.io/eks-charts"      # Helm chart repository for AWS EKS charts
  chart      = "aws-node-termination-handler"          # Helm chart name for the Node Termination Handler
  version    = "0.21.0"                                # Version of the Helm chart
  namespace  = "kube-system"                           # Namespace to install the handler into

  # Disable PodSecurityPolicy (legacy) since it's no longer needed with newer Kubernetes versions
  set {
    name  = "enablePodSecurityPolicy"
    value = "false"
  }

  # Enable draining for spot interruption events (shutdown)
  set {
    name  = "enableSpotInterruptionDraining"
    value = "true"  # Drains nodes when spot instances are interrupted
  }

  # Enable monitoring for AWS Spot Instance rebalance recommendations
  set {
    name  = "enableRebalanceMonitoring"
    value = "true"  # Monitors rebalance signals for spot instances
  }

  # Enable draining when AWS Spot Instance rebalance recommendations are received
  set {
    name  = "enableRebalanceDraining"
    value = "true"  # Drains nodes on rebalance recommendation events
  }

  # Node selector to apply the termination handler only to spot instances
  set {
    name  = "nodeSelector.lifecycle"
    value = "spot"  # Ensures the handler runs only on spot lifecycle nodes
  }

  # Dependencies to ensure the termination handler is installed after critical components are ready
  depends_on = [
    aws_iam_role.external_dns_role,                         # Depends on IAM role for external DNS
    aws_iam_role_policy_attachment.external_dns_policy_attachment,  # Depends on external DNS policy attachment
    aws_eks_cluster.cluster,                                # Depends on the EKS cluster being ready
    null_resource.node_groups_ready                         # Ensures node groups are fully ready
  ]
}
