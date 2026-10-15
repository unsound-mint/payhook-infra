variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "image_tag" {
  type    = string
  default = "main"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "alert_email" {
  type    = string
  default = ""
}
