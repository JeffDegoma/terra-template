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



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = data.terraform_remote_state.remote.outputs.vpc_name
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
  snapshot_identifier = ""
  
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

data "aws_db_snapshot" "latest_snapshot" {
  db_instance_identifier = module.db.snapshot_identifier
  most_recent            = true
}





module "rds_security_group" {
  source = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "rds_security_group"
  description = " rds security group"
  vpc_id      = data.terraform_remote_state.remote.outputs.vpc_id

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