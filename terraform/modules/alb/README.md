# ALB Module

# Usage

## httpの場合
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example-alb"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_id                  = aws_vpc.main.id
  aws_internet_gateway_id = aws_internet_gateway.main.id
  public_subnets = {
    "public-a" = { cidr = "10.0.0.0/24", az = "ap-northeast-1a", name = "public-a" },
    "public-c" = { cidr = "10.0.1.0/24", az = "ap-northeast-1c", name = "public-c" }
  }
  public_route_table_name = "public-rtb"
}


module "alb" {
  source = "../../modules/alb"

  env                    = "example"
  alb_name               = "example-alb"
  target_group_name      = "example-tg"
  vpc_id                 = aws_vpc.main.id
  subnet_ids             = module.vpc.public_subnet_ids
  enable_https           = false
  alb_log_bucket_name    = "example-alb-log-efadjsa"
  sg_ingress_cidr_blocks = ["0.0.0.0/0"]

  health_check_path = "/"
  matcher           = "200"
}
```

## httpsの場合
```hcl
//////////////////////////////
// 変数・ローカル定義
//////////////////////////////
locals {
  domain_name = "smvdevelopmentinfrastructure.com"
  a_record_names = [
    local.domain_name,
    "hoge.${local.domain_name}"
  ]

  acm_requests = {
    default = {
      domain_name               = local.domain_name,
      subject_alternative_names = [format("*.%s", local.domain_name)]
    },
    hoge = {
      domain_name               = local.domain_name,
      subject_alternative_names = [format("hoge.%s", local.domain_name)]
    }
  }
}

//////////////////////////////
// VPC & IGW
//////////////////////////////
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example-alb"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_id                  = aws_vpc.main.id
  aws_internet_gateway_id = aws_internet_gateway.main.id
  public_subnets = {
    "public-a" = { cidr = "10.0.0.0/24", az = "ap-northeast-1a", name = "public-a" },
    "public-c" = { cidr = "10.0.1.0/24", az = "ap-northeast-1c", name = "public-c" }
  }
  public_route_table_name = "public-rtb"
}

//////////////////////////////
// DNS
//////////////////////////////
data "aws_route53_zone" "main" {
  name = local.domain_name
}

resource "aws_route53_record" "a_records" {
  for_each = toset(local.a_record_names)

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

//////////////////////////////
// ACM (証明書)
//////////////////////////////
module "acm" {
  for_each = local.acm_requests
  source   = "../../modules/acm"

  domain_name               = each.value.domain_name
  zone_id                   = data.aws_route53_zone.main.zone_id
  subject_alternative_names = each.value.subject_alternative_names
}

//////////////////////////////
// ALB
//////////////////////////////
module "alb" {
  source = "../../modules/alb"

  env                    = "example"
  alb_name               = "example-alb"
  target_group_name      = "example-tg"
  vpc_id                 = aws_vpc.main.id
  subnet_ids             = module.vpc.public_subnet_ids
  alb_log_bucket_name    = "example-alb-log-efadjsaa"
  sg_ingress_cidr_blocks = ["0.0.0.0/0"]
  health_check_path      = "/"
  matcher                = "200"

  a_record_names = local.a_record_names
  certificate_arns = [
    module.acm["default"].certificate_arn,
    module.acm["hoge"].certificate_arn
  ]
}
```