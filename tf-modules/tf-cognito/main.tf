resource "aws_cognito_user_pool" "user_pools" {
  for_each = var.user_pools

  name = "cognito-${var.landscape}-${var.env}-${var.region_short}-${each.key}"

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = false
  }

  dynamic "schema" {
    for_each = try(var.custom_sign_in_attributes[each.key], [])
    content {
      attribute_data_type = schema.value.attribute_data_type
      name                = schema.value.name
      required            = schema.value.required
      mutable             = schema.value.mutable

      dynamic "string_attribute_constraints" {
        for_each = schema.value.attribute_data_type == "String" ? [schema.value] : []
        content {
          min_length = try(string_attribute_constraints.value.min_length, null)
          max_length = try(string_attribute_constraints.value.max_length, null)
        }
      }
    }
  }

  auto_verified_attributes = ["email"]

  tags = {
    Landscape = var.landscape
    Name      = "cognito-${var.landscape}-${var.env}-${var.region_short}-${each.key}"
  }
}

resource "aws_cognito_user_pool_client" "app_clients" {
  for_each = var.applications

  name                = "${each.key}-client"
  user_pool_id        = aws_cognito_user_pool.user_pools[each.value.user_pool].id
  explicit_auth_flows = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]

  callback_urls       = each.value.callback_urls
  logout_urls         = each.value.logout_urls
  allowed_oauth_flows = each.value.allowed_oauth_flows
  allowed_oauth_scopes = each.value.allowed_oauth_scopes
  allowed_oauth_flows_user_pool_client = try(each.value.allowed_oauth_flows_user_pool_client, true)
  supported_identity_providers = each.value.supported_identity_providers

  # Token configuration
  access_token_validity  = try(var.token_configuration[each.key].access_token_validity, 60)
  id_token_validity      = try(var.token_configuration[each.key].id_token_validity, 60)
  refresh_token_validity = try(var.token_configuration[each.key].refresh_token_validity, 30)

  token_validity_units {
    access_token  = try(var.token_configuration[each.key].token_validity_units.access_token, "minutes")
    id_token      = try(var.token_configuration[each.key].token_validity_units.id_token, "minutes")
    refresh_token = try(var.token_configuration[each.key].token_validity_units.refresh_token, "days")
  }

  depends_on = [aws_cognito_identity_provider.saml_providers["<IDP_NAME>"]]
}

resource "aws_cognito_identity_provider" "saml_providers" {
  for_each = { for k, v in var.applications : k => v if try(v.saml_provider_name, null) != null }

  user_pool_id  = aws_cognito_user_pool.user_pools[each.value.user_pool].id
  provider_name = each.value.saml_provider_name
  provider_type = "SAML"
  provider_details = {
    MetadataURL = each.value.saml_metadata_document_url
  }

  attribute_mapping = each.value.attribute_mapping

  lifecycle {
    ignore_changes = [
      provider_details["ActiveEncryptionCertificate"],
      provider_details["SLORedirectBindingURI"],
      provider_details["SSORedirectBindingURI"]
    ]
  }
}


# Create Cognito domains for each user pool
resource "aws_cognito_user_pool_domain" "domains" {
  for_each = var.user_pools

  domain      = "${var.landscape}-${var.env}-${var.region_short}"
  user_pool_id = aws_cognito_user_pool.user_pools[each.key].id

}
