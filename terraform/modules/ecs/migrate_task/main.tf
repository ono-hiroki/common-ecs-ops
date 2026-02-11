data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "aws_ecs_task_definition" "migrate" {
  family = "${var.env}-migrate" // TODO: variableで設定できるようにする
  cpu          = 256
  memory       = 512
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  container_definitions = templatefile("${path.module}/codebuild_migrate.json", {
    env            = var.env
    aws_account_id = data.aws_caller_identity.current.account_id
    region         = data.aws_region.current.region
    app_env        = var.app_env // TODO: 使ってないと思うので削除検討
  })
  execution_role_arn = module.iam_role_ecs.iam_role_arn
  task_role_arn      = module.iam_role_ecs.iam_role_arn
}

# --------------------------------------------------
# IAM Role: ECS
# --------------------------------------------------
module "iam_role_ecs" {
  # TODO: 権限はvariableで受け取る
  source = "../../../modules/iam/role"
  name   = "${var.env}-migrate-task-role"
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSESFullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
  ]
}


resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/${var.env}/migrate"
  retention_in_days = 90
}

locals {
  migrate_taskdef_yaml = yamlencode({
    family                  = aws_ecs_task_definition.migrate.family
    requiresCompatibilities = aws_ecs_task_definition.migrate.requires_compatibilities
    networkMode             = aws_ecs_task_definition.migrate.network_mode
    cpu = tostring(aws_ecs_task_definition.migrate.cpu)
    memory = tostring(aws_ecs_task_definition.migrate.memory)
    executionRoleArn        = aws_ecs_task_definition.migrate.execution_role_arn
    taskRoleArn             = aws_ecs_task_definition.migrate.task_role_arn

    containerDefinitions = [
      for c in jsondecode(aws_ecs_task_definition.migrate.container_definitions) : (
        c.name == "php"
        // MEMO: buildspecの方でも ECR_IMAGE_URI を知っていないといけないので、暗黙的な依存関係がある。
        //       しかし、envsubstでの置換のほうがjqよりも簡単で可読性も高いので、ここでは envsubst を使う。
        ? merge(c, { image = "$${ECR_IMAGE_URI}" })
        : c
      )
    ]
  })
}

resource "aws_ssm_parameter" "migrate_taskdef_yaml" {
  name  = "/${var.env}/migrate/taskdef_yaml" // TODO: variableで設定できるようにする
  type  = "String"
  value = local.migrate_taskdef_yaml
}

resource "aws_security_group" "migrate_task" {
  name   = var.security_group_name
  vpc_id = var.vpc_id
}
