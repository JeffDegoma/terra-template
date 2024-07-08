#/bin/bash
#install dependencies, terraform and kubectl INSIDE an awscli docker container

#Tools
yum update -y
yum install -y jq nano git wget yum-utils shadow-utils python3

#Terraform
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install terraform

echo "installing python lib"
pip3 install requests
pip3 install requests_aws4auth
pip3 install urllib3==1.26.6

echo "Libs installed"
echo "Terraform running"





tail -f /dev/null #keeps container running

