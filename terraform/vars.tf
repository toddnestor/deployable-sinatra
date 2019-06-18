variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "public_key_path" {}
variable "key_name" {
  default = "terraform"
}
variable "github_token" {}
variable "registry_name" {}
variable "namespace" {}
variable "environment" {}
variable "vpc_id" {}
variable "public_subnet_ids" {
  type = "list"
}
variable "container_version" {}
variable "repo_owner" {}
variable "repo_name" {}
variable "branch" {}
variable "dns_zone_name" {}
