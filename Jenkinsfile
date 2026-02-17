pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    choice(
      name: 'ACTION',
      choices: ['check', 'apply', 'deploy_only'],
      description: 'check = terraform validate | apply = terraform apply + ansible | deploy_only = ansible only'
    )
  }

  environment {
    TF_DIR = "terraform"
    ANS_DIR = "ansible"
    INVENTORY = "inventory.ini"
    PLAYBOOK  = "install_docker.yml"
    // CRITICAL: This is the path on your Ubuntu host, not inside the container.
    HOST_WS = "/var/lib/docker/volumes/jenkins_home/_data/workspace/${JOB_NAME}"
  }

  stages {
    stage("Checkout") {
      steps {
        checkout scm
      }
    }

    stage("Docker Sanity Check") {
      steps {
        sh 'docker version && docker ps'
      }
    }

    stage("Terraform: Init & Plan") {
      steps {
        sh '''
          set -e
          echo "Using Host Path for Docker Mount: $HOST_WS"

          echo "===== Terraform Init ====="
          docker run --rm \
            -v "$HOST_WS":/work -w /work/$TF_DIR \
            hashicorp/terraform:1.6 init -input=false

          echo "===== Terraform Validate ====="
          docker run --rm \
            -v "$HOST_WS":/work -w /work/$TF_DIR \
            hashicorp/terraform:1.6 validate

          echo "===== Terraform Plan ====="
          docker run --rm \
            -v "$HOST_WS":/work -w /work/$TF_DIR \
            hashicorp/terraform:1.6 plan -input=false -out=tfplan
        '''
      }
    }

    stage("Terraform: Apply") {
      when { expression { params.ACTION == 'apply' } }
      steps {
        input message: "Apply Terraform to AWS?", ok: "Apply Now"
        sh '''
          set -e
          docker run --rm \
            -v "$HOST_WS":/work -w /work/$TF_DIR \
            hashicorp/terraform:1.6 apply -input=false -auto-approve tfplan
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
          sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')
        ]) {
          sh '''
            set -e
            # Copy SSH key to the workspace so the Docker container can see it via the volume mount
            cp "$SSH_KEY" ./ec2_key
            chmod 600 ./ec2_key

            echo "===== Running Ansible Playbook ====="
            docker run --rm \
              -v "$HOST_WS":/work -w /work/$ANS_DIR \
              --network host \
              alpine/ansible:latest \
              ansible-playbook -i $INVENTORY $PLAYBOOK \
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
        sh 'curl -I http://54.147.148.219 | head -n 1 || true'
      }
    }
  }

  post {
    failure { echo "❌ Pipeline failed." }
    success { echo "✅ Pipeline successful." }
  }
}