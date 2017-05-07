variable "dynamo_table" { default = "credential-store" }

resource "aws_dynamodb_table" "credstash" {
  name = "${ var.dynamo_table }"
  read_capacity = 1
  write_capacity = 1
  hash_key = "name"
  range_key = "version"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "version"
    type = "S"
  }
}

resource "aws_kms_key" "credstash" {
  description = "Credstash"
  deletion_window_in_days = 12
}

resource "aws_kms_alias" "credstash" {
  name = "alias/credstash"
  target_key_id = "${ aws_kms_key.credstash.key_id }"
}

resource "aws_iam_role" "credstash" {
  name = "credstash"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "",
    "Effect": "Allow",
    "Principal": {
      "Service": "ec2.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF
}

resource "aws_iam_role_policy" "credstash_ro" {
  name = "credstash_read"
  role = "${ aws_iam_role.credstash.id }"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": [
      "kms:Decrypt"
    ],
    "Effect": "Allow",
    "Resource": "${ aws_kms_key.credstash.arn }"
  },
  {
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ],
    "Effect": "Allow",
    "Resource": "${ aws_dynamodb_table.credstash.arn }"
  }]
}
EOF
}

output "iam_role_ro" { value =  "${ aws_iam_role.credstash.name }" }
