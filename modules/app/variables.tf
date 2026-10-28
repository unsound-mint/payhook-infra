variable "name" {
  description = "Prefix for resource names, e.g. payhook-dev."
  type        = string
}

variable "environment" {
  description = "Environment name. Anything other than \"dev\" must set certificate_arn: a payments API doesn't get plain HTTP."
  type        = string
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
  description = "Image tag to run. Changing it rolls the instances (instance refresh). Outside dev use an immutable tag (a commit SHA or a version): a moving tag like \"main\" means instances launched later can run different code than the ones already running."
  type        = string
  default     = "main"

  validation {
    condition     = var.environment == "dev" || can(regex("^([0-9a-f]{7,40}|v?[0-9]+\\.[0-9]+\\.[0-9]+)$", var.image_tag))
    error_message = "Outside dev, image_tag must be a commit SHA or a version like v1.2.3, not a moving tag."
  }
}

variable "ami_id" {
  description = "AMI to launch. Empty = the latest Amazon Linux 2023 AMI at plan time, so a new AWS release shows up as a launch template change and rolls the instances. Set it to pin and upgrade on purpose."
  type        = string
  default     = ""

  validation {
    condition     = var.ami_id == "" || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must look like ami-0123456789abcdef0, or be empty."
  }
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

  validation {
    condition     = var.certificate_arn != "" || var.environment == "dev"
    error_message = "certificate_arn is required outside the dev environment: without it the ALB serves plain HTTP."
  }
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
  description = "Docker Compose release installed at boot. Change compose_sha256 with it."
  type        = string
  default     = "v2.39.4"
}

variable "compose_sha256" {
  description = "SHA-256 of docker-compose-linux-x86_64 for compose_version (from the release's .sha256 file). The boot script refuses a binary that doesn't match."
  type        = string
  default     = "7af95166a730b87e172d4fc9aefea8725d3c6c7327d59149267b452114ddb7d4"

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.compose_sha256))
    error_message = "compose_sha256 must be 64 lowercase hex characters."
  }
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
