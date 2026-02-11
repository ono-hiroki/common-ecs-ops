###########################################################
# ALB用 Security Group
###########################################################
resource "aws_security_group" "alb_sg" {
  name   = "${var.env}-alb"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "alb_http_ingress" {
  count = 1

  security_group_id = aws_security_group.alb_sg.id
  description       = "Allow HTTP inbound"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.sg_ingress_cidr_blocks
}

resource "aws_security_group_rule" "alb_https_ingress" {
  count = var.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb_sg.id
  description       = "Allow HTTPS inbound"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.sg_ingress_cidr_blocks
}

resource "aws_security_group_rule" "alb_egress_all" {
  security_group_id = aws_security_group.alb_sg.id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

###########################################################
# ALB (Application Load Balancer)
###########################################################
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  idle_timeout       = 60
  subnets            = var.subnet_ids
  security_groups    = [aws_security_group.alb_sg.id]

  access_logs {
    bucket  = aws_s3_bucket.log.bucket
    enabled = true
  }
}

###########################################################
# Target Group
###########################################################
resource "aws_lb_target_group" "main" {
  name                 = var.target_group_name
  vpc_id               = var.vpc_id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300
  target_type          = "ip"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    matcher             = var.matcher
  }

  depends_on = [aws_lb.main]
}


###########################################################
# ALB Listener
###########################################################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "This is HTTP"
      status_code  = "200"
    }
  }

}

###########################################################
# ALB Listener (HTTPS)
###########################################################
resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = length(var.certificate_arns) > 0 ? var.certificate_arns[0] : null

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "This is HTTPS"
      status_code  = "200"
    }
  }
}

# resource "aws_lb_listener_rule" "rule_target_a" {
#   listener_arn = aws_lb_listener.http.arn
#   priority     = 10
#
#   condition {
#     source_ip {
#       values = ["153.170.85.14/32"]
#     }
#   }
#
#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.example.arn
#   }
# }

locals {
  additional_certificate_map = var.enable_https && length(var.certificate_arns) > 1 ? {
    for idx, cert in slice(var.certificate_arns, 1, length(var.certificate_arns)) : "additional_${idx}" => cert
  } : {}
}

resource "aws_lb_listener_certificate" "additional" {
  for_each = local.additional_certificate_map

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value
}

###########################################################
# ALB Listener Rule
###########################################################
resource "aws_lb_listener_rule" "http_to_https" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  condition {
    host_header {
      values = var.a_record_names
    }
  }
}

###########################################################
# ログバケット
###########################################################
resource "aws_s3_bucket" "log" {
  bucket        = var.alb_log_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_lifecycle_configuration" "log" {
  bucket = aws_s3_bucket.log.bucket
  rule {
    id     = "log"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_policy" "log" {
  bucket = aws_s3_bucket.log.id
  policy = data.aws_iam_policy_document.log.json
}

data "aws_iam_policy_document" "log" {
  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.log.id}/*"]

    principals {
      type        = "AWS"
      identifiers = ["582318560864"] # 東京リージョンELBのAccountID
    }
  }
}
###########################################################
# アラーム
###########################################################
resource "aws_cloudwatch_metric_alarm" "server_error" {
  alarm_name          = "${var.env}-5XXエラー数"
  evaluation_periods  = "1"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "HTTPCode_Target_5XX_Count"
  threshold           = 1

  dimensions = {
    TargetGroup  = aws_lb_target_group.main.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_description = "${var.env}の5XXエラー数"
}

resource "aws_cloudwatch_metric_alarm" "un_healthy" {
  alarm_name          = "${var.env}-ヘルスチェック失敗"
  evaluation_periods  = "1"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Maximum"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  metric_name         = "UnHealthyHostCount"
  threshold           = 1

  dimensions = {
    TargetGroup  = aws_lb_target_group.main.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_description = "${var.env}のヘルスチェック失敗数"
}


# resource "aws_lb_target_group" "example" {
#   name        = "${var.env}-target-group"
#   port        = 80
#   protocol    = "HTTP"
#   vpc_id      = var.vpc_id
#   target_type = "instance"
#   health_check {
#     path                = "/"
#     protocol            = "HTTP"
#     port                = "traffic-port"
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 5
#     interval            = 30
#     matcher             = "200"
#   }
# }
#
# resource "aws_instance" "example" {
#   ami           = "ami-0a6fd4c92fc6ed7d5"
#   instance_type = "t2.micro"
#   subnet_id     = var.subnet_ids[0]
# }
#
# # ターゲットグループへのEC2インスタンスのアタッチ
# resource "aws_lb_target_group_attachment" "example_attachment" {
#   target_group_arn = aws_lb_target_group.example.arn
#   target_id        = aws_instance.example.id
#   port             = 80
# }