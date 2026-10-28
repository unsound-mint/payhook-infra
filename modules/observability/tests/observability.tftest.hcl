mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_resource "aws_sns_topic" {
    defaults = { arn = "arn:aws:sns:eu-central-1:123456789012:test-alerts" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:eu-central-1:123456789012:key/00000000-0000-0000-0000-000000000000" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}

variables {
  name                    = "test"
  alb_arn_suffix          = "app/test/abc"
  target_group_arn_suffix = "targetgroup/test-api/abc"
  db_instance_id          = "test"
  log_group_name          = "/test/app"
}

run "alerts_topic_uses_customer_managed_key" {
  command = apply # the key ARN is only known after apply (mocked)

  assert {
    condition     = aws_sns_topic.alerts.kms_master_key_id != "alias/aws/sns" && aws_kms_key.alerts.enable_key_rotation
    error_message = "alarms can't publish to a topic encrypted with the AWS-managed SNS key"
  }
}

run "total_outage_alarm_fires_on_missing_data" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.no_healthy_targets.treat_missing_data == "breaching"
    error_message = "no healthy hosts must alarm even when the metric disappears"
  }
}

run "no_subscription_without_email" {
  command = plan

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "an empty alert_email must not create a subscription"
  }
}
