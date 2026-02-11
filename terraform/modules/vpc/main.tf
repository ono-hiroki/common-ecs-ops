resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  map_public_ip_on_launch = true
  tags = {
    Name = each.value.name
  }
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = var.vpc_id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = {
    Name = each.value.name
  }
}


resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.aws_internet_gateway_id
  }

  tags = {
    Name = var.public_route_table_name
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = var.vpc_id

  tags = {
    Name = "${each.value.tags["Name"]}-rt"
    key  = each.key
  }
}
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}


#########################
# NAT Gateway
#########################
resource "aws_eip" "main" {
  for_each = var.nat_gateway_public_to_private_mapping
  domain   = "vpc"
  tags = {
    Name = "${each.key}-nat"
  }
}

resource "aws_nat_gateway" "main" {
  for_each      = var.nat_gateway_public_to_private_mapping
  allocation_id = aws_eip.main[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = {
    Name    = "${aws_subnet.public[each.key].tags.Name}-nat"
    mapping = each.key
  }
}


locals {
  nat_routes = flatten([
    for public_key, private_keys in var.nat_gateway_public_to_private_mapping : [
      for private_key in private_keys : {
        public_key  = public_key
        private_key = private_key
        // ユニークなキーとして利用
        route_id = "${public_key}-to-${private_key}"
      }
    ]
  ])
  # example:
  #  {
  #    "private_key" = "private-a"
  #    "public_key" = "public-a"
  #    "route_id" = "public-a-to-private-a"
  #  },
  #  {
  #    "private_key" = "private-c"
  #    "public_key" = "public-c"
  #    "route_id" = "public-c-to-private-c"
  #  },
}

output "nat_routes" {
  value = local.nat_routes
}

locals {
  nat_routs = [
    {
      private_key = "private-a"
      public_key  = "public-a"
      route_id    = "public-a-private-a"
    },
    {
      private_key = "private-c"
      public_key  = "public-a"
      route_id    = "public-a-private-c"
    },
  ]

  each_nat_routs = {
    for route in local.nat_routs : route.route_id => route
  }
}

output "each_nat_routs" {
  value = local.each_nat_routs
}
resource "aws_route" "private_subnet_to_nat" {
  for_each = { for route in local.nat_routes : route.route_id => route }
  # example:
  #   {
  #     "public-a-private-a" = {
  #       "private_key" = "private-a"
  #       "public_key" = "public-a"
  #       "route_id" = "public-a-private-a"
  #     }
  #     "public-a-private-c" = {
  #       "private_key" = "private-c"
  #       "public_key" = "public-a"
  #       "route_id" = "public-a-private-c"
  #     }
  #   }

  route_table_id         = aws_route_table.private[each.value.private_key].id
  nat_gateway_id         = aws_nat_gateway.main[each.value.public_key].id
  destination_cidr_block = "0.0.0.0/0"
}