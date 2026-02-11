variable "env" {
  type        = string
  description = "環境名 (例: dev, stg, prod)"
}

variable "codebuild_project_name" {
  type        = string
  description = "CodeBuild プロジェクト名"
  default     = "example-codebuild-project"
}

variable "codebuild_project_migrate_name" {
  description = "Name of the CodeBuild project for migrations"
  type        = string
  default     = "migrate-project"
}


variable "codebuild_image" {
  type        = string
  description = "CodeBuild で使用するビルドイメージ"
  default     = "aws/codebuild/standard:7.0"
}

variable "codebuild_compute_type" {
  type        = string
  description = "CodeBuild コンピュートタイプ (BUILD_GENERAL1_SMALL など)"
  default     = "BUILD_GENERAL1_SMALL"
}

variable "buildspec_filepath" {
  type        = string
  description = "CodeBuild で使用する buildspec.yml のパス"
  default     = "buildspec.yml"
}

variable "codepipeline_name" {
  type        = string
  description = "CodePipeline の名前"
  default     = "example-pipeline"
}

variable "repository_owner" {
  type        = string
  description = "リポジトリのオーナー (例: ono-hiroki)"
}

variable "repository_name" {
  type        = string
  description = "リポジトリ名 (例: ecs-common-ops)"
}

variable "branch_name" {
  type        = string
  description = "リポジトリのブランチ名 (例: main)"
  default     = "main"
}

variable "artifact_bucket_name" {
  type        = string
  description = "S3 バケット名 (CodePipeline の artifact 保存先)"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS クラスター名"
}

variable "ecs_service_name" {
  type        = string
  description = "ECS サービス名"
}

variable "force_destroy_artifact_bucket" {
  type        = bool
  description = "S3 バケットを強制削除するかどうか"
  default     = true
}

variable "repository_connection_arn" {
  description = "ARN of the CodeStar Connections connection to repository"
  type        = string
}

variable "build_migrate_env_map" {
  description = "BuildMigrateアクションに渡す環境変数"
  type        = map(string)
  # 例: terraform.tfvars で
  # env_vars = {
  #   ENV      = "dev",
  #   APP_ENV  = "dev",
  #   FOO_BAR  = "baz"
  # }
}

variable "trigger_branches_includes" {
  description = "プッシュ トリガーに含めるブランチ名一覧"
  type        = list(string)
  default     = ["main"]
}

variable "trigger_file_paths_includes" {
  description = "プッシュ トリガーに含めるファイル/ディレクトリの glob パターン"
  type        = list(string)
  default     = []         # 空なら file_paths ブロック自体を生成しない
}

################################################################################
# すでにある iam_role モジュールを使うための変数
################################################################################

variable "codepipeline_trusted_identifier" {
  type        = string
  description = "CodePipeline ロールの trust entity (例: codepipeline.amazonaws.com)"
  default     = "codepipeline.amazonaws.com"
}