output "api_url" {
  value = "http://${module.app.alb_dns_name}"
}

output "webhook_secrets_parameter" {
  description = "SSM parameter with the provider signing secrets (aws ssm get-parameter --with-decryption --name ...)."
  value       = module.app.webhook_secrets_parameter
}

output "alerts_topic_arn" {
  value = module.observability.alerts_topic_arn
}
