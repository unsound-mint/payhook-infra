variable "name" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the database security group."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets (at least two AZs) for the DB subnet group."
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Security group allowed to reach PostgreSQL."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "multi_az" {
  description = "Standby replica in a second AZ. Off by default to keep dev cheap; turn it on for production."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Days of automated backups to keep."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Keep true for anything that matters; false lets a demo environment be destroyed in one command."
  type        = bool
  default     = true
}
