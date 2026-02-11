variable "env" {
  type        = string
  description = "環境名 (例: dev, stg, prod)"
}

variable "cluster_arn" {
  type        = string
  description = "ECS クラスターの ARN (既存 or 別モジュールから渡す)"
}

variable "cluster_name" {
  type        = string
  description = "ECS クラスター名 (オートスケーリングのターゲット作成時に使用)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "ECS サービスが属するサブネットの ID"
}

variable "target_group_arn" {
  type        = string
  description = "ALB Target Group ARN (サービスに紐づけたいものを指定)"
}

variable "desired_count" {
  type        = number
  description = "ECS サービスのタスク数"
}

variable "assign_public_ip" {
  type        = bool
  description = "Fargate タスクにパブリック IP を割り当てるか"
}

variable "execution_role_arn" {
  type        = string
  description = "タスク実行ロール ARN (例: ECS タスク実行ロール)"
}

variable "task_role_arn" {
  type        = string
  description = "タスクロール ARN (アプリが利用する権限を付与したロール)"
}

variable "nginx_repository_name" {
  type        = string
  description = "nginx 用 ECR リポジトリ名 (イメージ名を組み立てる時に使用)"
}

variable "php_repository_name" {
  type        = string
  description = "php-fpm 用 ECR リポジトリ名 (イメージ名を組み立てる時に使用)"
}

variable "ecr_enable_force_delete" {
  type        = bool
  description = "ECR リポジトリ削除時にイメージが残っていても削除するか"
  default     = false
}

variable "appautoscaling_min_capacity" {
  type        = number
  description = "App Auto Scaling (最小タスク数)"
  default     = 1
}

variable "appautoscaling_max_capacity" {
  type        = number
  description = "App Auto Scaling (最大タスク数)"
  default     = 9
}

variable "log_retention_in_days" {
  type        = number
  description = "CloudWatch Logs の保持日数"
  default     = 180
}

variable "ecs_service_name" {
  type        = string
  description = "ECS サービス名"
}

#######################################################################################################
# ECS タスク定義
#######################################################################################################
variable "memory" {
  type        = number
  description = "Fargate タスクのメモリ (MB)"
}

variable "cpu" {
  type        = number
  description = "Fargate タスクの CPU (vCPU)"
}

variable "secret_list" {
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default     = []
  description = <<EOT
  SecretsManager の ARNなどを持つオブジェクトのリスト。
  [
    { name = "DB_PASSWORD", valueFrom = "..."},
    ...
  ]
  EOT
}

variable "environment_list" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = <<EOT
  環境変数の key/value を持つオブジェクトのリスト。
  [
    { name = "APP_ENV", value = "staging"},
    ...
  ]
  EOT
}