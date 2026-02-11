# --------------------------------------------------
# Locals
# --------------------------------------------------
locals {
  codepipeline_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess",
    "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess",
    "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
  ]

  codebuild_policy_arns = [
    "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess",
    "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
    aws_iam_policy.codebuild_iam_pass_role.arn,
  ]
}

locals {
  build_migrate_env_list = [
    for k, v in var.build_migrate_env_map : {
      name  = k
      value = v
    }
  ]
}

# --------------------------------------------------
# IAM Policies
# --------------------------------------------------
data "aws_iam_policy_document" "codebuild" {
  version = "2012-10-17"

  statement {
    actions   = ["events:*", "iam:PassRole"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "codebuild_iam_pass_role" {
  name_prefix = "${var.env}-codebuild-"
  policy      = data.aws_iam_policy_document.codebuild.json
}

# --------------------------------------------------
# IAM Role: CodePipeline
# --------------------------------------------------
module "iam_role_code_pipeline" {
  source      = "../../modules/iam/role"
  name        = "${var.env}-codepipeline-role"
  policy_arns = local.codepipeline_policy_arns
}

# --------------------------------------------------
# IAM Role: CodeBuild
# --------------------------------------------------iam_role_code_build
module "iam_role_code_build" {
  source      = "../../modules/iam/role"
  name        = "${var.env}-codebuild-role"
  policy_arns = local.codebuild_policy_arns
}

# --------------------------------------------------
# S3 Bucket (Artifact Store)
# --------------------------------------------------
resource "aws_s3_bucket" "artifact" {
  bucket        = var.artifact_bucket_name
  force_destroy = var.force_destroy_artifact_bucket
}

resource "aws_s3_bucket_lifecycle_configuration" "artifact" {
  bucket = aws_s3_bucket.artifact.bucket
  rule {
    id     = "artifact"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }

  }
}


# --------------------------------------------------
# CodeBuild Project
# --------------------------------------------------
resource "aws_codebuild_project" "main" {
  name         = var.codebuild_project_name
  service_role = module.iam_role_code_build.iam_role_arn

  source {
    type      = "CODEPIPELINE"
    buildspec = var.buildspec_filepath
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.codebuild_compute_type
    image           = var.codebuild_image
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }
}

resource "aws_codebuild_project" "migrate" {
  name         = var.codebuild_project_migrate_name
  description  = var.codebuild_project_migrate_name
  service_role = module.iam_role_code_build.iam_role_arn


  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-migrate.yml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true
  }
}


# --------------------------------------------------
# CodePipeline
# --------------------------------------------------
resource "aws_codepipeline" "main" {
  name     = var.codepipeline_name
  role_arn = module.iam_role_code_pipeline.iam_role_arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifact.bucket
    type     = "S3"
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        dynamic "branches" {
          for_each = length(var.trigger_branches_includes) > 0 ? [1] : []
          content {
            includes = var.trigger_branches_includes
          }
        }

        dynamic "file_paths" {
          for_each = length(var.trigger_file_paths_includes) > 0 ? [1] : []
          content {
            includes = var.trigger_file_paths_includes
          }
        }
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["Source"]

      configuration = {
        ConnectionArn    = var.repository_connection_arn
        FullRepositoryId = "${var.repository_owner}/${var.repository_name}"
        BranchName       = var.branch_name
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["Source"]
      output_artifacts = ["Build"]

      configuration = {
        ProjectName = aws_codebuild_project.main.name

        EnvironmentVariables = jsonencode([
          {
            name  = "ENV"
            value = var.env
          },
          # {
          #   name  = "APP_ENV"
          #   value = var.app_env
          # }
        ])
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "BuildMigrate"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["Source"]
      version         = "1"
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.migrate.name

        EnvironmentVariables = jsonencode(local.build_migrate_env_list)
      }
    }

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["Build"]
      run_order       = 2

      configuration = {
        ClusterName = var.ecs_cluster_name
        ServiceName = var.ecs_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}