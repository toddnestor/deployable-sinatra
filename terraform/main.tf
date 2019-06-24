module "development-sinatra" {
  source = "./modules/containerized-service"

  aws_access_key = "${var.aws_access_key}"
  aws_secret_key = "${var.aws_secret_key}"
  github_token = "${var.github_token}"
  private_subnet_ids = "${var.private_subnet_ids}"
  public_subnet_ids = "${var.public_subnet_ids}"
  container_version = "${var.container_version}"
  vpc_id = "${var.vpc_id}"
  dns_zone_name = "${var.dns_zone_name}"

  name = "deployable-sinatra"
  environment = "development"
  repo_name = "deployable-sinatra"
  git_branch = "develop"
}
