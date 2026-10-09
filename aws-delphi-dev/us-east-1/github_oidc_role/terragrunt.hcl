terraform {
  source = "../../../tf-modules/tf-github-oidc-role"
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependencies {
  paths = ["../github_oidc_provider"]
}
