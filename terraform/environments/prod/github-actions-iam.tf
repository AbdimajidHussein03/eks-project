
# 1. TRUST POLICY
# Who is allowed to assume this role?

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [
        "arn:aws:iam::583931059504:oidc-provider/token.actions.githubusercontent.com"
      ]
    }

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:AbdimajidHussein03/eks-project:*"
      ]
    }
  }
}

# 2. IAM ROLE
# The AWS identity GitHub Actions will assume


resource "aws_iam_role" "github_actions_terraform" {
  name = "eks-project-github-actions-terraform"

  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}


# 3. CUSTOM S3 STATE POLICY
# Gives Terraform access to its remote state


data "aws_iam_policy_document" "github_actions_state" {

  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]

    resources = [
      "arn:aws:s3:::abdimajid-eks-project-tfstate"
    ]
  }

  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::abdimajid-eks-project-tfstate/*"
    ]
  }
}

# 4. CREATE THE CUSTOM S3 IAM POLICY


resource "aws_iam_policy" "github_actions_state" {
  name        = "eks-project-github-actions-state"
  description = "Terraform state access for the EKS GitHub Actions pipeline"

  policy = data.aws_iam_policy_document.github_actions_state.json
}


# 5. ATTACH S3 STATE POLICY TO GITHUB ROLE


resource "aws_iam_role_policy_attachment" "github_actions_state" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.github_actions_state.arn
}


# 6. EC2 / VPC / SECURITY GROUP ACCESS


resource "aws_iam_role_policy_attachment" "github_actions_ec2" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}


# -------------------------------------------------------
# 7. IAM ACCESS
# Needed because Terraform creates/manages IAM roles,
# policies and OIDC resources
# -------------------------------------------------------

resource "aws_iam_role_policy_attachment" "github_actions_iam" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}


# -------------------------------------------------------
# 8. ECR ACCESS
# Terraform manages the ECR repository
# -------------------------------------------------------

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}


# -------------------------------------------------------
# 9. ROUTE 53 ACCESS
# Terraform reads/manages Route 53-related resources
# -------------------------------------------------------

resource "aws_iam_role_policy_attachment" "github_actions_route53" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}


# -------------------------------------------------------
# 10. EKS MANAGEMENT POLICY
# Explicit permissions for Terraform to manage EKS
# -------------------------------------------------------

data "aws_iam_policy_document" "github_actions_eks" {
  statement {
    effect = "Allow"

    actions = [
      "eks:*"
    ]

    resources = ["*"]
  }
}


resource "aws_iam_policy" "github_actions_eks" {
  name        = "eks-project-github-actions-eks"
  description = "Allow the Terraform GitHub Actions pipeline to manage EKS"

  policy = data.aws_iam_policy_document.github_actions_eks.json
}


resource "aws_iam_role_policy_attachment" "github_actions_eks" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.github_actions_eks.arn
}