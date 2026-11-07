variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "advanced-devops-lab"
}

variable "cluster_name" {
  type    = string
  default = "devops-eks-cluster"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach EKS public API; use EC2 public IP/32"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired" {
  type    = number
  default = 2
}

variable "node_min" {
  type    = number
  default = 1
}

variable "node_max" {
  type    = number
  default = 3
}
