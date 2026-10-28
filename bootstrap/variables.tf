variable "region" {
  description = "Region for the state bucket and IAM resources."
  type        = string
  default     = "eu-central-1"
}

variable "github_repo" {
  description = "owner/name of the repository allowed to deploy"
  type        = string
  default     = "unsound-mint/payhook-infra"
}
