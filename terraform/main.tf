##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-2"
}

##################################################################################
# RESOURCES
##################################################################################

# S3

//resource "aws_s3_bucket" "logs_bucket" {
//  bucket = "${var.environment}-sinatra-alb-logs"
//}
//
//resource "aws_iam_role" "logs_role" {
//  name = "alb-logs-role"
//
//  assume_role_policy = <<EOF
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Action": "sts:AssumeRole",
//      "Principal": {
//        "Service": "s3.amazonaws.com"
//      },
//      "Effect": "Allow",
//      "Sid": ""
//    }
//  ]
//}
//EOF
//}
//
//resource "aws_iam_role_policy" "codepipeline_policy" {
//  name = "alb_logs_policy"
//  role = "${aws_iam_role.logs_role.id}"
//
//  policy = <<EOF
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Effect":"Allow",
//      "Action": [
//        "s3:*"
//      ],
//      "Resource": [
//        "${aws_s3_bucket.logs_bucket.arn}",
//        "${aws_s3_bucket.logs_bucket.arn}/*"
//      ]
//    }
//  ]
//}
//EOF
//}

# ALB

module "raise_ror_frontend_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "2.17.0"

  name        = "PublicWebServer80"
  description = "Security group for web-server with HTTP ports open to EVERYONE"
  vpc_id      = "${var.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    User           = "Terraform"
    Name           = "PublicWebServer80"
    "User:Service" = "MainRorApp"
    Environment    = "${var.environment}"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "3.5.0"

  load_balancer_name = "${var.environment}-ALBSinatra"

  security_groups = ["${module.raise_ror_frontend_sg.this_security_group_id}"]
  subnets         = ["${var.public_subnet_ids}"]
  vpc_id          = "${var.vpc_id}"

  enable_cross_zone_load_balancing = true
  load_balancer_is_internal        = false
  logging_enabled = false
  # log_bucket_name                  = "${aws_s3_bucket.logs_bucket.bucket}"

  tags = {
    User           = "Terraform"
    Name           = "ALBMRorApp"
    "User:Service" = "MainRorApp"
    Environment    = "${var.environment}"
  }
}

# ECS

resource "aws_ecs_cluster" "sinatra" {
  name = "ECS${var.environment}"
  tags = {
    User        = "Terraform"
    Name        = "ECS${var.environment}"
    "User:Service" = "MainRorApp"
    Environment = "${var.environment}"
  }
}

# FARGATE

module "ecs-fargate" {
  # The registry module does not currently output the name of the auto-generated
  # LB Target Group.  It also does not support modifying the deployment controller
  # type.  As such, the project was forked, with modifications made.
  # A pull request has been opened with the maintainer to implement the same
  # functionality.  When https://github.com/telia-oss/terraform-aws-ecs-fargate/pull/13
  # and https://github.com/telia-oss/terraform-aws-ecs-fargate/pull/14
  # is merged, the below commented out source should be reinstated, with the
  # new version applied which includes the new output functionality.

  source  = "git::https://github.com/RaiseMe/terraform-aws-ecs-fargate.git?ref=tags/v0.1.2.5"

  cluster_id         = "${aws_ecs_cluster.sinatra.arn}"
  lb_arn             = "${module.alb.load_balancer_id}"
  name_prefix        = "${var.environment}-sinatra"
  private_subnet_ids = ["${var.public_subnet_ids}"]
  vpc_id             = "${var.vpc_id}"

  task_container_image = "${module.ecr.registry_url}:${var.container_version}"
  task_container_port  = "4000"

  task_container_environment_count = 10
  task_container_environment       = {
    ROR_PORT = "4000"
    AWS_ACCESS_KEY_ID = "${var.aws_access_key}"
    AWS_SECRET_ACCESS_KEY = "${var.aws_secret_key}"
    RACK_ENV = "${var.environment}"
    RAILS_ENV = "${var.environment}"
    RAILS_SKIP_ASSET_COMPILATION = "true"
    RAILS_SKIP_MIGRATIONS = "true"
  }

  deployment_controller_type = "CODE_DEPLOY"

  desired_count        = "2"
  health_check         = {
    port = "4000"
    path = "/"
    interval = 60
  }

  tags = {
    User        = "Terraform"
    Name        = "Fargate${var.environment}"
    "User:Service" = "MainRorApp"
    Environment = "${var.environment}"
  }
}

resource "aws_lb_target_group" "green" {
  #  name         = "green"
  vpc_id       = "${var.vpc_id}"
  port         = "4000"
  protocol     = "HTTP"
  target_type  = "ip"
  health_check = {
    port = "4000"
    path = "/"
    interval = 60
  }

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefor we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    User        = "Terraform"
    Name        = "${var.environment}-ror-target-4000-green"
    "User:Service" = "MainRorApp"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group_rule" "lb_to_containers" {
  security_group_id        = "${module.ecs-fargate.service_sg_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "4000"
  to_port                  = "4000"
  source_security_group_id = "${module.raise_ror_frontend_sg.this_security_group_id}"
}

# resource "aws_alb_listener" "frontend" {
#   load_balancer_arn = "${aws_ecs_cluster.sinatra.arn}"
#   port              = "80"
#   protocol          = "HTTP"

#   default_action = {
#     target_group_arn = "${module.ecs-fargate.target_group_arn}"
#     type             = "forward"
#   }
# }

resource "aws_alb_listener" "front_end_80" {
  load_balancer_arn = "${module.alb.load_balancer_id}"
  port = "80"
  protocol = "HTTP"

  default_action = {
    type = "forward"
    target_group_arn = "${module.ecs-fargate.target_group_arn}"
  }
}

# ECR

module "ecr" {
  source              = "git::https://github.com/cloudposse/terraform-aws-ecr.git?ref=master"
  name                = "${var.registry_name}"
  namespace           = "${var.namespace}"
  stage               = "${var.environment}"
}

# CODEPIPELINE

module "build" {
  source              = "git::https://github.com/cloudposse/terraform-aws-cicd.git?ref=master"
  namespace           = "${var.namespace}"
  name                = "${var.registry_name}"
  stage               = "${var.environment}"

  # Enable the pipeline creation
  enabled             = "true"

  # Application repository on GitHub
  github_oauth_token  = "${var.github_token}"
  repo_owner          = "toddnestor"
  repo_name           = "deployable-sinatra"
  branch              = "develop"

  # http://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html
  # http://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
  build_image         = "aws/codebuild/docker:1.12.1"
  build_compute_type  = "BUILD_GENERAL1_SMALL"

  # These attributes are optional, used as ENV variables when building Docker images and pushing them to ECR
  # For more info:
  # http://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html
  # https://www.terraform.io/docs/providers/aws/r/codebuild_project.html
  privileged_mode     = "true"
  image_repo_name     = "${module.ecr.repository_name}"
  image_tag           = "${var.environment}"
}
