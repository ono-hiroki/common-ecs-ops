# VPC Module

## Usage

### サブネットのみ 
```hcl
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
    "public-a-1" = { cidr = "10.0.0.0/24", az = "ap-northeast-1a", name = "public-a-1" }
    "public-a-2" = { cidr = "10.0.1.0/24", az = "ap-northeast-1a", name = "public-a-2" }
    "public-c-1" = { cidr = "10.0.2.0/24", az = "ap-northeast-1c", name = "public-c-1" }
    "public-c-2" = { cidr = "10.0.3.0/24", az = "ap-northeast-1c", name = "public-c-2" }
    "public-d-1" = { cidr = "10.0.4.0/24", az = "ap-northeast-1d", name = "public-d-1" }
    "public-d-2" = { cidr = "10.0.5.0/24", az = "ap-northeast-1d", name = "public-d-2", }
  }

  private_subnets = {}

  public_route_table_name = "public-rtb"
  aws_internet_gateway_id = aws_internet_gateway.main.id

  nat_gateway_public_to_private_mapping = {}
}
```
### サブネットとNATゲートウェイ
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "example-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_id = aws_vpc.main.id

  public_subnets = {
    "public-a-1" = { cidr = "10.0.0.0/24", az = "ap-northeast-1a", name = "public-a-1" }
    "public-a-2" = { cidr = "10.0.1.0/24", az = "ap-northeast-1a", name = "public-a-2" }
    "public-c-1" = { cidr = "10.0.2.0/24", az = "ap-northeast-1c", name = "public-c-1" }
    "public-c-2" = { cidr = "10.0.3.0/24", az = "ap-northeast-1c", name = "public-c-2" }
    "public-d-1" = { cidr = "10.0.4.0/24", az = "ap-northeast-1d", name = "public-d-1" }
    "public-d-2" = { cidr = "10.0.5.0/24", az = "ap-northeast-1d", name = "public-d-2", }
  }

  private_subnets = {
    "private-a-1" = { cidr = "10.0.6.0/24", az = "ap-northeast-1a", name = "private-a-1" }
    "private-a-2" = { cidr = "10.0.7.0/24", az = "ap-northeast-1a", name = "private-a-2" }
    "private-c-1" = { cidr = "10.0.8.0/24", az = "ap-northeast-1c", name = "private-c-1" }
    "private-c-2" = { cidr = "10.0.9.0/24", az = "ap-northeast-1c", name = "private-c-2" }
    "private-d-1" = { cidr = "10.0.10.0/24", az = "ap-northeast-1d", name = "private-d-1" }
    "private-d-2" = { cidr = "10.0.11.0/24", az = "ap-northeast-1d", name = "private-d-2" }
  }

  public_route_table_name = "public-rtb"
  aws_internet_gateway_id = aws_internet_gateway.main.id

  nat_gateway_public_to_private_mapping = {
    "public-a-1" = ["private-a-1", "private-a-2", "private-d-2"],
    "public-c-1" = ["private-c-1", "private-c-2"],
    "public-d-1" = []
  }
}
```
