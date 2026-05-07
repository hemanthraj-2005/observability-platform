variable "aws_region" {
  description = "AWS region where the observability host will be created."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used for AWS resource names and tags."
  type        = string
  default     = "observability-platform"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "Existing VPC ID. Leave empty to use the default VPC."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Existing subnet ID. Leave empty to use the first default VPC subnet."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for the observability host."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Existing EC2 key pair name used for SSH access."
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to access SSH."
  type        = string
}

variable "allowed_app_cidr" {
  description = "CIDR allowed to access exposed app and observability ports."
  type        = string
  default     = "0.0.0.0/0"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB."
  type        = number
  default     = 30
}
