terraform {
  source = "tfr:///terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider?version=5.60.0"
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = {
  tags = {
    Name = "provider-${include.inputs.landscape}-${include.inputs.env}-${include.inputs.region_short}-github_oidc"
  }
}
