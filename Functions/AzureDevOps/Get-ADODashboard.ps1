function Get-ADODashboard
{
    <#
    .Synopsis
        Gets Azure DevOps Dashboards
    .Description
        Gets Azure DevOps Team Dashboards and Widgets within a dashboard.
    .Example
        Get-ADOTeam -Organization MyOrganization -PersonalAccessToken $pat |
            Get-ADODashboard
    .Link
        https://docs.microsoft.com/en-us/rest/api/azure/devops/dashboard/dashboards/list
    #>
    [CmdletBinding(DefaultParameterSetName='dashboard/dashboards')]
    [OutputType('PSDevOps.Dashboard','PSDevOps.Widget')]
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

    # The Team.
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]
    $Team,

    # The DashboardID
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,
        ParameterSetName='dashboard/dashboards/{DashboardId}')]
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,
        ParameterSetName='dashboard/dashboards/{DashboardId}/widgets')]
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,
        ParameterSetName='dashboard/dashboards/{DashboardId}/widgets/{WidgetID}')]
    [string]
    $DashboardID,

    # If set, will widgets within a dashboard.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,
        ParameterSetName='dashboard/dashboards/{DashboardId}/widgets')]
    [Alias('Widgets')]
    [switch]
    $Widget,

    # The WidgetID.  If provided, will get details about a given Azure DevOps Widget.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,
        ParameterSetName='dashboard/dashboards/{DashboardId}/widgets/{WidgetID}')]
    [string]
    $WidgetID,

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
        $c, $t, $dashboardProgressId = 0, $q.Count, $(Get-Random)

        while ($q.Count) {
            . $DQ $q # Pop one off the queue and declare all of it's variables (see /parts/DQ.ps1).


            $uri = # The URI is comprised of:
                @(
                    "$server".TrimEnd('/')   # the Server (minus any trailing slashes),
                    $Organization            # the Organization,
                    $Project
                    if ($Team) { $team }
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
            
            Write-Progress "Getting $typename" "$server $Organization $Project" -Id $dashboardProgressId -PercentComplete ($c * 100/$t)
            $c++

            
            $typeNames = @(
                "$organization.$typename"
                if ($Project) { "$organization.$Project.$typename" }
                "PSDevOps.$typename"
            )

            $additionalProperties = @{Organization=$Organization;Project=$project;Server=$Server}
            if ($Team) {
                $additionalProperties.Team=$team
            }
            if ($DashboardID) {
                $additionalProperties.DashboardID = $DashboardID
            }
            if (-not $DashboardID) {
                $invokeParams.ExpandProperty = 'DashboardEntries'
            }
            Invoke-ADORestAPI -Uri $uri @invokeParams -PSTypeName $typenames -Property $additionalProperties
        }

        $null = $null
        Write-Progress "Getting" "[$c/$t]" -Completed -Id $dashboardProgressId
    }
}

