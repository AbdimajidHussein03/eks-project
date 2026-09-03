vpc_name = "eks-project-vpc"

vpc_cidr = "10.0.0.0/16"

availability_zones = [
  "eu-west-2a",
  "eu-west-2b",
  "eu-west-2c"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24"
]

private_subnet_cidrs = [
  "10.0.4.0/24",
  "10.0.5.0/24",
  "10.0.6.0/24"
]

cluster_name    = "eks-project"
cluster_version = "1.35"

eks_public_access_cidrs = ["45.150.144.196/32"]