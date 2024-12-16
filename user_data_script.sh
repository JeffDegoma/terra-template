#!/bin/bash

# cd /var/lib/jenkins
# bash jenkins-init
# sleep 5s

mkdir hello-there

echo 'echo export PAKIL=HI >> ~/.bashrc'

source ~/.bashrc

mount -t efs -o tls ${filesystem-id} efs-mount-point/
