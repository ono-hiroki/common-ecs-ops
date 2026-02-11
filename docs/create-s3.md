# S3の作成

- terraform state用のバケット作成

- 標準化では、バケット名を`<env>-<domain>-terraform-state`の形式で作成している。しかし、命名は悩み中。
- `terraform-state-<AWSアカウントID>-<project名>-<env>`の形式にすることも検討中。

```bash
aws s3api create-bucket \
--bucket '{{ .BUCKET_NAME }}' \
--create-bucket-configuration "LocationConstraint={{ .AWS_DEFAULT_REGION }}"
```

手動でS3を作成するのが面倒な場合はTerragruntを使うのもありな気がしている。