// ===========================================================================
// ACEest Fitness & Gym - Assignment 2
// End-to-end CI/CD pipeline
//
//   Checkout -> Build env -> Lint -> Pytest -> SonarQube + Quality Gate
//            -> Docker build (multi-version) -> Test in container
//            -> Push to Docker Hub -> Deploy to Kubernetes -> Verify -> Rollback on failure
//
// Credentials required in Jenkins (Manage Jenkins > Credentials):
//   dockerhub-creds  : Username with password  (Docker Hub user + access token)
//   sonar-token      : Secret text             (SonarQube user token)
//   SonarQube server : configured under Manage Jenkins > System as 'SonarQube'
// ===========================================================================
pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '15'))
        timeout(time: 45, unit: 'MINUTES')
    }

    environment {
        DOCKERHUB_USER = '2025tm93228'
        IMAGE          = "${DOCKERHUB_USER}/aceest-fitness"
        APP_VERSION    = '1.0.0'
        K8S_NAMESPACE  = 'aceest'
        VENV           = '.venv'
    }

    // Poll the Git repository so a push triggers a build automatically.
    triggers {
        pollSCM('H/5 * * * *')
    }

    stages {

        stage('1. Checkout') {
            steps {
                echo 'Pulling latest code from GitHub'
                checkout scm
                sh 'git log --oneline -5'
                script {
                    env.GIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.BUILD_TAG_VERSION = "${env.APP_VERSION}-${env.BUILD_NUMBER}-${env.GIT_SHORT}"
                }
                echo "Build tag: ${env.BUILD_TAG_VERSION}"
            }
        }

        stage('2. Build Environment') {
            steps {
                sh '''
                    python3 -m venv ${VENV}
                    . ${VENV}/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements-dev.txt
                '''
            }
        }

        stage('3. Lint & Compile') {
            steps {
                sh '''
                    . ${VENV}/bin/activate
                    python -m compileall -q app.py db.py models.py tests
                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
                    flake8 . --count --exit-zero --statistics
                '''
            }
        }

        stage('4. Unit Tests') {
            steps {
                sh '''
                    . ${VENV}/bin/activate
                    pytest -v \
                      --junitxml=reports/junit.xml \
                      --cov=. --cov-report=xml:reports/coverage.xml \
                      --cov-report=term-missing
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        stage('5. SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        . ${VENV}/bin/activate
                        sonar-scanner \
                          -Dsonar.projectKey=aceest-fitness \
                          -Dsonar.projectVersion=${BUILD_TAG_VERSION} \
                          -Dsonar.python.coverage.reportPaths=reports/coverage.xml
                    '''
                }
            }
        }

        stage('6. Quality Gate') {
            steps {
                // Blocks the pipeline until SonarQube returns its gate verdict.
                // abortPipeline: true means a failed gate stops the build before
                // any image is published - quality enforcement, not just reporting.
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('7. Docker Build') {
            steps {
                sh '''
                    docker build --target test    -t ${IMAGE}:test .
                    docker build --target runtime -t ${IMAGE}:${APP_VERSION} \
                                                  -t ${IMAGE}:${BUILD_TAG_VERSION} \
                                                  -t ${IMAGE}:latest \
                                                  --build-arg APP_VERSION=${APP_VERSION} .
                    docker images ${IMAGE}
                '''
            }
        }

        stage('8. Test Inside Container') {
            steps {
                sh 'docker run --rm ${IMAGE}:test pytest -v'
            }
        }

        stage('9. Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                        credentialsId: 'dockerhub-creds',
                        usernameVariable: 'DH_USER',
                        passwordVariable: 'DH_PASS')]) {
                    sh '''
                        echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
                        docker push ${IMAGE}:${APP_VERSION}
                        docker push ${IMAGE}:${BUILD_TAG_VERSION}
                        docker push ${IMAGE}:latest
                        docker logout
                    '''
                }
            }
        }

        stage('10. Deploy to Kubernetes') {
            steps {
                sh '''
                    kubectl apply -f k8s/00-base/namespace.yaml
                    kubectl apply -f k8s/01-rolling-update/
                    kubectl set image deployment/aceest-rolling \
                        aceest=${IMAGE}:${BUILD_TAG_VERSION} -n ${K8S_NAMESPACE} --record || true
                    kubectl rollout status deployment/aceest-rolling \
                        -n ${K8S_NAMESPACE} --timeout=180s
                '''
            }
        }

        stage('11. Smoke Test Deployment') {
            steps {
                sh '''
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    kubectl run smoke-${BUILD_NUMBER} --rm -i --restart=Never \
                      --image=curlimages/curl:latest -n ${K8S_NAMESPACE} -- \
                      curl -fsS http://aceest-rolling-svc/health
                '''
            }
        }
    }

    post {
        failure {
            // Automatic rollback: if any stage after deployment failed, revert
            // the Deployment to the previous ReplicaSet so the cluster is left
            // running the last known-good version.
            echo "BUILD #${env.BUILD_NUMBER} FAILED - attempting rollback to last stable revision"
            sh '''
                kubectl rollout undo deployment/aceest-rolling -n ${K8S_NAMESPACE} || true
                kubectl rollout status deployment/aceest-rolling -n ${K8S_NAMESPACE} --timeout=120s || true
            '''
        }
        success {
            echo "BUILD #${env.BUILD_NUMBER} PASSED - ${IMAGE}:${env.BUILD_TAG_VERSION} published and deployed"
        }
        cleanup {
            sh 'rm -rf ${VENV} || true'
        }
    }
}
