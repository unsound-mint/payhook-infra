output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "github_plan_role_arn" {
  description = "Read-only role for plans. Set as the AWS_PLAN_ROLE_ARN repository variable in GitHub."
  value       = aws_iam_role.github_plan.arn
}

output "github_role_arn" {
  description = "Apply/destroy role, assumable only from the production environment. Set as the AWS_ROLE_ARN repository variable in GitHub."
  value       = aws_iam_role.github.arn
}
