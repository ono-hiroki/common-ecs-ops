variable "env" {}
variable "vpc_id" {}
variable "source_security_group_ids" {}
variable "zone_id" {}
variable "cname" {}
variable "cname_ro" {}
variable "subnet_ids" {
  type = list(string)
}
variable "availability_zones" {
  type = list(string)
}
variable "instance_count" {}
variable "user_name" {}
variable "password" {}
variable "database_name" {}
variable "min_capacity" {}
variable "max_capacity" {}
variable "is_fixed" {
  description = "RDSクラスターの削除保護を有効化するか"
  type        = bool
}
