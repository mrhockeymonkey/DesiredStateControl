[CmdletBinding()]
Param (
    [Parameter()]
    [Hashtable]
    $ConfigurationData,
    
    [Parameter()]
    [String]
    $OutputPath,

    [Parameter()]
    [String]
    $RolesDir,
    
    [Parameter()]
    [String]
    $CustomFilters
)

# Load filters
Write-Output $CustomFilters
$Filters = . $CustomFilters

# Load roles
Get-ChildItem -Path $RolesDir -Filter *.ps1 | ForEach-Object {
    Write-Verbose "Loading role from path: $($_.FullName)"
    . $_.FullName
}

# Define meta configuration
[DSCLocalConfigurationManager()]
Configuration MetaConfiguration {
    Node $Allnodes.NodeName {
        Settings {
            ConfigurationMode = 'ApplyAndMonitor'
            RefreshMode ='PULL'
            ConfigurationModeFrequencyMins = 180
            RefreshFrequencyMins = 360 
            AllowModuleOverwrite = $true
            #CertificateId = $CertThumb
        }
        ConfigurationRepositoryWeb PSDSCPullServer {
            ServerUrl = 'https://server:8080/PSDSCPullServer.svc/'
            RegistrationKey = '4376e42c-c598-4f3e-9a0d-1ea0c11892fe'
            AllowUnsecureConnection = $false
            ConfigurationNames = @($Node.NodeName)
        }
        ReportServerWeb PSDSCReportServer {
            ServerURL = 'https://server:8080/PSDSCPullServer.svc/'
            RegistrationKey = '4376e42c-c598-4f3e-9a0d-1ea0c11892fe'
            AllowUnsecureConnection = $false
        }
    }
}

# Define root configuration
Configuration RootConfiguration {
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    #Import-DscResource -ModuleName PackageManagementProviderResource -ModuleVersion 1.0.3.1

    # here we map each role to its given configuration
    Node $AllNodes.NodeName {
        ForEach ($Role in $Node.Roles) {
            If (Test-Path -Path "$RolesDir\$Role.ps1") {
                Write-Verbose "Compile: $($Node.NodeName): $Role"
                & $Role "${Role}DSC" {}
            }
            Else {
                Write-Warning "Role '$Role' not found!"
            }
        }
    }

    # we will always need some flexibility so here we map configurations based on filters defined in CustomFiltering.psd1
    ForEach ($f in $Filters.GetEnumerator()) {
        Node $AllNodes.Where($f.value).NodeName {
            Write-Verbose "Compile: $($Node.NodeName): $($f.Key)"
            & $f.Key "$($f.Key)DSC"
        }
    }
}

RootConfiguration -ConfigurationData $ConfigurationData -OutputPath $OutputPath -Verbose:$VerbosePreference
MetaConfiguration -ConfigurationData $ConfigurationData -OutputPath $OutputPath -Verbose:$VerbosePreference
