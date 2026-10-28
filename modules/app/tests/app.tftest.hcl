mock_provider "aws" {
  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }
  mock_data "aws_region" {
    defaults = { region = "eu-central-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_elb_service_account" {
    defaults = { arn = "arn:aws:iam::054676820928:root" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

mock_provider "random" {}

variables {
  name              = "test"
  environment       = "dev"
  vpc_id            = "vpc-123"
  vpc_cidr          = "10.20.0.0/16"
  public_subnet_ids = ["subnet-a", "subnet-b"]
  db_address        = "db.internal"
  db_port           = 5432
  db_name           = "payhook"
  db_username       = "payhook"
  db_secret_arn     = "arn:aws:secretsmanager:eu-central-1:123456789012:secret:rds-db"
}

run "hardened_instances" {
  command = plan

  assert {
    condition     = aws_launch_template.app.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required"
  }
  assert {
    condition     = aws_launch_template.app.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "root volume must be encrypted"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.app_from_alb.cidr_ipv4 == null
    error_message = "app instances must only accept traffic from the ALB security group"
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.app_postgres.cidr_ipv4 == "10.20.0.0/16"
    error_message = "database egress must stay inside the VPC"
  }
  assert {
    condition     = aws_lb.this.drop_invalid_header_fields
    error_message = "ALB should drop invalid headers"
  }
  assert {
    condition     = aws_autoscaling_group.app.health_check_type == "ELB"
    error_message = "ASG should replace instances the ALB marks unhealthy"
  }
}

run "deploys_start_replacements_first" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.app.instance_refresh[0].preferences[0].min_healthy_percentage == 100 && aws_autoscaling_group.app.instance_refresh[0].preferences[0].auto_rollback == true
    error_message = "instance refresh must keep full capacity and roll back on failure, or a one-instance deploy is downtime"
  }
}

run "secrets_not_in_user_data" {
  command = plan

  assert {
    # Every secret in the .env file must come from a shell variable filled at
    # boot from Secrets Manager / SSM, never a literal rendered by Terraform.
    condition = alltrue([
      for k in ["PAYHOOK_WEBHOOK_SECRETS", "PAYHOOK_CALLBACK_SECRET"] :
      can(regex("${k}=\\$\\{", base64decode(aws_launch_template.app.user_data)))
    ]) && strcontains(base64decode(aws_launch_template.app.user_data), "secretsmanager get-secret-value")
    error_message = "user data must fetch secrets at boot, not embed them"
  }
  assert {
    condition     = strcontains(base64decode(aws_launch_template.app.user_data), "ghcr.io/unsound-mint/payhook:main")
    error_message = "user data should run the configured image"
  }
}

run "http_only_without_certificate" {
  command = plan
  assert {
    condition     = length(aws_lb_listener.https) == 0 && aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "without a certificate, HTTP should forward to the app"
  }
}

run "https_redirect_with_certificate" {
  command = plan
  variables {
    certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/abc"
  }
  assert {
    condition     = length(aws_lb_listener.https) == 1 && aws_lb_listener.http.default_action[0].type == "redirect"
    error_message = "with a certificate, HTTP should redirect to HTTPS"
  }
}

run "certificate_required_outside_dev" {
  command = plan
  variables {
    environment = "prod"
    image_tag   = "0a1b2c3d4e5f"
  }
  expect_failures = [var.certificate_arn]
}

run "prod_with_certificate_is_accepted" {
  command = plan
  variables {
    environment     = "prod"
    image_tag       = "v1.2.3"
    certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/abc"
  }
  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "a prod environment with a certificate should serve HTTPS"
  }
}

run "compose_binary_is_verified" {
  command = plan
  assert {
    condition     = strcontains(base64decode(aws_launch_template.app.user_data), "sha256sum -c")
    error_message = "the docker-compose download must be checksum-verified at boot"
  }
}

run "moving_image_tag_rejected_outside_dev" {
  command = plan
  variables {
    environment     = "prod"
    certificate_arn = "arn:aws:acm:eu-central-1:123456789012:certificate/abc"
  }
  expect_failures = [var.image_tag]
}

run "pinned_ami_skips_the_ssm_lookup" {
  command = plan
  variables {
    ami_id = "ami-0aaaaaaaaaaaaaaaa"
  }
  assert {
    condition     = aws_launch_template.app.image_id == "ami-0aaaaaaaaaaaaaaaa" && length(data.aws_ssm_parameter.al2023) == 0
    error_message = "a pinned ami_id must be used as is"
  }
}

run "desired_capacity_must_fit_the_bounds" {
  command = plan
  variables {
    min_size         = 2
    max_size         = 3
    desired_capacity = 1
  }
  expect_failures = [var.desired_capacity]
}

run "min_size_cannot_exceed_max_size" {
  command = plan
  variables {
    min_size         = 4
    max_size         = 3
    desired_capacity = 3
  }
  expect_failures = [var.min_size]
}
