# Create a map for non-secure String & SecureString parameters
locals {
  secure_params     = { for param in var.parameters : "${param.comp}/${param.app_alias}/${param.name}" => param if param.type == "SecureString" }
  non_secure_params = { for param in var.parameters : "${param.comp}/${param.app_alias}/${param.name}" => param if param.type != "SecureString" }
}

# Resource for SecureString parameters with ignore_changes on value
# The secure value should be changed after creation
resource "aws_ssm_parameter" "secure" {
  for_each = local.secure_params

  name        = "/${each.value.comp}/${each.value.app_alias}/${each.value.name}"
  value       = each.value.value
  type        = each.value.type
  description = each.value.description
  tags = {
    App_Alias = lower(each.value.app_alias)
    Name = "/${each.value.comp}/${each.value.app_alias}/${each.value.name}"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

# Resource for non-SecureString parameters
resource "aws_ssm_parameter" "non_secure" {
  for_each = local.non_secure_params

  name        = "/${each.value.comp}/${each.value.app_alias}/${each.value.name}"
  value       = each.value.value
  type        = each.value.type
  description = each.value.description
  tags = {
    App_Alias = lower(each.value.app_alias)
    Name = "/${each.value.comp}/${each.value.app_alias}/${each.value.name}"
  }
}
