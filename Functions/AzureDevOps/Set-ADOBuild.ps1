function Set-ADOBuild
{
    <#
    .Synopsis
        Sets ADO Build information
    .Description
        Sets the Azure DevOps Build information
    .Example
        Set-ADOBuild -Log .\MyLog.log
    .Example
        Set-ADOBuild -BuildNumber 21
    .Example
        Set-ADOBuild -Tag TestPassed, CodeCoveragePassed
    .Example
        Set-ADOBuild -ReleaseName NewRelease
    .Link
        https://docs.microsoft.com/en-us/azure/devops/pipelines/scripts/logging-commands
    #>
    [CmdletBinding(PositionalBinding=$false)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification="Directly outputs in certain scenarios")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Justification="Confirmation would be impossible within host")]
    [OutputType([string])]
    param(
    # A new build number (or identifier)
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('BN')]
    [string]
    $BuildNumber,

    # One or more tags for this build
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('T')]
    [string[]]
    $Tag,

    # The name of the release
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Name','RN')]
    [string]
    $ReleaseName,

    # Adds a location to the environment path
    [Alias('PP','EP', 'PrependPath')]
    [string]
    $EnvironmentPath
    )

    process {
        #region Prepare Output
        $out = @(
            if ($BuildNumber) {
                "##vso[build.updatebuildnumber]$BuildNumber"
            }

            if ($tag) {
                foreach ($t in $tag) {
                    "##vso[build.addbuildtag]$t"
                }
            }

            if ($ReleaseName) {
                "##vso[build.updatereleasename]$ReleaseName"
            }

            if ($EnvironmentPath) {
                "##vso[task.prependpath]$EnvironmentPath"
            }
        )
        #endregion Prepare Output

        if ($env:Agent_ID -and $DebugPreference -eq 'SilentlyContinue') {
            $out | Out-Host
        } else {
            $out -join [Environment]::NewLine
        }
    }
}