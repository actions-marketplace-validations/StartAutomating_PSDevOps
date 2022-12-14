function Get-ADOWiki
{
    <#
    .Synopsis
        Gets Azure DevOps Wikis
    .Description
        Gets Azure DevOps Wikis related to a project.
    .Example
        Get-ADOWiki -Organization MyOrganization -Project MyProject -PersonalAccessToken $pat
    .Link
        https://docs.microsoft.com/en-us/rest/api/azure/devops/wiki/wikis/list
    #>
    [CmdletBinding(DefaultParameterSetName='wiki/wikis')]
    [OutputType('PSDevOps.Wiki')]
    param(
    # The Organization.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('Org')]
    [string]
    $Organization,

    # The Project.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [string]
    $Project,

    # The Wiki Identifier.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,
        ParameterSetName='wiki/wikis/{WikiID}')]
    [string]
    $WikiID,

    # The server.  By default https://dev.azure.com/.
    # To use against TFS, provide the tfs server URL (e.g. http://tfsserver:8080/tfs).
    [Parameter(ValueFromPipelineByPropertyName)]
    [uri]
    $Server = "https://dev.azure.com/",

    # The api version.  By default, 5.1-preview.
    # If targeting TFS, this will need to change to match your server version.
    # See: https://docs.microsoft.com/en-us/azure/devops/integrate/concepts/rest-api-versioning?view=azure-devops
    [string]
    $ApiVersion = "5.1-preview")
    dynamicParam { . $GetInvokeParameters -DynamicParameter }
    begin {
        #region Copy Invoke-ADORestAPI parameters
        $invokeParams = . $getInvokeParameters $PSBoundParameters
        #endregion Copy Invoke-ADORestAPI parameters
        $q = [Collections.Queue]::new()
    }

    process {
        $ParameterSet = $psCmdlet.ParameterSetName
        $q.Enqueue(@{ParameterSet=$ParameterSet} + $PSBoundParameters)
    }
    end {
        $c, $t, $progId = 0, $q.Count, [Random]::new().Next()

        while ($q.Count) {
            . $DQ $q # Pop one off the queue and declare all of it's variables (see /parts/DQ.ps1).

            $c++
            Write-Progress "Getting $(@($ParameterSet -split '/')[-1])" "$server $Organization $Project" -Id $progId -PercentComplete ($c * 100/$t)

            $uri = # The URI is comprised of:
                @(
                    "$server".TrimEnd('/')   # the Server (minus any trailing slashes),
                    $Organization            # the Organization,
                    $Project
                    '_apis'                  # the API Root ('_apis'),
                    (. $ReplaceRouteParameter $ParameterSet)
                                             # and any parameterized URLs in this parameter set.
                ) -as [string[]] -ne ''  -join '/'

            $uri += '?' # The URI has a query string containing:
            $uri += @(
                if ($Server -ne 'https://dev.azure.com/' -and
                    -not $PSBoundParameters.ApiVersion) {
                    $ApiVersion = '2.0'
                }
                if ($ApiVersion) { # the api-version
                    "api-version=$apiVersion"
                }
            ) -join '&'

            # We want to decorate our return value.  Handily enough, both URIs contain a distinct name in the last URL segment.
            $typename = @($parameterSet -split '/' -notlike '{*}')[-1].TrimEnd('s') # We just need to drop the 's'
            $typeNames = @(
                "$organization.$typename"
                if ($Project) { "$organization.$Project.$typename" }
                "PSDevOps.$typename"
            )

            $additionalProperties = @{Organization=$Organization;Project=$project;Server=$Server}
            Invoke-ADORestAPI -Uri $uri @invokeParams -PSTypeName $typenames -Property $additionalProperties
        }

        Write-Progress "Getting $($ParameterSet)" "$server $Organization $Project" -Id $progId -Completed
    }
}