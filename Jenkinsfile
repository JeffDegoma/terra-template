pipeline {
    agent any

    stages {
        stage('checkout infra repo') {
            steps {
            ## git checkout instance repo
            ## docker-compose up --build
            ## terraform init
            ## terraform plan
            ## terraform apply
        
            sh '''
                export PATH=/usr/lib/oracle/19.3/client64/bin:$PATH
                export LD_LIBRARY_PATH=/usr/lib/oracle/19.3/client64/lib
                export TNS_ADMIN=/usr/lib/oracle/19.3/client64/lib/network/admin

                sqlplus 'username/password@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=myrdsinstance.abcdefghij.us-west-2.rds.amazonaws.com)(PORT=1521))(CONNECT_DATA=(SID=ORCL)))' @my_sql_script.sql
            '''
            }
        }
         stage('Deploy the Application') { 
              steps {
                  sh "docker-compose up -d"

              }
          }
    }
}

