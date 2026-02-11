variable "env" {
  description = "環境名"
}
variable "domain" {
  description = "ドメイン名"
}

variable "environment_map" {
  description = "ECSに渡す環境変数"
  type        = map(string)
}

variable "secrets_map" {
  description = "secrets manager 経由でECSに渡す環境変数"
  type        = map(string)
}