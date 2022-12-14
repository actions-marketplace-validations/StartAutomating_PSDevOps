function New-ADOProject
{
    <#
    .Synopsis
        Creates new projects in Azure DevOps.
    .Description
        Creates new projects in Azure DevOps or TFS.
    .Link
        https://docs.microsoft.com/en-us/rest/api/azure/devops/core/projects/list?view=azure-devops-rest-5.1
    .Example
        New-ADOProject -Organization StartAutomating -Project Formulaic -PersonalAccessToken $pat
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType('PSDevOps.Project')]
    param(
    # The name of the project.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [string]
    $Name,

    # The project description.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [string]
    $Description,

    # The process template used by the project.  By default, 'Agile'
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('ProcessTemplate')]
    [string]
    $Process = 'Agile',

    # If set, the project will be created as a public project.
    # If not set, the project will be created as a private project.
    [switch]
    $Public,

    # The project abbreviation
    [string]
    $Abbreviation,

    # The Organization
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('Org')]
    [string]
    $Organization,


    # The server.  By default https://dev.azure.com/.
    # To use against TFS, provide the tfs server URL (e.g. http://tfsserver:8080/tfs).
    [Parameter(ValueFromPipelineByPropertyName)]
    [uri]
    $Server = "https://dev.azure.com/",

    # The api version.  By default, 5.1.
    # If targeting TFS, this will need to change to match your server version.
    # See: https://docs.microsoft.com/en-us/azure/devops/integrate/concepts/rest-api-versioning?view=azure-devops
    [string]
    $ApiVersion = "5.1-preview")

    dynamicParam { . $GetInvokeParameters -DynamicParameter }

    begin {
        #region Copy Invoke-ADORestAPI parameters
        $invokeParams = . $getInvokeParameters $PSBoundParameters
        #endregion Copy Invoke-ADORestAPI parameters
    }
    process {

        if (-not ($Process -as [guid])) {
            #region Get Work Processes
            # Because the process was not a GUID, we have to call Get-ADOWorkProcess.
            $getAdoWorkProcess = # To do this, first we get the commandmetadata for Invoke-ADORestAPI.
                [Management.Automation.CommandMetaData]$ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-ADOWorkProcess', 'Function')

            $getWorkProcessParams = @{} + $PSBoundParameters # Then we copy our parameters
            foreach ($k in @($getWorkProcessParams.Keys)) {  # and walk thru each parameter name.
                # If a parameter isn't found in Invoke-ADORestAPI
                if (-not $getAdoWorkProcess.Parameters.ContainsKey($k)) {
                    $getWorkProcessParams.Remove($k) # we remove it.
                }
            }

            $processExists = Get-ADOWorkProcess @getWorkProcessParams | Where-Object { $_.Name -eq $Process }
            if (-not $processExists) {
                Write-Error "No Work Process named $process exists in $Organization"
                return
            }
            $process = $processExists.typeID
            #region Get Work Processes
        }

        $uri = "$Server".TrimEnd('/'), $Organization, '_apis/projects?' -join '/'
        if ($Server -ne 'https://dev.azure.com/' -and
            -not $PSBoundParameters.ApiVersion) {
            $ApiVersion = '2.0'
        }
        if ($ApiVersion) {
            $uri += "api-version=$ApiVersion"
        }

        $body = @{
            name = $Name
            description = $Description
            capabilities = @{
                processTemplate = @{
                    templateTypeId = $process
                }
                versioncontrol = @{
                    sourceControlType = 'git'
                }
            }
            visibility = if ($Public) { 'public' } else { 'private' }
        } | ConvertTo-Json


        $invokeParams.Method   = 'POST'
        $invokeParams.Body     = $body
        $invokeParams.uri      = $uri
        $invokeParams.Property = @{
            Organization =$Organization
            Server = $Server
        }
        $invokeParams.PSTypeName = "$organization.Project", 'PSDevOps.Project'
        if ($WhatIfPreference) {
            $invokeParams.Remove('PersonalAccessToken')
            return $invokeParams
        }
        if (-not $PSCmdlet.ShouldProcess("POST $uri $body")) { return }
        Invoke-ADORestAPI @invokeParams
    }
}