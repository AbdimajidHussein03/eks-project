# Trust policy for the GitHub Actions application pipeline.
data "aws_iam_policy_document" "github_actions_application_trust" {
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

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:AbdimajidHussein03@217622941/eks-project@1342833423:ref:refs/heads/main"
      ]
    }
  }
}

# IAM role used by the GitHub Actions application pipeline.
resource "aws_iam_role" "github_actions_application" {
  name               = "eks-project-github-actions-application"
  assume_role_policy = data.aws_iam_policy_document.github_actions_application_trust.json
}

# Allow the pipeline to build and push images to Amazon ECR.
resource "aws_iam_role_policy_attachment" "github_actions_application_ecr" {
  role       = aws_iam_role.github_actions_application.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# Allow the pipeline to interact with the existing EKS cluster.
data "aws_iam_policy_document" "github_actions_application_eks" {
  statement {
    effect = "Allow"

    actions = [
      "eks:DescribeCluster",
      "eks:UpdateClusterConfig",
      "eks:DescribeUpdate"
    ]

    resources = [
      "arn:aws:eks:eu-west-2:583931059504:cluster/eks-project"
    ]
  }
}

# Create the custom EKS IAM policy.
resource "aws_iam_policy" "github_actions_application_eks" {
  name        = "eks-project-github-actions-application-eks"
  description = "Allow the GitHub Actions application pipeline to access the EKS cluster"
  policy      = data.aws_iam_policy_document.github_actions_application_eks.json
}

# Attach the custom EKS policy to the application role.
resource "aws_iam_role_policy_attachment" "github_actions_application_eks" {
  role       = aws_iam_role.github_actions_application.name
  policy_arn = aws_iam_policy.github_actions_application_eks.arn
}

# Allow the IAM role to authenticate to the EKS cluster.
resource "aws_eks_access_entry" "github_actions_application" {
  cluster_name  = "eks-project"
  principal_arn = aws_iam_role.github_actions_application.arn
  type          = "STANDARD"
}

# Give the application pipeline Kubernetes edit permissions in default.
resource "aws_eks_access_policy_association" "github_actions_application" {
  cluster_name  = "eks-project"
  principal_arn = aws_iam_role.github_actions_application.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"

  access_scope {
    type       = "namespace"
    namespaces = ["default"]
  }
}