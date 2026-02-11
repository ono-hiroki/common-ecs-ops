output "security_group_id" {
  description = "Aurora Serverless のセキュリティグループID"
  value       = aws_security_group.main.id
}