resource "aws_accessanalyzer_analyzer" "external" {
  analyzer_name = "analyzer-${var.landscape}-${var.env}-${var.region_short}-external"
  type          = "ACCOUNT"

  tags = {
    Name = "analyzer-${var.landscape}-${var.env}-${var.region_short}-external"
  }
}
