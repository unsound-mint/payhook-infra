variable "name" {
  description = "Prefix for resource names, e.g. payhook-dev."
  type        = string
}

variable "environment" {
  description = "Environment name. Anything other than \"dev\" must set certificate_arn: a payments API doesn't get plain HTTP."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the security groups and target group."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR; the only range the instances may reach on 5432."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR like 10.20.0.0/16."
  }
}

variable "public_subnet_ids" {
  description = "Subnets for the ALB and the instances (at least two AZs)."
  type        = list(string)
}

variable "image_repository" {
  description = "Container image repository (without the tag)."
  type        = string
  default     = "ghcr.io/unsound-mint/payhook"
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
  description = "EC2 instance type."
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 1

  validation {
    condition     = var.min_size >= 1 && var.min_size <= var.max_size
    error_message = "min_size must be at least 1 and no larger than max_size."
  }
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Initial number of instances; target tracking changes it afterwards."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_capacity >= var.min_size && var.desired_capacity <= var.max_size
    error_message = "desired_capacity must be between min_size and max_size."
  }
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
  description = "Days to keep application logs in CloudWatch (must be a value CloudWatch accepts, e.g. 7, 14, 30)."
  type        = number
  default     = 14
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
  description = "Database host name."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "db_username" {
  description = "Database user."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager secret holding the database password (JSON with a password key)."
  type        = string
}
