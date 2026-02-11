variable "env" {}
variable "app_env" {}
variable "security_group_name" {
  description = "Name of the security group for the migrate task"
  type        = string
  default     = "migrate-task-sg"
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

