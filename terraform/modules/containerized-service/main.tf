##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "us-east-2"
}

provider "godaddy" {}

##################################################################################
# RESOURCES
##################################################################################

# S3

data "aws_elb_service_account" "default" {}

data "aws_iam_policy_document" "albs3" {
  statement {
    sid = "AllowToPutLoadBalancerLogsToS3Bucket"

    principals {
      type        = "AWS"
      identifiers = ["${data.aws_elb_service_account.default.arn}"]
    }

    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.environment}-${var.name}-alb-logs/AWSLogs/*"]
  }
}

resource "aws_s3_bucket" "logs_bucket" {
  bucket        = "${var.environment}-${var.name}-alb-logs"
  policy        = "${data.aws_iam_policy_document.albs3.json}"
  force_destroy = "true"
  acl           = "log-delivery-write"

  lifecycle_rule = {
    id      = "log-expiration"
    enabled = "true"

    expiration = {
      days = "30"
    }
  }
}

# ALB

module "raise_ror_frontend_sg_80" {
  source  = "terraform-aws-modules/security-group/aws//modules/http-80"
  version = "2.17.0"

  name        = "PublicWebServer80-${var.environment}-${var.name}"
  description = "Security group for web-server with HTTP ports open to EVERYONE"
  vpc_id      = "${var.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    User           = "Terraform"
    Name           = "PublicWebServer80-${var.environment}-${var.name}"
    "User:Service" = "${var.name}"
    Environment    = "${var.environment}"
  }
}

module "raise_ror_frontend_sg_8443" {
  source  = "terraform-aws-modules/security-group/aws//modules/https-8443"
  version = "2.17.0"

  name        = "PublicWebServer8443-${var.environment}-${var.name}"
  description = "Security group for web-server with HTTPS ports open to EVERYONE"
  vpc_id      = "${var.vpc_id}"

  ingress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    User           = "Terraform"
    Name           = "PublicWebServer8443-${var.environment}-${var.name}"
    "User:Service" = "${var.name}"
    Environment    = "${var.environment}"
  }
}

module "alb-public" {
  source     = "terraform-aws-modules/alb/aws"
  version    = "3.6.0"
  create_alb = "${1 - var.internal}"

  load_balancer_name = "${var.environment}-${var.name}"

  security_groups = ["${module.raise_ror_frontend_sg_80.this_security_group_id}"]
  subnets         = ["${var.public_subnet_ids}"]
  vpc_id          = "${var.vpc_id}"

  enable_cross_zone_load_balancing = true
  load_balancer_is_internal        = false
  log_bucket_name                  = "${aws_s3_bucket.logs_bucket.bucket}"

  tags = {
    User           = "Terraform"
    Name           = "ALB-${var.name}"
    "User:Service" = "${var.name}"
    "User:Type"    = "WebServer"
    Environment    = "${var.environment}"
  }
}

module "alb-internal" {
  source     = "terraform-aws-modules/alb/aws"
  version    = "3.6.0"
  create_alb = "${var.internal}"

  load_balancer_name = "${var.environment}-${var.name}"

  security_groups = ["${module.raise_ror_frontend_sg_80.this_security_group_id}"]
  subnets         = ["${var.private_subnet_ids}"]
  vpc_id          = "${var.vpc_id}"

  enable_cross_zone_load_balancing = true
  load_balancer_is_internal        = true
  log_bucket_name                  = "${aws_s3_bucket.logs_bucket.bucket}"

  tags = {
    User           = "Terraform"
    Name           = "ALB-${var.name}"
    "User:Service" = "${var.name}"
    "User:Type"    = "WebServer"
    Environment    = "${var.environment}"
  }
}

# ECS

resource "aws_ecs_cluster" "application" {
  name = "ECS${var.environment}-${var.name}"

  tags = {
    User           = "Terraform"
    Name           = "ECS${var.environment}-${var.name}"
    "User:Service" = "${var.name}"
    Environment    = "${var.environment}"
  }
}

# FARGATE

module "ecs-fargate" {
  # The registry module does not currently output the name of the auto-generated  # LB Target Group.  It also does not support modifying the deployment controller  # type.  As such, the project was forked, with modifications made.  # A pull request has been opened with the maintainer to implement the same  # functionality.  When https://github.com/telia-oss/terraform-aws-ecs-fargate/pull/13  # and https://github.com/telia-oss/terraform-aws-ecs-fargate/pull/14  # is merged, the below commented out source should be reinstated, with the  # new version applied which includes the new output functionality.

//  source = "git::https://github.com/RaiseMe/terraform-aws-ecs-fargate.git?ref=tags/v0.1.2.6"
  source = "../../../../terraform-aws-ecs-fargate"

  cluster_id         = "${aws_ecs_cluster.application.arn}"
  lb_arn             = "${coalesce(module.alb-public.load_balancer_id, module.alb-internal.load_balancer_id)}"
  name_prefix        = "${var.environment}-${var.name}"
  private_subnet_ids = ["${var.private_subnet_ids}"]
  vpc_id             = "${var.vpc_id}"

  task_container_image            = "${module.ecr.registry_url}:${var.container_version}"
  task_container_port             = "${var.container_port}"
  task_container_assign_public_ip = true

  task_container_environment_count = 10
  task_container_environment       = "${var.environment_variables}"

  deployment_controller_type = "CODE_DEPLOY"

  desired_count = "2"

  health_check = {
    port     = "${var.container_port}"
    path     = "/healthcheck"
    interval = 60
  }

  tags = {
    User           = "Terraform"
    Name           = "Fargate${var.environment}-${var.name}"
    "User:Service" = "${var.name}"
    Environment    = "${var.environment}"
  }
}

resource "aws_lb_target_group" "green" {
  vpc_id      = "${var.vpc_id}"
  port        = "${var.container_port}"
  protocol    = "HTTP"
  target_type = "ip"

  health_check = {
    port     = "${var.container_port}"
    path     = "/"
    interval = 60
  }

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefore we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    User           = "Terraform"
    Name           = "${var.environment}-${var.name}-target-${var.container_port}-green"
    "User:Service" = "${var.name}"
    Environment    = "${var.environment}"
  }
}

resource "aws_security_group_rule" "lb_to_containers" {
  security_group_id        = "${module.ecs-fargate.service_sg_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "${var.container_port}"
  source_security_group_id = "${module.raise_ror_frontend_sg_80.this_security_group_id}"
}

resource "aws_alb_listener" "front_end_80" {
  load_balancer_arn = "${coalesce(module.alb-public.load_balancer_id, module.alb-internal.load_balancer_id)}"
  port              = "80"
  protocol          = "HTTP"

  default_action = {
    type             = "forward"
    target_group_arn = "${module.ecs-fargate.target_group_arn}"
  }
}

resource "aws_alb_listener" "front_end_8443" {
  load_balancer_arn = "${coalesce(module.alb-public.load_balancer_id, module.alb-internal.load_balancer_id)}"
  port              = "8443"
  protocol          = "HTTP"

  default_action = {
    type             = "forward"
    target_group_arn = "${module.ecs-fargate.target_group_arn}"
  }
}

# ECR

module "ecr" {
  source    = "git::https://github.com/cloudposse/terraform-aws-ecr.git?ref=master"
  name      = "${var.name}"
  namespace = "RaiseMe"
  stage     = "${var.environment}"
}

# CODEPIPELINE

module "codedeploy-for-ecs" {
  source                     = "tmknom/codedeploy-for-ecs/aws"
  version                    = "1.2.0"
  name                       = "${var.environment}-${var.name}"
  ecs_cluster_name           = "${aws_ecs_cluster.application.name}"
  ecs_service_name           = "${var.environment}-${var.name}"
  lb_listener_arns           = ["${aws_alb_listener.front_end_80.arn}"]
  blue_lb_target_group_name  = "${module.ecs-fargate.target_group_name}"
  green_lb_target_group_name = "${aws_lb_target_group.green.name}"

  auto_rollback_enabled            = true
  auto_rollback_events             = ["DEPLOYMENT_FAILURE"]
  wait_time_in_minutes             = 0
  termination_wait_time_in_minutes = 0
  iam_path                         = "/service-role/"

  test_traffic_route_listener_arns = ["${aws_alb_listener.front_end_8443.arn}"]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "iam_codepipeline_role" {
  name                 = "${var.environment}-${var.name}-codepipeline"
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
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codedeploypolicy" {
  name = "${var.environment}-${var.name}-codedeploypolicy"
  role = "${module.codedeploy-for-ecs.iam_role_name}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
          "Action": [
              "s3:PutObject",
              "codedeploy:*",
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
                "s3:*",
                "codedeploy:*"
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

resource "aws_iam_role_policy" "iam_codepipeline_policy" {
  name = "${var.environment}-${var.name}-iam_codepipeline_policy"
  role = "${aws_iam_role.iam_codepipeline_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*",
                "codedeploy:*"
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
  name                 = "${var.environment}-${var.name}-ecsServiceRole"
  path                 = "/"
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
  name = "${var.environment}-${var.name}-ecsServiceRolePolicy"
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

resource "aws_iam_role" "iam_code_build_role" {
  name                 = "${var.environment}-${var.name}-iam_code_build_role"
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
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "iam_code_build_policy" {
  name = "${var.environment}-${var.name}-iam_code_build_policy"
  role = "${aws_iam_role.iam_code_build_role.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "s3:PutObject",
          "codedeploy:*",
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
          "ecs:ListTaskDefinitions",
          "ecs:DescribeServices",
          "ecs:CreateService",
          "ecs:ListServices",
          "ecs:UpdateService",
          "iam:PassRole"
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
  bucket        = "${var.environment}-${var.name}-codepipeline"
  acl           = "private"
  force_destroy = "true"

  tags {
    Name        = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_codebuild_project" "codebuild_docker_image" {
  name          = "${var.environment}-${var.name}-codebuild_docker_image"
  description   = "build docker images"
  build_timeout = "300"
  service_role  = "${aws_iam_role.iam_code_build_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:17.09.0"
    type            = "LINUX_CONTAINER"
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
      name  = "IMAGE_TAG"
      value = "${var.name}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "app/buildspec.yml"
  }
}

data "template_file" "generate_app_spec" {
  template = "${file("${path.module}/generate_app_spec.sh.tpl")}"

  vars = {
    environment    = "${var.environment}"
    name           = "${var.name}"
    container_port = "${var.container_port}"
  }
}

# used to make a list of maps with name/value for each environment variable specified so they can be added
# to the task definition
resource "null_resource" "environment_variables" {
  count = "${length(keys(var.environment_variables))}"

  triggers {
    name  = "${element(keys(var.environment_variables), count.index)}"
    value = "${element(values(var.environment_variables), count.index)}"
  }
}

data "template_file" "generate_task_definition" {
  template = "${file("${path.module}/generate_task_definition.sh.tpl")}"

  vars = {
    environment           = "${var.environment}"
    name                  = "${var.name}"
    container_port        = "${var.container_port}"
    cpu                   = "${var.cpu}"
    memory                = "${var.memory}"
    environment_variables = "${jsonencode(null_resource.environment_variables.*.triggers)}"
  }
}

data "template_file" "buildspec" {
  template = "${file("${path.module}/buildspec.yml.tpl")}"

  vars = {
    environment              = "${var.environment}"
    name                     = "${var.name}"
    generate_task_definition = "${indent(8, data.template_file.generate_task_definition.rendered)}"
    generate_app_spec        = "${indent(8, data.template_file.generate_app_spec.rendered)}"
  }
}

resource "aws_codebuild_project" "codebuild_task_definition" {
  name          = "${var.environment}-${var.name}-codebuild_task_definition"
  description   = "generate task definition and appspec"
  build_timeout = "300"
  service_role  = "${aws_iam_role.iam_code_build_role.arn}"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/docker:17.09.0"
    type            = "LINUX_CONTAINER"
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
      name  = "IMAGE_TAG"
      value = "${var.name}"
    }

    environment_variable {
      name  = "EXECUTION_ROLE"
      value = "${module.ecs-fargate.execution_role_arn}"
    }

    environment_variable {
      name  = "TASK_ROLE"
      value = "${module.ecs-fargate.task_role_arn}"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${data.template_file.buildspec.rendered}"
  }
}

resource "aws_codepipeline" "codepipeline" {
  name     = "${var.environment}-${var.name}"
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
        OAuthToken = "${var.github_token}"
        Owner      = "${var.repo_owner}"
        Repo       = "${coalesce(var.repo_name, var.name)}"
        Branch     = "${var.git_branch}"
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
      version         = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.codebuild_docker_image.name}"
      }
    }
  }

  # We use CodeBuild to generate the task definition
  stage {
    name = "GenerateTaskDefinitionAndAppSpec"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["code"]
      output_artifacts = ["task"]
      version          = "1"

      configuration {
        ProjectName = "${aws_codebuild_project.codebuild_task_definition.name}"
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
      input_artifacts = ["task"]
      version         = "1"

      configuration {
        ApplicationName     = "${module.codedeploy-for-ecs.codedeploy_app_name}"
        DeploymentGroupName = "${var.environment}-${var.name}"
      }
    }
  }
}
