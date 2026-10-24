output "analyzer_arn" {
  description = "ARN of the account external-access analyzer."
  value       = aws_accessanalyzer_analyzer.external.arn
}

output "analyzer_name" {
  description = "Name of the account external-access analyzer."
  value       = aws_accessanalyzer_analyzer.external.analyzer_name
}
