///////////////////////////////////////////////////////////////////////////////
// データソース
///////////////////////////////////////////////////////////////////////////////
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

///////////////////////////////////////////////////////////////////////////////
// セキュリティグループ
///////////////////////////////////////////////////////////////////////////////
resource "aws_security_group" "ecs_service" {
  name   = "${var.env}-ecs-service"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "ecs_service_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ecs_service.id
}


///////////////////////////////////////////////////////////////////////////////
// CloudWatch Logs
///////////////////////////////////////////////////////////////////////////////
locals {
  nginx_log_group_path   = "/${var.env}/ecs/nginx"
  php_fpm_log_group_path = "/${var.env}/ecs/php-fpm"
}

resource "aws_cloudwatch_log_group" "nginx" {
  name              = local.nginx_log_group_path
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_group" "php_fpm" {
  name              = local.php_fpm_log_group_path
  retention_in_days = var.log_retention_in_days
}

///////////////////////////////////////////////////////////////////////////////
// ECS タスク定義
///////////////////////////////////////////////////////////////////////////////
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.env}-laravel-app"
  cpu                      = var.cpu
  memory                   = var.memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  container_definitions = templatefile(
    "${path.module}/container_definitions.json",
    {
      nginx_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${var.nginx_repository_name}:latest"
      php_image   = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${var.php_repository_name}:latest"
      mysql_image = "mysql:8.0"

      secrets      = var.secret_list
      environments = var.environment_list

      nginx_log_group_path   = local.nginx_log_group_path
      php_fpm_log_group_path = local.php_fpm_log_group_path
    }
  )

  volume {
    name = "php-fpm-socket"
  }

  volume {
    name = "laravel-public"
  }

  volume {
    name = "mysql_data"
  }
}

// サービスへ反映させるために最新のECS タスク定義をデータソース経由で取得
data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.main.family
}

///////////////////////////////////////////////////////////////////////////////
// ECS サービス
///////////////////////////////////////////////////////////////////////////////
resource "aws_ecs_service" "main" {
  name                              = var.ecs_service_name
  cluster                           = var.cluster_arn
  task_definition                   = data.aws_ecs_task_definition.main.arn
  desired_count                     = var.desired_count
  platform_version                  = "1.4.0"
  health_check_grace_period_seconds = 300
  enable_execute_command            = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "nginx" // TODO: 変数化し、container_definitions.json と合わせる
    container_port   = 80
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_ecs_task_definition.main
  ]

  tags = {
    Name = "${var.env}-ecs-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

///////////////////////////////////////////////////////////////////////////////
// AutoScaling 設定
///////////////////////////////////////////////////////////////////////////////
resource "aws_appautoscaling_target" "ecs_target" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.appautoscaling_min_capacity
  max_capacity       = var.appautoscaling_max_capacity
}

resource "aws_appautoscaling_policy" "main" {
  name               = "${var.env}-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 40

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }

  depends_on = [aws_appautoscaling_target.ecs_target]
}

resource "aws_cloudwatch_metric_alarm" "ecs_high" {
  alarm_name          = "${var.env}-ecs-app-CPUUtilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 60

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = aws_ecs_service.main.name
  }

  alarm_description = "${var.env}のCPU使用率"
}

///////////////////////////////////////////////////////////////////////////////
// ECR リポジトリ
///////////////////////////////////////////////////////////////////////////////
module "php_repository" {
  source              = "../ecr"
  name                = var.php_repository_name
  enable_force_delete = var.ecr_enable_force_delete
}

module "nginx_repository" {
  source              = "../ecr"
  name                = var.nginx_repository_name
  enable_force_delete = var.ecr_enable_force_delete
}