mock_provider "aws" {}

variables {
  name                  = "test"
  vpc_id                = "vpc-123"
  subnet_ids            = ["subnet-a", "subnet-b"]
  app_security_group_id = "sg-app"
}

run "private_encrypted_managed_password" {
  command = plan

  assert {
    condition     = !aws_db_instance.this.publicly_accessible
    error_message = "database must not be publicly accessible"
  }
  assert {
    condition     = aws_db_instance.this.storage_encrypted
    error_message = "storage must be encrypted"
  }
  assert {
    condition     = aws_db_instance.this.manage_master_user_password
    error_message = "password must be managed by RDS/Secrets Manager, not Terraform"
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.from_app.referenced_security_group_id == "sg-app" && aws_vpc_security_group_ingress_rule.from_app.cidr_ipv4 == null
    error_message = "only the app security group may reach the database"
  }
  assert {
    condition     = aws_db_instance.this.deletion_protection && !aws_db_instance.this.skip_final_snapshot
    error_message = "default must protect the database and take a final snapshot"
  }
}

run "disposable_dev_database" {
  command = plan
  variables {
    deletion_protection = false
  }
  assert {
    condition     = aws_db_instance.this.skip_final_snapshot
    error_message = "a disposable database should skip the final snapshot"
  }
}
