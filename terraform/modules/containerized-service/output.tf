output "subdomain" {
  value = "${var.subdomain}"
}

output "name" {
  value = "${var.name}"
}

output "alb_dns" {
  description = "DNS endpoint of the created ALB"
  value = "${coalesce(module.alb-public.dns_name, module.alb-internal.dns_name)}"
}

output "alb_logs_bucket" {
  description = "S3 bucket where the ALB logs go go"
  value = "${aws_s3_bucket.logs_bucket.bucket}"
}

output "alb_arn" {
  description = "ARN that identifies the created ALB (Application Load Balancer)"
  value = "${coalesce(module.alb-public.load_balancer_id, module.alb-internal.load_balancer_id)}"
}

output "ecs_cluster_arn" {
  value = "${aws_ecs_cluster.application.arn}"
}

# ECS Fargate outputs

output "service_arn" {
  description = "The Amazon Resource Name (ARN) that identifies the service."
  value       = "${module.ecs-fargate.service_arn}"
}

output "target_group_arn" {
  description = "The ARN of the Target Group."
  value       = "${module.ecs-fargate.target_group_arn}"
}

output "target_group_name" {
  description = "The Name of the Target Group."
  value       = "${module.ecs-fargate.target_group_name}"
}

output "task_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the service role."
  value       = "${module.ecs-fargate.task_role_arn}"
}

output "task_role_name" {
  description = "The name of the service role."
  value       = "${module.ecs-fargate.task_role_name}"
}

output "service_sg_id" {
  description = "The Amazon Resource Name (ARN) that identifies the service security group."
  value       = "${module.ecs-fargate.service_sg_id}"
}

# CodePipeline
output "code_pipeline_role_arn" {
  description = "ARN for the role used by the CodePipeline"
  value = "${aws_iam_role.iam_codepipeline_role.id}"
}

output "code_pipeline_role_name" {
  description = "Name for the role used by the CodePipeline"
  value = "${aws_iam_role.iam_codepipeline_role.name}"
}

output "code_deploy_role_arn" {
  description = "ARN for role used by CodeDeploy"
  value = "${module.codedeploy-for-ecs.iam_role_arn}"
}

output "code_deploy_role_name" {
  description = "Name for role used by CodeDeploy"
  value = "${module.codedeploy-for-ecs.iam_role_name}"
}

output "ecs_service_role_arn" {
  description = "ARN for the role used by the ECS"
  value = "${aws_iam_role.iam_ecs_service_role.id}"
}

output "ecs_service_role_name" {
  description = "Name for the role used by the ECS"
  value = "${aws_iam_role.iam_ecs_service_role.name}"
}

output "code_build_role_arn" {
  description = "ARN for the role used by the CodeBuild"
  value = "${aws_iam_role.iam_code_build_role.id}"
}

output "code_build_role_name" {
  description = "Name for the role used by the CodeBuild"
  value = "${aws_iam_role.iam_ecs_service_role.name}"
}

output "code_pipeline_s3_bucket" {
  description = "S3 bucket where the CodePipeline artifacts go"
  value = "${aws_s3_bucket.default.bucket}"
}
