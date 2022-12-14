function Invoke-ADORestAPI
{
    <#
    .Synopsis
        Invokes the ADO Rest API
    .Description
        Invokes the Azure DevOps REST API
    .Example
        # Uses the Azure DevOps REST api to get builds from a project
        $org = 'StartAutomating'
        $project = 'PSDevOps'
        Invoke-ADORestAPI "https://dev.azure.com/$org/$project/_apis/build/builds/?api-version=5.1"
    .Link
        Invoke-RestMethod
    #>
    [OutputType([PSObject])]
    [CmdletBinding(DefaultParameterSetName='Uri')]
    param(
    # The REST API Url
    [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Alias('Url')]
    [uri]
    $Uri,

    <#
Specifies the method used for the web request. The acceptable values for this parameter are:
 - Default
 - Delete
 - Get
 - Head
 - Merge
 - Options
 - Patch
 - Post
 - Put
 - Trace
    #>
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [ValidateSet('GET','DELETE','HEAD','MERGE','OPTIONS','PATCH','POST', 'PUT', 'TRACE')]
    [string]
    $Method = 'GET',

    # Specifies the body of the request.
    # If this value is a string, it will be passed as-is
    # Otherwise, this value will be converted into JSON.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Object]
    $Body,

    # Parameters provided as part of the URL (in segments or a query string).
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Alias('UrlParameters')]
    [Collections.IDictionary]
    $UrlParameter = @{},

    # Additional parameters provided after the URL.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Alias('QueryParameters')]
    [Collections.IDictionary]
    $QueryParameter = @{},

    # Specifies the content type of the web request.
    # If this parameter is omitted and the request method is POST, Invoke-RestMethod sets the content type to application/x-www-form-urlencoded. Otherwise, the content type is not specified in the call.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [string]
    $ContentType = 'application/json',

    # Specifies the headers of the web request. Enter a hash table or dictionary.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [System.Collections.IDictionary]
    [Alias('Header')]
    $Headers,

    # A Personal Access Token
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('PAT')]
    [string]
    $PersonalAccessToken,

    # Specifies a user account that has permission to send the request. The default is the current user.
    # Type a user name, such as User01 or Domain01\User01, or enter a PSCredential object, such as one generated by the Get-Credential cmdlet.
    [Parameter(ValueFromPipelineByPropertyName)]
    [pscredential]
    [Management.Automation.CredentialAttribute()]
    $Credential,

    # Indicates that the cmdlet uses the credentials of the current user to send the web request.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('UseDefaultCredential')]
    [switch]
    $UseDefaultCredentials,

    # A continuation token.  This is appended as a query parameter, and can be used to continue a request.
    # Invoke-ADORestAPI will call recursively invoke itself until a response does not have a ContinuationToken
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [string]
    $ContinuationToken,

    # The typename of the results.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Alias('Decorate','Decoration')]
    [string[]]
    $PSTypeName,

    # A set of additional properties to add to an object
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Collections.IDictionary]
    $Property,

    # A list of property names to remove from an object
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [string[]]
    $RemoveProperty,

    # If provided, will expand a given property returned from the REST api.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [string]
    $ExpandProperty,

    # If provided, will decorate the values within a property in the return object.
    # This allows nested REST properties to work with the PowerShell Extended Type System.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='Uri')]
    [Collections.IDictionary]
    [Alias('TypeNameOfProperty')]
    $DecorateProperty,

    # If set, will cache results from a request.  Only HTTP GET results will be cached.
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]
    $Cache,

    # If set, will return results as a byte array.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('Binary','AsByteArray')]
    [switch]
    $AsByte,

    # If set, will run as a background job.
    # This parameter will be ignored if the caller is piping the results of Invoke-ADORestAPI.
    # This parameter will also be ignore when calling with -DynamicParameter or -MapParameter.
    [Parameter(ValueFromPipelineByPropertyName)]
    [switch]
    $AsJob,

    # If set, will get the dynamic parameters that should be provided to any function that wraps Invoke-ADORestApi
    [Parameter(Mandatory,ParameterSetName='GetDynamicParameters',ValueFromPipelineByPropertyName)]
    [Alias('DynamicParameters')]
    [switch]
    $DynamicParameter,

    # If set, will return the parameters for any function that can be passed to Invoke-ADORestApi.
    # Unmapped parameters will be added as a noteproperty of the returned dictionary.
    [Parameter(Mandatory,ParameterSetName='MapParameters',ValueFromPipelineByPropertyName)]
    [Alias('MapParameters')]
    [Collections.IDictionary]
    $MapParameter
    )

     begin {
        # From [Irregular](https://github.com/StartAutomating/Irregular):
        # ?<REST_Variable> -VariableFormat Braces
        $RestVariable = [Regex]::new(@'
(?>                           # A variable can be in a URL segment or subdomain
    (?<Start>[/\.])           # Match the <Start>ing slash|dot ...
    (?<IsOptional>\?)?        # ... an optional ? (to indicate optional) ...
    (?:
        \{(?<Variable>\w+)\} # ... A <Variable> name in {} OR    
    )
|
    (?<IsOptional>            # If it's optional it can also be 
        [{\[](?<Start>/)      # a bracket or brace, followed by a slash
    )
    (?<Variable>\w+)[}\]]     # then a <Variable> name followed by } or ]

|                             # OR it can be in a query parameter:
    (?<Start>[\?\&])          # Match The <Start>ing ? or & ...
    (?<Query>[\$\w\-]+)       # ... the <Query> parameter name ... 
    =                         # ... an equals ...
    (?<IsOptional>\?)?        # ... an optional ? (to indicate optional) ...
    (?:
        \{(?<Variable>\w+)\} # ... A <Variable> name in {} OR
    )
)
'@, 'IgnoreCase,IgnorePatternWhitespace')

        $ReplaceRestVariable = {
            param($match)

            if ($urlParameter -and $urlParameter[$match.Groups["Variable"].Value]) {
                return $match.Groups["Start"].Value + $(
                        if ($match.Groups["Query"].Success) { $match.Groups["Query"].Value + '=' }
                    ) +
                    ([Web.HttpUtility]::UrlEncode(
                        $urlParameter[$match.Groups["Variable"].Value]
                    ))
            } else {
                return ''
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'GetDynamicParameters') {
            if (-not $script:InvokeADORestAPIParams) {
                $script:InvokeADORestAPIParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
                $InvokeADORestApi = $MyInvocation.MyCommand
                :nextInputParameter foreach ($in in ([Management.Automation.CommandMetaData]$InvokeADORestApi).Parameters.Keys) {
                    foreach ($ex in 'Uri','Method','Headers','Body','ContentType',
                        'ExpandProperty','Property','RemoveProperty','DecorateProperty',
                        'PSTypeName', 'ContinuationToken', 'DynamicParameter', 'MapParameter', 'UrlParameter', 'AsByte') {
                        if ($in -like $ex) { continue nextInputParameter }
                    }

                    $script:InvokeADORestAPIParams.Add($in, [Management.Automation.RuntimeDefinedParameter]::new(
                        $InvokeADORestApi.Parameters[$in].Name,
                        $InvokeADORestApi.Parameters[$in].ParameterType,
                        $InvokeADORestApi.Parameters[$in].Attributes
                    ))
                }
                foreach ($paramName in $script:InvokeADORestAPIParams.Keys) {
                    foreach ($attr in $script:InvokeADORestAPIParams[$paramName].Attributes) {
                         if ($attr.ValueFromPipeline) {$attr.ValueFromPipeline = $false}
                         if ($attr.ValueFromPipelineByPropertyName) {$attr.ValueFromPipelineByPropertyName = $false}
                    }
                }
            }
            return $script:InvokeADORestAPIParams
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'MapParameters') {
            $invokeParams = [Ordered]@{} + $MapParameter # Then we copy our parameters
            $unmapped     = [Ordered]@{}
            foreach ($k in @($invokeParams.Keys)) {  # and walk thru each parameter name.
                # If a parameter isn't found in Invoke-ADORestAPI
                if (-not $MyInvocation.MyCommand.Parameters.ContainsKey($k)) {
                    $unmapped[$k] = $invokeParams[$k]
                    $invokeParams.Remove($k) # we remove it.
                }
            }
            if ($invokeParams.Credential) { $script:CachedCredential = $invokeParams.Credential }
            if (-not $invokeParams.Credential -and $script:CachedCredential) {
                $invokeParams.Credential = $script:CachedCredential
            }
            $invokeParams.psobject.properties.add([PSNoteProperty]::new('Unmapped',$unmapped))
            return $invokeParams
        }

        #region Prepare Parameters
        $irmSplat = @{} + $PSBoundParameters    # First, copy PSBoundParameters and remove the parameters that aren't Invoke-RestMethod's
        $irmSplat.Remove('PersonalAccessToken') # * -PersonalAccessToken
        $irmSplat.Remove('PSTypeName') # * -PSTypeName
        $irmSplat.Remove('Property') # *-Property
        $irmSplat.Remove('RemoveProperty') # *-RemoveProperty
        $irmSplat.Remove('ExpandProperty') # *-ExpandProperty
        $irmSplat.Remove('DecorateProperty')
        if (-not $PersonalAccessToken -and
            -not $Credential -and
            -not $UseDefaultCredentials -and
            $script:CachedPersonalAccessToken) {
            $psBoundParameters["PersonalAccessToken"] = $PersonalAccessToken = $script:CachedPersonalAccessToken
        }
        if ($AsJob -and $MyInvocation.PipelinePosition -eq $MyInvocation.PipelineLength) {
            $paramCopy = @{} + $PSBoundParameters
            $paramCopy.Remove('AsJob')
            $jobDefinition = [ScriptBlock]::Create(@'
param([Hashtable]$parameter)
'@ + @"
function $($MyInvocation.MyCommand.Name) {
    $($MyInvocation.MyCommand.Definition)
}
$($MyInvocation.MyCommand.Name) @parameter
"@)
            Start-Job -ScriptBlock $jobDefinition -ArgumentList $paramCopy
            return
        }

        if ($PersonalAccessToken) { # If there was a personal access token, set the authorization header
            if ($Headers) { # (make sure not to step on other headers).
                $irmSplat.Headers.Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken")))"
            }
            else {

                $irmSplat.Headers = @{ # If you were wondering, the Personal Access Token is passed like an HTTP credential,
                    Authorization = # (by setting the authorization header to Basic Base64EncodedBytesOf UserName:Password).
                        # The very slight trick is that PersonalAccessToken's don't have a username
                        "Basic $([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(":$PersonalAccessToken")))"
                }
            }
            $script:CachedPersonalAccessToken = $PersonalAccessToken
        }
        if ($Body -and $Body -isnot [string]) { # If a body was passed, and it wasn't a string
            $irmSplat.Body = ConvertTo-Json -Depth 100 -InputObject $body # make it JSON.
        }
        if (-not $irmSplat.ContentType) { # If no content type was passed
            $irmSplat.ContentType = $ContentType # set it to the default.
        }
        #endregion Prepare Parameters

        if (-not $script:AzureDevOpsRequestCache) { $script:AzureDevOpsRequestCache = @{} }

        $uri = $RestVariable.Replace($uri, $ReplaceRestVariable)

        #region Call Invoke-RestMethod
        if ($ContinuationToken) {
            $QueryParameter['ContinuationToken'] = $ContinuationToken
        }

        if ($QueryParameter -and $QueryParameter.Count) {
            $uri =
                "$uri" +
                $(if (-not $uri.Query) { '?' } elseif (-not "$Uri".EndsWith('?')) { '&' }) +
                $(
                    @(foreach ($qp in $QueryParameter.GetEnumerator()) {
                        '' + $qp.Key + '=' + [Web.HttpUtility]::UrlEncode($qp.Value).Replace('+', '%20')
                    }) -join '&'
                )
        }
        if ($Cache -and $method -eq 'Get' -and $script:AzureDevOpsRequestCache[$uri]) {
            foreach ($out in $script:AzureDevOpsRequestCache[$uri]) { $out }
            return
        }
        $webRequest =  [Net.WebRequest]::Create($uri)
        $webRequest.Method = $Method
        $webRequest.contentType = $ContentType
        if ($irmSplat.Headers) {
            foreach ($h in $irmSplat.Headers.GetEnumerator()) {
                $webRequest.headers.add($h.Key, $h.Value)
            }
        }
        if ($UseDefaultCredentials) {
            $webRequest.useDefaultCredentials = $UseDefaultCredentials
        }
        elseif ($Credential) {
            $webRequest.credentials = $Credential.GetNetworkCredential()
        }

        if ($irmSplat.Body) {

            $bytes = [Text.Encoding]::UTF8.GetBytes($irmSplat.Body)
            $webRequest.contentLength = $bytes.Length
            $requestStream = $webRequest.GetRequestStream()
            $requestStream.Write($bytes, 0, $bytes.Length)
            $requestStream.Close()
        } else {
            $webRequest.contentLength = 0
        }

        if ($Property -and $Property.Count) {
            $psProperties = @(
                foreach ($propKeyValue in $Property.GetEnumerator()) {
                    if ($propKeyValue.Value -as [ScriptBlock[]]) {
                        [PSScriptProperty]::new.Invoke(@($propKeyValue.Key) + $propKeyValue.Value)
                    } else {
                        [PSNoteProperty]::new($propKeyValue.Key, $propKeyValue.Value)
                    }
                }
            )
        }

        Write-Verbose "$Method $Uri [$($webRequest.ContentLength) bytes]"

        $response = . {

            $webResponse =
                try {
                    $WebRequest.GetResponse()
                } catch {
                    $ex = $_
                    if ($ex.Exception.InnerException.Response) {
                        $streamIn = [IO.StreamReader]::new($ex.Exception.InnerException.Response.GetResponseStream())
                        $strResponse = $streamIn.ReadToEnd()
                        $streamIn.Close()
                        $streamIn.Dispose()
                        $PSCmdlet.WriteError(
                            [Management.Automation.ErrorRecord]::new(
                                [Exception]::new("$($ex.Exception.InnerException.Response.StatusCode, $ex.Exception.InnerException.Response.StatusDescription)$strResponse ", $ex.Exception.InnerException
                            ), $ex.Exception.HResult, 'NotSpecified', $webRequest)
                        )
                        return
                    } else {
                        $errorRecord = [Management.Automation.ErrorRecord]::new($ex.Exception, $ex.Exception.HResult, 'NotSpecified', $webRequest)
                        $PSCmdlet.WriteError($errorRecord)
                        return
                    }
                }
            $rs = $webresponse.GetResponseStream()
            $responseHeaders = $webresponse.Headers
            $responseHeaders =
                if ($responseHeaders -and $responseHeaders.GetEnumerator()) {
                    $reHead = @{}
                    foreach ($r in $responseHeaders.GetEnumerator()) {
                        $reHead[$r] = $responseHeaders[$r]
                    }
                    $reHead
                } else {
                    @{}
                }
            if ($AsByte) {
                $ms = [IO.MemoryStream]::new()
                $rs.CopyTo($ms)
                ,$ms.ToArray()
                $ms.Dispose()
                return
            }
            $streamIn = [IO.StreamReader]::new($rs, $webResponse.Contentencoding)
            $strResponse = $streamIn.ReadToEnd()
            if ($webResponse.ContentType -like '*json*') {
                try {
                    $strResponse | ConvertFrom-Json
                } catch {
                    $strResponse
                }
            } else {
                $strResponse
            }

            $streamIn.Close()

        } 2>&1
        $null = $null
        # We call Invoke-RestMethod with the parameters we've passed in.
        # It will take care of converting the results from JSON.
        if ($response -is [byte[]]) {
            return $response
        }

        $apiOutput =
            $response |
            & { process {
                $in = $_

                # What it will not do is "unroll" them.
                # A lot of things in the Azure DevOps REST apis come back as a count/value pair
                if ($in -eq 'null') {
                    return
                }                
                if ($ExpandProperty) {
                    if ($in.$ExpandProperty) {
                        return $in.$ExpandProperty
                    }
                } elseif ($in.Value -and $in.Count) {  # If that's what we're dealing with
                    $in.Value # pass value down the pipe.
                } elseif ($in -notlike '*<html*') { # Otherise, As long as the value doesn't look like HTML,
                    $in # pass it down the pipe.
                } else { # If it happened to look like HTML, write an error
                    $PSCmdlet.WriteError(
                        [Management.Automation.ErrorRecord]::new(
                            [Exception]::new("Response was HTML, Request Failed."),
                            "ResultWasHTML", "NotSpecified", $in))
                    $psCmdlet.WriteVerbose("$in") # and write the full content to verbose.
                    return
                }
            } } 2>&1 |
            & { process { # One more step of the pipeline will unroll each of the values.


                $in = $_
                if ($in -is [string]) { return $in }                
                if ($null -ne $in.Count -and $in.Count -eq 0) {
                    return
                }

                if ($PSTypeName -and # If we have a PSTypeName (to apply formatting)
                    $in -isnot [Management.Automation.ErrorRecord] # and it is not an error (which we do not want to format)
                ) {
                    $in.PSTypeNames.Clear() # then clear the existing typenames and decorate the object.
                    foreach ($t in $PSTypeName) {
                        $in.PSTypeNames.add($T)
                    }
                }

                if ($Property -and $Property.Count) {
                    foreach ($prop in $psProperties) {
                        $in.PSObject.Members.Add($prop, $true)
                    }
                }
                if ($RemoveProperty) {
                    foreach ($propToRemove in $RemoveProperty) {
                        $in.PSObject.Properties.Remove($propToRemove)
                    }
                }
                if ($DecorateProperty) {
                    foreach ($kv in $DecorateProperty.GetEnumerator()) {
                        if ($in.$($kv.Key)) {
                            foreach ($v in $in.$($kv.Key)) {
                                if ($null -eq $v -or -not $v.pstypenames) { continue }
                                $v.pstypenames.clear()
                                foreach ($tn in $kv.Value) {
                                    $v.pstypenames.add($tn)
                                }
                            }
                        }
                    }
                }
                return $in # output the object and we're done.
            } }
        #endregion Call Invoke-RestMethod

        # If we have a continuation token
        $paramCopy = @{} + $PSBoundParameters
        $invokeResults = [Collections.ArrayList]::new()
        & {
            if ($responseHeaders -and $responseHeaders['X-MS-ContinuationToken'] -and $Uri -notmatch '\$(top|first)=') {
                if ($Uri.Query -notmatch '\$(top|first)=') { # and the uri is not have top or first parameter
                    $apiOutput # output

                    # Then recursively call yourself with the ContinuationToken
                    $paramCopy['ContinuationToken'] = $responseHeaders.'X-MS-ContinuationToken'
                    Invoke-ADORestAPI @paramCopy
                } else {
                    # Otherwise, output, but add on the ContinuationToken as a property.
                    $apiOutput |
                        Add-Member NoteProperty ContinuationToken $responseHeaders.'X-MS-ContinuationToken' -Force -PassThru
                }
            } else { # If we didn't have a continuation token, just output
                $apiOutput
            }
        } | & { process {
            $in = $_
            if ($in) {
                $null = $invokeResults.Add($in)
                $in

            }
        } }

        if ($Method -eq 'Get') {
            if ($Cache -and -not $ContinuationToken) {
                $script:AzureDevOpsRequestCache[$uri] = $invokeResults.ToArray()
            }
        } else {
            $null =
                New-Event -SourceIdentifier "Invoke-ADORestApi.$Method" -MessageData $(
                    $paramCopy.Remove('PersonalAccessToken')
                    $paramCopy+=@{Response = $response;Results  = $invokeResults.ToArray() }
                    [PSCustomObject]$paramCopy
                )
        }
    }
}