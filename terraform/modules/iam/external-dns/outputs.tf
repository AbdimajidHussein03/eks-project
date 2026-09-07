output "external_dns_role_arn" {
  description = "Expose the ExternalDNS IAM role ARN"
  value       = aws_iam_role.external_dns.arn
}