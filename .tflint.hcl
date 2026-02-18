plugin "aws" {
  enabled = true
  version = "0.35.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  format = "compact"
  module = true
  force = false
}

rule "terraform_required_providers" { enabled = true }
rule "terraform_required_version"   { enabled = true }
