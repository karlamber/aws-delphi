# Output for SecureString parameters
output "secure_parameter_names_and_types" {
  value = {
    for key, param in aws_ssm_parameter.secure :
    key => {
      name = param.name
      type = param.type
    }
  }
  description = "A map of SecureString parameter names and types"
}

# Output for non-SecureString parameters
output "non_secure_parameter_names_and_types" {
  value = {
    for key, param in aws_ssm_parameter.non_secure :
    key => {
      name = param.name
      type = param.type
    }
  }
  description = "A map of non-SecureString parameter names and types"
}
