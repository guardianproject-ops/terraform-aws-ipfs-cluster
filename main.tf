locals {
  availability_zones = slice(data.aws_availability_zones.this.names, 0, 2)
}

data "aws_caller_identity" "this" {}
data "aws_availability_zones" "this" {
  state = "available"
}

module "vpc" {
  source  = "cloudposse/vpc/aws"
  version = "2.0.0"

  count = module.this.enabled ? 1 : 0

  ipv4_primary_cidr_block          = "10.30.0.0/16"
  assign_generated_ipv6_cidr_block = false

  context    = module.this.context
  attributes = ["vpc"]
}

module "dynamic_subnet" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.1.0"

  count = module.this.enabled ? 1 : 0

  availability_zones = [local.availability_zones[0]]
  vpc_id             = module.vpc[0].vpc_id
  igw_id             = [module.vpc[0].igw_id]
  ipv4_cidr_block    = ["10.30.0.0/17"]
  ipv6_enabled       = false

  metadata_http_endpoint_enabled = true
  metadata_http_tokens_required  = true

  context    = module.this.context
  attributes = ["vpc"]
}


module "dummy_subnet" {
  source  = "cloudposse/dynamic-subnets/aws"
  version = "2.1.0"

  count = module.this.enabled ? 1 : 0

  availability_zones = [local.availability_zones[1]]
  vpc_id             = module.vpc[0].vpc_id
  igw_id             = [module.vpc[0].igw_id]
  ipv4_cidr_block    = ["10.30.128.0/17"]
  ipv6_enabled       = false

  metadata_http_endpoint_enabled = false

  private_subnets_enabled = false
  nat_gateway_enabled     = false
  nat_instance_enabled    = false

  context    = module.this.context
  attributes = ["vpc"]
}

module "vpc_endpoints" {
  source  = "cloudposse/vpc/aws//modules/vpc-endpoints"
  version = "2.0.0"

  vpc_id = module.vpc[0].vpc_id

  gateway_vpc_endpoints = {
    "s3" = {
      name = "s3"
      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Action = [
              "s3:*",
            ]
            Effect    = "Allow"
            Principal = "*"
            Resource  = "*"
          },
        ]
      })
      route_table_ids = [module.vpc[0].vpc_main_route_table_id]
    }
  }

  interface_vpc_endpoints = {
    "ec2" = {
      name                = "ec2"
      security_group_ids  = [module.ec2_security_group[0].id]
      subnet_ids          = module.dynamic_subnet[0].private_subnet_ids
      policy              = null
      private_dns_enabled = false
    },
    "kms" = {
      name                = "kms"
      security_group_ids  = [module.ec2_security_group[0].id]
      subnet_ids          = module.dynamic_subnet[0].private_subnet_ids
      policy              = null
      private_dns_enabled = false
    }
    "logs" = {
      name                = "logs"
      security_group_ids  = [module.ec2_security_group[0].id]
      subnet_ids          = module.dynamic_subnet[0].private_subnet_ids
      policy              = null
      private_dns_enabled = false
    }
    "ssm" = {
      name                = "ssm"
      security_group_ids  = [module.ec2_security_group[0].id]
      subnet_ids          = module.dynamic_subnet[0].private_subnet_ids
      policy              = null
      private_dns_enabled = false
    },
    "ssmmessages" = {
      name                = "ssmmessages"
      security_group_ids  = [module.ec2_security_group[0].id]
      subnet_ids          = module.dynamic_subnet[0].private_subnet_ids
      policy              = null
      private_dns_enabled = false
    },
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }

    actions = [
      "kms:*",
    ]

    resources = [
      "*"
    ]
  }
}

module "kms_key" {
  source  = "cloudposse/kms-key/aws"
  version = "0.12.1"

  description             = "general purpose KMS key for this IPFS cluster deployment"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  alias                   = "alias/${module.this.id}"

  policy = data.aws_iam_policy_document.kms.json

  context    = module.this.context
  attributes = ["kms"]
}
