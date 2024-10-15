# Security Group for ALB (Application Load Balancer)
resource "aws_security_group" "alb" {
  name   = "${var.cluster_name}-${var.environment}-alb"  # Name of the security group for the ALB
  vpc_id = data.aws_vpc.selected.id  # VPC ID where the security group will be created

  # Dynamic block to define ingress rules based on variable input
  dynamic "ingress" {
    for_each = var.alb_ingress_rules  # Iterate over ALB ingress rules provided in variables
    content {
      description      = ingress.value.description       # Description of the ingress rule
      from_port        = ingress.value.from_port         # Starting port for ingress traffic
      to_port          = ingress.value.to_port           # Ending port for ingress traffic
      protocol         = ingress.value.protocol          # Protocol used (e.g., TCP, HTTP)
      cidr_blocks      = ingress.value.cidr_blocks       # IPv4 CIDR blocks allowed for ingress
      ipv6_cidr_blocks = ingress.value.ipv6_cidr_blocks  # IPv6 CIDR blocks allowed for ingress
    }
  }

  # Egress rule to allow outbound traffic to any destination
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"                # Allow all protocols
    cidr_blocks      = ["0.0.0.0/0"]       # Allow traffic to any IPv4 address
    ipv6_cidr_blocks = ["::/0"]            # Allow traffic to any IPv6 address
  }

  # Tags for the security group, including default tags and custom name
  tags = merge(var.default_tags, {
    "Name"        = "${var.cluster_name}-${var.environment}-alb-sg",  # Security group name for ALB
    "Environment" = var.environment  # Environment tag
  })
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-${var.environment}-sg"  # Name of the security group for the EKS cluster
  description = "Security group for EKS cluster"  # Description for the EKS cluster security group
  vpc_id      = data.aws_vpc.selected.id  # VPC ID where the security group will be created

  # Dynamic block to define ingress rules for the EKS cluster
  dynamic "ingress" {
    for_each = var.eks_cluster_ingress_rules  # Iterate over EKS cluster ingress rules
    content {
      from_port        = ingress.value.from_port          # Starting port for ingress traffic
      to_port          = ingress.value.to_port            # Ending port for ingress traffic
      protocol         = ingress.value.protocol           # Protocol used (e.g., TCP)
      cidr_blocks      = ingress.value.cidr_blocks        # IPv4 CIDR blocks allowed for ingress
      ipv6_cidr_blocks = try(ingress.value.ipv6_cidr_blocks, null)  # IPv6 CIDR blocks, if available
    }
  }

  # Egress rule to allow outbound traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                # Allow all protocols
    cidr_blocks = ["0.0.0.0/0"]       # Allow traffic to any IPv4 address
  }

  # Tags for the security group, including default tags and custom name
  tags = merge(var.default_tags, {
    "Name"        = "${var.cluster_name}-${var.environment}-cluster-sg",  # Security group name for EKS cluster
    "Environment" = var.environment  # Environment tag
  })
}

# Security Group for EKS Node Groups
resource "aws_security_group" "node_group" {
  name        = "${var.cluster_name}-${var.environment}-node-group-sg"  # Name of the security group for node groups
  description = "Security group for EKS Node Group"  # Description for the node group security group
  vpc_id      = data.aws_vpc.selected.id  # VPC ID where the security group will be created

  # Dynamic block to define ingress rules for node groups
  dynamic "ingress" {
    for_each = var.node_group_sg_ingress_rules  # Iterate over node group ingress rules
    content {
      from_port       = ingress.value.from_port        # Starting port for ingress traffic
      to_port         = ingress.value.to_port          # Ending port for ingress traffic
      protocol        = ingress.value.protocol         # Protocol used (e.g., TCP)
      cidr_blocks     = ingress.value.cidr_blocks      # IPv4 CIDR blocks allowed for ingress
      security_groups = ingress.value.use_alb_sg ? [aws_security_group.alb.id] : []  # Use ALB SG if specified
    }
  }

  # Ingress rule to allow all traffic between nodes in the same security group
  ingress {
    description = "Allow all traffic between nodes in the same security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all protocols
    self        = true  # Restrict to traffic within the same security group
  }

  # Egress rule to allow outbound traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                # Allow all protocols
    cidr_blocks = ["0.0.0.0/0"]       # Allow traffic to any IPv4 address
  }

  # Ingress rule to allow traffic from the API to the nodes
  ingress {
    description     = "Allow all traffic from API to nodes"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"  # Allow all protocols
    security_groups = aws_eks_cluster.cluster.vpc_config[0].security_group_ids  # Allow traffic from the cluster's security groups
  }

  # Egress rule to allow outbound traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                # Allow all protocols
    cidr_blocks = ["0.0.0.0/0"]       # Allow traffic to any IPv4 address
  }

  # Tags for the security group, including default tags and custom name
  tags = merge(var.default_tags, {
    "Name"        = "${var.cluster_name}-${var.environment}-node-group-sg",  # Security group name for node groups
    "Environment" = var.environment  # Environment tag
  })
}
