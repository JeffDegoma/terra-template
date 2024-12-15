provider "aws" {
    version =  ">= 4.55"
    region  = var.region
}

terraform {  
    backend "s3" {
        bucket  = "terraform-backend-pakil-state-1"
        encrypt = true
        key     = "terraform.tfstate"    
        region  = "us-east-1"
    }
}

 data "terraform_remote_state" "remote" {
      backend =  "s3"
      config = {
        bucket  = "terraform-backend-pakil-state-1"
        key     = "terraform.tfstate"    
        region  = "us-east-1"
      }
}



locals {
  region = var.region
  name   = "demo-${basename(path.cwd)}-${var.project_name}"
  jenkins_port = "8080"
  filesystem-id = module.efs.id
  ami = var.ami
  account = "654654507397"

  vpc_cidr = "10.0.0.0/16"
  #azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Name       = local.name
    Example    = local.name
  }

  user_data = <<-EOF
#!/bin/bash

echo 'export PAKIL=HI >> ~/.bashrc'


echo export FILESYSTEM_ID=${local.filesystem-id} >> ~/.bashrc

source ~/.bashrc

mount -t efs -o tls $FILESYSTEM_ID /var/lib/jenkins
EOF
}


### Data sources provide information about resources that are not managed by the current Terraform configuration. 



# data "aws_route53_zone" "this" {
#   name = "${local.account}.realhandsonlabs.net"
# }

################################################################################
#ACM for loadbalancer
################################################################################

# module "acm" {
#   source  = "terraform-aws-modules/acm/aws"
#   version = "~> 3.0"

#   domain_name = "${local.account}.realhandsonlabs.net"
#   zone_id     = data.aws_route53_zone.this.id
# }

# module "wildcard_cert" {
#   source  = "terraform-aws-modules/acm/aws"
#   version = "~> 3.0"

#   domain_name = "*.${local.account}.realhandsonlabs.net"
#   zone_id     = data.aws_route53_zone.this.id
# }


## This fetches AMI resources from AWS
data "aws_ami" "packer-custom-ami" {
 most_recent = true
 owners           = ["self"]

  filter {
   name   = "name"
  #  values = [var.packer_ami_value]
   values = [var.ami ? var.packer_ami_value : data.terraform_remote_state.remote.outputs.id]
 }
}

data "aws_caller_identity" "current" {}

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
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"] //more azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.9.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
  database_subnets = ["10.0.6.0/24", "10.0.7.0/24", "10.0.8.0/24"]
  create_igw      = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  # tags = local.tags
}


module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "bastion-instance"
  instance_type          = "t2.micro"
  key_name               = "priv"
  monitoring             = true
  # user_data = base64encode("${templatefile("${path.module}/user_data_script.sh", {
  #   filesystem-id   = local.filesystem-id
# })}")
  # user_data_base64            = base64encode(local.user_data)
  # user_data_replace_on_change = true
  vpc_security_group_ids = ["${module.ec2_security_group.security_group_id}", module.efs.security_group_id ]
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

  #  https_listeners = [
   http_tcp_listeners = [
   {
     port               = 80
    #  port               = 443
    #  protocol           = "HTTPS"
     protocol           = "HTTP"
     target_group_index = 0
    #  certificate_arn    = module.acm.acm_certificate_arn
   },
  ]

  target_groups = [
    {
      name             = "${var.instance_name}"
      backend_protocol = "HTTP"
      backend_port     = local.jenkins_port
      target_type      = "instance"
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
      }
      # targets = {
      # jenkins = {
      #   target_id = module.jenkins_instance.id
      #   port      = 8080
      # }
      # }
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
  # egress_cidr_blocks = [local.vpc_cidr] 

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
      description = "RDS ports"
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
      "ec2:DescribeSpotFleetRequests",
      "kms:Encrypt", 
      "kms:Decrypt", 
      "kms:ReEncrypt*", 
      "kms:GenerateDataKey*", 
      "kms:DescribeKey"
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
    },
    {
      Effect = "Allow",
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
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



##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################
##################################################################################################

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"

  for_each = {
    # On-demand instances
    ex-1 = {
      instance_type              = var.instance_type
      use_mixed_instances_policy = false
      user_data  = <<-EOT
#!/bin/bash


echo export FILESYSTEM_ID=${local.filesystem-id} >> ~/.bashrc
echo export TF_VAR_ami=${local.ami} >> ~/.bashrc

source ~/.bashrc
cd /home/admin
cp -R /var/lib/jenkins .
mount -t efs -o tls $FILESYSTEM_ID /var/lib/jenkins

apt-get install jenkins -y
cd jenkins
cp * /var/lib/jenkins
cd /var/lib/jenkins
bash jenkins-init

EOT
    }
    # Spot instances
  }

  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay       = 600
      checkpoint_percentages = [35, 70, 100]
      instance_warmup        = 300
      min_healthy_percentage = 50
      auto_rollback          = true
    }
    triggers = ["tag"]
  }

  name = "${local.name}-${each.key}"
  image_id      = data.aws_ami.packer-custom-ami.id
  # image_id      = "ami-0feed9c72042c31d8"
  instance_type = each.value.instance_type

  security_groups                 = [module.autoscaling_sg.security_group_id, module.ec2_security_group.security_group_id, module.alb_sg.security_group_id, module.efs.security_group_id]
  user_data                       = base64encode(each.value.user_data)
  # user_data = base64encode("${templatefile("./user_data_script.sh", {
  #   filesystem-id   = local.filesystem-id
  # })}")
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "EC2 role for ${local.name}"
  iam_role_policies = {
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    accessPolicy = aws_iam_policy.accessPolicy.id
    rdsAccess = aws_iam_policy.rds_access.id
    AmazonElasticFileSystemFullAccess = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
    AmazonElasticFileSystemsUtils = "arn:aws:iam::aws:policy/AmazonElasticFileSystemsUtils"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true
  key_name               = "priv"

  tags = local.tags

  target_group_arns = module.alb.target_group_arns
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Autoscaling group security group"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      # rule                     = "https-443-tcp"
      source_security_group_id = module.alb_sg.security_group_id
    },
    {
      from_port                = 8080 #forwards to jenkins port
      to_port                  = 8080
      protocol                 = 6
      description              = "alb to jenkins"
      source_security_group_id = module.alb_sg.security_group_id
    }
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}



module "efs" {
  source = "terraform-aws-modules/efs/aws"

  # File system
  name           = "example"
  creation_token = "example-token"
  encrypted      = true
  # kms_key_arn    = "arn:aws:kms:eu-west-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy = {
    transition_to_ia = "AFTER_30_DAYS"
  }
  attach_policy                      = true
  bypass_policy_lockout_safety_check = false
  policy_statements = [
    {
      sid     = "Example"
      actions = ["elasticfilesystem:ClientMount"]
      principals = [
        {
          type        = "AWS"
          identifiers = [data.aws_caller_identity.current.arn]
        }
      ]
    }
  ]

  # Mount targets / security group
  mount_targets = {
   for k, v in zipmap(module.vpc.azs, module.vpc.private_subnets) : k => {subnet_id = v}
  #  for k, v in zipmap(module.vpc.azs, module.vpc.public_subnets) : k => {subnet_id = v}
  }
  security_group_description = "Example EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks =  module.vpc.private_subnets_cidr_blocks
      # cidr_blocks =  module.vpc.public_subnets_cidr_blocks
    }
  }

  # Access point(s)
  access_points = {
    posix_example = {
      name = "posix-example"
      posix_user = {
        gid            = 1001
        uid            = 1001
        secondary_gids = [1002]
      }

      tags = {
        Additionl = "yes"
      }
    }
    root_example = {
      root_directory = {
        path = "/var/lib/jenkins"
        creation_info = {
          owner_gid   = 1001
          owner_uid   = 1001
          permissions = "755"
        }
      }
    }
  }

  # Backup policy
  enable_backup_policy = true

  # # Replication configuration
  # create_replication_configuration = true
  # replication_configuration_destination = {
  #   region = "eu-west-2"
  # }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


# module "jenkins_instance" {
#   source  = "terraform-aws-modules/ec2-instance/aws"
#   ami = data.aws_ami.packer-custom-ami.id
#   name = var.instance_name

#   user_data_base64            = base64encode(local.user_data)
#   user_data_replace_on_change = true
  
#   root_block_device = [
#     {
#       encrypted   = true
#       volume_type = "gp3"
#       throughput  = 200
#       volume_size = 8
#     },
#   ]
#   instance_type          = var.instance_type
#   key_name               = "priv"
#   monitoring             = true
#   vpc_security_group_ids = [module.ec2_security_group.security_group_id, module.alb_sg.security_group_id, module.jenkins_ec2_security_group.security_group_id]
#   associate_public_ip_address = false
#   subnet_id              = "${element(module.vpc.private_subnets, 0)}"
#   create_iam_instance_profile = true
#   iam_role_description        = "cloud9 permissions"
#   iam_role_policies = {
#     Cloud9Administrator = var.Cloud9Administrator
#     accessPolicy = aws_iam_policy.accessPolicy.id
#     rdsAccess = aws_iam_policy.rds_access.id
#   }


#   tags = {
#     Terraform   = "true"
#     Environment = "dev"
#   }
# }



# module "jenkins_ec2_security_group" {
#   source = "terraform-aws-modules/security-group/aws"
#   version = "~> 4.0"

#   name        = var.jenkins_sg
#   description = "${var.jenkins_sg} security group"
#   vpc_id      = module.vpc.vpc_id

 
#   ingress_with_source_security_group_id = [
#     {
#       rule                     = "http-80-tcp"
#       source_security_group_id = module.alb_sg.security_group_id
#     },
#     {
#       from_port                = 8080
#       to_port                  = 8080
#       protocol                 = 6
#       description              = "alb to jenkins"
#       source_security_group_id = module.alb_sg.security_group_id
#     }
#   ]
#   egress_rules = ["all-all"]

#   tags = local.tags
# }
