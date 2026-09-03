variable "vpc_id" {
  description = "VPC where the EKS security groups will be created"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

