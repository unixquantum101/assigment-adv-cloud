variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Prefix used in resource names and tags."
  type        = string
  default     = "cc-project"
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type for every swarm node."
  type        = string
  default     = "t3.micro"
}

variable "worker_count" {
  description = "Number of swarm worker nodes (rubric: at least 2)."
  type        = number
  default     = 2
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.20.1.0/24"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.7/32). Only this address may SSH in."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr must be a valid CIDR and must not be 0.0.0.0/0."
  }
}

variable "public_key_path" {
  description = "Path to the SSH PUBLIC key uploaded as the EC2 key pair."
  type        = string
  default     = "~/.ssh/cc-project.pub"
}

variable "private_key_path" {
  description = "Path to the matching SSH PRIVATE key (used only by the swarm bootstrap provisioners; never stored in state or git)."
  type        = string
  default     = "~/.ssh/cc-project"
}
