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

module "raise_ror_frontend_sg_80" {
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

module "raise_ror_frontend_sg_8443" {
  source = "terraform-aws-modules/security-group/aws//modules/https-8443"
  version = "2.17.0"

  name        = "PublicWebServer8443"
  description = "Security group for web-server with HTTPS ports open to EVERYONE"
  vpc_id      = "${var.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    User           = "Terraform"
    Name           = "PublicWebServer8443"
    "User:Service" = "MainRorApp"
    Environment    = "${var.environment}"
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "3.5.0"

  load_balancer_name = "${var.environment}-ALBSinatra"

  security_groups = ["${module.raise_ror_frontend_sg_80.this_security_group_id}"]
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
  task_container_assign_public_ip = true

  task_container_environment_count = 10
  task_container_environment       = {
    RACK_ENV = "${var.environment}"
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

resource "aws_lb_target_group" "blue" {
  vpc_id       = "${var.vpc_id}"
  port         = "4001"
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
  from_port                = "80"
  to_port                  = "4000"
  source_security_group_id = "${module.raise_ror_frontend_sg_80.this_security_group_id}"
}

resource "aws_alb_listener" "front_end_80" {
  load_balancer_arn = "${module.alb.load_balancer_id}"
  port = "80"
  protocol = "HTTP"

  default_action = {
    type = "forward"
    target_group_arn = "${module.ecs-fargate.target_group_arn}"
  }
}

resource "aws_alb_listener" "front_end_8443" {
  load_balancer_arn = "${module.alb.load_balancer_id}"
  port              = "8443"
  protocol          = "HTTP"

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

//module "build" {
//  source              = "git::https://github.com/cloudposse/terraform-aws-cicd.git?ref=master"
//  namespace           = "${var.namespace}"
//  name                = "${var.registry_name}"
//  stage               = "${var.environment}"
//
//  # Enable the pipeline creation
//  enabled             = "true"
//
//  # Application repository on GitHub
//  github_oauth_token  = "${var.github_token}"
//  repo_owner          = "toddnestor"
//  repo_name           = "deployable-sinatra"
//  branch              = "develop"
//
//  # http://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref.html
//  # http://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html
//  build_image         = "aws/codebuild/docker:1.12.1"
//  build_compute_type  = "BUILD_GENERAL1_SMALL"
//
//  # These attributes are optional, used as ENV variables when building Docker images and pushing them to ECR
//  # For more info:
//  # http://docs.aws.amazon.com/codebuild/latest/userguide/sample-docker.html
//  # https://www.terraform.io/docs/providers/aws/r/codebuild_project.html
//  privileged_mode     = "true"
//  image_repo_name     = "${module.ecr.repository_name}"
//  image_tag           = "${var.environment}"
//}

# NEW CODEPIPELINE

module "codedeploy-for-ecs" {
  source                     = "tmknom/codedeploy-for-ecs/aws"
  version                    = "1.2.0"
  name                       = "${var.environment}-sinatra"
  ecs_cluster_name           = "${aws_ecs_cluster.sinatra.name}"
  ecs_service_name           = "${var.environment}-sinatra"
  lb_listener_arns           = ["${module.alb.load_balancer_id}"]
  blue_lb_target_group_name  = "${aws_lb_target_group.green.name}"
  green_lb_target_group_name = "${aws_lb_target_group.blue.name}"

  auto_rollback_enabled            = true
  auto_rollback_events             = ["DEPLOYMENT_FAILURE"]
  action_on_timeout                = "STOP_DEPLOYMENT"
  wait_time_in_minutes             = 5
  termination_wait_time_in_minutes = 0
  iam_path                         = "/service-role/"

  # A listener can be defined for directing pre-blue/green failover traffic to.
//  test_traffic_route_listener_arns = ["${local.alb_listener_test_arns}"]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "iam_codepipeline_role" {
  name = "iam_codepipeline"
  permissions_boundary = ""
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}
resource "aws_iam_role_policy" "iam_codepipeline_policy" {
  name = "iam_codepipeline_policy"
  role = "${aws_iam_role.iam_codepipeline_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "codebuild:StartBuild",
                "codebuild:BatchGetBuilds"
            ],
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role" "iam_ecs_service_role" {
  name = "ecsServiceRole"
  path = "/"
  permissions_boundary = ""
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "ecsServiceRolePolicy" {
  name = "ecsServiceRolePolicy"
  role = "${aws_iam_role.iam_ecs_service_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:Describe*",
            "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
            "elasticloadbalancing:DeregisterTargets",
            "elasticloadbalancing:Describe*",
            "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
            "elasticloadbalancing:RegisterTargets"
        ],
        "Resource": "*"
    }
  ]
}
POLICY
}
#Allow all
resource "aws_security_group" "elb_sg" {
  name        = "allow_all"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = "${var.vpc_id}"
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_all"
  }
}
# Create a new load balancer
resource "aws_elb" "flask-app-elb" {
  name               = "flask-app"
  subnets = ["${var.public_subnet_ids}"]
  listener {
    instance_port     = 5000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:5000/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  security_groups = ["${aws_security_group.elb_sg.id}"]
  tags {
    Name = "flask-app"
  }
}

resource "aws_iam_role" "iam_code_build_role" {
  name = "iam_code_build_role"
  permissions_boundary = ""
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "iam_code_build_policy" {
  name = "iam_code_build_policy"
  role = "${aws_iam_role.iam_code_build_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning"
      ],
      "Resource": "*",
      "Effect": "Allow",
      "Sid": "AccessCodePipelineArtifacts"
    },
    {
      "Action": [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
      ],
      "Resource": "*",
      "Effect": "Allow",
      "Sid": "AccessECR"
    },
    {
      "Action": [
          "ecr:GetAuthorizationToken"
      ],
      "Resource": "*",
      "Effect": "Allow",
      "Sid": "ecrAuthorization"
    },
    {
      "Action": [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:DescribeServices",
          "ecs:CreateService",
          "ecs:ListServices",
          "ecs:UpdateService"
      ],
      "Resource": "*",
      "Effect": "Allow",
      "Sid": "ecsAccess"
    },
    {
         "Sid":"logStream",
         "Effect":"Allow",
         "Action":[
            "logs:PutLogEvents",
            "logs:CreateLogGroup",
            "logs:CreateLogStream"
         ],
         "Resource":"arn:aws:logs:${data.aws_region.current.name}:*:*"
    },
    {
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:PassRole"
            ],
            "Resource": "${aws_iam_role.iam_ecs_service_role.arn}"
    }
  ]
}
POLICY
}
resource "aws_s3_bucket" "default" {
  bucket = "todds-test-bucket-for-this"
  acl    = "private"
  force_destroy = "true"

  tags {
    Name        = "Demo"
    Environment = "Demo"
  }
}

resource "aws_codebuild_project" "codebuild_docker_image" {
  name         = "codebuild_docker_image"
  description  = "build docker images"
  build_timeout      = "300"
  service_role = "${aws_iam_role.iam_code_build_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/docker:17.09.0"
    type         = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      "name"  = "AWS_REGION"
      "value" = "${data.aws_region.current.name}"
    }
    environment_variable {
      "name"  = "AWS_ACCOUNT_ID"
      "value" = "${data.aws_caller_identity.current.account_id}"
    }
    environment_variable {
      "name"  = "IMAGE_REPO_NAME"
      "value" = "${module.ecr.repository_name}"
    }
    environment_variable {
      name = "IMAGE_TAG"
      value = "${var.repo_name}"
    }
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "app/buildspec.yml"
  }

}


resource "aws_codepipeline" "codepipeline" {
  name     = "demo"
  role_arn = "${aws_iam_role.iam_codepipeline_role.arn}"

  artifact_store {
    location = "${aws_s3_bucket.default.bucket}"
    type     = "S3"
  }

  # Configure CodePipeline poll code from Github if there is any commits.
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["code"]

      configuration {
        OAuthToken           = "${var.github_token}"
        Owner                = "${var.repo_owner}"
        Repo                 = "${var.repo_name}"
        Branch               = "${var.branch}"
      }
    }
  }

  # We use CodeBuild to Build Docker Image.
  stage {
    name = "BuildDocker"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["code"]
      output_artifacts = ["task"]
      version         = "1"
      configuration {
        ProjectName = "${aws_codebuild_project.codebuild_docker_image.name}"
      }
    }
  }

  # We use CodeDeploy to deploy application.
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["code"]
      version         = "1"

      configuration {
        ApplicationName = "${module.codedeploy-for-ecs.codedeploy_app_name}"
        DeploymentGroupName = "${module.codedeploy-for-ecs.codedeploy_deployment_group_id}"
      }
    }
  }
}
