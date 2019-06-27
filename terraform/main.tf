provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-2"
}

provider "godaddy" {}

module "development-sinatra" {
  source = "./modules/containerized-service"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  github_token   = "${var.github_token}"

  name        = "deployable-sinatra"
  environment = "development"
  git_branch  = "develop"
  internal    = false
  container_version = "deployable-sinatra-8476aa0"

  environment_variables = {
    RACK_ENV = "development"
    THIS_BE_REAL = "I GOTS THIS"
  }
}
//
//module "staging-sinatra" {
//  source = "./modules/containerized-service"
//
//  aws_access_key = "${var.aws_access_key}"
//  aws_secret_key = "${var.aws_secret_key}"
//  github_token   = "${var.github_token}"
//
//  name        = "deployable-sinatra"
//  environment = "staging"
//  git_branch  = "staging"
//  subdomain   = "test-two"
//  internal    = false
//  container_version = "deployable-sinatra-9f3f04c"
//
//  environment_variables = {
//    RACK_ENV      = "staging"
//    LetsTest      = "If you see this it works"
//    SomethingElse = "And if you see this it really works!"
//  }
//}

//resource "aws_db_subnet_group" "default" {
//  name       = "main"
//  subnet_ids = ["subnet-317cbe4b", "subnet-671c222a"]
//
//  tags = {
//    Name = "My DB subnet group"
//  }
//}
//
//resource "aws_rds_cluster_instance" "postgresql_instances" {
//  count              = 2
//  identifier         = "${var.environment}-minerva-${count.index}"
//  cluster_identifier = "${aws_rds_cluster.postgresql.id}"
//  instance_class     = "db.r4.large"
//  engine             = "aurora-postgresql"
//}
//
//resource "aws_rds_cluster" "postgresql" {
//  cluster_identifier      = "${var.environment}-minerva"
//  engine                  = "aurora-postgresql"
//  availability_zones      = ["us-east-2a", "us-east-2b", "us-east-2c"]
//  database_name           = "minerva"
//  master_username         = "minerva"
//  master_password         = "student9"
//  backup_retention_period = 5
//  preferred_backup_window = "07:00-09:00"
//  db_subnet_group_name    = "${aws_db_subnet_group.default.name}"
//  skip_final_snapshot     = true
//}
//
//module "minerva" {
//  source = "./modules/containerized-service"
//
//  aws_access_key = "${var.aws_access_key}"
//  aws_secret_key = "${var.aws_secret_key}"
//  github_token   = "${var.github_token}"
//
//  name        = "minerva"
//  environment = "${var.environment}"
//  git_branch  = "develop"
//  internal    = false
//  repo_owner  = "RaiseMe"
//  container_version = "minerva-bcd477a"
//
//  environment_variables = {
//    RACK_ENV    = "staging"
//    DB_USER     = "${aws_rds_cluster.postgresql.master_username}"
//    DB_PASSWORD = "${aws_rds_cluster.postgresql.master_password}"
//    DB_NAME     = "${aws_rds_cluster.postgresql.database_name}"
//    DB_HOST     = "${aws_rds_cluster.postgresql.endpoint}"
//  }
//}

# GODADDY DNS #

resource "godaddy_domain_record" "subdomain" {
  domain = "${var.dns_zone_name}"

  record {
    name = "${coalesce(module.development-sinatra.subdomain, module.development-sinatra.name)}"
    type = "CNAME"
    data = "${module.development-sinatra.alb_dns}"
    ttl  = 600
  }
//
//  record {
//    name = "${coalesce(module.staging-sinatra.subdomain, module.staging-sinatra.name)}"
//    type = "CNAME"
//    data = "${module.staging-sinatra.alb_dns}"
//    ttl  = 600
//  }

//  record {
//    name = "${module.minerva.name}"
//    type = "CNAME"
//    data = "${module.minerva.alb_dns}"
//    ttl  = 600
//  }
}
