output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "github_role_arn" {
  description = "Set as the AWS_ROLE_ARN repository variable in GitHub."
  value       = aws_iam_role.github.arn
}
