mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = { names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"] }
  }
}

variables {
  name = "test"
}

run "two_tiers_in_two_azs" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "expected 2 public and 2 private subnets"
  }
  assert {
    condition     = alltrue([for s in aws_subnet.private : !coalesce(s.map_public_ip_on_launch, false)])
    error_message = "private subnets must not assign public IPs"
  }
  assert {
    condition     = aws_subnet.public[0].availability_zone != aws_subnet.public[1].availability_zone
    error_message = "public subnets must be in different AZs"
  }
  assert {
    condition     = length(aws_route_table_association.private) == 2
    error_message = "every private subnet must use the private (no internet) route table"
  }
}

run "rejects_single_az" {
  command = plan
  variables {
    az_count = 1
  }
  expect_failures = [var.az_count]
}
