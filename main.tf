
provider "aws" {
  version = ">= 2.28.1"
  region  = var.region
  profile = var.profile
}

locals {
  tags = {
    Terraform   = "true"
    Environment = var.env
    Project     = "demo"
    Application = "nodejs"
  }
}

# https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = format("%s-vpc", var.name)
  cidr               = var.vpc_cider
  azs                = formatlist("%s%s", var.region, ["a", "b"])
  private_subnets    = var.private_ciders
  database_subnets   = var.database_ciders
  public_subnets     = var.public_ciders
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = true
  tags               = local.tags
}


# https://github.com/terraform-aws-modules/terraform-aws-security-group
module "app-sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "APP-SG"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  # Public subnet ciders
  ingress_cidr_blocks = var.public_ciders
  ingress_rules       = ["http-80-tcp", "ssh-tcp"]
  egress_rules        = ["all-all"]
  tags                = local.tags

}


# https://github.com/terraform-aws-modules/terraform-aws-security-group
module "db-sg" {
  source      = "terraform-aws-modules/security-group/aws"
  count       = var.enable_db ? 1 : 0
  name        = "DB-SG"
  description = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id      = module.vpc.vpc_id

  # private subnet ciders
  ingress_cidr_blocks = var.private_ciders
  ingress_rules       = ["mysql-tcp"]
  egress_rules        = ["all-all"]
  tags                = local.tags

}

# https://github.com/terraform-aws-modules/terraform-aws-security-group
module "public-lb-sg" {
  source              = "terraform-aws-modules/security-group/aws"
  name                = "LB-PUBLIC-SG"
  count               = var.enable_asg ? 1 : 0
  description         = "Security group with HTTP ports open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp", "http-80-tcp"]
  egress_rules        = ["all-all"]
  tags                = local.tags
}

# https://github.com/terraform-aws-modules/terraform-aws-rds
module "db" {
  source                              = "terraform-aws-modules/rds/aws"
  version                             = "~> 2.0"
  count                               = var.enable_db ? 1 : 0
  identifier                          = "demodb"
  engine                              = "mysql"
  engine_version                      = "5.7.19"
  instance_class                      = "db.t2.micro"
  allocated_storage                   = 5
  name                                = format("%s-db", var.name)
  username                            = "demouser"
  password                            = "YourPwdShouldBeLongAndSecure!"
  port                                = "3306"
  iam_database_authentication_enabled = true
  vpc_security_group_ids              = var.enable_db ? [module.db-sg[0].this_security_group_id] : []
  maintenance_window                  = "Mon:00:00-Mon:03:00"
  backup_window                       = "03:00-06:00"


  # DB subnet group
  subnet_ids = module.vpc.database_subnets

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion 
  # final_snapshot_identifier = var.name
  skip_final_snapshot     = true
  backup_retention_period = 0
  deletion_protection     = false

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

  tags = local.tags
}


module "secret-lambda" {
  source         = "./modules/aws-rotation-lambda"
  count          = var.enable_db ? 1 : 0
  name           = "SecretManager"
  security_group = var.enable_db ? module.app-sg.this_security_group_id : ""
  subnets        = module.vpc.private_subnets
  tags           = local.tags
}


module "secret-manager-with-rotation" {
  source                     = "./modules/aws-secret-manager"
  count                      = var.enable_db ? 1 : 0
  name                       = "MasterUser"
  enable_rotation            = true
  rotation_schedule          = "rate(90 days)"
  rotation_lambda_arn        = var.enable_db ? module.secret-lambda[0].rotation_lambda_arn : ""
  mysql_username             = var.enable_db ? module.db[0].this_db_instance_username : ""
  mysql_password             = var.enable_db ? module.db[0].this_db_instance_password : ""
  mysql_database             = var.enable_db ? module.db[0].this_db_instance_name : ""
  mysql_host                 = var.enable_db ? module.db[0].this_db_instance_address : ""
  mysql_port                 = var.enable_db ? module.db[0].this_db_instance_port : ""
  mysql_dbInstanceIdentifier = var.enable_db ? module.db[0].this_db_instance_id : ""
  tags                       = local.tags
}


# resource "aws_key_pair" "deployer" {
#   key_name   = "secret-demo"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCVTMvcoyACvqsAwnNJ6L5bSws66awG/klzr0stLPl1W036XscBBSw8PSic1glLGjWz7PptYAx22ahMOnAovgTrkoXIZEdXVw7Yljda54Btm4BKPfdfzw/K7gHvlZqhgx8lHH+unY33yAe9bdeJqvaZ6LHYQj0ZgXUKwlKy9kTgn88kLizxPknMhfUvCLmLLQVuLqrKhXyYSs1bUpiGHCsq9IxrQxd5dYl09uW0cJtKy7+WOllQzxC0iL6yaTM34hz1c9Y9BD3Aq4YTBLaiur/8q2pFZnDFR0C5k3xCnze7lPN6vITwqBoTXu4jUdSb/6EsaXDiIsyJNVtwKW0VrtTx"
# }

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 3.0"
  count   = var.enable_asg ? 1 : 0
  name    = "service"

  # Launch configuration
  lc_name              = "demo-lc"
  image_id             = var.ec2_ami
  instance_type        = var.ec2_instance_type
  security_groups      = [module.app-sg.this_security_group_id]
  iam_instance_profile = aws_iam_instance_profile.app_instance_profile.name
  target_group_arns    = var.enable_asg ? module.alb[0].target_group_arns : []
  user_data            = data.template_cloudinit_config.config.rendered

  #   ebs_block_device = [
  #     {
  #       device_name           = "/dev/xvdz"
  #       volume_type           = "gp2"
  #       volume_size           = "50"
  #       delete_on_termination = true
  #     },
  #   ]

  root_block_device = [
    {
      volume_size = "20"
      volume_type = "gp2"
    },
  ]

  # Auto scaling group
  asg_name                  = "my-asg"
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = "dev"
      propagate_at_launch = true
    },
    {
      key                 = "Terraform"
      value               = "true"
      propagate_at_launch = true
    },
  ]
}

# https://github.com/terraform-aws-modules/terraform-aws-ec2-instance
module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"
  count   = var.enable_db ? 0 : 1


  instance_count         = var.ec2_number_of_instances
  name                   = "Bastion host"
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  vpc_security_group_ids = [module.app-sg.this_security_group_id]
  subnet_id              = module.vpc.public_subnets[0]
  iam_instance_profile   = aws_iam_instance_profile.app_instance_profile.name
  # key_name                    = aws_key_pair.deployer.key_name
  user_data                   = data.template_cloudinit_config.github_action.rendered
  associate_public_ip_address = true
  tags                        = local.tags

}


# https://github.com/terraform-aws-modules/terraform-aws-alb
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"
  count   = var.enable_asg ? 1 : 0

  name               = "my-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = var.enable_asg ? [module.public-lb-sg.this_security_group_id] : []
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

  tags = local.tags
}


# Enable session manager
resource "aws_iam_role_policy_attachment" "attach-ssm-policy" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Permission to fetch secrets
resource "aws_iam_role_policy_attachment" "attach-secretmanager-policy" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.read_secrets.arn
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

  tags = local.tags
}

resource "aws_iam_policy" "read_secrets" {
  name        = "SecretmanagerReadOnly"
  description = "Seacret Manager read only policy"
  policy      = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": [
            "secretsmanager:Describe*",
            "secretsmanager:Get*",
            "secretsmanager:List*" 
        ],
        "Resource": "*"
    }
}
 POLICY
}
