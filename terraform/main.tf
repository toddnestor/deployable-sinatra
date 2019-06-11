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

module "ecr" {
  source              = "git::https://github.com/cloudposse/terraform-aws-ecr.git?ref=master"
  name                = "${var.registry_name}"
  namespace           = "${var.namespace}"
  stage               = "${var.environment}"
}

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
