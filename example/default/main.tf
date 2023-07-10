#------------------------------------------------------------------------------#
# @title: Terraform Example
# @description: Used to test and provide a working example for this module.
#------------------------------------------------------------------------------#

terraform {
  required_version = "~> 1.1.3"
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

variable "aws_region" {
  description = "(Optional) AWS region for this to be applied to. (Default: 'us-east-1')"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "(Optional) Provider AWS profile name for local aws cli configuration. (Default: '')"
  type        = string
  default     = ""
}

module "example-default" {
  source    = "../../"
  base-tags = {
    Environment = "test"
    Managed     = "true"
    CreatedBy   = "terraform"
  }
  
  deployments = {  
    distro_001  = {
      name = "a-fancee-example-01"
      enable_metrics  = true
      origins = {
        default = {
          bucket_name     = "an-example-01"
          create_bucket   = true
          s3_upload = [{
            enabled = true
            path    = "html"
            pattern = "**"
            prefix  = ""
          }]
          s3_website = {
            index_document = "index.html"
            error_document = "index.html"
            routing_rules = [
              {
                Condition = { 
                  KeyPrefixEquals = "alpha/"
                  HttpErrorCodeReturnedEquals = "404"
                }
                Redirect  = {
                  HttpRedirectCode = 302
                  ReplaceKeyPrefixWith = "beta/"
                }
              }
            ]
          }
        }
      }
    }
  }
}

# Additional outputs available.
output "example-default--aws_region"          { value = module.example-default.aws_region }
output "example-default--key_attributes"      { value = module.example-default.key_attributes }
output "example-default--name"                { value = "Default S3"}
output "example-default--base-tags"           { value = module.example-default.base-tags }
