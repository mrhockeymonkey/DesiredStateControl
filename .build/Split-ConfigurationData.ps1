Function Split-ConfigurationData {
    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject
    )

    Begin {}

    Process {
        ForEach ($Node in $InputObject.AllNodes) {
            $ConfigData = @{
                AllNodes = [array]$Node
                NonNodeData = $InputObject.NonNodeData
	        }

            Write-Output $ConfigData
        }
    }

    End {}

}
