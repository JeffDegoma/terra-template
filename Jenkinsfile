pipeline {
    agent any
     parameters {
        choice(choices:['build','destroy'], description: 'Users Choice', name: 'CHOICE')
    }
    stages {
        stage('checkout repo') {
            steps {
                 withCredentials([[
                $class: "AmazonWebServicesCredentialsBinding",
                credentialsId: "aws-credentials",
                accessKeyVariable: "AWS_ACCESS_KEY_ID",
                secretKeyVariable: "AWS_SECRET_ACCESS_KEY"
             ]]){
                sh '''
                    sudo AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY docker-compose up --build --remove-orphans -d
                    
                '''
              }
       
            }
        }
         stage('Terraform pull state') { 
            steps {
                withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                    s3Download(file: 'terraform.tfstate', bucket: 'terraform-backend-pakil-state', path: 'terraform.tfstate', force: true)
                }
            }
          }
         stage('Terraform init') { 
              steps {
	              withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                  sh '''
		                sleep 20s
                    sudo docker exec -i ec2 terraform init
                    '''
                 }
	              }
          }
         stage('Terraform plan') {
            when {
                expression {env.CHOICE == 'destroy'}
            }
            steps {
                withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                    sh 'sudo docker exec -i ec2 terraform plan --target=module.rds_security_group --target=module.db'

                }
            }
          }
       }
}
   