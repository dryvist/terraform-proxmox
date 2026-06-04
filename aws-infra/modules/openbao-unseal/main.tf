terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# NOTE: AWS Provider is configured in parent module (aws-infra/main.tf)
# This module inherits the provider from its parent

# KMS key for OpenBao auto-unseal (AWS KMS seal)
# OpenBao nodes use this key to encrypt/decrypt the root key on startup,
# removing the need for manual unseal-key entry after a restart.
resource "aws_kms_key" "openbao_unseal" {
  description             = "OpenBao auto-unseal"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "openbao-auto-unseal"
  }
}

resource "aws_kms_alias" "openbao_unseal" {
  name          = "alias/openbao-unseal"
  target_key_id = aws_kms_key.openbao_unseal.key_id
}

# Dedicated IAM user the OpenBao nodes authenticate as for the auto-unseal seal.
resource "aws_iam_user" "openbao_unseal" {
  name = "openbao-unseal"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "openbao-auto-unseal"
  }
}

# Least-privilege policy: only the three KMS actions the auto-unseal seal needs,
# scoped to this single key ARN. No wildcard resources, no key administration.
resource "aws_iam_user_policy" "openbao_unseal" {
  name = "openbao-unseal-kms"
  user = aws_iam_user.openbao_unseal.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "OpenBaoUnsealKMS"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = aws_kms_key.openbao_unseal.arn
      },
    ]
  })
}

resource "aws_iam_access_key" "openbao_unseal" {
  user = aws_iam_user.openbao_unseal.name
}
