variable "base-tags" {
  description   = "(Optional) Define a base set of tags to apply to every supported resource managed; you can overwrite these in each deployment configuration."
  default       = {}
  type          = map
}

variable "deployments-test" {
  description = "(Required). Configurations to build a CDN deployment."  
  type = map(object({
    name            = string
    enabled         = optional(bool)
    default_index   = optional(string)
  }))
  default = {}  
}

variable "deployments" {
  description = "(Required). Configurations to build a CDN deployment; most is optional though."
  type        = map(object({
    name                = string
    s3_log_bucket       = optional(string)
    tags                = optional(map(any))
    default_index       = optional(string)
    aliases             = optional(list(string))
    aliases_to_create   = optional(list(object({
      domain      = string
      zone_name   = string
    })))
    enabled             = optional(bool)
    deploy_scope        = optional(string)
    http_version        = optional(string)
    web_acl_id          = optional(string)
    is_ipv6_enabled     = optional(string)
    retain_on_delete    = optional(bool)
    wait_for_deployment = optional(bool)
    enable_metrics      = optional(bool)
    custom_error_responses = optional(list(object({
      error_caching_min_ttl = number
      error_code            = number
      response_code         = number
      response_page_path    = string
    })))

    certificate = optional(object({
      acm_arn                     = optional(string)
      minimum_protocol_version    = optional(string)
      ssl_support_method          = optional(string)
      iam_certificate_id          = optional(string)
    }))

    geo_restriction = optional(object({
      restriction_type = string
      locations        = list(string)
    }))

    origin_groups   = optional(map(object({
      failover_criteria = object({
        status_codes    = list(string)
      })
      members = map(object({
        origin_id   = string
      }))
    })))

    origins = optional(map(object({
      bucket_name             = string
      create_bucket           = optional(bool)
      origin_path             = optional(string)
      log_bucket              = optional(string)
      enable_versioning       = optional(bool)  
      require_mfa_delete      = optional(bool)
      s3_upload  = optional(list(object({
        enabled = bool
        path    = string
        pattern = string
        prefix  = string
      })))
      s3_cors_rules   = optional(list(object({
        allowed_headers = list(string)
        allowed_methods = list(string)
        allowed_origins = list(string)
        expose_headers  = list(string)
        max_age_seconds = number
      })))
      
      s3_website = optional(object({
        index_document = optional(string)
        error_document = optional(string)
        routing_rules  = optional(list(object({
          Condition = optional(object({
              KeyPrefixEquals             = optional(string)
              HttpErrorCodeReturnedEquals = optional(string)
            }))          
          Redirect = optional(object({
              HostName              = optional(string)
              HttpRedirectCode      = optional(string)
              Protocol              = optional(string)
              ReplaceKeyPrefixWith  = optional(string)
              ReplaceKeyWith        = optional(string)
            }))
          })))
      }))
      
      custom_headers  = optional(list(object({
        name = string
        value = string
      })))
    })))

    custom_origins = optional(map(object({
      domain_name                 = string
      origin_path                 = string
      http_port                   = number
      https_port                  = number
      origin_protocol_policy      = string
      origin_ssl_protocols        = list(string)
      origin_keepalive_timeout    = number
      origin_read_timeout         = number
      custom_headers  = list(object({
        name = string
        value = string
      }))
    })))

    default_cache_behavior  = optional(object({
      target_origin_id        = optional(string)
      allowed_methods         = optional(list(string))
      cached_methods          = list(string)
      viewer_protocol_policy  = string
      compress                = string
      default_ttl             = number
      max_ttl                 = number
      min_ttl                 = number
      trusted_signers         = list(string)
      forwarded_values        = object({
        headers                 = list(string)
        query_string            = bool
        query_string_cache_keys = list(string)
        cookies                 = object({
          forward             = string
          whitelisted_names   = list(string)
        })
      })
      lambda_function_associations = map(object({
        event_type      = string
        lambda_arn      = string
        include_body    = bool
      }))
    }))

    additional_cache_behaviors = optional(map(object({
      target_origin_id        = string
      path_pattern            = string
      allowed_methods         = list(string)
      cached_methods          = list(string)
      viewer_protocol_policy  = string
      compress                = bool
      default_ttl             = number
      max_ttl                 = number
      min_ttl                 = number
      forwarded_values        = object({
        headers                 = list(string)
        query_string            = bool
        query_string_cache_keys = list(string)
        cookies                 = object({
          forward             = string
          whitelisted_names   = list(string)
        })
      })
      lambda_function_associations = map(object({
        event_type      = string
        lambda_arn      = string
        include_body    = bool
      }))
    })))
  }))
}