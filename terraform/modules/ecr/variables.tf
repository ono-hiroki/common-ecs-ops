variable "name" {
  description = "ECRのリポジトリ名"
  type        = string
}

variable "enable_force_delete" {
  description = "ECRの強制削除を有効化"
  type        = bool
  default     = false
}
