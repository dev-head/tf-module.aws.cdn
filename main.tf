resource "aws_cloudfront_origin_access_identity" "default" {
  for_each    = var.deployments
  comment     = format("CF OAI for [%s] distro.", lookup(each.value, "name"))
}

resource "aws_s3_bucket_policy" "default" {
    for_each    = local.buckets_to_create
    bucket      = aws_s3_bucket.default[each.key].id
    policy = each.value["s3_website"] == null? data.aws_iam_policy_document.default[each.key].json : data.aws_iam_policy_document.default-s3-website[each.key].json
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  for_each                = local.buckets_to_create
  bucket                  = aws_s3_bucket.default[each.key].bucket
  block_public_acls       = true
  block_public_policy     = each.value["s3_website"] == null? true : false
  ignore_public_acls      = true
  restrict_public_buckets = each.value["s3_website"] == null? true : false
}

resource "random_password" "origin_s3_http_referer" {
  for_each  = local.origins
  length    = 32
  special   = false
}

resource "aws_s3_bucket" "default" {
  for_each        = local.buckets_to_create
  bucket          = lookup(each.value, "bucket_name")
  acl             = lookup(each.value, "acl", "private")
  force_destroy   = lookup(each.value, "force_destroy", false)
  tags            = merge({"Name": lookup(each.value, "bucket_name")}, var.base-tags, lookup(each.value, "tags"))

  dynamic "logging" {
    for_each = each.value["log_bucket"] == null? [] : [each.value["log_bucket"]]
    content {
      target_bucket = coalesce(each.value["log_bucket"], false)? format("%s.s3.amazonaws.com", lookup(each.value, "log_bucket")) : null
      target_prefix = coalesce(each.value["log_bucket"], false)? format("log-s3/%s-", lookup(each.value, "bucket_name")) : null        
    }
  }
  
  dynamic "website" {
    for_each = each.value["s3_website"] == null? [] : [each.value["s3_website"]]
    content {
      index_document  = lookup(website.value, "index_document")
      error_document  = lookup(website.value, "error_document")
      routing_rules   = website.value["routing_rules"] != null && try(length(website.value["routing_rules"]) > 0, false)? jsonencode(lookup(website.value, "routing_rules")) : null      
    }
  }

  versioning {
      enabled     = coalesce(each.value["enable_versioning"], true)
      mfa_delete  = coalesce(each.value["require_mfa_delete"], false)
  }
  
  dynamic "cors_rule" {
    for_each = each.value["s3_cors_rules"] == null? [] : each.value["s3_cors_rules"]
    content {
      allowed_headers = lookup(cors_rule.value, "allowed_headers")
      allowed_methods = lookup(cors_rule.value, "allowed_methods")
      allowed_origins = lookup(cors_rule.value, "allowed_origins")
      expose_headers  = lookup(cors_rule.value, "expose_headers")
      max_age_seconds = lookup(cors_rule.value, "max_age_seconds", 300)
    }
  }
}

resource "aws_s3_bucket_object" "default" {
  for_each        = local.map_of_s3_upload_objects
  bucket          = aws_s3_bucket.default[lookup(each.value, "bucket_key")].id
  key             = trimprefix(lookup(each.value, "object_path"), "/")
  source          = lookup(each.value, "upload_path")
  etag            = filemd5(lookup(each.value, "upload_path"))

  # module isn't designed to manage s3 content, it's more of a helper to get started.
  lifecycle {  ignore_changes  = all }
}

resource "aws_cloudfront_distribution" "default" {
  for_each            = var.deployments  
  comment             = format("CF for [%s] {terraform}", lookup(each.value, "name"))
  enabled             = coalesce(each.value["enabled"], true)
  default_root_object = coalesce(each.value["default_index"], "index.html")
  aliases             = (each.value["aliases"] == null && each.value["aliases_to_create"] == null)? [] : compact(distinct(concat(coalesce(each.value["aliases"], []), try([for aliases in lookup(each.value, "aliases_to_create") : aliases.domain], []))))
  is_ipv6_enabled     = coalesce(each.value["is_ipv6_enabled"], false)
  http_version        = coalesce(each.value["http_version"], "http2")
  web_acl_id          = lookup(each.value, "web_acl_id", null)
  retain_on_delete    = coalesce(each.value["retain_on_delete"], false)
  wait_for_deployment = coalesce(each.value["wait_for_deployment"], false)
  price_class         = lookup(local.price_class_map, coalesce(each.value["deploy_scope"], "north_america"))
  tags                = merge({"Name": format("%s", lookup(each.value, "name"))}, var.base-tags, lookup(each.value, "tags"))

  dynamic "custom_error_response" {
    for_each = coalesce(each.value["custom_error_responses"], [])
    content {
      error_caching_min_ttl = lookup(custom_error_response.value, "error_caching_min_ttl")
      error_code            = lookup(custom_error_response.value, "error_code")
      response_code         = lookup(custom_error_response.value, "response_code")
      response_page_path    = lookup(custom_error_response.value, "response_page_path")
    }
  }

  dynamic "origin_group" {
    for_each = coalesce(each.value["origin_groups"], {})
    content {
      origin_id = origin_group.key

      dynamic "failover_criteria" {
        for_each = lookup(origin_group.value, "failover_criteria", false) ? [] : tolist(lookup(origin_group.value, "failover_criteria", false))
        content {
          status_codes = lookup(failover_criteria.value, "status_codes")
        }
      }

      dynamic "member" {
        for_each = lookup(origin_group.value, "members")
        content {
          origin_id = lookup(member.value, "origin_id")
        }
      }
    }
  }
  
  dynamic "origin" {
    for_each = coalesce(each.value["origins"], {})
    content {
      origin_id   = origin.key
      origin_path = lookup(origin.value, "origin_path")    
      
      # this is used to allow the s3 bucket to dictate what the end point is.
      # if you have an error, it's because we didn't create a bucket or your api key doesn't have access.
      domain_name = try(
        coalesce(aws_s3_bucket.default[format("%s.%s", each.key, origin.key)].website_endpoint),
        coalesce(aws_s3_bucket.default[format("%s.%s", each.key, origin.key)].bucket_regional_domain_name),
        coalesce(data.aws_s3_bucket.existing[format("%s.%s", each.key, origin.key)].website_endpoint),
        coalesce(data.aws_s3_bucket.existing[format("%s.%s", each.key, origin.key)].bucket_regional_domain_name),
        coalesce(format("%s.s3-%s.amazonaws.com", lookup(origin.value, "bucket_name"), data.aws_region.current.name)),
        null
      )
      
      dynamic "custom_origin_config" {
        for_each = origin.value["s3_website"] == null? [] : [1]
        content {
          http_port              = 80
          https_port             = 443
          origin_protocol_policy = "http-only"
          origin_ssl_protocols   = local.default_origin_ssl_protocols
        }
      }
      
      dynamic "custom_header" {
        for_each = origin.value["s3_website"] != null? concat([{ name = "referer", value = random_password.origin_s3_http_referer[format("%s.%s", each.key, origin.key)].result }], coalesce(origin.value["custom_headers"], [])) : coalesce(origin.value["custom_headers"], [])
        content {
          name    = lookup(custom_header.value, "name")
          value   = lookup(custom_header.value, "value")
        }
      }
      
      dynamic "s3_origin_config" {
        for_each = origin.value["s3_website"] == null? [1] : []
          content {
            origin_access_identity = aws_cloudfront_origin_access_identity.default[each.key].cloudfront_access_identity_path
        }
      }      
    }
  }

  dynamic "origin" {
    for_each = coalesce(each.value["custom_origins"], {})
    content {
      origin_id   = origin.key
      domain_name = lookup(origin.value, "domain_name")
      origin_path = lookup(origin.value, "origin_path")

      dynamic "custom_header" {
        for_each = coalesce(origin.value["custom_headers"], [])
        content {
          name    = lookup(custom_header.value, "name")
          value   = lookup(custom_header.value, "value")
        }
      }

      custom_origin_config {
        http_port                   = lookup(origin.value, "http_port")
        https_port                  = lookup(origin.value, "https_port")
        origin_protocol_policy      = lookup(origin.value, "origin_protocol_policy")
        origin_ssl_protocols        = lookup(origin.value, "origin_ssl_protocols")
        origin_keepalive_timeout    = lookup(origin.value, "origin_keepalive_timeout")
        origin_read_timeout         = lookup(origin.value, "origin_read_timeout")
      }
    }
  }

  dynamic "default_cache_behavior" {
    for_each = each.value["default_cache_behavior"] == null? [local.default_cache_behavior] : tolist(each.value["default_cache_behavior"])        
    content {
      target_origin_id            = lookup(default_cache_behavior.value, "target_origin_id")
      allowed_methods             = lookup(default_cache_behavior.value, "allowed_methods")
      cached_methods              = lookup(default_cache_behavior.value, "cached_methods")
      compress                    = lookup(default_cache_behavior.value, "compress")
      default_ttl                 = lookup(default_cache_behavior.value, "default_ttl")
      field_level_encryption_id   = null  # Will be supported in future versions
      max_ttl                     = lookup(default_cache_behavior.value, "max_ttl")
      min_ttl                     = lookup(default_cache_behavior.value, "min_ttl")
      smooth_streaming            = lookup(default_cache_behavior.value, "smooth_streaming", null)
      trusted_signers             = lookup(default_cache_behavior.value, "trusted_signers")
      viewer_protocol_policy      = lookup(default_cache_behavior.value, "viewer_protocol_policy")

      dynamic "forwarded_values" {
        for_each = default_cache_behavior.value["forwarded_values"] == null? [] : [default_cache_behavior.value["forwarded_values"]]
        content {
          query_string            = lookup(forwarded_values.value, "query_string")
          query_string_cache_keys = lookup(forwarded_values.value, "query_string_cache_keys")
          headers                 = lookup(forwarded_values.value, "headers")
          cookies {
            forward             = lookup(lookup(forwarded_values.value, "cookies"),  "forward")
            whitelisted_names   = lookup(lookup(forwarded_values.value, "cookies"), "whitelisted_names")
          }
        }
      }

      dynamic "lambda_function_association" {
        for_each = lookup(default_cache_behavior.value, "lambda_function_associations")
        content {
          event_type      = lookup(lambda_function_association.value, "event_type")
          lambda_arn      = lookup(lambda_function_association.value, "lambda_arn")
          include_body    = lookup(lambda_function_association.value, "include_body")
        }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = each.value["additional_cache_behaviors"] == null? [] : tolist(each.value["additional_cache_behaviors"])
    content {
      target_origin_id            = lookup(ordered_cache_behavior.value, "target_origin_id")
      path_pattern                = lookup(ordered_cache_behavior.value, "path_pattern")
      allowed_methods             = lookup(ordered_cache_behavior.value, "allowed_methods")
      cached_methods              = lookup(ordered_cache_behavior.value, "cached_methods")
      compress                    = lookup(ordered_cache_behavior.value, "compress")
      default_ttl                 = lookup(ordered_cache_behavior.value, "default_ttl")
      max_ttl                     = lookup(ordered_cache_behavior.value, "max_ttl")
      min_ttl                     = lookup(ordered_cache_behavior.value, "min_ttl")
      viewer_protocol_policy      = lookup(ordered_cache_behavior.value, "viewer_protocol_policy")
      field_level_encryption_id   = null  # Will be supported in future versions

      dynamic "forwarded_values" {
        for_each = tolist(lookup(ordered_cache_behavior.value, "forwarded_values"))
        content {
          query_string            = lookup(forwarded_values.value, "query_string")
          query_string_cache_keys = lookup(forwarded_values.value, "query_string_cache_keys")

          cookies {
            forward             = lookup(lookup(forwarded_values.value, "cookies"),  "forward")
            whitelisted_names   = lookup(lookup(forwarded_values.value, "cookies"), "whitelisted_names")
          }
        }
      }

      dynamic "lambda_function_association" {
        for_each = lookup(ordered_cache_behavior.value, "lambda_function_associations")
        content {
          event_type      = lookup(lambda_function_association.value, "event_type")
          lambda_arn      = lookup(lambda_function_association.value, "lambda_arn")
          include_body    = lookup(lambda_function_association.value, "include_body")
        }
      }
    }
  }

  dynamic "logging_config" {
    for_each = each.value["s3_log_bucket"] == null? [] : [each.value["s3_log_bucket"]]
    content {
      include_cookies = false
      bucket          = format("%s.s3.amazonaws.com", each.value["s3_log_bucket"])
      prefix          = format("log-cdn/%s-", lookup(each.value, "name"))
    }
  }

  restrictions {
    geo_restriction {
      restriction_type  = each.value["geo_restriction"] == null? local.default_geo_restrictions["restriction_type"] : lookup(each.value["geo_restriction"], "restriction_type", null)
      locations         = each.value["geo_restriction"] == null? local.default_geo_restrictions["locations"] : lookup(each.value["geo_restriction"], "locations", null)
    }
  }
    
  viewer_certificate  {
    cloudfront_default_certificate  = each.value["certificate"] == null? true : (lookup(each.value["certificate"], "acm_arn", null) == null && lookup(each.value["certificate"], "iam_certificate_id", null) == null?  true : false)
    ssl_support_method              = each.value["certificate"] == null? null : coalesce(each.value["certificate"]["ssl_support_method"], "sni-only")  
    iam_certificate_id              = each.value["certificate"] == null? null : lookup(each.value["certificate"], "iam_certificate_id", null)
    acm_certificate_arn             = each.value["certificate"] == null? null : lookup(each.value["certificate"], "acm_arn", null)
    minimum_protocol_version        = each.value["certificate"] == null? null : lookup(each.value["certificate"], "minimum_protocol_version", null)
  }
}

resource "aws_route53_record" "default" {
  for_each  = local.domains_map
  zone_id   = data.aws_route53_zone.default[each.key].zone_id
  name      = lookup(each.value, "domain")
  type      = "A"

  alias {
    name                   = aws_cloudfront_distribution.default[lookup(each.value, "key")].domain_name
    zone_id                = aws_cloudfront_distribution.default[lookup(each.value, "key")].hosted_zone_id
    evaluate_target_health = true
  }
}


resource "aws_cloudfront_monitoring_subscription" "default" {
  for_each          = var.deployments  
  distribution_id   = aws_cloudfront_distribution.default[each.key].id

  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = each.value["enable_metrics"] == null? "Disabled" : (each.value["enable_metrics"] == true? "Enabled": "Disabled")
    }
  }
}
