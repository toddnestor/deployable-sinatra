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
variable "container_version" {}
variable "dns_zone_name" {}



variable "environment" {}
variable "vpc_id" {}
variable "public_subnet_ids" {
  type = "list"
}
variable "private_subnet_ids" {
  type = "list"
}
variable "repo_owner" {
  default = "toddnestor"
}
variable "repo_name" {}
variable "git_branch" {}
variable "name" {}
variable "internal" {
  default = true
}
variable "subdomain" {
  default = ""
}
variable "container_port" {
  default = "4000"
}
variable "memory" {
  default = "512"
}
variable "cpu" {
  default = "256"
}
