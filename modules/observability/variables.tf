variable "name" {
  description = "Prefix for resource names."
  type        = string
}

variable "alert_email" {
  description = "Where to send alarms (confirm the SNS subscription email). Empty = no subscription."
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be an email address, or empty."
  }
}

variable "alb_arn_suffix" {
  description = "arn_suffix of the load balancer (CloudWatch dimension)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "arn_suffix of the API target group (CloudWatch dimension)."
  type        = string
}

variable "db_instance_id" {
  description = "RDS instance identifier (CloudWatch dimension)."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group the app writes to; JSON ERROR lines are counted."
  type        = string
}
