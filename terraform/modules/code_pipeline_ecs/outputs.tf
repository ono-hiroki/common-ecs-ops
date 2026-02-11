output "artifact_bucket_name" {
  description = "Artifact 保存用 S3 バケット名"
  value       = aws_s3_bucket.artifact.bucket
}

output "codebuild_project_name" {
  description = "CodeBuild プロジェクト名"
  value       = aws_codebuild_project.main.name
}

output "codepipeline_name" {
  description = "CodePipeline 名"
  value       = aws_codepipeline.main.name
}

output "codebuild_role_arn" {
  description = "CodeBuild 用の IAM ロール ARN"
  value       = module.iam_role_code_build.iam_role_arn
}

output "codepipeline_role_arn" {
  description = "CodePipeline 用の IAM ロール ARN"
  value       = module.iam_role_code_pipeline.iam_role_arn
}

output "codepipeline_arn" {
  value = aws_codepipeline.main.arn
}