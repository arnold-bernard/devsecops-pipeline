pipeline {
    agent any

    environment {
        IMAGE_NAME = "juice-shop"
        IMAGE_TAG  = "${BUILD_NUMBER}"
        DOCKER_REPO = "arnoldbernard/juice-shop"
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/arnold-bernard/devsecops-pipeline.git'
            }
        }

        stage('SonarQube Scan') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('Sonarqube-Server') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }


        stage('Build Docker Image') {
            steps {
                dir('app/juice-shop') {
                    sh """
                        docker build \
                        -t ${DOCKER_REPO}:${IMAGE_TAG} \
                        -t ${DOCKER_REPO}:latest .
                    """
                }
            }
        }

        stage('Trivy Scan') {
            steps {
                sh """
                    trivy image \
                    --severity HIGH,CRITICAL \
                    --exit-code 1 \
                    ${DOCKER_REPO}:${IMAGE_TAG}
                """
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {

                    sh '''
                    echo "$DOCKER_PASS" | docker login \
                    -u "$DOCKER_USER" \
                    --password-stdin
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh """
                    docker push ${DOCKER_REPO}:${IMAGE_TAG}
                    docker push ${DOCKER_REPO}:latest
                """
            }
        }

    }

    post {

        success {
            echo "===================================="
            echo "Pipeline Completed Successfully"
            echo "Docker Image: ${DOCKER_REPO}:${IMAGE_TAG}"
            echo "===================================="
        }

        failure {
            echo "===================================="
            echo "Pipeline Failed"
            echo "===================================="
        }

        always {
            cleanWs()
        }
    }
}

