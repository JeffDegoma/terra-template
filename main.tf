provider "aws" {
    version =  ">= 4.55"
    region  = var.region
}

terraform {  
    backend "s3" {
        bucket  = "terraform-backend-pakil-state"
        encrypt = true
        key     = "terraform.tfstate"    
        region  = "us-east-1"
    }
}

locals {
  region = var.region
  name   = "demo-${basename(path.cwd)}-${var.project_name}"

  vpc_cidr = "10.0.0.0/16"
  #azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name       = local.name
    Example    = local.name
  }
  user_data = <<-EOT
    #!/bin/bash
    cd /var/lib/jenkins
    bash jenkins-init
  EOT
}


### Data sources provide information about resources that are not managed by the current Terraform configuration. 

## This fetches AMI resources from AWS
data "aws_ami" "packer-custom-ami" {
 most_recent = true
 owners           = ["self"]

  filter {
   name   = "name"
   values = [var.packer_ami_value]
 }
}



##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################



## AWS VPC module to simplify networking services

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr
  create_database_subnet_group = true
  //specify database subnet group name
  database_subnet_names    = ["DB Subnet One", "DB Subnet Two", "DB Subnet Three"]
  public_subnet_names = ["management-a", "management-b"]
  azs             = ["us-east-1a", "us-east-1b"] //more azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  # private_subnets = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  database_subnets = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"]
  create_igw      = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  # tags = local.tags
}

module "jenkins_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  ami = data.aws_ami.packer-custom-ami.id
  name = var.instance_name

  user_data_base64            = base64encode(local.user_data)
  user_data_replace_on_change = true
  
  root_block_device = [
    {
      encrypted   = true
      volume_type = "gp3"
      throughput  = 200
      volume_size = 8
    },
  ]
  instance_type          = var.instance_type
  key_name               = "priv"
  monitoring             = true
  vpc_security_group_ids = [module.ec2_security_group.security_group_id, module.alb_sg.security_group_id, module.jenkins_ec2_security_group.security_group_id]
  associate_public_ip_address = false
  subnet_id              = "${element(module.vpc.private_subnets, 0)}"
  create_iam_instance_profile = true
  iam_role_description        = "cloud9 permissions"
  iam_role_policies = {
    Cloud9Administrator = var.Cloud9Administrator
    accessPolicy = aws_iam_policy.accessPolicy.id
    rdsAccess = aws_iam_policy.rds_access.id
  }


  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}



module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "bastion-instance"

  instance_type          = "t2.micro"
  key_name               = "priv"
  monitoring             = true
  vpc_security_group_ids = ["${module.ec2_security_group.security_group_id}"]
  associate_public_ip_address = true
  subnet_id              = "${element(module.vpc.public_subnets, 0)}"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name = local.name

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_sg.security_group_id]

   http_tcp_listeners = [
   {
     port               = 80
     protocol           = "HTTP"
     target_group_index = 0
   },
  ]

  target_groups = [
    {
      name             = "${var.instance_name}"
      backend_protocol = "HTTP"
      backend_port     = "80"
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
      }
      targets = {
      jenkins = {
        target_id = module.jenkins_instance.id
        port      = 8080
      }
    }
    }
  ]

  tags = local.tags
}


module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "${local.name}-alb"
  description = "alb security group"
  vpc_id      = module.vpc.vpc_id

  ingress_rules       = ["http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = local.tags
}


module "ec2_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.sg_name
  description = "${var.sg_name} security group"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"] # change or remove
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "User-service ports"
    }
  ] 
  
  egress_rules       = ["all-all"]
  egress_cidr_blocks = [local.vpc_cidr] 

  tags = local.tags

}


module "jenkins_ec2_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.jenkins_sg
  description = "${var.jenkins_sg} security group"
  vpc_id      = module.vpc.vpc_id

 
  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    },
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = 6
      description              = "alb to jenkins"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]

  tags = local.tags
}


module "rds_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "rds_security_group"
  description = " rds security group"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"] # change or remove
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "Jenkins ports"
    }
  
  ]
  egress_rules = ["all-all"]

  tags = local.tags
}



resource "aws_iam_policy" "rds_access" {
  name = "rds_access"
  policy = jsonencode({
    Version =  "2012-10-17"
    Statement = [{
      Effect = "Allow",
      Action =[
        "rds-db:connect"
    ],
      Resource = "*"
      }
    ]
})
}


resource "aws_iam_policy" "accessPolicy" {

 name = "AccessPolicy"

 policy = jsonencode({
   Version = "2012-10-17"
   Statement = [{
    Effect = "Allow",
    Action =[
      "ec2:DescribeSpotFleetInstances",
      "ec2:ModifySpotFleetRequest",
      "ec2:CreateTags",
      "ec2:DescribeRegions",
      "ec2:DescribeInstances",
      "ec2:TerminateInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeSpotFleetRequests"
    ],
      Resource = "*"
    },
    {
    Effect = "Allow",
    Action = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:UpdateAutoScalingGroup"
    ],
      Resource = "*"
    },
    {
      Effect = "Allow",
      Action = [
        "iam:ListInstanceProfiles",
        "iam:ListRoles",
        "iam:PassRole"
      ],
      Resource = "*"
    }
   ]
 })

}



module "db" {
  source = "terraform-aws-modules/rds/aws"
  identifier = "${local.name}-db"

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine                   = "postgres"
  engine_version           = "14"
  engine_lifecycle_support = "open-source-rds-extended-support-disabled"
  family                   = "postgres14" # DB parameter group
  major_engine_version     = "14"         # DB option group
  instance_class           = "db.t3.medium"

  allocated_storage     = 20
  max_allocated_storage = 100

  # NOTE: Do NOT use 'user' as the value for 'username' as it throws:
  # "Error creating DB Instance: InvalidParameterValue: MasterUsername
  # user cannot be used as it is a reserved word used by the engine"
  db_name  = "completePostgresql"
  username = "complete_postgresql"
  port     = 5432
  password = "somepasswordhere"
  iam_database_authentication_enabled = true #set to true to enable token access
  
  manage_master_user_password = false
  manage_master_user_password_rotation              = false

  multi_az               = true
  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.rds_security_group.security_group_id]

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = local.tags

}
