variable "region" {
  description = "AWS region. The S3 backend block pins its own region, so change both."
  type        = string
  default     = "eu-central-1"
}

variable "image_tag" {
  description = "payhook image tag to run. Dev follows the moving main tag; use a commit SHA to pin."
  type        = string
  default     = "main"
}

variable "ami_id" {
  description = "Pin the instance AMI. Empty = latest Amazon Linux 2023 at plan time."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for the app."
  type        = string
  default     = "t3.small"
}

variable "certificate_arn" {
  description = "ACM certificate for HTTPS. Empty = plain HTTP (demo mode)."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Where to send alarms. Empty = no subscription."
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address, or empty."
  }
}
