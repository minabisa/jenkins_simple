pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    choice(
      name: 'ACTION',
      choices: ['check', 'apply', 'deploy_only'],
      description: 'check = terraform validate only | apply = terraform apply + ansible | deploy_only = ansible only'
    )
  }

  environment {
    TF_DIR = "terraform"
    ANS_DIR = "ansible"
    INVENTORY = "inventory.ini"
    PLAYBOOK  = "install_docker.yml"
    HOST_WORKSPACE = "/var/lib/docker/volumes/jenkins_home/_data/workspace/${JOB_NAME}"
  }

  stages {

    stage("Checkout") {
      steps {
        checkout scm
      }
    }

    stage("Docker Sanity Check") {
      steps {
        sh '''
          echo "Workspace: $PWD"
          docker version
          docker ps
        '''
      }
    }

    
    stage("Terraform: fmt + init + validate + plan") {
      steps {
        sh '''
          set -e

          echo "Internal Workspace: ${WORKSPACE}"
          
          # 1. Check files using the internal path first
          echo "Checking for terraform directory..."
          ls -la "${WORKSPACE}/${TF_DIR}"

          # 2. Run Terraform via Docker
          # Note: We use ${WORKSPACE} because the Host Docker 
          # sees the volume mount at the same location if configured correctly,
          # or we use the Jenkins path if it's a bind mount.
          
          echo "===== Terraform fmt ====="
          docker run --rm \
            -v "${WORKSPACE}":/work -w /work/${TF_DIR} \
            hashicorp/terraform:1.6 \
            fmt -check -recursive

          echo "===== Terraform init ====="
          docker run --rm \
            -v "${WORKSPACE}":/work -w /work/${TF_DIR} \
            hashicorp/terraform:1.6 \
            init -input=false

          echo "===== Terraform validate ====="
          docker run --rm \
            -v "${WORKSPACE}":/work -w /work/${TF_DIR} \
            hashicorp/terraform:1.6 \
            validate

          echo "===== Terraform plan ====="
          docker run --rm \
            -v "${WORKSPACE}":/work -w /work/${TF_DIR} \
            hashicorp/terraform:1.6 \
            plan -input=false -out=tfplan
        '''
      }
    }



    stage("Terraform: apply") {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        input message: "Apply Terraform to AWS?", ok: "Apply Now"

        sh '''
    set -e
    docker run --rm \
        -v "${HOST_WORKSPACE}":/work \
        -w /work/"${TF_DIR}" \
        hashicorp/terraform:1.6 \
        apply -input=false -auto-approve tfplan
   '''
      }
    }

    stage("Ansible: Configure EC2") {
      when {
        anyOf {
          expression { params.ACTION == 'apply' }
          expression { params.ACTION == 'deploy_only' }
        }
      }
      steps {
        withCredentials([
          sshUserPrivateKey(
            credentialsId: 'ec2-ssh-key',
            keyFileVariable: 'SSH_KEY',
            usernameVariable: 'SSH_USER'
          )
        ]) {
          sh '''
            set -e

            echo "===== Preparing SSH Key ====="
            cp "$SSH_KEY" ./ec2_key
            chmod 600 ./ec2_key

            echo "===== Testing Ansible connection ====="
            docker run --rm \
              -v "$PWD":/work -w /work/${ANS_DIR} \
              --network host \
              alpine/ansible:latest \
              ansible -i ${INVENTORY} all -m ping \
              --user "$SSH_USER" \
              --private-key /work/ec2_key \
              -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"

            echo "===== Running Playbook ====="
            docker run --rm \
              -v "$PWD":/work -w /work/${ANS_DIR} \
              --network host \
              alpine/ansible:latest \
              ansible-playbook -i ${INVENTORY} ${PLAYBOOK} \
              --user "$SSH_USER" \
              --private-key /work/ec2_key \
              -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
          '''
        }
      }
    }

    stage("Smoke Test") {
      when {
        anyOf {
          expression { params.ACTION == 'apply' }
          expression { params.ACTION == 'deploy_only' }
        }
      }
      steps {
        sh '''
          echo "===== Smoke Test ====="
          echo "Checking Nginx (port 80)..."
          curl -I http://54.147.148.219 | head -n 1 || true

          echo "Checking Jenkins (port 8080)..."
          curl -I http://54.147.148.219:8080/login | head -n 1 || true
        '''
      }
    }

  }

  post {
    success {
      echo "✅ Pipeline completed successfully"
    }
    failure {
      echo "❌ Pipeline failed — check console output"
    }
    always {
      echo "Pipeline finished."
    }
  }
}
