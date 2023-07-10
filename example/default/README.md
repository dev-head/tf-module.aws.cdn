AWS CDN Example || S3
=====================


Description
-----------
This is just a basic example, it represents a minimal configuration for S3 to CloudFront.

#### Change to required Terraform Version
```commandline
chtf 0.12.19
```

#### Make commands (includes local.ini support)
```commandline
make apply
make help
```

Example Outputs 
---------------
```

example-default--deployments = tomap({
  "distro_002" = {
    "additional_cache_behaviors" = tomap(null) /* of object */
    "aliases" = tolist([
      "an-example-01.alerts-dev.example.com",
    ])
    "aliases_to_create" = tolist([
      {
        "domain" = "an-example-02.alerts-dev.example.com"
        "zone_name" = "alerts-dev.example.com"
      },
    ])
    "certificate" = {
      "acm_arn" = "arn:aws:acm:us-east-1:55555555555:certificate/55555555-5555-5555-5555-5555555555"
      "iam_certificate_id" = tostring(null)
      "minimum_protocol_version" = "TLSv1.2_2021"
      "ssl_support_method" = tostring(null)
    }
    "custom_error_responses" = tolist(null) /* of object */
    "custom_origins" = tomap(null) /* of object */
    "default_cache_behavior" = null /* object */
    "default_index" = tostring(null)
    "deploy_scope" = tostring(null)
    "enabled" = tobool(null)
    "geo_restriction" = null /* object */
    "http_version" = tostring(null)
    "is_ipv6_enabled" = tostring(null)
    "name" = "an-example"
    "origin_groups" = tomap(null) /* of object */
    "origins" = tomap({
      "default" = {
        "bucket_name" = "an-example-01"
        "create_bucket" = true
        "custom_headers" = tolist(null) /* of object */
        "enable_versioning" = tobool(null)
        "log_bucket" = tostring(null)
        "origin_path" = tostring(null)
        "require_mfa_delete" = tobool(null)
        "s3_cors_rules" = tolist(null) /* of object */
        "s3_upload" = tolist([
          {
            "enabled" = true
            "path" = "html"
            "pattern" = "**"
            "prefix" = ""
          },
        ])
      }
    })
    "retain_on_delete" = tobool(null)
    "s3_log_bucket" = tostring(null)
    "tags" = tomap(null) /* of dynamic */
    "wait_for_deployment" = tobool(null)
    "web_acl_id" = tostring(null)
  }
})

example-default--key_attributes = {
  "distro_002" = {
    "aliases" = toset([
      "an-example-01.alerts-dev.example.com",
      "an-example-02.alerts-dev.example.com",
    ])
    "arn" = "arn:aws:cloudfront::55555555555:distribution/55555555555"
    "domain_name" = "zzzzzzzzzzzzz.cloudfront.net"
    "domains_created" = [
      "an-example-02.alerts-dev.example.com",
    ]
    "etag" = "E55555555555"
    "id" = "EE55555555555"
    "origin_access_identity" = {
      "cloudfront_access_identity_path" = "origin-access-identity/cloudfront/55555555555"
      "iam_arn" = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity 55555555555"
      "id" = "55555555555"
    }
    "s3_buckets_created" = [
      "an-example-01.s3.amazonaws.com",
    ]
    "s3_origins" = {
      "default" = {
        "origin_path" = tostring(null)
        "s3_bucket" = "an-example-01.s3.amazonaws.com"
        "s3_bucket_arn" = "arn:aws:s3:::an-example-01"
      }
    }
    "status" = "Deployed"
  }
}

example-default--name = "Default S3"
```