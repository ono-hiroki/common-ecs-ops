resource "aws_security_group" "main" {
  name   = "${var.env}-aurora"
  vpc_id = var.vpc_id
}

resource "aws_route53_record" "cname" {
  zone_id = var.zone_id
  name    = var.cname
  type    = "CNAME"
  records = [aws_rds_cluster.main.endpoint]
  ttl     = "300"
}

resource "aws_route53_record" "cname_ro" {
  zone_id = var.zone_id
  name    = var.cname_ro
  type    = "CNAME"
  records = [aws_rds_cluster.main.reader_endpoint]
  ttl     = "300"
}

resource "aws_db_subnet_group" "main" {
  name       = var.env
  subnet_ids = var.subnet_ids
}

#######################################################################################################
resource "aws_rds_cluster" "main" {
  cluster_identifier              = "${var.env}-cluster"
  engine                          = "aurora-mysql"
  engine_version                  = "8.0.mysql_aurora.3.07.1"
  engine_mode                     = "provisioned"
  availability_zones              = var.availability_zones
  master_username                 = var.user_name
  master_password                 = var.password
  database_name                   = var.database_name
  backup_retention_period         = 5
  preferred_backup_window         = "18:00-20:00" # 03:00-05:00(JST)
  preferred_maintenance_window    = "wed:20:00-wed:21:00" # 05:00-06:00(JST)
  skip_final_snapshot             = var.is_fixed ? false : true
  deletion_protection             = var.is_fixed ? true : false
  vpc_security_group_ids          = [aws_security_group.main.id]
  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  lifecycle {
    ignore_changes = [
      engine_version,
      availability_zones,
      master_username,
      master_password,
    ]
  }
}

resource "aws_rds_cluster_instance" "main" {
  count              = var.instance_count
  identifier         = "${var.env}-serverless-${count.index}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}

#######################################################################################################
resource "aws_rds_cluster_parameter_group" "main" {
  name   = "${var.env}-cluster"
  family = "aurora-mysql8.0"

  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_connection"
    value = "utf8mb4_bin"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_bin"
  }

  parameter {
    name  = "time_zone"
    value = "Asia/Tokyo"
  }

  parameter {
    name  = "slow_query_log"
    value = 1
  }
}
