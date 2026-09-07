terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-github-oidc-role?version=5.60.0"
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependencies {
  paths = ["../github_oidc_provider"]
}

inputs = {
  name = "role-${include.inputs.landscape}-${include.inputs.env}-${include.inputs.region_short}-github_oidc"

subjects = include.inputs.oidc_subjects

  policies = {
    AmazonS3FullAccess     = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    CloudFrontFullAccess   = "arn:aws:iam::aws:policy/CloudFrontFullAccess"
    AWSLambda_FullAccess   = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
  }
}
