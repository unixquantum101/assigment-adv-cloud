// Capstone pipeline: Checkout -> Lint -> Test -> Build -> Push (Docker Hub) -> Deploy (Swarm) -> Verify
// Triggered by the GitHub webhook (push to main) via the ngrok URL of the local Jenkins.
// Telegram notification (bonus) is sent from the post block for every run.

pipeline {
  agent any

  triggers {
    githubPush()
  }

  options {
    timestamps()
    disableConcurrentBuilds()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    // ---- EDIT THESE TWO VALUES ------------------------------------------
    REGISTRY_USER = 'your-dockerhub-username'
    SWARM_MANAGER = 'ubuntu@MANAGER_ELASTIC_IP'     // terraform output manager_public_ip
    // ---------------------------------------------------------------------
    STACK_NAME    = 'cc'
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
        script {
          env.SHORT_SHA = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.TAG       = "${env.BUILD_NUMBER}-${env.SHORT_SHA}"
        }
        echo "Image tag for this run: ${env.TAG}"
      }
    }

    stage('Lint') {
      steps {
        // Runs inside a throw-away Python container so Jenkins needs no Python setup.
        sh '''
          for svc in api web; do
            echo "=== flake8: $svc ==="
            docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -e PIP_CACHE_DIR=/tmp/pip -v "$WORKSPACE/services/$svc":/src -w /src python:3.12-slim sh -c "pip install -q --user -r requirements-dev.txt && python -m flake8 ."
          done
        '''
      }
    }

    stage('Test') {
      steps {
        // Any failing test makes pytest exit non-zero and fails the pipeline here.
        sh '''
          for svc in api web; do
            echo "=== pytest: $svc ==="
            docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -e PIP_CACHE_DIR=/tmp/pip -v "$WORKSPACE/services/$svc":/src -w /src python:3.12-slim sh -c "pip install -q --user -r requirements-dev.txt && python -m pytest -q --junitxml=/src/junit.xml"
          done
        '''
      }
      post {
        always {
          junit allowEmptyResults: true, testResults: 'services/*/junit.xml'
        }
      }
    }

    stage('Build images') {
      steps {
        sh '''
          docker build --build-arg APP_VERSION=$TAG -t $REGISTRY_USER/cc-api:$TAG   services/api
          docker build --build-arg APP_VERSION=$TAG -t $REGISTRY_USER/cc-web:$TAG   services/web
          docker build                              -t $REGISTRY_USER/cc-nginx:$TAG nginx
        '''
      }
    }

    stage('Push to Docker Hub') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub',
                                          usernameVariable: 'DH_USER',
                                          passwordVariable: 'DH_PASS')]) {
          sh '''
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            for img in cc-api cc-web cc-nginx; do
              docker push $REGISTRY_USER/$img:$TAG
            done
          '''
        }
      }
    }

    stage('Deploy to Swarm') {
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'swarm-manager-ssh', keyFileVariable: 'SSH_KEY'),
          usernamePassword(credentialsId: 'dockerhub',
                           usernameVariable: 'DH_USER',
                           passwordVariable: 'DH_PASS')
        ]) {
          sh '''
            SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=accept-new"
            scp $SSH_OPTS docker-stack.yml scripts/wait-converged.sh $SWARM_MANAGER:/home/ubuntu/
            echo "$DH_PASS" | ssh $SSH_OPTS $SWARM_MANAGER "docker login -u $DH_USER --password-stdin"
            ssh $SSH_OPTS $SWARM_MANAGER "REGISTRY_USER=$REGISTRY_USER TAG=$TAG docker stack deploy --with-registry-auth -c /home/ubuntu/docker-stack.yml $STACK_NAME"
            ssh $SSH_OPTS $SWARM_MANAGER "bash /home/ubuntu/wait-converged.sh $STACK_NAME 300"
            ssh $SSH_OPTS $SWARM_MANAGER "docker stack ps $STACK_NAME --filter desired-state=running"
          '''
        }
      }
    }

    stage('Verify (live requests per route)') {
      steps {
        sh '''
          HOST=${SWARM_MANAGER#*@}
          bash scripts/smoke-test.sh http://$HOST
        '''
      }
    }
  }

  post {
    always {
      sh 'docker logout || true'
      script {
        def ok   = (currentBuild.currentResult == 'SUCCESS')
        env.TG_TEXT = (ok ? '✅ SUCCESS' : '❌ FAILED') +
                      "\nJob: ${env.JOB_NAME}\nBuild: #${env.BUILD_NUMBER}\nTag: ${env.TAG ?: 'n/a'}\n${env.BUILD_URL}"
        withCredentials([string(credentialsId: 'telegram-bot-token', variable: 'TG_TOKEN'),
                         string(credentialsId: 'telegram-chat-id',  variable: 'TG_CHAT')]) {
          sh '''
            curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" -d chat_id="${TG_CHAT}" --data-urlencode "text=${TG_TEXT}" > /dev/null || true
          '''
        }
      }
    }
  }
}
