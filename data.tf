# Fetches information about the currently authenticated AWS account.
data "aws_caller_identity" "current" {}

# Retrieves the current AWS region where the infrastructure is being deployed.
data "aws_region" "current" {}

# Fetches details about a specific VPC by filtering based on the VPC's name tag.
# This assumes that a variable `vpc_name` is passed, which contains the VPC name.
data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name] # Assuming you have a variable for the VPC name
  }
}

# Fetches a list of private subnets within the selected VPC.
# Filters based on the VPC ID and the naming convention for private subnets.
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id] # VPC ID from the previous data block
  }
  filter {
    name   = "tag:Name"
    values = var.vpc_name == null ? ["null"] : ["${var.vpc_name}-private-${data.aws_region.current.name}*"]
    # Uses a naming convention to filter private subnets within the VPC.
  }
}

# Fetches a list of secondary private subnets (subnets labeled with 'b') in the selected VPC.
# Similar to the previous block but filters for subnets with a 'b' in the name.
data "aws_subnets" "private-b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id] # VPC ID from the selected VPC
  }
  filter {
    name   = "tag:Name"
    values = var.vpc_name == null ? ["null"] : ["${var.vpc_name}-private-${data.aws_region.current.name}*b*"]
    # Filters for subnets that include 'b' in their name.
  }
}

# Retrieves details about the specified EKS cluster.
# Depends on the creation of the EKS cluster and references the cluster's name.
data "aws_eks_cluster" "eks_cluster" {
  name       = aws_eks_cluster.cluster.name
  depends_on = [aws_eks_cluster.cluster] # Waits for the cluster resource to be created.
}

# Retrieves authentication information for the specified EKS cluster.
# Useful for creating EKS-authenticated resources, like kubeconfig.
data "aws_eks_cluster_auth" "eks_cluster_auth" {
  name = aws_eks_cluster.cluster.name
}

# Retrieves the most recent Amazon EKS worker node AMI (Amazon Machine Image).
# Filters for the AMI owned by AWS (owner ID: 602401143452) and matches the EKS node naming convention.
data "aws_ami" "eks_worker" {
  most_recent = true
  owners      = ["602401143452"] # AWS official AMI owner

  filter {
    name   = "name"
    values = ["amazon-eks-node-*"] # Filters for EKS node AMIs
  }

  filter {
    name   = "architecture"
    values = ["x86_64"] # Filters for 64-bit architecture AMIs
  }
}

# Retrieves the OIDC identity provider URL associated with the EKS cluster.
# This is used when working with OIDC-based authentication and roles in the cluster.
data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer # OIDC issuer URL
}
