variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
    name = string
  }))
}

variable "private_subnets" {
  type = map(object({
    cidr = string
    az   = string
    name = string
  }))
  default = {}
}

variable "public_route_table_name" {
  description = "Name of the public route table"
  type        = string
}

variable "aws_internet_gateway_id" {
  description = "ID of the internet gateway"
  type        = string
}

variable "enable_nat_gateway" {
  description = "プライベートサブネット向けの NAT Gateway を作成するかどうかを制御します。true の場合は NAT 関連リソースを作成します。"
  type        = bool
  default     = false
}

variable "nat_gateway_public_to_private_mapping" {
  description = <<EOF
各キーに指定されたパブリックサブネットに対して NAT Gateway を作成し、対応する値に記載されたプライベートサブネットでは、その NAT Gateway を利用するルートを追加します。

例:
  nat_gateway_public_to_private_mapping = {
    "public-a" = ["private-a", "private-d"],
    "public-c" = ["private-c"],
  }
この例では、"public-a" サブネットに NAT Gateway を作成し、"private-a" および "private-d" サブネットにその NAT Gateway を利用するルートを追加します。
同様に、"public-c" サブネットに NAT Gateway を作成し、"private-c" サブネットにその NAT Gateway を利用するルートを追加します。
EOF
  type        = map(list(string))
  default     = {}

  validation {
    condition = length(var.nat_gateway_public_to_private_mapping) == 0 || alltrue(
      [for k, _ in var.nat_gateway_public_to_private_mapping : contains(keys(var.public_subnets), k)]
    )
    error_message = "すべての nat_gateway_public_to_private_mapping のキーは、public_subnets のキーのいずれかでなければなりません。"
  }

  validation {
    condition = (
      length(var.nat_gateway_public_to_private_mapping) == 0 ||
      alltrue([
        for key in flatten(values(var.nat_gateway_public_to_private_mapping)) : contains(keys(var.private_subnets), key)
      ])
    )
    error_message = "nat_gateway_public_to_private_mapping のすべての値は、private_subnets のキーのいずれかでなければなりません。"
  }

  validation {
    condition = (
      length(var.nat_gateway_public_to_private_mapping) == 0 ||
      alltrue([
        for k, _ in var.nat_gateway_public_to_private_mapping : contains(keys(var.public_subnets), k)
      ])
    )
    error_message = "nat_gateway_public_to_private_mapping のキーは、public_subnets のキーのいずれかでなければなりません。"
  }

  validation {
    condition = (
      length(var.nat_gateway_public_to_private_mapping) == 0 ||
      // distinct で重複を削除。重複がある場合はキーの数が減るため、キーの数が同じであれば重複がない
      length(keys(var.nat_gateway_public_to_private_mapping)) == length(distinct(keys(var.nat_gateway_public_to_private_mapping)))
    )
    error_message = "nat_gateway_public_to_private_mapping のキーに重複があります。"
  }

  validation {
    condition = (
      length(var.nat_gateway_public_to_private_mapping) == 0 ||
      length(flatten(values(var.nat_gateway_public_to_private_mapping))) == length(distinct(flatten(values(var.nat_gateway_public_to_private_mapping))))
    )
    error_message = "nat_gateway_public_to_private_mapping の値に重複があります。"
  }
}

