output "RDS_ENDPOINT" {
  description = "rds endpoint"
  value       = module.db.db_instance_endpoint
}



# output "vpc_name"{
#   description = "load balancer dns"
#   value = module.vpc.name
# }


output "vpc" {
  value       = module.vpc
  description = "The VPC ID"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "The VPC ID"
}
