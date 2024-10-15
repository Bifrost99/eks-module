# AWS provider configuration
provider "aws" {
  region = var.region  # AWS region where resources will be deployed (e.g., us-west-2)
}

# Kubernetes provider configuration for interacting with the EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint  # EKS API server endpoint
  token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token  # Authentication token for EKS
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  # Decodes the base64-encoded certificate authority for secure communication with the EKS API
}

# Helm provider configuration for deploying Helm charts on the EKS cluster
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks_cluster.endpoint  # EKS API server endpoint
    token                  = data.aws_eks_cluster_auth.eks_cluster_auth.token  # Authentication token for EKS
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
    # Decodes the base64-encoded certificate authority for secure communication with the EKS API
  }
  # The Helm provider is configured with the Kubernetes context to manage Helm releases in the EKS cluster
}
