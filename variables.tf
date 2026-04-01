variable "aws_region" {
  description = "AWS region for the lab"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to AWS resource names/tags"
  type        = string
  default     = "pathnex-prom-graf-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (monitor host)"
  type        = string
  default     = "10.42.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (target host)"
  type        = string
  default     = "10.42.2.0/24"
}

variable "monitor_instance_type" {
  description = "EC2 instance type for the monitoring VM"
  type        = string
  default     = "t3.small"
}

variable "target_instance_type" {
  description = "EC2 instance type for the target VM"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access (optional, but recommended for labs)"
  type        = string
  default     = "Demo"
}

variable "grafana_ingress_cidr" {
  description = "CIDR allowed to access Grafana on port 3000 (set to your IP/32 for safety)"
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.grafana_ingress_cidr, 0))
    error_message = "grafana_ingress_cidr must be a valid CIDR, e.g. 203.0.113.10/32."
  }
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH into the monitor host. Defaults to grafana_ingress_cidr when null."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.ssh_ingress_cidr == null ? true : can(cidrhost(var.ssh_ingress_cidr, 0))
    error_message = "ssh_ingress_cidr must be null or a valid CIDR."
  }
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "pathnex"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "Pathnex@2026!"
  sensitive   = true
}
