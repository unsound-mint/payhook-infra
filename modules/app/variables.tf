variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "image_repository" {
  type    = string
  default = "ghcr.io/unsound-mint/payhook"
}

variable "image_tag" {
  description = "Image tag to run. Changing it rolls the instances (instance refresh)."
  type        = string
  default     = "main"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "certificate_arn" {
  description = "ACM certificate for HTTPS. Empty = HTTP only (fine for a demo, not for real payments)."
  type        = string
  default     = ""
}

variable "providers_list" {
  description = "Payment providers that may send webhooks; one signing secret is generated per provider."
  type        = list(string)
  default     = ["halyk", "kaspi"]
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "compose_version" {
  type    = string
  default = "v2.39.4"
}

variable "db_address" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_secret_arn" {
  type = string
}
