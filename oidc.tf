# Local variable to construct the OIDC URL for the EKS cluster
locals {
  oidc_url = "https://oidc.eks.${var.region}.amazonaws.com/id/${aws_eks_cluster.cluster.id}"
  # The OIDC URL is dynamically built based on the region and the EKS cluster ID
}

# Resource to create an OpenID Connect (OIDC) provider for EKS
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  # List of client IDs allowed to use this OIDC provider, where "sts.amazonaws.com" is required for EKS
  client_id_list  = ["sts.amazonaws.com"]

  # Thumbprint list for the OIDC provider, fetched from the TLS certificate of the EKS OIDC URL
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  # Retrieves the thumbprint from the TLS certificate for the OIDC URL, used to validate the provider

  # OIDC issuer URL for the EKS cluster, retrieved from the EKS cluster's identity configuration
  url             = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  # This OIDC URL comes directly from the EKS cluster's identity block, allowing IAM roles to trust the OIDC provider
}
