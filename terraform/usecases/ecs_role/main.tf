variable "env" {
  type        = string
  description = "環境名。"
}

module "iam_role_ecs" {
  source = "../../modules/iam/role"
  name   = "${var.env}-ecs-role"
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/service-role/ROSAKMSProviderPolicy",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite",
  ]
}

// ecsからs3にアクセスするためのポリシー
data "aws_iam_policy_document" "kms_decrypt_for_ecs" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt"
      # "kms:Encrypt",
      # "kms:ReEncrypt*",
      # "kms:GenerateDataKey*",
      # "kms:DescribeKey"
    ]
    resources = [
      "arn:aws:kms:ap-northeast-1:617050261132:key/e6213d98-238f-4e5b-949a-f8ba810098a0"
    ]
  }
}

resource "aws_iam_policy" "kms_decrypt_for_ecs" {
  name        = "${var.env}-kms-decrypt-for-ecs"
  description = "Allow ECS role to decrypt with the specified KMS key"
  policy      = data.aws_iam_policy_document.kms_decrypt_for_ecs.json
}



output "iam_role_arn" {
  value = module.iam_role_ecs.iam_role_arn
}