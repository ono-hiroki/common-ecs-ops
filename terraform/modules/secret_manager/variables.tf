variable "secrets" {
  type        = map(string)
  description = <<EOT
  Map 形式で渡すシークレット一覧。
  key = シークレット名
  value = シークレットの値
  EOT
}

variable "prefix_key" {
  type        = string
  description = "シークレットのkeyにつけるprefix。"
  default     = ""
}