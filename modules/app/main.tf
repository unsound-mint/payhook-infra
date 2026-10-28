# Application tier: public ALB -> Auto Scaling group of EC2 instances running the
# payhook containers (api, relay, worker) plus a local NATS JetStream with Docker Compose.

data "aws_region" "current" {}

# Latest Amazon Linux 2023 AMI, resolved at plan time from AWS's public SSM
# parameter. Skipped when ami_id pins one.
data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.al2023[0].value
}

# ---------- security groups ----------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public HTTP(S) to the load balancer"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count             = var.certificate_arn == "" ? 0 : 1
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "App instances: HTTP from the ALB only, no SSH"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

# Outbound: HTTPS for image pulls, AWS APIs and merchant callbacks; PostgreSQL
# inside the VPC only. (DNS, NTP and instance metadata use link-local addresses
# that security groups don't filter.)
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "images, AWS APIs, merchant callbacks"
}

resource "aws_vpc_security_group_egress_rule" "app_postgres" {
  security_group_id = aws_security_group.app.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  description       = "RDS"
}

# ---------- load balancer ----------

resource "aws_lb" "this" {
  name                       = var.name
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  idle_timeout               = 30

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    enabled = true
  }
  depends_on = [aws_s3_bucket_policy.alb_logs]
}

resource "aws_lb_target_group" "api" {
  name                 = "${var.name}-api"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 20 # matches the app's graceful shutdown window

  health_check {
    path                = "/readyz"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = var.certificate_arn == "" ? "forward" : "redirect"
    target_group_arn = var.certificate_arn == "" ? aws_lb_target_group.api.arn : null

    dynamic "redirect" {
      for_each = var.certificate_arn == "" ? [] : [1]
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = var.certificate_arn == "" ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ---------- secrets ----------

resource "random_password" "webhook" {
  for_each = toset(var.providers_list)
  length   = 40
  special  = false
}

resource "random_password" "callback" {
  length  = 40
  special = false
}

# "halyk=...,kaspi=..." as the app expects it.
resource "aws_ssm_parameter" "webhook_secrets" {
  name  = "/${var.name}/webhook-secrets"
  type  = "SecureString"
  value = join(",", [for p in var.providers_list : "${p}=${random_password.webhook[p].result}"])
}

resource "aws_ssm_parameter" "callback_secret" {
  name  = "/${var.name}/callback-secret"
  type  = "SecureString"
  value = random_password.callback.result
}

# ---------- instances ----------

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.name}/app"
  retention_in_days = var.log_retention_days
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.name}-"
  image_id      = local.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile { arn = aws_iam_instance_profile.app.arn }

  # IMDSv2 only: blocks the SSRF-to-credentials attack on the metadata service.
  metadata_options {
    http_tokens                 = "required"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2 # containers need one extra hop
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    region              = data.aws_region.current.region
    image               = "${var.image_repository}:${var.image_tag}"
    log_group           = aws_cloudwatch_log_group.app.name
    db_host             = var.db_address
    db_port             = var.db_port
    db_name             = var.db_name
    db_user             = var.db_username
    db_secret_arn       = var.db_secret_arn
    webhook_secrets_ssm = aws_ssm_parameter.webhook_secrets.name
    callback_secret_ssm = aws_ssm_parameter.callback_secret.name
    compose_version     = var.compose_version
    compose_sha256      = var.compose_sha256
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = var.name
  vpc_zone_identifier       = var.public_subnet_ids
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  target_group_arns         = [aws_lb_target_group.api.arn]
  health_check_type         = "ELB" # replace instances the ALB marks unhealthy
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = aws_launch_template.app.latest_version
  }

  # A new launch template version (new image tag, new user data) replaces the
  # instances. At 100% minimum healthy with a 200% ceiling the group launches
  # replacements before terminating old instances, so a one-instance group
  # doesn't go down during a deploy. If the replacements fail their health
  # checks the refresh is rolled back to the previous launch template version.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      instance_warmup        = 120
      auto_rollback          = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60
  }
}
