Terraform :: AWS :: Cloudfront
==============================

Description
-----------
This module provides for a concrete configuration for terraform to manage multiple Cloudfront distributions that are backed by any AWS supported origin. This module is designed to be more specific to our use cases and open enough to leverage any features that you might need exposed. The reason this module is leveraged over the typical public module is that we can can make our own adjustments and provide our own solutions at our own pace and not suffer under the weight of the public needs.

#### Note on S3 Origins. 
For S3 origins, this module will create an access identity user to connect to S3; S3 will have a policy to allow for this lock down. Due to Cloudfront and S3 being public, there is no support for encryption at rest in the S3 buckets; if AWS provides this down the road we will update to support it. 

Links 
-----
- [Example: S3 Default](./example/default/) found in `./example/default/`
- [geo_restriction](https://www.iso.org/obp/ui/#search/code/)
- [Terraform Cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution)
- [Terraform Experiments Requirement](https://www.terraform.io/language/expressions/type-constraints#experimental-optional-object-type-attributes)
- [AWS S3 Website Routing Rules](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-websiteconfiguration-routingrules.html)

Versions
--------

### Requirements 

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 3.71.0 |


### Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 3.71.0 |


Behaviors
---------
* `aliases` is used to allow other alias's to be pointed at the CDN, these records are not touched, you need to update it to point to the CDN after deployment.           
* `aliases_to_create` is used to define domains that will be created and pointed to the CDN automatically; the root domain MUST have a matching Route53 zone already.
* a default index.html page will be uploaded to the new S3 bucket; future changes are ignored on that resource.
* ensure `S3 log delivery group` is enabled on your S3 logging bucket ACL.
* whitelisting defined in `geo_restriction` object.
* if you define a `s3_website` for an origin, a semi public s3 bucket will be used instead, however with full S3 website support, which may help you more. 

#### Mapping of price class, use the key when you set it for a cdn deployment.
```hcl
    price_class_map = {
        all_locations           = "PriceClass_All",
        north_america_africa    = "PriceClass_200"
        north_america           = "PriceClass_100",
    }

```    
Resources Created 
-----------------
* `aws_cloudfront_distribution`
* `aws_cloudfront_origin_access_identity`
* `aws_route53_record` (if defined in `aliases_to_create`)
* `aws_s3_bucket` (if configured)
* `aws_s3_bucket_public_access_block` 
* `aws_s3_bucket_object`
* `aws_s3_bucket_policy`

Inputs 
------
> *NOTE* Most of the configuration of a deployment is optional, the defaults will be looking for S3; but you can define whatever configurations you need to make; just review the variable definition for more details on what is passed in for you to meet your needs. 

| Variable      | Type          | Required  | Example       | 
| ------------- | ------------- | --------- | ------------- |
| default_tags  | object        | No        | See Below (1) |
| deployments   | map(object)   | Yes       | See Below (2) | 


#### Basic Usage 
```hcl-terraform
module "service" {
  source          = "git@github.com:dev-head/tf-module.aws.cdn.git?ref=0.0.1"

  base-tags = {
    Environment = "test"
    Managed     = "true"
    CreatedBy   = "terraform"
  }
  
  deployments = {
    distro_001  = {
      name = "a fancy example"
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
        }
      }
    }
  }
}
```

Outputs 
-------
- `aws_caller_identity` Details on current AWS user.
- `aws_region` The current configured.
- `key_resources` Key Resources provides for full resource mapping for each of the defined deployments; allowing access to the full range of resource attributes.
- `key_attributes` Key Attributes provides for a specific mapping of defined resource values for each of the defined deployments; allowing for human friendly output.
- `base-tags` The tags that were set for all resources. (Optionally you can overwrite them in each distro by providing a tag to replace it or new tags.)


Development 
-----------

### Switch to whatever terraform version is currently supported. 
```
chtf 1.1.3
```

### Example Usage 
> The examples are designed for you to be able to build and test updates.
```
cd example/default 

# Creates `local.ini` for you to overright any local variables, such as your AWS Profile.
make init 

make plan
```


```shell script
git git fetch 
git pull origin main
git checkout -b dev/0.0.1

# Use change log update for commit message.
git add .  
git commit -a

git push origin dev/0.0.1
git checkout main 
git merge dev/0.0.1
git push origin main
```

### Release process.
```shell script
git tag -l
git tag -a 0.0.1
git show 0.0.1
git push origin 0.0.1
```