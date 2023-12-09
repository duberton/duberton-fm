module "s3" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "duberton-fm-album-covers"
  acl    = "private"

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  versioning = {
    enabled = false
  }
}