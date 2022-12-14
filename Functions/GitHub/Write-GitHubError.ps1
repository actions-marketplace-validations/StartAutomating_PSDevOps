function Write-GitHubError
{
    <#
    .Synopsis
        Writes a Git Error
    .Description
        Writes a GitHub Workflow Error
    .Example
        Write-GitHubError "Stuff hit the fan"
    .Link
        Write-GitHubWarning
    .Link
        https://docs.github.com/en/actions/reference/workflow-commands-for-GitHubhub-actions
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
    [Alias('Source','SourcePath','FullName')]
    [string]
    $File,

    # An optional line number.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('LineNumber')]
    [uint32]
    $Line,

    # An optional column number.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Column','ColumnNumber')]
    [uint32]
    $Col
    )

    begin {
        $cmdMd = [Management.Automation.CommandMetaData]$MyInvocation.MyCommand
    }

    process {
        #region Collect Additional Properties
        $properties = # Collect the optional properties
            @(foreach ($kv in $PSBoundParameters.GetEnumerator()) {
                if ('Message' -contains $kv.Key) { continue } # (anything but Message).
                if (-not $cmdMd.Parameters.ContainsKey($kv.Key)) { continue }
                "$($kv.Key.ToLower())=$($kv.Value)"
            }) -join ','
        #endregion Collect Additional Properties
        # Then output the error with it's message.
        $out = "::error$(if ($properties){" $properties"})::$Message"
        if ($env:GITHUB_WORKFLOW -and $DebugPreference -eq 'SilentlyContinue') {
            Write-Host $out
        } else {
            $out
        }
    }
}
