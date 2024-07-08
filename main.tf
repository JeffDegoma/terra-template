
provider "aws" {
    version =  ">= 4.55"
    region  = var.region
}

locals {
  region = var.region
  name   = "demo-${basename(path.cwd)}-${var.project_name}"

  vpc_cidr = "10.0.0.0/16"
  #azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  container_name = "container-name"
  container_port = 24224
  

  tags = {
    Name       = local.name
    Example    = local.name
  }
}


### Data sources provide information about resources that are not managed by the current Terraform configuration. 

## This fetches AMI resources from AWS
data "aws_ami" "amazon-linux-2" {
 most_recent = true


 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
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

  azs             = ["us-east-1a", "us-east-1b"] //more azs
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  create_igw      = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  ami = data.aws_ami.amazon-linux-2.id
  name = var.instance_name
  
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
  vpc_security_group_ids = ["${module.ec2_security_group.security_group_id}"]
  associate_public_ip_address = true
  subnet_id              = "${element(module.vpc.public_subnets, 0)}"
  create_iam_instance_profile = true
  iam_role_description        = "cloud9 permissions"
  iam_role_policies = {
    Cloud9Administrator = var.Cloud9Administrator
  }
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


module "ec2_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.sg_name
  description = "${var.sg_name} security group"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"] # change or remove
  ingress_rules  = ["ssh-tcp"]

  egress_rules = ["all-all"]

  tags = local.tags

}


