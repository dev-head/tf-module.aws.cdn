
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {

  default_origin_ssl_protocols  = ["TLSv1.2"]
  
  # mapping to support custom strings vs oddly named price class.
  price_class_map = {
    all_locations           = "PriceClass_All",
    north_america_africa    = "PriceClass_200"
    north_america           = "PriceClass_100",
  }

  default_cache_behavior  = {
    target_origin_id        = "default"
    allowed_methods         = ["GET", "OPTIONS", "HEAD"]
    cached_methods          = ["GET", "OPTIONS", "HEAD"]
    viewer_protocol_policy  = "redirect-to-https"
    compress                = "true"
    default_ttl             = 86400
    max_ttl                 = 31536000
    min_ttl                 = 10
    trusted_signers         = []
    forwarded_values        = {
      headers                 = []
      query_string            = true
      query_string_cache_keys = []
      cookies                 = { forward = "all", whitelisted_names = []}
    }
    lambda_function_associations = {}
  }

  default_geo_restrictions = {
    restriction_type    = "none"
    locations           = []
  }
  
  default_cors_policy = {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = []
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }  
    
  # Building a list of domains to create.
  list_of_domains = flatten(try([for deployment_key,deployment in var.deployments : [
    for index,domain in deployment.aliases_to_create: {
      key         = deployment_key
      index       = index
      domain      = domain.domain
      zone_mame   = domain.zone_name
    }    
  ]], []))
    
  # transform list to map so we can iterate over it in terraform for_each.
  domains_map =  {
    for domain in local.list_of_domains : "${domain.key}.${domain.index}" => domain
  }

  list_of_origins = flatten(try([for deployment_key,deployment in var.deployments : [
    for index,origin in deployment.origins: merge(origin, {
      key     = deployment_key
      index   = index
      tags    = deployment.tags
    })    
  ]], []))

  buckets_to_create =  {
    for item in local.list_of_origins : "${item.key}.${item.index}" => item if item.create_bucket == true
  }

  buckets_existing =  {
    for item in local.list_of_origins : "${item.key}.${item.index}" => item if item.create_bucket != true
  }

  origins = { 
    for item in local.list_of_origins : "${item.key}.${item.index}" => item
  }

  # we are building a list of s3 files that will be uploaded to s3.
  # to do this, we iterate over each deployment, each origin, each origins s3_upload configuration,
  # and each file matched from that configuration.
  # then we dress up the object to provide all the s3 upload data we'll need to iterate over as a resource.
  list_of_s3_upload_objects = flatten([for deployment_key,deployment in var.deployments : [
    for origin_key,origin in deployment.origins:  [
      for upload_key,s3_upload in origin.s3_upload : [
        for file_key,file_name in flatten([fileset(format("%s/%s", path.cwd, s3_upload.path), s3_upload.pattern)]) : {
          file_name   = file_name
          derived_key = format("%s.%s.%s.%s", deployment_key, origin_key, upload_key, file_key)
          bucket_name = origin.bucket_name
          object_path = s3_upload.prefix != ""? trimprefix(format("%s/%s/%s", trim(coalesce(origin.origin_path, "/"), "/"), trim(s3_upload.prefix, "/"), file_name), "/") : trimprefix(format("%s/%s", trim(coalesce(origin.origin_path, "/"), "/"), file_name), "/")
          upload_path = s3_upload.path != ""? format("%s/%s", s3_upload.path, file_name) : format("%s/%s", path.cwd, file_name)
          bucket_key  = format("%s.%s", deployment_key, origin_key)
        } if s3_upload.enabled
      ]
    ]
  ]] )
          
  map_of_s3_upload_objects = { for item in local.list_of_s3_upload_objects : item.derived_key => item }
}

data "aws_iam_policy_document" "default" {
  for_each    = local.buckets_to_create
  statement {
    sid       = "CF_OriginS3ObjectAccess"
    actions   = ["s3:GetObject"]
    resources = [format("arn:aws:s3:::%s/*", each.value["bucket_name"])]
    principals {
      type        = "AWS"
      identifiers = [
        aws_cloudfront_origin_access_identity.default[each.value["key"]].iam_arn
      ]
    }
  }
  statement {
    sid       = "CF_OriginS3BucketAccess"
    actions   = ["s3:ListBucket"]
    resources = [format("arn:aws:s3:::%s", lookup(each.value, "bucket_name" ))]
    principals {
      type        = "AWS"
      identifiers = [
        aws_cloudfront_origin_access_identity.default[each.value["key"]].iam_arn
      ]
    }
  }
}

data "aws_iam_policy_document" "default-s3-website" {
  for_each    = local.origins
  statement {
    sid       = "CF_OriginS3ObjectAccess"
    actions   = ["s3:GetObject"]
    resources = [format("arn:aws:s3:::%s/*", each.value["bucket_name"])]    
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
        test     = "StringEquals"
        variable = "aws:referer"
        values   = [random_password.origin_s3_http_referer[each.key].result]
    }
  }
}

data "aws_route53_zone" "default" {
  for_each        = local.domains_map
  name            = lookup(each.value, "zone_mame")
  private_zone    = false
}


data "aws_s3_bucket" "existing" {
  for_each  = local.buckets_existing
  bucket    = lookup(each.value, "bucket_name")  
}
