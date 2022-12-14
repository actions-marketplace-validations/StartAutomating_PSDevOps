function Set-ADOArtifactFeed
{
    <#
    .Synopsis
        Set Azure DevOps Artifact Feed
    .Description
        Changes the settings, permissions, views, and retention policies of an Azure DevOps Artifact Feed.
    .Link
        Get-ADOArtifactFeed
    .Link
        New-ADOArtifactFeed
    .Link
        Remove-ADOArtifactFeed
    .Example
        Set-ADOArtifactFeed -Organization StartAutomating -Project PSDevOps -FeedId 'Builds' -Description 'Project Builds' -WhatIf
    .Example
        Set-ADOArtifactFeed -RetentionPolicy -Organization StartAutomating -Project PSDevOps -FeedId 'Builds' -WhatIf -DaysToKeep 10
    #>
    [CmdletBinding(DefaultParameterSetName='packaging/Feeds/{FeedId}', SupportsShouldProcess=$true)]
    [OutputType('PSDevOps.ArtifactFeed','PSDevOps.ArtfiactFeed.RetentionPolicy','PSDevOps.ArtfiactFeed.View')]
    param(
    # The Organization
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('Org')]
    [string]
    $Organization,

    # The Project
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]
    $Project,

    # The name or ID of the feed.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
    [Alias('fullyQualifiedId')]
    [string]
    $FeedID,

    # The Feed Name or View Name
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{feedId}/views/{viewId}')]
    [ValidatePattern(
        #?<> -LiteralCharacter '|?/\:&$*"[]>' -CharacterClass Whitespace -Not -Repeat -StartAnchor StringStart -EndAnchor StringEnd
        '\A[^\s\|\?\/\\\:\&\$\*\"\[\]\>]+\z'
    )]
    [string]
    $Name,


    # If set, the feed will not hide all deleted/unpublished versions
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [switch]
    $ShowDeletedPackageVersions,

    # If set, will allow package names to conflict with the names of packages upstream.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [switch]
    $AllowConflictUpstream,

    # If set, this feed will not support the generation of package badges.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [Alias('NoBadges', 'DisabledBadges')]
    [switch]
    $NoBadge,

    # If provided, will allow upstream sources from public repositories.
    # Upstream sources allow your packages to depend on packages in public repositories or private feeds.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [ValidateSet('NPM', 'NuGet','PyPi','Maven', 'PowerShellGallery')]
    [string[]]
    $PublicUpstream,

    # A property bag describing upstream sources
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [PSObject[]]
    $UpstreamSource,

    # The feed description.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{FeedId}')]
    [ValidateLength(0,255)]
    [string]
    $Description,


    # The ViewID.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{feedId}/views/{viewId}')]
    [ValidatePattern(
        #?<> -LiteralCharacter '|?/\:&$*"[]>' -CharacterClass Whitespace -Not -Repeat -StartAnchor StringStart -EndAnchor StringEnd
        '\A[^\s\|\?\/\\\:\&\$\*\"\[\]\>]+\z'
    )]
    [string]
    $ViewID,

    # The view visibility.  By default, views are visible to all members of an organization.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/feeds/{feedId}/views/{viewId}')]
    [ValidateSet('Collection', 'Organization', 'Private')]
    [string]
    $ViewVisibility = 'Organization',


    # If set, will set artifact permissions.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='packaging/Feeds/{feedID}/permissions')]
    [Alias('Permissions')]
    [PSObject[]]
    $Permission,

    # If set, will set artifact retention policies
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='packaging/Feeds/{feedID}/retentionpolicies')]
    [Alias('RetentionPolicies')]
    [switch]
    $RetentionPolicy,

    # Maximum versions to preserve per package and package type.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/Feeds/{feedID}/retentionpolicies')]
    [uint32]
    $CountLimit,

    # Number of days to preserve a package version after its latest download.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='packaging/Feeds/{feedID}/retentionpolicies')]
    [Alias('DaysToKeepRecentlyDownloadedPackages')]
    [uint32]
    $DaysToKeep,

    # The server.  By default https://feeds.dev.azure.com/.
    [Parameter(ValueFromPipelineByPropertyName)]
    [uri]
    $Server = "https://feeds.dev.azure.com/",

    # The api version.  By default, 5.1-preview.
    [string]
    $ApiVersion = "5.1-preview")
    dynamicParam { . $GetInvokeParameters -DynamicParameter }
    begin {
        #region Copy Invoke-ADORestAPI parameters
        $invokeParams = . $getInvokeParameters $PSBoundParameters
        #endregion Copy Invoke-ADORestAPI parameters
    }

    process {
        $invokeParams.Uri = # First construct the URI.  It's made up of:
            "$(@(
                "$server".TrimEnd('/') # * The Server
                $Organization # * The Organization
                $(if ($Project) { $Project }) # * The Project
                '_apis' #* '_apis'
                . $ReplaceRouteParameter $PSCmdlet.ParameterSetName #* and the replaced route parameters.
            )  -join '/')?$( # Followed by a query string, containing
            @(
                if ($Server -ne 'https://feeds.dev.azure.com/' -and
                    -not $PSBoundParameters.ApiVersion) {
                    $ApiVersion = '2.0'
                }
                if ($ApiVersion) { # an api-version (if one exists)
                    "api-version=$ApiVersion"
                }
            ) -join '&'
            )"

        if ($RetentionPolicy)
        {
            if ($daysToKeep -or $CountLimit) {
                $invokeParams.Method = 'PUT'
                $invokeParams.Body = @{}
                if ($DaysToKeep) { $invokeParams.Body.daysToKeepRecentlyDownloadedPackages = $DaysToKeep }
                if ($CountLimit) { $invokeParams.Body.countLimit = $CountLimit}
            } else {
                $invokeParams.Method  = 'DELETE'
            }
        }
        elseif ($Permission)
        {
            $invokeParams.Method = 'PATCH'
            $invokeParams.Body = $Permission
        }
        elseif ($ViewID)
        {
            $invokeParams.Method = 'PATCH'
            $invokeParams.Body = @{}
            if ($Name) {
                $invokeParams.Body.Name = $name
            }
            if ($PSBoundParameters.ViewVisibility) {
                $invokeParams.visibility = $ViewVisibility
            }
        }
        else
        {
            $invokeParams.Method = 'PATCH'
            $invokeParams.Body = @{}
            if ($Name) {
                $invokeParams.Body.Name = $name
            }
            if ($Description) {
                $invokeParams.Body.Description = $Description
            }
            if ($PSBoundParameters.ContainsKey('NoBadge')) {
                $invokeParams.Body.BadgesEnabled = -not $NoBadge
            }

            if ($PSBoundParameters.ContainsKey('ShowDeletedPackageVersions')) {
                $invokeParams.Body.hideDeletedPackageVersions = -not $ShowDeletedPackageVersions
            }

            if ($PublicUpstream) {
                $UpstreamSource = $PSBoundParameters['UpstreamSource'] = @(
                    if ($PublicUpstream -contains 'NuGet') {
                        [PSCustomObject]@{
                            id= "$([guid]::NewGuid())"
                            name = 'NuGet Gallery'
                            protocol = 'nuget'
                            location = 'https://api.nuget.org/v3/index.json'
                            displayLocation = 'https://api.nuget.org/v3/index.json'
                            upstreamSourceType = 'public'
                        }
                    }
                    if ($PublicUpstream -contains 'NPM') {
                        [PSCustomObject]@{
                            id="$([guid]::NewGuid())"
                            name = 'npmjs'
                            protocol = 'npm'
                            location = 'https://registry.npmjs.org/'
                            displayLocation = 'https://registry.npmjs.org/'
                            upstreamSourceType = 'public'
                        }
                    }
                    if ($PublicUpstream -contains 'PyPI') {
                        [PSCustomObject]@{
                            id="$([guid]::NewGuid())"
                            name = 'PyPi'
                            protocol = 'pypi'
                            location = 'https://pypi.org/'
                            displayLocation = 'https://pypi.org/'
                            upstreamSourceType = 'public'
                        }
                    }
                    if ($PublicUpstream -contains 'Maven') {
                        [PSCustomObject]@{
                            id="$([guid]::NewGuid())"
                            name = 'Maven Central'
                            protocol = 'Maven'
                            location = 'https://repo.maven.apache.org/maven2/'
                            displayLocation = 'https://repo.maven.apache.org/maven2/'
                            upstreamSourceType = 'public'
                        }
                    }
                ) + @(if ($UpstreamSource) { $UpstreamSource })
            }

            if ($PSBoundParameters.ContainsKey('UpstreamSource')) {
                $invokeParams.Body.UpstreamSources = @($UpstreamSource | Select-Object -Unique)
            }
        }

        if ($WhatIfPreference) {
            $invokeParams.Remove('PersonalAccessToken')
            return $invokeParams
        }

         $subTypeName =
            if ($ViewID) { '.View'}
            elseif ($Permission) { '.Permission'}
            elseif ($RetentionPolicy) { '.RetentionPolicy' }
            else { '' }
        $typenames = @( # Prepare a list of typenames so we can customize formatting:
            if ($Organization -and $Project) {
                "$Organization.$Project.ArtifactFeed$subTypeName" # * $Organization.$Project.ArtifactFeed (if $product exists)
            }
            "$Organization.ArtifactFeed$subTypeName" # * $Organization.ArtifactFeed
            "PSDevOps.ArtifactFeed$subTypeName" # * PSDevOps.ArtifactFeed
        )

        if ($PSCmdlet.ShouldProcess("$($invokeParams.Method) $($invokeParams.Uri) $(if ($invokeParams.Body) { $invokeParams.Body | ConvertTo-Json -Depth 100})")) {
            Invoke-ADORestAPI @invokeParams -PSTypeName $typenames
        }
    }
}
