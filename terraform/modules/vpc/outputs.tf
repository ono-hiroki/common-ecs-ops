////////////////////////////////////////////////////////////
// Public Subnets
////////////////////////////////////////////////////////////
output "public_subnet_ids" {
  description = "List of all public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "public_subnet_key_ids" {
  description = "Map of public subnet keys to their IDs"
  value = {
    for name, subnet in aws_subnet.public :
    name => subnet.id
  }
}

output "public_subnet_cidr_blocks" {
  description = "Map of public subnet name to CIDR block"
  value = {
    for subnet_key, subnet in aws_subnet.public :
    subnet_key => subnet.cidr_block
  }
}

////////////////////////////////////////////////////////////
// Private Subnets
////////////////////////////////////////////////////////////
output "private_subnet_ids" {
  description = "List of all private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnet_cidr_blocks" {
  description = "Map of private subnet name to CIDR block"
  value = {
    for subnet_key, subnet in aws_subnet.private :
    subnet_key => subnet.cidr_block
  }
}

////////////////////////////////////////////////////////////
// Route Table
////////////////////////////////////////////////////////////
output "public_route_table_id" {
  description = "ID of the created public route table"
  value       = aws_route_table.public.id
}

output "public_route_table_association_ids" {
  description = "Map of public subnet key to route table association ID"
  value = {
    for subnet_key, assoc in aws_route_table_association.public :
    subnet_key => assoc.id
  }
}

# output "private_route_table_id" {
#   description = "プライベートルートテーブルのID (存在しない場合はnull)"
#   value     = length(aws_route_table.private) > 0 ? aws_route_table.private[0].id : null
# }




# output "aws_subnet_private" {
#   value = aws_subnet.private
# }