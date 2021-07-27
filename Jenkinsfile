pipeline {
  agent any

  environment {
    SIDEKIQ_PRO_SECRET = credentials("sidekiq_pro_secret")
    SLACK_WEBHOOK_URL = credentials("access_slack_webhook")
    PROJECT = 'sul-dlss/purl-fetcher'
  }

  stages {
    stage('Capistrano Deploy') {

      when {
        branch 'master'
      }

      steps {
        checkout scm

        sshagent (['sul-devops-team', 'sul-continuous-deployment']){
          sh '''#!/bin/bash -l
          export DEPLOY=1

          # Load RVM
          rvm use 3.0.1@purl-fetcher --create
          gem install bundler

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          bundle install --without production

          # Deploy it
          bundle exec cap stage deploy
          '''
        }
      }

      post {
        success {
          sh '''#!/bin/bash -l
            curl -X POST -H 'Content-type: application/json' --data "{\\"text\\":\\"[$PROJECT] The deploy to stage was successful [https://github.com/$PROJECT/compare/$GIT_PREVIOUS_SUCCESSFUL_COMMIT..$GIT_COMMIT]\\"}" $SLACK_WEBHOOK_URL
          '''
        }

        failure {
          sh '''#!/bin/bash -l
            curl -X POST -H 'Content-type: application/json' --data "{\\"text\\":\\"[$PROJECT] The deploy to stage was unsuccessful [https://github.com/$PROJECT/compare/$GIT_PREVIOUS_SUCCESSFUL_COMMIT..$GIT_COMMIT]\\"}" $SLACK_WEBHOOK_URL
          '''
        }
      }
    }

    stage('Deploy on release') {

      when {
        tag "v*"
      }

      steps {
        checkout scm

        sshagent (['sul-devops-team', 'sul-continuous-deployment']){
          sh '''#!/bin/bash -l
          export DEPLOY=1
          export REVISION=$TAG_NAME

          # Load RVM
          rvm use 3.0.1@purl-fetcher --create
          gem install bundler

          bundle config --global gems.contribsys.com $SIDEKIQ_PRO_SECRET
          bundle install --without production

          # Deploy it
          bundle exec cap prod deploy
          '''
        }
      }

      post {
        success {
          sh '''#!/bin/bash -l
            curl -X POST -H 'Content-type: application/json' --data "{\\"text\\":\\"[$PROJECT] The $TAG_NAME deploy to prod was successful [https://github.com/$PROJECT/compare/$GIT_PREVIOUS_SUCCESSFUL_COMMIT..$TAG_NAME]\\"}" $SLACK_WEBHOOK_URL
          '''
        }

        failure {
          sh '''#!/bin/bash -l
            curl -X POST -H 'Content-type: application/json' --data "{\\"text\\":\\"[$PROJECT] The $TAG_NAME deploy to prod was unsuccessful [https://github.com/$PROJECT/compare/$GIT_PREVIOUS_SUCCESSFUL_COMMIT..$TAG_NAME]\\"}" $SLACK_WEBHOOK_URL
          '''
        }
      }
    }
  }
}
