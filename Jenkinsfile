pipeline {
    agent {
        label 'osx'
    }

    environment {
        SONAR_HOME = "/Users/Shared/Developer/sonar-scanner-4.6.0.2311-macosx/bin"
        SONAR_BUILD_WRAPPER = "/Users/Shared/Developer/build-wrapper-macosx-x86/build-wrapper-macosx-x86"
        PATH="${PATH}:${GEM_HOME}/bin"
    }

   stages
  {

    stage('Verify Example App Android Build')
    {
      steps
      {
        sh """
          source ~/.zshrc
          cd example
          flutter clean
          flutter pub get
          flutter build apk
        """
      }
    }

    stage('Verify Example App iOS Build')
    {
      steps
      {
        sh """
          source ~/.zshrc
          cd example
          flutter clean
          flutter pub get
          flutter build ios-framework
        """
      }
    }

    stage('Run linter')
    {
      steps
      {
        sh """
          source ~/.zshrc
          flutter clean
          flutter pub get
          dart analyze .
        """
      }
    }

    stage('Run unit tests')
    {
      steps
      {
        sh """
          source ~/.zshrc
          flutter clean
          flutter pub get
          bash ./scripts/run-unit-tests.sh
        """
      }
    }

    stage('Android 12 / API 31')
    {
      steps
      {
        sh """
          source ~/.zshrc
          bash ./scripts/run-tests.sh A_32_Tealeaf
          ./scripts/run-tests.sh android-31
        """
      }
    }

    stage('iOS 15')
    {
      steps
      {
        sh """
          source ~/.zshrc
          bash ./scripts/run-tests.sh "iOS 15"
        """
      }
    }
  }
    post {
        always {
            script{
                getSlackReport(false)
            }
        }
        // Clean after build
        success {
            cleanWs cleanWhenNotBuilt: false, cleanWhenFailure: false, cleanWhenUnstable: false, deleteDirs: true, disableDeferredWipeout: true, patterns: [[pattern: "**/Reports/**", type: 'EXCLUDE']]
        }
        aborted {
            cleanWs cleanWhenNotBuilt: false, cleanWhenFailure: false, cleanWhenUnstable: false, deleteDirs: true, disableDeferredWipeout: true, patterns: [[pattern: "**/Reports/**", type: 'EXCLUDE']]
        }
    }
}
