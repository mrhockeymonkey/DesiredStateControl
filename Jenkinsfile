#!groovy

pipeline {
    agent any

    stages {
        stage ('Unit') { // every branch, tag and pr
            steps {
                powershell "whoami"
                echo "Units tests!"
                powershell 'gci env:\\ | fl *'
            }
        }

        stage ('SA') { // every branch, tag and pr
            steps {
                echo "script analyzer!"
            }
        }

        stage ('Integration') { // master branch and PRs
            when {
                anyOf {
                    branch 'master'
                    expression { BRANCH_NAME =~ 'PR-' }
                    tag ''
                }
            }
            steps {
                echo 'integration tests'
            }
        }

        stage ('Build') { // only releases and branch prefixed with 'build-'
            when {
                anyOf {
                    tag ''
                    expression {BRANCH_NAME =~ 'build-'}
                }
            }
            steps {
                powershell '''
                    <# Task: CIBuild #>
                    $ErrorActionPreference = 'Stop'
                    Try { 
                        Import-Module InvokeBuild
                        Invoke-Build -Task CIBuild
                    } Catch {Write-Warning $_.Exception.Message; Exit 1}
                '''
            }
        }

        stage ('Deploy UAT') { // only releases
            when {
                tag ''
            }
            steps {
                input "Deploy to UAT?"
                echo 'Try { Invoke-Build -Task Deploy -Environment UAT} Catch {Write-Warning $_.Exception.Message; Exit 1'
            }
        }

        stage ('Test UAT') { // only releases
            when {
                tag ''
            }
            steps {
                input "Test UAT?"
                echo 'Try { Invoke-Build -Task TBC } Catch {Write-Warning $_.Exception.Message; Exit 1'
            }
        }

        stage ('Deploy PROD') { // only releases
            when {
                tag ''
            }
            steps {
                input "Deploy to PROD?"
                echo 'try { Invoke-Build -Task Deploy -Environment PROD } Catch {Write-Warning $_.Exception.Message; Exit 1'
            }
        }
    }
}
