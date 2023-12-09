module "dynamodb_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name         = "duberton-fm"
  hash_key     = "pk"
  range_key    = "sk"
  billing_mode = "PAY_PER_REQUEST"
  table_class  = "STANDARD"

  attributes = [
    {
      name = "pk"
      type = "S"
    },
    {
      name = "sk"
      type = "S"
    }
  ]
}
