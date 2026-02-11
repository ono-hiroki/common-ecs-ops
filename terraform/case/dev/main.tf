locals {
  ecs_service_name = format("%s-service", var.env)
  is_nat_enabled = false
  environment_list = [
    for env_key, env_value in var.environment_map : {
      name  = env_key
      value = env_value
    }
  ]
  nginx_repository_name = "${var.env}-nginx"
  php_repository_name   = "${var.env}-php"
  migrate_task_sg_name = "${var.env}-migrate-task-sg"
}
terraform {
  required_version = "~> 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
  }
}

provider "aws" {
  default_tags {
    tags = {
      env        = var.env
      managed_by = "terraform"
    }
  }
}
///////////////////////////////////////////////////////////////////////////////
// DNS
///////////////////////////////////////////////////////////////////////////////
data "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_route53_record" "ns" {
  allow_overwrite = true
  name            = "${var.env}.${var.domain}"
  ttl             = 300
  type            = "NS"
  zone_id         = data.aws_route53_zone.main.zone_id
  records         = aws_route53_zone.subdomain_env.name_servers
}

resource "aws_route53_zone" "subdomain_env" {
  name = "${var.env}.${var.domain}"
}

resource "aws_route53_record" "to_alb" {
  zone_id = aws_route53_zone.subdomain_env.zone_id
  name    = "${var.env}.${var.domain}"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}


///////////////////////////////////////////////////////////////////////////////
// ACM
///////////////////////////////////////////////////////////////////////////////
module "acm" {
  source      = "../../modules/acm"
  domain_name = var.domain
  zone_id     = data.aws_route53_zone.main.zone_id
  subject_alternative_names = [
    format("*.%s", var.domain),
  ]
}

///////////////////////////////////////////////////////////////////////////////
// ネットワーク
///////////////////////////////////////////////////////////////////////////////
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example-vpc-only-public-subnet"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_id = aws_vpc.main.id

  public_subnets = {
    "public-a-1" = { cidr = "10.0.0.0/24", az = "ap-northeast-1a", name = "dev-public-a" }
    "public-c-1" = { cidr = "10.0.2.0/24", az = "ap-northeast-1c", name = "dev-public-c" }
    "public-d-1" = { cidr = "10.0.4.0/24", az = "ap-northeast-1d", name = "dev-public-d" }
  }

  private_subnets = {
    "private-a" = { cidr = "10.0.6.0/24", az = "ap-northeast-1a", name = "private-a" }
    "private-c" = { cidr = "10.0.8.0/24", az = "ap-northeast-1c", name = "private-c" }
    "private-d" = { cidr = "10.0.10.0/24", az = "ap-northeast-1d", name = "private-d" }
  }

  public_route_table_name = "public-rtb"
  aws_internet_gateway_id = aws_internet_gateway.main.id

  nat_gateway_public_to_private_mapping = {}
}
/////////////////////////////////////////////////////////////////////////////////
// ALB
/////////////////////////////////////////////////////////////////////////////////
module "alb" {
  source = "../../modules/alb"

  env               = var.env
  vpc_id            = aws_vpc.main.id
  subnet_ids        = module.vpc.public_subnet_ids
  # alb_name          = "${var.env}-${var.app_name}-alb"
  alb_name         = "${var.env}-alb"
  target_group_name = "${var.env}-tg"
  enable_https      = true
  certificate_arns  = [module.acm.acm_certificate_arn]

  a_record_names         = [
    var.domain,
    "${var.env}.${var.domain}",
  ]
  alb_log_bucket_name    = "${var.domain}-${var.env}-alb-logs"
  health_check_path      = "/health"
  matcher                = "200-399"
  sg_ingress_cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_listener_rule" "https" {
  listener_arn = module.alb.https_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = module.alb.target_group_arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}

//////////////////////////////////////////////////////////////////////////////////
// ECS
//////////////////////////////////////////////////////////////////////////////////
resource "aws_ecs_cluster" "main" {
  name = "${var.env}" // NOTICE: マイグレーションがこの名前に依存してるので注意

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "ecs_secret" {
  source     = "../../modules/secret_manager"
  prefix_key = "${upper(var.env)}_"
  secrets    = {
    for secret_key, secret_value in var.secrets_map : secret_key => secret_value
  }
}

module "ecs_role" {
  source = "../../usecases/ecs_role"
  env    = "dev"
}

module "ecs_service" {
  source = "../../modules/ecs"

  env                = var.env
  cluster_arn        = aws_ecs_cluster.main.arn
  cluster_name       = aws_ecs_cluster.main.name
  ecs_service_name   = local.ecs_service_name
  secret_list        = module.ecs_secret.secrets_list
  environment_list   = local.environment_list
  vpc_id             = aws_vpc.main.id
  subnet_ids         = local.is_nat_enabled ? module.vpc.private_subnet_ids : module.vpc.public_subnet_ids
  target_group_arn   = module.alb.target_group_arn
  desired_count      = 1
  assign_public_ip   = local.is_nat_enabled ? false : true
  execution_role_arn = module.ecs_role.iam_role_arn
  task_role_arn      = module.ecs_role.iam_role_arn
  memory             = 1024
  cpu                = 256

  nginx_repository_name   = local.nginx_repository_name
  php_repository_name     = local.php_repository_name
  ecr_enable_force_delete = true

  appautoscaling_min_capacity = 1
  appautoscaling_max_capacity = 9
}

resource "aws_security_group_rule" "ecs_service" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.ecs_service.ecs_service_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
}


///////////////////////////////////////////////////////////////////////////////
// マイグレーション用 ECS タスク
///////////////////////////////////////////////////////////////////////////////
module "migrate_task" {
  source = "../../modules/ecs/migrate_task"

  app_env             = "dev"
  env                 = var.env
  security_group_name = local.migrate_task_sg_name
  vpc_id              = aws_vpc.main.id
}

resource "aws_security_group" "migrate_task" {
  name   = "${var.env}-app"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group_rule" "migrate_task_egress" {
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.migrate_task.security_group_id
}

resource "aws_security_group_rule" "aurora_ingress_from_migrate_task" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.rds.security_group_id
  source_security_group_id = module.migrate_task.security_group_id
}
///////////////////////////////////////////////////////////////////////////////
// CodePipeline・CodeBuild
///////////////////////////////////////////////////////////////////////////////
# resource "aws_codestarconnections_connection" "bitbucket_connection" {
#   name = "${var.env}-github-connection"
#   provider_type = "GitHub"
#   # provider_type = "Bitbucket"
# }

data "aws_codestarconnections_connection" "main" {
  name = "github-connection"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
locals {
  env_vars = {
    ECR_IMAGE_REPO          = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/${local.php_repository_name}",
    TASKDEF_PARAM_NAME = "/${var.env}/migrate/taskdef_yaml", # TODO: variableで設定できるようにする
    TASK_FAMILY        = "${var.env}-migrate",
    CLUSTER_NAME       = aws_ecs_cluster.main.name
    SUBNET_IDS         = join(",", module.vpc.public_subnet_ids)
    SECURITY_GROUP_IDS = join(",", [aws_security_group.migrate_task.id])
  }
}

module "code" {
  source = "../../modules/code_pipeline_ecs"

  env                    = var.env

  build_migrate_env_map  = local.env_vars
  artifact_bucket_name   = "${var.env}-app-artifact"
  codepipeline_name      = "${var.env}-codepipeline"
  codebuild_project_name = "${var.env}-codebuild-project"
  codebuild_project_migrate_name = "${var.env}-migrate"
  buildspec_filepath     = "buildspec.yml"

  repository_owner  = "example-org"
  repository_name   = "sample-backend"
  branch_name       = "main"
  trigger_branches_includes   = ["main"]
  trigger_file_paths_includes = ["tmp/*"]


  ecs_cluster_name = aws_ecs_cluster.main.name
  ecs_service_name = local.ecs_service_name
  repository_connection_arn = data.aws_codestarconnections_connection.main.arn

}


/////////////////////////////////////////////////////////////////////////////////
// RDS (Aurora Serverless)
/////////////////////////////////////////////////////////////////////////////////
module "rds" {
  source             = "../../modules/rds/aurora_serverless"
  env                = var.env
  vpc_id             = aws_vpc.main.id
  source_security_group_ids = [module.ecs_service.ecs_service_security_group_id]
  zone_id            = aws_route53_zone.subdomain_env.zone_id
  cname              = "rds.${var.env}.${var.domain}"
  cname_ro           = "rds-ro.${var.env}.${var.domain}"
  availability_zones = [
    "ap-northeast-1a",
    "ap-northeast-1c",
    "ap-northeast-1d",
  ]
  subnet_ids         = module.vpc.private_subnet_ids
  instance_count     = 1
  user_name          = "admin"
  password           = "N!Z]9K_e~vXy^)K0"
  database_name      = "app"
  min_capacity       = 0.5
  max_capacity       = 1.0
  is_fixed           = false
}


resource "aws_security_group_rule" "aurora_ingress_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = module.rds.security_group_id
  source_security_group_id = module.ecs_service.ecs_service_security_group_id
}



resource "aws_security_group_rule" "aurora_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = module.rds.security_group_id
}