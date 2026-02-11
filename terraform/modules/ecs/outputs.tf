///////////////////////////////////////////////////////////////////////////////
// Outputs
///////////////////////////////////////////////////////////////////////////////

output "ecs_service_security_group_id" {
  description = "セキュリティグループの ID"
  value       = aws_security_group.ecs_service.id
}

output "ecs_service_security_group_arn" {
  description = "セキュリティグループの ARN"
  value       = aws_security_group.ecs_service.arn
}


output "nginx_log_group_name" {
  description = "CloudWatch Logs の nginx 用ロググループ名"
  value       = aws_cloudwatch_log_group.nginx.name
}

output "php_fpm_log_group_name" {
  description = "The name of the CloudWatch Log Group for php-fpm."
  value       = aws_cloudwatch_log_group.php_fpm.name
}


output "ecs_task_definition_arn" {
  description = "ECS タスク定義の ARN"
  value       = aws_ecs_task_definition.main.arn
}

output "ecs_task_definition_family" {
  description = "ECS タスク定義のファミリー"
  value       = aws_ecs_task_definition.main.family
}


output "ecs_service_id" {
  description = "ECSサービスの ID"
  value       = aws_ecs_service.main.id
}

output "ecs_service_name" {
  description = "The name of the ECS service."
  value       = aws_ecs_service.main.name
}

output "appautoscaling_target_id" {
  description = "オートスケーリングのターゲット ID"
  value       = aws_appautoscaling_target.ecs_target.id
}

# ECR リポジトリ (モジュールで作成されたものを出力)
output "nginx_repository_name" {
  description = "nginx 用の ECR リポジトリ名"
  value       = module.nginx_repository.name
}

output "php_repository_name" {
  description = "php 用の ECR リポジトリ名"
  value       = module.php_repository.name
}

# Secrets Manager (ARN などを参照したい場合)
# output "secrets_arns" {
#   description = "A map of secret ARNs in AWS Secrets Manager."
#   value       = { for k, secret in aws_secretsmanager_secret.secrets : k => secret.arn }
# }


output "ecs_service_main" {
  value = aws_ecs_service.main
}