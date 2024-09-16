output "RDS_ENDPOINT" {
  description = "rds endpoint"
  value       = module.db.db_instance_endpoint
}

output "ami" {
  description = "ami name"
  value = data.aws_ami.packer-custom-ami
}


output "ec2_complete_public_ip" {
  description = "The public IP address assigned to the instance, if applicable. NOTE: If you are using an aws_eip with your instance, you should refer to the EIP's address directly and not use `public_ip` as this field will change after the EIP is attached"
  value       = module.ec2_instance.public_ip
}