output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "autoscaling_group_name" {
  value = aws_autoscaling_group.app.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "webhook_secrets_parameter" {
  value = aws_ssm_parameter.webhook_secrets.name
}
