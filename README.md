# common-ecs-ops

ECS Fargate 環境を構築するための Terraform モジュール集。環境ごとの設定分離と再利用可能なモジュール設計で、インフラの標準化を実現。

## ディレクトリ構成

```
terraform/
├── modules/              # 再利用可能な Terraform モジュール
│   ├── vpc/              # VPC、サブネット、NAT Gateway
│   ├── alb/              # Application Load Balancer
│   ├── ecs/              # ECS クラスター、サービス、タスク定義
│   ├── ecr/              # Elastic Container Registry
│   ├── rds/              # RDS (PostgreSQL/MySQL)
│   ├── acm/              # SSL/TLS 証明書
│   ├── iam/              # IAM ロール、ポリシー
│   ├── secret_manager/   # Secrets Manager
│   └── code_pipeline_ecs/# CodePipeline + CodeBuild (CI/CD)
├── environments/         # 環境ごとの設定 (.tfbackend, .tfvars)
│   ├── dev/
│   ├── stg/
│   └── prd/
├── case/                 # 環境ごとのエントリーポイント
└── Taskfile.yaml         # Task runner 設定
```

## モジュール一覧

| モジュール | 説明 |
|-----------|------|
| `vpc` | VPC、パブリック/プライベートサブネット、NAT Gateway、Internet Gateway |
| `alb` | ALB、ターゲットグループ、リスナー設定 |
| `ecs` | ECS Fargate クラスター、サービス、タスク定義、マイグレーションタスク |
| `ecr` | コンテナイメージリポジトリ |
| `rds` | RDS インスタンス、サブネットグループ、セキュリティグループ |
| `acm` | ACM 証明書（DNS 検証） |
| `iam` | ECS タスク実行ロール、タスクロール |
| `secret_manager` | データベース認証情報などのシークレット管理 |
| `code_pipeline_ecs` | GitHub → CodeBuild → ECS デプロイの CI/CD パイプライン |

## 使い方

### 前提条件

- [Terraform](https://www.terraform.io/) 1.0+
- [Task](https://taskfile.dev/)
- AWS CLI（プロファイル設定済み）

### 環境セットアップ

1. 環境ごとの設定ファイルを作成

```bash
# environments/dev/
.tfbackend   # S3 バックエンド設定
.tfvars      # 環境変数
.profile     # AWS プロファイル (export AWS_PROFILE=xxx)
```

2. Terraform 実行

```bash
# dev 環境の plan
task dev:tf:plan

# dev 環境の apply
task dev:tf:apply

# stg/prd も同様
task stg:tf:plan
task prd:tf:apply
```

### 利用可能なコマンド

| コマンド | 説明 |
|---------|------|
| `task {env}:tf:init` | Terraform 初期化 |
| `task {env}:tf:plan` | 変更内容のプレビュー |
| `task {env}:tf:apply` | インフラ適用 |
| `task {env}:tf:destroy` | インフラ削除 |
| `task {env}:tf:state:list` | State 一覧表示 |

※ `{env}` は `dev`, `stg`, `prd` のいずれか

## 設計方針

- **モジュール分離**: 各 AWS リソースを独立したモジュールとして管理
- **環境分離**: dev/stg/prd の設定を `.tfvars` で切り替え
- **State 管理**: S3 バックエンドでリモート State 管理
- **CI/CD 統合**: CodePipeline モジュールでデプロイ自動化
