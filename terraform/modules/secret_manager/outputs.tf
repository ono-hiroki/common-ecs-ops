output "secrets_list" {
  description = "AWS ECS タスク定義などで利用できる形に整形したシークレットリスト"
  value = [
    for key, _ in var.secrets : {
      name      = key
      valueFrom = aws_secretsmanager_secret.secrets[key].arn
    }
  ]
}