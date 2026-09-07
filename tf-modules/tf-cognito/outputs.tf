output "user_pool_ids" {
  description = "Map of user pool names to their IDs"
  value = { for name, pool in aws_cognito_user_pool.user_pools : name => pool.id }
}

output "app_client_ids" {
  description = "Map of application names to their client IDs"
  value = { for app, client in aws_cognito_user_pool_client.app_clients : app => client.id }
}

output "saml_provider_names" {
  description = "Map of application names to their SAML provider names"
  value = { for app, provider in aws_cognito_identity_provider.saml_providers : app => provider.provider_name }
}

output "saml_provider_metadata_urls" {
  description = "Map of application names to their SAML metadata URLs"
  value = { for app, provider in aws_cognito_identity_provider.saml_providers : app => provider.provider_details["MetadataURL"] }
}

output "app_client_callback_urls" {
  description = "Map of application names to their callback URLs"
  value = { for app, client in aws_cognito_user_pool_client.app_clients : app => client.callback_urls }
}

output "app_client_logout_urls" {
  description = "Map of application names to their logout URLs"
  value = { for app, client in aws_cognito_user_pool_client.app_clients : app => client.logout_urls }
}

output "user_pool_custom_attributes" {
  description = "Map of user pool names to their custom attributes"
  value = var.custom_sign_in_attributes
}

output "cognito_domain_urls" {
  description = "Map of user pool names to their full Cognito domain URLs"
  value = {
    for name, domain in aws_cognito_user_pool_domain.domains :
    name => "https://${domain.domain}.auth.${var.region}.amazoncognito.com"
  }
}

output "token_configurations" {
  description = "Map of application names to their token configurations"
  value = {
    for app, config in var.token_configuration : app => {
      access_token_validity  = config.access_token_validity
      id_token_validity      = config.id_token_validity
      refresh_token_validity = config.refresh_token_validity
      token_validity_units   = config.token_validity_units
    }
  }
}
