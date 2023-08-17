terraform {
  backend "s3" {
    dynamodb_table = "terraform-state-lock"
    region         = "eu-west-2"
    profile        = "your-project-name_deployment_devops_iam"
    key            = "foundations/terraform.state"
    bucket         = "your-project-name-terraform-bucket"
  }
}
provider "aws" {
  alias   = "root"
  profile = "default"
  region  = "eu-west-2"
}
provider "aws" {
  profile = local.workspace["profile"]
  region  = "eu-west-2"
}
data "aws_caller_identity" "root" {
  provider = aws.root
}
data "aws_iam_account_alias" "current" {}
data "aws_caller_identity" "current" {}
data "aws_ec2_transit_gateway" "tgw" {
  id       = var.transit_gateway_id
  provider = aws.root
}

# Delete the vpc default stack
resource "aws_ram_resource_share" "share_tgw" {
  provider                  = aws.root
  allow_external_principals = true
  name                      = "tgw to ${data.aws_iam_account_alias.current.account_alias}"
}
resource "aws_ram_principal_association" "account_association" {
  provider           = aws.root
  principal          = data.aws_caller_identity.current.account_id
  resource_share_arn = aws_ram_resource_share.share_tgw.arn
}
resource "aws_ram_resource_association" "tgw" {
  provider           = aws.root
  resource_arn       = data.aws_ec2_transit_gateway.tgw.arn
  resource_share_arn = aws_ram_resource_share.share_tgw.arn
}

# Make a vpc with 3 private subnets
module "vpc" {
  source                      = "terraform-aws-modules/vpc/aws"
  name                        = "vpc"
  cidr                        = local.workspace["start_cidr_range"]
  azs                         = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
  private_subnets             = cidrsubnets(local.workspace["start_cidr_range"], 5, 5, 5)
  public_subnets              = local.workspace["public_subnets"]
  enable_dns_hostnames        = true
  enable_nat_gateway          = true
  default_security_group_name = "${var.vpc_name}security-group"
  default_route_table_name    = "${var.vpc_name}-route-table"
  default_network_acl_name    = "${var.vpc_name}-network-acl"
  public_subnet_suffix        = "-public"
  private_subnet_suffix       = "-private"
  tags                        = {
    Terraform   = "true"
    Environment = "dev"
    Name        = var.vpc_name
  }
}

resource "aws_route" "tgw_routing" {
  route_table_id         = module.vpc.vpc_main_route_table_id
  transit_gateway_id     = var.transit_gateway_id
  destination_cidr_block = "10.0.0.0/8"
  depends_on             = [time_sleep.wait_3_minutes]
}
resource "time_sleep" "wait_3_minutes" {
  depends_on      = [aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment]
  create_duration = "3m"
}
# Add the transit gateway attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "transit_gateway_attachment" {
  subnet_ids         = module.vpc.private_subnets
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = module.vpc.vpc_id
}
# Delete the default vpc?

module "your-project-name_developer_policy" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 4"
  name        = "your-project-name_dev"
  path        = "/your-project-name/"
  description = "Generic policy for your-project-name Engineers."
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "athena:*",
        "elasticmapreduce:*",
        "sts:*",
        "rds:*",
        "tiros:*",
        "autoscaling:*",
        "autoscaling-plans:*",
        "aws-marketplace:*",
        "access-analyzer:*",
        "cloudformation:*",
        "glue:*",
        "states:*",
        "amplify:*",
        "elasticfilesystem:*",
        "ssm:*",
        "ssmmessages:*",
        "kms:*",
        "compute-optimizer:*",
        "ecs:*",
        "ecr:*",
        "es:*",
        "dax:*",
        "SNS:*",
        "iam:*",
        "servicediscovery:*",
        "tag:*",
        "application-autoscaling:*",
        "lightsail:*",
        "s3:*",
        "route53:*",
        "route53domains:*",
        "route53-recovery-readiness:*",
        "route53-recovery-cluster:*",
        "route53resolver:*",
        "route53-recovery-control-config:*",
        "ec2:*",
        "lambda:*",
        "support:*",
        "appmesh:*",
        "ram:*",
        "apigateway:*",
        "deepracer:*",
        "elasticbeanstalk:*",
        "events:*",
        "cloudwatch:*",
        "logs:*",
        "dynamodb:*",
        "elasticloadbalancing:*",
        "resource-groups:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

module "your-project-name_developer_policy_s3" {
  source      = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version     = "~> 4"
  name        = "your-project-name_dev_s3"
  path        = "/your-project-name/"
  description = "Generic policy for your-project-name Engineers for s3 specifically."
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
       "Resource": [
          "arn:aws:s3:::your-project-name-dataengineeringsandbox-terraform/*",
          "arn:aws:s3:::your-project-name-dataengineeringsandbox-terraform"
      ]
    }
  ]
}
EOF
}

module "your-project-name_developer_assumable_role" {
  source                  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version                 = "~> 4"
  trusted_role_arns       = formatlist("arn:aws:iam::${data.aws_caller_identity.root.account_id}:user/%s", local.workspace["developers"])
  create_role             = true
  role_name               = "your-project-name_dev"
  role_requires_mfa       = false
  custom_role_policy_arns = [
    module.your-project-name_developer_policy.arn,
    module.your-project-name_developer_policy_s3.arn
  ]
  number_of_custom_role_policy_arns = 1
}
/*==== Service Endpoints ====*/
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.eu-west-2.s3"
  route_table_ids   = [module.vpc.default_route_table_id]
  vpc_endpoint_type = "Gateway"
  tags              = {
    "Name" = "${var.vpc_name}-s3",
    "VPC"  = module.vpc.vpc_id
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.eu-west-2.dynamodb"
  route_table_ids   = [module.vpc.default_route_table_id]
  vpc_endpoint_type = "Gateway"
  tags              = {
    "Name" = "${var.vpc_name}-dyanmodb",
    "VPC"  = module.vpc.vpc_id
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.eu-west-2.ecr.api"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [module.vpc.default_security_group_id]
  tags               = {
    "Name" = "${var.vpc_name}-ecr-api",
    "VPC"  = module.vpc.vpc_id
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.eu-west-2.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [module.vpc.default_security_group_id]
  tags               = {
    "Name" = "${var.vpc_name}-ecr-dkr",
    "VPC"  = module.vpc.vpc_id
  }
}

resource "aws_vpc_endpoint" "cloudwatch-monitoring" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.eu-west-2.monitoring"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [module.vpc.default_security_group_id]
  tags               = {
    "Name" = "${var.vpc_name}-cloudwatch-monitoring",
    "VPC"  = module.vpc.vpc_id
  }
}

resource "aws_vpc_endpoint" "cloudwatch-logs" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.eu-west-2.logs"
  vpc_endpoint_type  = "Interface"
  security_group_ids = [module.vpc.default_security_group_id]
  tags               = {
    "Name" = "${var.vpc_name}-cloudwatch-logs",
    "VPC"  = module.vpc.vpc_id
  }
}

# Bastion
resource "aws_key_pair" "bastion-key" {
  key_name   = "bastion-key"
  public_key = file("./bastion.pub")
}

resource "aws_instance" "bastion" {
  ami                         = "ami-082d53fad564a7c6a"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.bastion-key.key_name
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.bastion-security.id]
}


resource "aws_security_group" "bastion-security" {
  name   = "bastion-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol  = "icmp"
    from_port = 0
    to_port   = 0
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}