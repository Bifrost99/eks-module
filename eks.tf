resource "aws_eks_cluster" "cluster" {
  # The name of the cluster, created using the cluster name and environment variables
  name = "${var.cluster_name}-${var.environment}"

  # IAM role ARN that the EKS cluster assumes
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    # Private subnets in which the cluster will be deployed
    subnet_ids              = data.aws_subnets.private.ids

    # Enables private access to the Kubernetes API server
    endpoint_private_access = var.cluster_endpoint_private_access

    # Enables public access to the Kubernetes API server
    endpoint_public_access  = var.cluster_endpoint_public_access

    # Security group associated with the EKS cluster
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Specifies the types of logs to enable for the EKS cluster (e.g., api, audit, etc.)
  enabled_cluster_log_types = var.cluster_logging_types

  # The Kubernetes version of the cluster
  version = var.cluster_version

  # The cluster creation depends on the policy attachment to the IAM role
  depends_on = [
    aws_iam_role_policy_attachment.eks_policy_attachment
  ]
}

resource "aws_eks_node_group" "node_group" {
  # Iterate over the node groups defined in the eks_node_groups variable
  for_each = var.eks_node_groups

  # The name of the cluster to which the node group belongs
  cluster_name    = aws_eks_cluster.cluster.name

  # Name of the node group
  node_group_name = each.key

  # IAM role ARN for the node group
  node_role_arn   = aws_iam_role.eks_node_group.arn

  # Private subnet for the node group (using only the first subnet here)
  subnet_ids      = [data.aws_subnets.private-b.ids[0]]

  scaling_config {
    # Desired, maximum, and minimum number of nodes in the node group
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  # The capacity type (e.g., ON_DEMAND or SPOT)
  capacity_type = each.value.capacity_type

  launch_template {
    # The launch template used to configure the instances in the node group
    id      = aws_launch_template.lt[each.key].id
    version = aws_launch_template.lt[each.key].latest_version
  }

  # Labels applied to the nodes in the node group
  labels = each.value.labels

  # Tags to associate with the node group, merging default and specific tags
  tags = merge(var.default_tags, each.value.tags)

  # Dependencies to ensure that cluster, IAM role, and launch template are created first
  depends_on = [
    aws_eks_cluster.cluster,
    aws_iam_role.eks_node_group,
    aws_launch_template.lt
  ]
}

resource "aws_launch_template" "lt" {
  # Iterate over the node groups to create a launch template for each
  for_each = var.eks_node_groups

  # Name of the launch template, incorporating the cluster name and node group key
  name          = "${aws_eks_cluster.cluster.name}-${each.key}-lt"

  # AMI ID for the EKS worker nodes (use default AMI if none is provided)
  image_id      = var.ami_id == null ? data.aws_ami.eks_worker.id : var.ami_id

  # Instance type for the node group
  instance_type = each.value.instance_types[0]

  # User data script to configure the nodes for EKS
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -o xtrace
    /etc/eks/bootstrap.sh ${aws_eks_cluster.cluster.name} ${each.value.bootstrap_arguments}
  EOT
  )

  network_interfaces {
    # Security group for the nodes
    security_groups             = [aws_security_group.node_group.id]

    # Delete network interfaces on instance termination
    delete_on_termination       = each.value.network_interfaces[0].delete_on_termination
  }

  block_device_mappings {
    # Configure block storage for the instance
    device_name = "/dev/xvda"
    ebs {
      # Volume size and type for the root volume
      volume_size           = each.value.block_device_mappings["/dev/xvda"].ebs.volume_size
      volume_type           = each.value.block_device_mappings["/dev/xvda"].ebs.volume_type

      # Ensure the volume is deleted when the instance is terminated
      delete_on_termination = each.value.block_device_mappings["/dev/xvda"].ebs.delete_on_termination
    }
  }

  tag_specifications {
    # Specify tags for the EC2 instance created by the launch template
    resource_type = "instance"
    tags = merge(
      var.default_tags,
      each.value.tags,
      {
        "kubernetes.io/cluster/${aws_eks_cluster.cluster.name}" = "owned"
        "Environment" = var.environment
      }
    )
  }

  # Ensure that the cluster and IAM role are created before the launch template
  depends_on = [
    aws_eks_cluster.cluster,
    aws_iam_role.eks_node_group
  ]
}
