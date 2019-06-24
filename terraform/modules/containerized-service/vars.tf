variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "github_token" {}
variable "container_version" {
  default = "deployable-sinatra-be9343c"
}
variable "dns_zone_name" {
  default = "nestor.life"
}

variable "environment" {}
variable "vpc_id" {
  default = "vpc-82a231ea"
}
variable "public_subnet_ids" {
  type = "list"
  default = ["subnet-75fa6f1d", "subnet-671c222a"]
}
variable "private_subnet_ids" {
  type = "list"
  default = ["subnet-75fa6f1d", "subnet-671c222a"]
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
