#################### Frequently Changeable Resources ####################

variable "cluster_name" {
  description = "The name of the Amazon EKS cluster. This name will be used for associating resources with the cluster, and should be unique within your environment."
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version. The version of Kubernetes used for the cluster. Keep this updated as new Kubernetes versions are released for compatibility and new features."
  type        = string
  default     = "1.30"
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, staging, prod). CLuster name will be client_name + environment, example coolclient-dev"
  type        = string
  default     = null
}

variable "ami_id" {
  description = "The ID of the AMI to use for the EKS worker nodes. This can be left as null to use the default AMI provided by Amazon EKS for the specified Kubernetes version."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region where the resources are deployed. This region should correspond to where your infrastructure and users are primarily located."
  type        = string
  default     = "us-west-2"
}

variable "default_tags" {
  description = "Default tags to apply to all resources. Tags help in identifying resources for cost allocation, auditing, and ownership purposes."
  type        = map(string)
  default = {
    "ManagedBy" = "Terraform"
    "Service"   = "EKS"
    "Owner"     = "DevOps Team"
  }
}

variable "admin_users" {
  description = "List of Kubernetes admins who will have full control over the cluster. These users will have access to manage the cluster and its resources."
  default     = [""]
}

variable "developer_users" {
  description = "List of Kubernetes developer users who will have limited access to the cluster based on RBAC rules. Developers usually have access to specific namespaces or resources."
  default     = []
}

variable "external_dns_domain_filters" {
  description = "List of domain filters for ExternalDNS. These domains define which DNS zones ExternalDNS will be responsible for managing. ExternalDNS will create and manage DNS records only within these domains."
  type        = list(string)
  default     = []
}


variable "alb_ingress_rules" {
  description = "List of ingress rules for the Application Load Balancer (ALB) security group. These rules define the allowed traffic to the ALB, such as HTTP and HTTPS traffic."
  type = list(object({
    description      = string
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = list(string)
    ipv6_cidr_blocks = list(string)
  }))
  default = [
    {
      description      = "http"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    },
    {
      description      = "https"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]
}

variable "node_group_sg_ingress_rules" {
  description = "List of ingress rules for the Node Group security group. These rules define the allowed traffic for the worker nodes."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    use_alb_sg  = bool
  }))
  default = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = []
      use_alb_sg  = true
    },
    {
      from_port   = 1025
      to_port     = 65535
      protocol    = "tcp"
      cidr_blocks = []
      use_alb_sg  = true
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = []
      use_alb_sg  = true
    }
  ]
}

######################### EKS Cluster Resources #########################

variable "vpc_name" {
  description = "The name or ID of the VPC where the EKS cluster will be deployed. This VPC must be configured with appropriate subnets and networking configurations for EKS."
  type        = string
}

variable "cluster_endpoint_private_access" {
  description = "Indicates whether the Amazon EKS private API server endpoint is enabled. When enabled, the Kubernetes API can be accessed via the private VPC network."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Indicates whether the Amazon EKS public API server endpoint is enabled. When enabled, the Kubernetes API server can be accessed over the internet (publicly). Use caution, as this exposes the API to the public."
  type        = bool
  default     = true
}

variable "cluster_logging_enabled" {
  description = "Indicates whether logging is enabled for the EKS cluster. Logging helps capture events from the Kubernetes control plane (such as API requests, authentication attempts, etc.)."
  type        = bool
  default     = true
}

variable "cluster_logging_types" {
  description = "List of cluster logging types to enable. Logging types can include 'api', 'audit', 'authenticator', 'controllerManager', and 'scheduler'. Enabling these helps in monitoring the cluster for security, performance, and troubleshooting."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "external_dns_policy" {
  description = "ExternalDNS policy determines how DNS records should be managed. 'sync' will sync the records, while 'upsert-only' allows adding and updating records but prevents deletions."
  type        = string
  default     = "sync"
}


variable "eks_cluster_ingress_rules" {
  description = "List of ingress rules for the EKS cluster security group. These rules define which traffic is allowed to communicate with the EKS control plane."
  type = list(object({
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = list(string)
    ipv6_cidr_blocks = list(string) # Optional: Use `null` if not needed
  }))
  default = [
    {
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]
}

######################### Node Group Resources #########################

variable "eks_node_groups" {
  description = "Map of EKS node groups with configurations. Node groups represent the worker nodes in your cluster, each with its own configuration of instance types, sizes, and networking settings."
  type = map(object({
    desired_size   = number            # Desired number of instances in the node group.
    max_size       = number            # Maximum number of instances allowed in the node group for scaling purposes.
    min_size       = number            # Minimum number of instances that should be running at any given time.
    instance_types = list(string)      # List of instance types (e.g., m5.large, t3.medium) used for the worker nodes in the node group.
    capacity_type  = string            # Capacity type (e.g., "ON_DEMAND" or "SPOT").
    labels         = map(string)       # Map of labels to apply to the nodes (used for scheduling and management).
    tags           = map(string)       # Additional tags to apply to the worker nodes for organizational purposes.
    network_interfaces = list(object({ # Network interface settings for each node (e.g., public/private IP address configurations).
      delete_on_termination       = bool
    }))
    block_device_mappings = map(object({ # Block device mappings, defining EBS volumes attached to the node instances.
      ebs = object({
        volume_size           = number
        volume_type           = string
        delete_on_termination = bool
      })
    }))
    bootstrap_arguments = optional(string, "") # Additional arguments passed to the EKS bootstrap script on the worker nodes.
  }))
}



######################### Helm Charts (Kube-system) #########################

variable "ingress_gateway_chart_name" {
  description = "The name of the Helm chart for the ingress gateway (typically for managing ALB). The ingress gateway allows external access to your Kubernetes services."
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "ingress_gateway_chart_repo" {
  description = "The repository URL for the ingress gateway Helm chart. This repository contains the Helm chart for deploying the ingress gateway in your Kubernetes cluster."
  type        = string
  default     = "https://aws.github.io/eks-charts"
}

variable "ingress_gateway_chart_version" {
  description = "The version of the ingress gateway Helm chart. Keep this updated with the latest stable version for new features and security updates."
  type        = string
}

variable "ebs_csi_controller_chart_name" {
  description = "The name of the Helm chart for the EBS CSI controller. This is used to manage EBS volumes as persistent storage in your Kubernetes cluster."
  type        = string
  default     = "aws-ebs-csi-driver"
}

variable "ebs_csi_controller_repository" {
  description = "The repository URL for the EBS CSI controller Helm chart. This contains the necessary resources to deploy the EBS CSI driver in your Kubernetes cluster."
  type        = string
  default     = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
}

variable "ebs_csi_controller_version" {
  description = "The version of the EBS CSI controller Helm chart. Ensure you're using the latest version for new features and security patches."
  type        = string
  default     = "2.34.0"
}

variable "ebs_csi_controller_namespace" {
  description = "The namespace where EBS CSI controller Helm chart should be deployed. By default, it is installed in the 'kube-system' namespace."
  default     = "kube-system"
}

variable "external_dns_chart_name" {
  description = "The name of the Helm chart for ExternalDNS. ExternalDNS automates the creation and management of DNS records for Kubernetes resources such as Services and Ingresses."
  type        = string
  default     = "external-dns"
}

variable "external_dns_chart_repo" {
  description = "The repository URL for the ExternalDNS Helm chart. This repository contains the Helm chart for deploying ExternalDNS, enabling Kubernetes to manage DNS records automatically."
  type        = string
  default     = "https://kubernetes-sigs.github.io/external-dns/"
}

variable "external_dns_chart_version" {
  description = "The version of the ExternalDNS Helm chart. Keeping this version up to date ensures compatibility with the latest Kubernetes and DNS features."
  type        = string
  default     = "1.12.2"
}

variable "spot_termination_handler_version" {
  description = "Version of the spot termination handler Helm chart. This chart helps manage and gracefully terminate EC2 Spot instances when AWS reclaims them."
  type        = string
  default     = "0.18.0"
}

