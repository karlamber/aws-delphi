terraform {
  source = "../../../tf-modules/tf-cognito"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = {
  user_pools = {
    employees = { detail = "employees" }
  }

  custom_sign_in_attributes = {
    employees = [
      {
        name                = "roles"
        attribute_data_type = "String"
        required            = false
        mutable             = true
        min_length          = 0
        max_length          = 2048
      }
    ]
  }

  applications = {
    argus = {
      user_pool                    = "employees"
      name                         = "argus-authn"
      domain                       = "argus-authn-${include.inputs.env}"
      allow_admin_create_user_only = true
      # Add SAML when ready:
      # saml_provider_name         = "<IDP_NAME>"
      # saml_metadata_document_url = "<SAML_METADATA_URL>"
      callback_urls = [
        "http://localhost:9000/auth/callback",
        "https://argus-${include.inputs.env}.fifty9.net/auth/callback",
      ]
      logout_urls = [
        "http://localhost:9000/login",
        "https://argus-${include.inputs.env}.fifty9.net/login",
      ]
      allowed_oauth_flows          = ["code"]
      allowed_oauth_scopes         = ["openid", "email", "profile"]
      supported_identity_providers = ["COGNITO"]
      attribute_mapping = {
        email       = "email"
        given_name  = "given_name"
        family_name = "family_name"
      }
    }
  }
}
