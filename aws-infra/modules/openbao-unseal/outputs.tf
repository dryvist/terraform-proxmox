output "kms_key_id" {
  description = "KMS key ID for OpenBao auto-unseal"
  value       = aws_kms_key.openbao_unseal.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for OpenBao auto-unseal"
  value       = aws_kms_key.openbao_unseal.arn
}

output "unseal_iam_user" {
  description = "IAM user name the OpenBao nodes authenticate as for auto-unseal"
  value       = aws_iam_user.openbao_unseal.name
}

output "unseal_access_key_id" {
  description = "AWS access key ID for the OpenBao auto-unseal IAM user"
  value       = aws_iam_access_key.openbao_unseal.id
}

output "unseal_secret_access_key" {
  description = "AWS secret access key for the OpenBao auto-unseal IAM user"
  value       = aws_iam_access_key.openbao_unseal.secret
  sensitive   = true
}
