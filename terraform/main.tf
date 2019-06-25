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
