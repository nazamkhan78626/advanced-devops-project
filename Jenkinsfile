pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        AWS_REGION    = 'ap-south-1'
        ECR_REPO      = 'devops-flask'
        CLUSTER_NAME  = 'devops-eks-cluster'
        K8S_NAMESPACE = 'devops'
        DEPLOYMENT    = 'devops-flask-app'
        CONTAINER     = 'app'
        KUBECONFIG    = "${WORKSPACE}/.kubeconfig"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                dir('app') {
                    sh '''
                        set -eux

                        rm -rf .venv
                        python3 -m venv .venv

                        .venv/bin/pip install --upgrade pip
                        .venv/bin/pip install -r requirements.txt
                        .venv/bin/pip install pytest

                        .venv/bin/pytest -q
                    '''
                }
            }
        }

        stage('Resolve Image') {
            steps {
                script {
                    env.AWS_ACCOUNT_ID = sh(
                        script: "aws sts get-caller-identity --query Account --output text",
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"

                    env.IMAGE_TAG = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()

                    env.IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPO}:${env.IMAGE_TAG}"

                    echo "Image URI: ${env.IMAGE_URI}"
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    set -eux

                    docker build \
                      -t ${IMAGE_URI} \
                      ./app

                    docker inspect ${IMAGE_URI} \
                      --format '{{.Config.User}}'
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    set -eux

                    aws ecr get-login-password \
                      --region ${AWS_REGION} |
                    docker login \
                      --username AWS \
                      --password-stdin ${ECR_REGISTRY}

                    docker push ${IMAGE_URI}
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    set -eux

                    aws eks update-kubeconfig \
                      --name ${CLUSTER_NAME} \
                      --region ${AWS_REGION} \
                      --kubeconfig ${KUBECONFIG}

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      set image \
                      deployment/${DEPLOYMENT} \
                      ${CONTAINER}=${IMAGE_URI}

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      rollout status \
                      deployment/${DEPLOYMENT} \
                      --timeout=5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -eux

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      get deployment ${DEPLOYMENT}

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      get pods \
                      -l app=devops-flask-app \
                      -o wide

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      get service devops-flask-service
                '''
            }
        }

        stage('Health Check') {
            steps {
                sh '''
                    set -eux

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      delete pod jenkins-health-check \
                      --ignore-not-found=true

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      run jenkins-health-check \
                      --image=curlimages/curl \
                      --restart=Never \
                      --command -- \
                      sleep 300

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      wait \
                      --for=condition=Ready \
                      pod/jenkins-health-check \
                      --timeout=120s

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      exec jenkins-health-check -- \
                      curl -fsS \
                      http://devops-flask-service/health

                    kubectl \
                      --kubeconfig ${KUBECONFIG} \
                      -n ${K8S_NAMESPACE} \
                      delete pod jenkins-health-check \
                      --ignore-not-found=true
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment to EKS completed successfully."
        }

        failure {
            echo "Pipeline failed. Check the failed stage in Console Output."

            sh '''
                kubectl \
                  --kubeconfig ${KUBECONFIG} \
                  -n ${K8S_NAMESPACE} \
                  get pods -o wide || true

                kubectl \
                  --kubeconfig ${KUBECONFIG} \
                  -n ${K8S_NAMESPACE} \
                  get events \
                  --sort-by=.metadata.creationTimestamp |
                tail -30 || true
            '''
        }

        always {
            sh '''
                kubectl \
                  --kubeconfig ${KUBECONFIG} \
                  -n ${K8S_NAMESPACE} \
                  delete pod jenkins-health-check \
                  --ignore-not-found=true || true

                docker image prune -f || true
                rm -f ${KUBECONFIG} || true
            '''

            cleanWs(
                deleteDirs: true,
                notFailBuild: true
            )
        }
    }
}
