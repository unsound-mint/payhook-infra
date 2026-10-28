variable "name" {
  description = "Prefix for resource names."
  type        = string
}

variable "cidr_block" {
  description = "CIDR of the VPC; subnets are carved out of it as /24s."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR like 10.20.0.0/16."
  }
}

variable "az_count" {
  description = "Number of availability zones to spread subnets over."
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "RDS subnet groups and the ALB need at least two AZs."
  }
}
