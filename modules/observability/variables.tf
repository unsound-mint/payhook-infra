variable "name" {
  type = string
}

variable "alert_email" {
  description = "Where to send alarms (confirm the SNS subscription email). Empty = no subscription."
  type        = string
  default     = ""
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "log_group_name" {
  type = string
}
