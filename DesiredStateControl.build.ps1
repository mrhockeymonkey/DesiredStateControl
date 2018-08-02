[CmdletBinding()]
Param ()

$ErrorActionPreference = 'Stop'
$BuildDir = Join-Path $PSScriptRoot '.build'
$RolesDir = Join-Path $PSScriptRoot 'Roles'
$OutputDir = Join-Path $PSScriptRoot 'Output'
$LibDir = Join-Path $PSScriptRoot 'Library'
$MaxActiveRunspaces = 28
$RootConfiguration = Resolve-Path -Path $PSScriptRoot\RootConfiguration.ps1
$CustomFilters = Resolve-Path -Path $PSScriptRoot\CustomFiltering.ps1

# Dot source helper functions
Get-ChildItem -Path $BuildDir -Recurse -Include *.ps1 | ForEach-Object {
    . $_.FullName
}

# Setup psmodulepath to include library
$env:PSModulePath = $env:PSModulePath + ";$LibDir"

# Default 'build' task
Task . LocalBuild

Task LocalBuild CleanupOutputDir, GetConfigurationData, ExportConfigurationData, CreateRunspacePool, CompileRootConfiguration # EnrichConfigurationData wont work on CI
Task CIBuild Installreqs, LocalBuild


# Tasks
Task InstallReqs {
    Import-Module PSDepend
    Invoke-PSDepend -Path $PSScriptRoot -Force -Verbose
}

Task CleanupOutputDir {
    If (Test-Path -Path $OutputDir) {
        Remove-Item -Path $OutputDir -Force -Recurse
    }
    $Null = New-Item -Path $OutputDir -ItemType Directory
}

Task GetConfigurationData {

}

Task EnrichConfigurationData {

}

Task ExportConfigurationData {
    $Script:ConfigurationData | Split-ConfigurationData | ForEach-Object {
        $NodeName = $_.AllNodes[0].NodeName
        $_ | Export-Clixml -Path "$OutputDir\$NodeName.xml"
    }
}

Task CreateRunspacePool GetConfigurationData, {
    $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    #Get-ChildItem -Path $RolesDir -Filter *.psm1 | Select-Object -ExpandProperty FullName | ForEach-Object {
    #	$SessionState.ImportPSModule($_)
    #}

    <#
        .NOTES (Weirdness)
        it would make sense here to also pre-import configurations but for some reason this is really flakey
        Instead configurations are imported at runtime :'(
    #>

    Write-Output "InitialSessionState created: `n"
    Write-Output $SessionState

    #Write-Output "Imported modules are: `n"
    #Write-Output $SessionState.Modules.Name
    #Create runspace pool and var to track runspaces
    $Script:Runspaces = [System.Collections.ArrayList]::New()
    $Script:RunspacePool = [RunspaceFactory]::CreateRunspacePool(
        1, #Min runspaces
        $MaxActiveRunspaces,
        $SessionState,
        $Host
    )
    


    $Script:ConfigurationData | Split-ConfigurationData | ForEach-Object {
        Write-Output "Adding $($_.AllNodes.NodeName) to runspace pool"
        $Params = @{
            RootConfiguration = $RootConfiguration
            ConfigurationData = $_
            OutputPath = $OutputDir
            RolesDir = $RolesDir
            CustomFilters = $CustomFilters
        }
        
        $Script = {
            [CmdletBinding()]
            Param ($RootConfiguration, $ConfigurationData, $OutputPath, $RolesDir, $CustomFilters)
            $PSBoundParameters.Remove('RootConfiguration')
            . $RootConfiguration @PSBoundParameters
        }
        
        $PowerShell = [System.Management.Automation.PowerShell]::Create()
        $PowerShell.RunspacePool = $Script:RunspacePool
        [Void]$PowerShell.AddScript($Script).AddParameters($Params)
        
        [Void]$Script:Runspaces.Add([PSCustomObject]@{
            Node = $_.AllNodes.NodeName
            PowerShell = $PowerShell
        })

    }
}

Task CompileRootConfiguration CreateRunspacePool, {
    # Start the engines
    $Script:RunspacePool.Open()
    $Script:Runspaces | ForEach-Object {
        $_ | Add-Member -MemberType NoteProperty -Name Runspace -Value $($_.Powershell.BeginInvoke())
    }

    # Track progress
    Do {
        $More = $false
        $CompletedRunspaces = [System.Collections.ArrayList]::New()
        If ($Script:Runspaces.Count -gt 0) {
            $More = $true
            $Script:Runspaces | Where-Object -FilterScript {$_.Runspace.isCompleted} | ForEach-Object {
                $Node = $_.Node
                $InnerError = $_.Powershell.Streams.Error
                Try {
                    $_.Powershell.EndInvoke($_.Runspace)
                }
                Catch {
                    Write-Build RED "Compilation FAILED for $Node. $($_.Exception.Message)"
                    $RunspacePool.Close()
                    $RunspacePool.Dispose()
                    Throw $InnerError
                }
                Finally {
                    $_.PowerShell.Dispose()
                    [Void]$CompletedRunspaces.Add($_)
                }
            }
            $CompletedRunspaces | ForEach-Object {
                [Void]$Script:Runspaces.Remove($_)
            }
        }
        Start-Sleep -Seconds 1
    }
    While ($More)
    
    $Script:RunspacePool.Close()
    $Script:RunspacePool.Dispose()
}

Task PublishRootConfiguration {
    Get-ChildItem -Path $OutputDir -Filter '*.mof' | Where-Object {$_.BaseName -notlike '*.meta'} | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "\\server\c$\Program Files\WindowsPowerShell\DscService\Configuration" -Verbose
        New-DscChecksum -Path "\\server\c$\Program Files\WindowsPowerShell\DscService\Configuration\$($_.Name)" -Force -Verbose
    }
}
