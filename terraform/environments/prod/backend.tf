terraform {
  backend "s3" {
    bucket       = "abdimajid-eks-project-tfstate"
    key          = "eks-project/prod/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}