# Define local variable to hold the IDs of all EKS node groups
locals {
  node_group_ids = [for k in keys(var.eks_node_groups) : aws_eks_node_group.node_group[k].id]
  # Creates a list of node group IDs by iterating over the keys of var.eks_node_groups
  # Each element corresponds to the ID of an EKS node group
}

# Resource to ensure node groups are ready
resource "null_resource" "node_groups_ready" {
  count = length(local.node_group_ids)  # Create one null resource for each node group ID

  triggers = {
    node_group_id = local.node_group_ids[count.index]  # Track the readiness of each node group by ID
  }

  # Ensure that this resource only runs after the EKS node groups are fully created
  depends_on = [
    aws_eks_node_group.node_group  # Wait for all EKS node groups to be created before checking readiness
  ]
}
