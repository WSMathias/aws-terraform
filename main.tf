
provider "aws" {
  version = ">= 2.28.1"
  region  = "eu-west-1"
  profile = "default"
}


# https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["eu-west-1a", "eu-west-1b"]
  private_subnets  = var.private_ciders
  database_subnets = var.database_ciders
  public_subnets   = var.public_ciders

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}


# https://github.com/terraform-aws-modules/terraform-aws-security-group
module "app-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "APP-SG"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  # Public subnet ciders
  ingress_cidr_blocks = var.public_ciders
  ingress_rules            = ["http-80-tcp"]


  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}


# https://github.com/terraform-aws-modules/terraform-aws-security-group
module "db-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "DB-SG"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id
  
  # private subnet ciders
  ingress_cidr_blocks = var.private_ciders 
  ingress_rules     = ["mysql-tcp"]


  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-security-group
module "public-lb-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "LB-PUBLIC-SG"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules            = ["https-443-tcp", "http-80-tcp"]

  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-rds
module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "demodb"

  engine            = "mysql"
  engine_version    = "5.7.19"
  instance_class    = "db.t2.small"
  allocated_storage = 5

  name     = "demodb"
  username = "user"
  password = "YourPwdShouldBeLongAndSecure!"
  port     = "3306"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [module.db-sg.this_security_group_id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"


  # DB subnet group
  subnet_ids = module.vpc.database_subnets

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "demodb"

  # Database Deletion Protection
  deletion_protection = false

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8"
    },
    {
      name  = "character_set_server"
      value = "utf8"
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-ec2-instance
module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  instance_count = var.ec2_number_of_instances

  name                   = var.name
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [module.app-sg.this_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name

  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}


# https://github.com/terraform-aws-modules/terraform-aws-alb
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "my-alb"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.public-lb-sg.this_security_group_id]

  target_groups = [
    {
      name_prefix      = "app-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  # https_listeners = [
  #   {
  #     port               = 443
  #     protocol           = "HTTPS"
  #     certificate_arn    = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
  #     target_group_index = 0
  #   }
  # ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = var.env
  }
}

# alb module lacks this feature
resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = module.alb.target_group_arns[0]
  target_id        = module.ec2_instances.id[0]
  port             = 80
}

# Enable session manager
resource "aws_iam_role_policy_attachment" "attach-ssm-policy" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "app_instance"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "app_instance_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}



