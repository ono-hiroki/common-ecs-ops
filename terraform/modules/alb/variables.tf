variable "env" {
  type        = string
  description = "環境名 (例: dev, staging, production)"
}

variable "vpc_id" {
  type        = string
  description = "VPCのID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "ALBを配置するサブネットのIDリスト"
}

variable "alb_name" {
  type        = string
  description = "ALB の Name タグやリソース名に使用する"
}

variable "sg_ingress_cidr_blocks" {
  type        = list(string)
  description = "ALB SGのingressで許可するCIDRブロックリスト"
}

variable "target_group_name" {
  type        = string
  description = "ターゲットグループ名"
}

variable "health_check_path" {
  type        = string
  description = "ターゲットグループのヘルスチェックパス"
}

variable "matcher" {
  type        = string
  description = "ヘルスチェックのHTTPコード判定"
}

variable "certificate_arns" {
  description = "HTTPS リスナー用の ACM 証明書 ARN のリスト。リストの最初の証明書がデフォルト証明書として設定されます。"
  type        = list(string)
  default     = []
}

variable "enable_https" {
  type        = bool
  description = "HTTPS リスナーを有効にするかどうか"
  default     = true
}

variable "a_record_names" {
  type        = list(string)
  description = "ALBに紐づけるAレコードの名前"
  default     = null
}

variable "alb_log_bucket_name" {
  type        = string
  description = "ALBのアクセスログを保存するS3バケット名"
}