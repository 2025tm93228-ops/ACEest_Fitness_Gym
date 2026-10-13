pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        IMAGE_NAME = 'aceest-fitness'
        VENV       = '.venv'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Pulling the latest code from GitHub...'
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('Build Environment') {
            steps {
                echo 'Creating a clean virtual environment...'
                sh '''
                    python3 -m venv ${VENV}
                    . ${VENV}/bin/activate
                    pip install --upgrade pip
                    pip install -r requirements-dev.txt
                '''
            }
        }

        stage('Lint & Compile') {
            steps {
                sh '''
                    . ${VENV}/bin/activate
                    python -m compileall -q app.py db.py models.py tests
                    flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
                    flake8 . --count --exit-zero --statistics
                '''
            }
        }

        stage('Unit Tests (Quality Gate)') {
            steps {
                sh '''
                    . ${VENV}/bin/activate
                    pytest -v --junitxml=reports/junit.xml --cov=. --cov-report=xml:reports/coverage.xml
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'reports/junit.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build --target test -t ${IMAGE_NAME}:test .
                    docker run --rm ${IMAGE_NAME}:test pytest -v
                    docker build --target runtime -t ${IMAGE_NAME}:${BUILD_NUMBER} -t ${IMAGE_NAME}:latest .
                    docker images ${IMAGE_NAME}
                '''
            }
        }

        stage('Container Smoke Test') {
            steps {
                sh '''
                    docker rm -f aceest-smoke || true
                    docker run -d --name aceest-smoke -p 5050:5000 ${IMAGE_NAME}:latest
                    sleep 6
                    curl -fsS http://localhost:5050/health
                    docker rm -f aceest-smoke
                '''
            }
        }
    }

    post {
        success { echo "BUILD #${env.BUILD_NUMBER} PASSED - image ${IMAGE_NAME}:${env.BUILD_NUMBER} ready." }
        failure { echo "BUILD #${env.BUILD_NUMBER} FAILED - check the stage log above." }
        cleanup { sh 'rm -rf ${VENV}' }
    }
}
