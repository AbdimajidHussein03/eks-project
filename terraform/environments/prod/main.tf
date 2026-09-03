module "vpc" {
  source = "../../modules/vpc"

  vpc_name             = var.vpc_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "iam" {
  source = "../../modules/iam"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  private_subnet_ids              = module.vpc.private_subnet_ids
  cluster_role_arn                = module.iam.cluster_role_arn
  node_role_arn                   = module.iam.node_role_arn
  eks_public_access_cidrs         = var.eks_public_access_cidrs
  admin_principal_arn             = "arn:aws:iam::583931059504:user/terraform-eks-project"
  control_plane_security_group_id = module.security.control_plane_security_group_id
  node_security_group_id          = module.security.node_security_group_id
}

module "security" {
  source = "../../modules/security"

  vpc_id       = module.vpc.vpc_id
  cluster_name = var.cluster_name
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = "eks-2048"
}

module "external_dns_iam" {
  source = "../../modules/external-dns-iam"

  eks_oidc_issuer_url = module.eks.oidc_issuer_url
  route53_zone_name   = "abdimajidcloud.com"
}