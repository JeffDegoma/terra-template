output "RDS_ENDPOINT" {
  description = "rds endpoint"
  value       = module.db.db_instance_endpoint
}



output "vpc_name"{
  description = "load balancer dns"
  value = module.vpc.name
}

