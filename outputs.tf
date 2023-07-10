output  "key_resources" {
  description = "Key Resources provides for full resource mapping for each of the defined sites; allowing access to the full range of resource attributes."
  value = {
    for key,site in var.deployments : key => {
      aws_cloudfront_distribution = try(aws_cloudfront_distribution.default[key], null)
      domains_created             = [for i,domain in local.domains_map :  domain.domain if domain.key == key]
      s3_buckets_created          = [for i,bucket in local.buckets_to_create : format("%s.s3.amazonaws.com", bucket.bucket_name) if bucket.key == key]
    }
  }
}

output  "key_attributes" {
  description = "Key Attributes provides for a specific mapping of defined resource values for each of the defined sites; allowing for human friendly output."
  value = {
    for key,site in var.deployments : key => {
      id              = try(aws_cloudfront_distribution.default[key].id, null)
      arn             = try(aws_cloudfront_distribution.default[key].arn, null)
      status          = try(aws_cloudfront_distribution.default[key].status, null)
      domain_name     = try(aws_cloudfront_distribution.default[key].domain_name, null)
      domains_created     = [for i,domain in local.domains_map :  domain.domain if domain.key == key]
      s3_buckets_created  = [for i,bucket in local.buckets_to_create : format("%s.s3.amazonaws.com", bucket.bucket_name) if bucket.key == key]
      s3_origins  = {
        for okey,origin in site.origins : okey => {
          s3_bucket       = format("%s.s3.amazonaws.com", origin.bucket_name)
          origin_path     = origin.origin_path
          s3_bucket_arn   = origin.create_bucket == true? aws_s3_bucket.default[format("%s.%s", key, okey)].arn  : null
        }
      }
      aliases         = try(aws_cloudfront_distribution.default[key].aliases, null)
      origin_access_identity  = {
        id                              = try(aws_cloudfront_origin_access_identity.default[key].id, null)
        iam_arn                         = try(aws_cloudfront_origin_access_identity.default[key].iam_arn, null)
        cloudfront_access_identity_path = try(aws_cloudfront_origin_access_identity.default[key].cloudfront_access_identity_path, null)
      }
    }
  }
}

output "aws_caller_identity" { value = data.aws_caller_identity.current }
output "aws_region" { value = data.aws_region.current }
output "base-tags" { value = var.base-tags }
output "deployments" { value = var.deployments }
output "testing" { value = local.buckets_to_create }