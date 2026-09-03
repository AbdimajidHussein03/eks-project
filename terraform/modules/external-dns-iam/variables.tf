variable "eks_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "route53_zone_name" {
  description = "Route 53 hosted zone name"
  type        = string
}