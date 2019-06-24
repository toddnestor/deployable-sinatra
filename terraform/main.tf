module "development-sinatra" {
  source = "./modules/containerized-service"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  github_token = "${var.github_token}"

  name = "deployable-sinatra"
  environment = "development"
  repo_name = "deployable-sinatra"
  git_branch = "develop"
  internal = false
}

module "staging-sinatra" {
  source = "./modules/containerized-service"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  github_token = "${var.github_token}"

  name = "deployable-sinatra"
  environment = "staging"
  repo_name = "deployable-sinatra"
  git_branch = "develop"
  subdomain = "test-two"
  internal = false
}
