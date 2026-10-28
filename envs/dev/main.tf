terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # State in S3 with native lockfile locking (no DynamoDB table needed since Terraform 1.10).
  # The bucket is created by ../../bootstrap. Bucket name is passed at init:
  #   terraform init -backend-config="bucket=<state bucket>"
  backend "s3" {
    key          = "payhook/dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "payhook"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name = "payhook-dev"
}

module "network" {
  source = "../../modules/network"
  name   = local.name
}

module "app" {
  source            = "../../modules/app"
  name              = local.name
  environment       = "dev"
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  image_tag         = var.image_tag
  instance_type     = var.instance_type
  certificate_arn   = var.certificate_arn

  db_address    = module.database.address
  db_port       = module.database.port
  db_name       = module.database.db_name
  db_username   = module.database.username
  db_secret_arn = module.database.master_secret_arn
}

module "database" {
  source                = "../../modules/database"
  name                  = local.name
  vpc_id                = module.network.vpc_id
  subnet_ids            = module.network.private_subnet_ids
  app_security_group_id = module.app.app_security_group_id
  # dev: cheap and disposable
  instance_class        = "db.t4g.micro"
  backup_retention_days = 1
  deletion_protection   = false
}

module "observability" {
  source                  = "../../modules/observability"
  name                    = local.name
  alert_email             = var.alert_email
  alb_arn_suffix          = module.app.alb_arn_suffix
  target_group_arn_suffix = module.app.target_group_arn_suffix
  db_instance_id          = module.database.instance_id
  log_group_name          = module.app.log_group_name
}
