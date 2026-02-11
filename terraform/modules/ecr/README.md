## ECR module

このモジュールはライフサイクルポリシーを持つAWS ECSリポジトリを作成します。

- Lifecycle Policyは10個のイメージを保持し、それ以上のイメージは削除します。
- イメージはMutableであり、イメージのタグが変更されると新しいイメージが作成されます。
- enable_force_deleteを有効にすると、リポジトリの強制削除を有効にします。デフォルトでは無効です。

## Requirements

No requirements.

## Providers

| Name                                              | Version |
|---------------------------------------------------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a     |

## Modules

No modules.

## Resources

| Name                                                                                                                              | Type     |
|-----------------------------------------------------------------------------------------------------------------------------------|----------|
| [aws_ecr_lifecycle_policy.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository)             | resource |

## Inputs

| Name                                                                                            | Description  | Type     | Default | Required |
|-------------------------------------------------------------------------------------------------|--------------|----------|---------|:--------:|
| <a name="input_enable_force_delete"></a> [enable\_force\_delete](#input\_enable\_force\_delete) | ECRの強制削除を有効化 | `bool`   | `false` |    no    |
| <a name="input_name"></a> [name](#input\_name)                                                  | ECRのリポジトリ名   | `string` | n/a     |   yes    |

## Outputs

| Name                                             | Description |
|--------------------------------------------------|-------------|
| <a name="output_name"></a> [name](#output\_name) | ECRリポジトリの名前 |

## Usage

```hcl
module "ecr" {
  source = "./modules/ecr"
  name                = "example-repo"
  enable_force_delete = false
}