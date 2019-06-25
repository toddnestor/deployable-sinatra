provider "godaddy" {
}

module "development-sinatra" {
  source = "./modules/containerized-service"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  github_token = "${var.github_token}"

  name = "deployable-sinatra"
  environment = "development"
  git_branch = "develop"
  internal = false

  environment_variables = {
    RACK_ENV = "development"
  }
}

module "staging-sinatra" {
  source = "./modules/containerized-service"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  github_token = "${var.github_token}"

  name = "deployable-sinatra"
  environment = "staging"
  git_branch = "staging"
  subdomain = "test-two"
  internal = false

  environment_variables = {
    RACK_ENV = "staging"
    LetsTest = "If you see this it works"
    SomethingElse = "And if you see this it really works!"
  }
}

# GODADDY DNS #

resource "godaddy_domain_record" "subdomain" {
  domain   = "${var.dns_zone_name}"

  record {
    name = "${coalesce(module.development-sinatra.subdomain, module.development-sinatra.name)}"
    type = "CNAME"
    data = "${module.development-sinatra.alb_dns}"
    ttl = 600
  }

  record {
    name = "${coalesce(module.staging-sinatra.subdomain, module.staging-sinatra.name)}"
    type = "CNAME"
    data = "${module.staging-sinatra.alb_dns}"
    ttl = 600
  }
}

//resource "aws_rds_cluster" "postgresql" {
//  cluster_identifier      = "${var.environment}-minerva"
//  engine                  = "aurora-postgresql"
//  availability_zones      = ["us-east-1c", "us-east-1d"]
//  database_name           = "minerva"
//  master_username         = "testuser"
//  master_password         = "testpassword"
//  backup_retention_period = 5
//  preferred_backup_window = "07:00-09:00"
//  vpc_security_group_ids = ["whatever", "they", "are"]
//}
//
//module "minerva" {
//  source = "../modules/containerized-service"
//
//  name = "minerva"
//  environment = "${var.environment}"
//  git_branch = "master"
//  internal = false
//
//  environment_variables = {
//    RACK_ENV = "${var.environment}"
//    DB_USER = "${aws_rds_cluster.postgresql.master_username}"
//    DB_PASSWORD = "${aws_rds_cluster.postgresql.master_password}"
//    DB_NAME = "${aws_rds_cluster.postgresql.database_name}"
//    DB_HOST = "${aws_rds_cluster.postgresql.endpoint}"
//  }
//}
