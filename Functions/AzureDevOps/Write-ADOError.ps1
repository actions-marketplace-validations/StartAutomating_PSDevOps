function Write-ADOError
{
    <#
    .Synopsis
        Writes an ADO Error
    .Description
        Writes an Azure DevOps Error
    .Example
        Write-ADOError "Stuff hit the fan"
    .Link
        Write-ADOWarning
    .Link
        https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands
    #>
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "",
        Justification="Directly outputs in certain scenarios")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("Test-ForUnusableFunction", "",
        Justification="Directly outputs in certain scenarios")]
    param(
    # The error message.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [string]
    $Message,

    # An optional source path.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Source','FullName','File')]
    [string]
    $SourcePath,

    # An optional line number.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Line')]
    [uint32]
    $LineNumber,

    # An optional column number.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Column','Col')]
    [uint32]
    $ColumnNumber,

    # An optional error code.
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]
    $Code
    )

    begin {
        $cmdMd = [Management.Automation.CommandMetaData]$MyInvocation.MyCommand
    }

    process {
        #region Collect Optional Properties
        $properties = # Collect the optional properties
            @(foreach ($kv in $PSBoundParameters.GetEnumerator()) {
                if ('Message' -contains $kv.Key) { continue } # (anything but Message).
                if (-not $cmdMd.Parameters.ContainsKey($kv.Key)) { continue }
                "$($kv.Key.ToLower())=$($kv.Value)"
            }) -join ';'
        #endregion Collect Optional Properties
        # Then output the error with it's message.
        $out = "##vso[task.logissue type=error$(if ($properties){";$properties"})]$Message"
        if ($env:Agent_ID -and $DebugPreference -eq 'SilentlyContinue') {
            Write-Host $out
        } else {
            $out
        }
    }
}