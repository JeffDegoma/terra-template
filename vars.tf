variable "region" {
    default = "us-east-1"
}
variable "instance_name" {
    default = "jenkins-main"
}
variable "Cloud9Administrator" {
    default = "arn:aws:iam::aws:policy/AWSCloud9Administrator"
}
variable "sg_name" {
    default = "cloud9-sg"
}
variable "jenkins_sg" {
    default = "jenkins-sg"
}
variable "instance_type" {
    default = "t3.medium"
}
variable "environment_name" {
    default = "remote-host-2"
}
variable "image_id" {
    default = "resolve:ssm:/aws/service/cloud9/amis/amazonlinux-2-x86_64"
}
variable "packer_ami_value" {
    default = ""
}
variable "account" {
    default = ""
}

variable "project_name" {
    default = "cloud9"
}
