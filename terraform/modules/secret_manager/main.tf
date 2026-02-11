resource "aws_secretsmanager_secret" "secrets" {
  for_each                       = var.secrets
  name                           = "${var.prefix_key}${each.key}"
  description                    = "Secret for ${each.key}"
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = false
}

resource "aws_secretsmanager_secret_version" "secret_versions" {
  for_each      = var.secrets
  secret_id     = aws_secretsmanager_secret.secrets[each.key].id
  # secret_string = each.value
  secret_string_wo          = each.value
  secret_string_wo_version  = 1
}