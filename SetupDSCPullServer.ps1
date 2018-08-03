param (
    [Parameter(Mandatory)]
    [string]$CertificateThumbPrint,

    [Parameter(Mandatory)]
    [string] $RegistrationKey
)

Import-Module -Name xPSDesiredStateConfiguration, PSDesiredStateConfiguration

Configuration SetupDscPullServer {
    param ( 

        [ValidateNotNullOrEmpty()] 
        [string]$CertificateThumbPrint,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey
    ) 

    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 8.2.0.0
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xWebAdministration -ModuleVersion 1.19.0.0

    Node 'localhost' { 
        WindowsFeature DSCServiceFeature { 
            Ensure = 'Present'
            Name   = 'DSC-Service'
        }

        xDscWebService PSDSCPullServer { 
            Ensure                  = 'Present'
            EndpointName            = 'PSDSCPullServer'
            Port                    = 8080
            PhysicalPath            = "$env:SystemDrive\inetpub\PSDSCPullServer"
            CertificateThumbPrint   = $certificateThumbPrint
            #CertificateThumbPrint   = 'AllowUnencryptedTraffic'
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                   = 'Started'
            UseSecurityBestPractices = $false
            SqlProvider = $true
            SqlConnectionString = "Provider=SQLNCLI11;Data Source=DBATestSvr;Trusted_Connection=yes;Initial Catalog=DSCTest;"
            #"Provider=SQLNCLI11;Data Source=(local)\SQLExpress;User ID=SA;Password=Password12!;Initial Catalog=master;"
            DependsOn               = '[WindowsFeature]DSCServiceFeature'
        } 

        File RegistrationKeyFile {
            Ensure          = 'Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }
    }
}

SetupDscPullServer -CertificateThumbPrint $CertificateThumbPrint -RegistrationKey $RegistrationKey
