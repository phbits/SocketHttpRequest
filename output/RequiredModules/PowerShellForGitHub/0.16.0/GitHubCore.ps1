# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    defaultAcceptHeader = 'application/vnd.github.v3+json'
    mediaTypeVersion = 'v3'
    baptisteAcceptHeader = 'application/vnd.github.baptiste-preview+json'
    dorianAcceptHeader = 'application/vnd.github.dorian-preview+json'
    hagarAcceptHeader = 'application/vnd.github.hagar-preview+json'
    hellcatAcceptHeader = 'application/vnd.github.hellcat-preview+json'
    inertiaAcceptHeader = 'application/vnd.github.inertia-preview+json'
    londonAcceptHeader = 'application/vnd.github.london-preview+json'
    lukeCageAcceptHeader = 'application/vnd.github.luke-cage-preview+json'
    machineManAcceptHeader = 'application/vnd.github.machine-man-preview'
    mercyAcceptHeader = 'application/vnd.github.mercy-preview+json'
    mockingbirdAcceptHeader = 'application/vnd.github.mockingbird-preview'
    nebulaAcceptHeader = 'application/vnd.github.nebula-preview+json'
    repositoryAcceptHeader = 'application/vnd.github.v3.repository+json'
    sailorVAcceptHeader = 'application/vnd.github.sailor-v-preview+json'
    scarletWitchAcceptHeader = 'application/vnd.github.scarlet-witch-preview+json'
    squirrelGirlAcceptHeader = 'application/vnd.github.squirrel-girl-preview'
    starfoxAcceptHeader = 'application/vnd.github.starfox-preview+json'
    symmetraAcceptHeader = 'application/vnd.github.symmetra-preview+json'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

Set-Variable -Scope Script -Option ReadOnly -Name ValidBodyContainingRequestMethods -Value ('Post', 'Patch', 'Put', 'Delete')

function Invoke-GHRestMethod
{
<#
    .SYNOPSIS
        A wrapper around Invoke-WebRequest that understands the GitHub API.

    .DESCRIPTION
        A very heavy wrapper around Invoke-WebRequest that understands the GitHub API and
        how to perform its operation with and without console status updates.  It also
        understands how to parse and handle errors from the REST calls.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER UriFragment
        The unique, tail-end, of the REST URI that indicates what GitHub REST action will
        be performed.  This should not start with a leading "/".

    .PARAMETER Method
        The type of REST method being performed.  This only supports a reduced set of the
        possible REST methods (delete, get, post, put).

    .PARAMETER Description
        A friendly description of the operation being performed for logging and console
        display purposes.

    .PARAMETER Body
        This optional parameter forms the body of a PUT or POST request. It will be automatically
        encoded to UTF8 and sent as Content Type: "application/json; charset=UTF-8"

    .PARAMETER AcceptHeader
        Specify the media type in the Accept header.  Different types of commands may require
        different media types.

    .PARAMETER InFile
        Gets the content of the web request from the specified file.  Only valid for POST requests.

    .PARAMETER ContentType
        Specifies the value for the MIME Content-Type header of the request.  This will usually
        be configured correctly automatically.  You should only specify this under advanced
        situations (like if the extension of InFile is of a type unknown to this module).

    .PARAMETER ExtendedResult
        If specified, the result will be a PSObject that contains the normal result, along with
        the response code and other relevant header detail content.

    .PARAMETER Save
        If specified, this will save the result to a temporary file and return the FileInfo of that
        temporary file.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER TelemetryEventName
        If provided, the successful execution of this REST command will be logged to telemetry
        using this event name.

    .PARAMETER TelemetryProperties
        If provided, the successful execution of this REST command will be logged to telemetry
        with these additional properties.  This will be silently ignored if TelemetryEventName
        is not provided as well.

    .PARAMETER TelemetryExceptionBucket
        If provided, any exception that occurs will be logged to telemetry using this bucket.
        It's possible that users will wish to log exceptions but not success (by providing
        TelemetryEventName) if this is being executed as part of a larger scenario.  If this
        isn't provided, but TelemetryEventName *is* provided, then TelemetryEventName will be
        used as the exception bucket value in the event of an exception.  If neither is specified,
        no bucket value will be used.

    .OUTPUTS
        [PSCustomObject] - The result of the REST operation, in whatever form it comes in.
        [FileInfo] - The temporary file created for the downloaded file if -Save was specified.

    .EXAMPLE
        Invoke-GHRestMethod -UriFragment "users/octocat" -Method Get -Description "Get information on the octocat user"

        Gets the user information for Octocat.

    .EXAMPLE
        Invoke-GHRestMethod -UriFragment "user" -Method Get -Description "Get current user"

        Gets information about the current authenticated user.

    .NOTES
        This wraps Invoke-WebRequest as opposed to Invoke-RestMethod because we want access
        to the headers that are returned in the response, and Invoke-RestMethod drops those headers.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $UriFragment,

        [Parameter(Mandatory)]
        [ValidateSet('Delete', 'Get', 'Post', 'Patch', 'Put')]
        [string] $Method,

        [string] $Description,

        [string] $Body = $null,

        [string] $AcceptHeader = $script:defaultAcceptHeader,

        [ValidateNotNullOrEmpty()]
        [string] $InFile,

        [string] $ContentType = $script:defaultJsonBodyContentType,

        [switch] $ExtendedResult,

        [switch] $Save,

        [string] $AccessToken,

        [string] $TelemetryEventName = $null,

        [hashtable] $TelemetryProperties = @{},

        [string] $TelemetryExceptionBucket = $null
    )

    Invoke-UpdateCheck

    # Minor error checking around $InFile
    if ($PSBoundParameters.ContainsKey('InFile') -and ($Method -ne 'Post'))
    {
        $message = '-InFile may only be specified with Post requests.'
        Write-Log -Message $message -Level Error
        throw $message
    }

    if ($PSBoundParameters.ContainsKey('InFile') -and (-not [String]::IsNullOrWhiteSpace($Body)))
    {
        $message = 'Cannot specify BOTH InFile and Body'
        Write-Log -Message $message -Level Error
        throw $message
    }

    if ($PSBoundParameters.ContainsKey('InFile'))
    {
        $InFile = Resolve-UnverifiedPath -Path $InFile
        if (-not (Test-Path -Path $InFile -PathType Leaf))
        {
            $message = "Specified file [$InFile] does not exist or is inaccessible."
            Write-Log -Message $message -Level Error
            throw $message
        }
    }

    # Normalize our Uri fragment.  It might be coming from a method implemented here, or it might
    # be coming from the Location header in a previous response.  Either way, we don't want there
    # to be a leading "/" or trailing '/'
    if ($UriFragment.StartsWith('/')) { $UriFragment = $UriFragment.Substring(1) }
    if ($UriFragment.EndsWith('/')) { $UriFragment = $UriFragment.Substring(0, $UriFragment.Length - 1) }

    if ([String]::IsNullOrEmpty($Description))
    {
        $Description = "Executing: $UriFragment"
    }

    # Telemetry-related
    $stopwatch = New-Object -TypeName System.Diagnostics.Stopwatch
    $localTelemetryProperties = @{}
    $TelemetryProperties.Keys | ForEach-Object { $localTelemetryProperties[$_] = $TelemetryProperties[$_] }
    $errorBucket = $TelemetryExceptionBucket
    if ([String]::IsNullOrEmpty($errorBucket))
    {
        $errorBucket = $TelemetryEventName
    }

    # Handling retries for 202
    $numRetriesAttempted = 0
    $maxiumRetriesPermitted = Get-GitHubConfiguration -Name 'MaximumRetriesWhenResultNotReady'

    # Since we have retry logic, we won't create a new stopwatch every time,
    # we'll just always continue the existing one...
    $stopwatch.Start()

    $hostName = $(Get-GitHubConfiguration -Name "ApiHostName")

    if ($hostName -eq 'github.com')
    {
        $url = "https://api.$hostName/$UriFragment"
    }
    else
    {
        $url = "https://$hostName/api/v3/$UriFragment"
    }

    # It's possible that we are directly calling the "nextLink" from a previous command which
    # provides the full URI.  If that's the case, we'll just use exactly what was provided to us.
    if ($UriFragment.StartsWith('http'))
    {
        $url = $UriFragment
    }

    $headers = @{
        'Accept' = $AcceptHeader
        'User-Agent' = 'PowerShellForGitHub'
    }

    $AccessToken = Get-AccessToken -AccessToken $AccessToken
    if (-not [String]::IsNullOrEmpty($AccessToken))
    {
        $headers['Authorization'] = "token $AccessToken"
    }

    if ($Method -in $ValidBodyContainingRequestMethods)
    {
        if ($PSBoundParameters.ContainsKey('InFile') -and [String]::IsNullOrWhiteSpace($ContentType))
        {
            $file = Get-Item -Path $InFile
            $localTelemetryProperties['FileExtension'] = $file.Extension

            if ($script:extensionToContentType.ContainsKey($file.Extension))
            {
                $ContentType = $script:extensionToContentType[$file.Extension]
            }
            else
            {
                $localTelemetryProperties['UnknownExtension'] = $file.Extension
                $ContentType = $script:defaultInFileContentType
            }
        }

        $headers.Add("Content-Type", $ContentType)
    }

    $originalSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol

    # When $Save is in use, we need to remember what file we're saving the result to.
    $outFile = [String]::Empty
    if ($Save)
    {
        $outFile = New-TemporaryFile
    }

    try
    {
        while ($true) # infinite loop for handling the 202 retry, but we'll either exit via a return, or throw an exception if retry limit exceeded.
        {
            Write-Log -Message $Description -Level Verbose
            Write-Log -Message "Accessing [$Method] $url [Timeout = $(Get-GitHubConfiguration -Name WebRequestTimeoutSec))]" -Level Verbose

            $result = $null
            $params = @{}
            $params.Add("Uri", $url)
            $params.Add("Method", $Method)
            $params.Add("Headers", $headers)
            $params.Add("UseDefaultCredentials", $true)
            $params.Add("UseBasicParsing", $true)
            $params.Add("TimeoutSec", (Get-GitHubConfiguration -Name WebRequestTimeoutSec))
            if ($PSBoundParameters.ContainsKey('InFile')) { $params.Add('InFile', $InFile) }
            if (-not [String]::IsNullOrWhiteSpace($outFile)) { $params.Add('OutFile', $outFile) }

            if (($Method -in $ValidBodyContainingRequestMethods) -and (-not [String]::IsNullOrEmpty($Body)))
            {
                $bodyAsBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
                $params.Add("Body", $bodyAsBytes)
                Write-Log -Message "Request includes a body." -Level Verbose
                if (Get-GitHubConfiguration -Name LogRequestBody)
                {
                    Write-Log -Message $Body -Level Verbose
                }
            }

            # Disable Progress Bar in function scope during Invoke-WebRequest
            $ProgressPreference = 'SilentlyContinue'

            [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12

            $result = Invoke-WebRequest @params

            if ($Method -eq 'Delete')
            {
                Write-Log -Message "Successfully removed." -Level Verbose
            }

            # Record the telemetry for this event.
            $stopwatch.Stop()
            if (-not [String]::IsNullOrEmpty($TelemetryEventName))
            {
                $telemetryMetrics = @{ 'Duration' = $stopwatch.Elapsed.TotalSeconds }
                Set-TelemetryEvent -EventName $TelemetryEventName -Properties $localTelemetryProperties -Metrics $telemetryMetrics
            }

            $finalResult = $result.Content
            try
            {
                if ($Save)
                {
                    $finalResult = Get-Item -Path $outFile
                }
                else
                {
                    $finalResult = $finalResult | ConvertFrom-Json
                }
            }
            catch [InvalidOperationException]
            {
                # In some cases, the returned data might have two different keys of the same characters
                # but different casing (this can happen with gists with two files named 'a.txt' and 'A.txt').
                # PowerShell 6 introduced the -AsHashtable switch to work around this issue, but this
                # module wants to be compatible down to PowerShell 4, so we're unable to use that feature.
                Write-Log -Message 'The returned object likely contains keys that differ only in casing.  Unable to convert to an object.  Returning the raw JSON as a fallback.' -Level Warning
                $finalResult = $finalResult
            }
            catch [ArgumentException]
            {
                # The content must not be JSON (which is a legitimate situation).
                # We'll return the raw content result instead.
                # We do this unnecessary assignment to avoid PSScriptAnalyzer's PSAvoidUsingEmptyCatchBlock.
                $finalResult = $finalResult
            }

            if ((-not $Save) -and (-not (Get-GitHubConfiguration -Name DisableSmarterObjects)))
            {
                # In the case of getting raw content from the repo, we'll end up with a large object/byte
                # array which isn't convertible to a smarter object, but by _trying_ we'll end up wasting
                # a lot of time.  Let's optimize here by not bothering to send in something that we
                # know is definitely not convertible ([int32] on PS5, [long] on PS7).
                if (($finalResult -isnot [Object[]]) -or
                    (($finalResult.Count -gt 0) -and
                    ($finalResult[0] -isnot [int]) -and
                    ($finalResult[0] -isnot [long])))
                {
                    $finalResult = ConvertTo-SmarterObject -InputObject $finalResult
                }
            }

            if ($result.Headers.Count -gt 0)
            {
                $links = $result.Headers['Link'] -split ','
                $nextLink = $null
                $nextPageNumber = 1
                $numPages = 1
                $since = 0
                foreach ($link in $links)
                {
                    if ($link -match '<(.*page=(\d+)[^\d]*)>; rel="next"')
                    {
                        $nextLink = $Matches[1]
                        $nextPageNumber = [int]$Matches[2]
                    }
                    elseif ($link -match '<(.*since=(\d+)[^\d]*)>; rel="next"')
                    {
                        # Special case scenario for the users endpoint.
                        $nextLink = $Matches[1]
                        $since = [int]$Matches[2]
                        $numPages = 0 # Signifies an unknown number of pages.
                    }
                    elseif ($link -match '<.*page=(\d+)[^\d]+rel="last"')
                    {
                        $numPages = [int]$Matches[1]
                    }
                }
            }

            $resultNotReadyStatusCode = 202
            if ($result.StatusCode -eq $resultNotReadyStatusCode)
            {
                $retryDelaySeconds = Get-GitHubConfiguration -Name RetryDelaySeconds

                if ($Method -ne 'Get')
                {
                    # We only want to do our retry logic for GET requests...
                    # We don't want to repeat PUT/PATCH/POST/DELETE.
                    Write-Log -Message "The server has indicated that the result is not yet ready (received status code of [$($result.StatusCode)])." -Level Warning
                }
                elseif ($retryDelaySeconds -le 0)
                {
                    Write-Log -Message "The server has indicated that the result is not yet ready (received status code of [$($result.StatusCode)]), however the module is currently configured to not retry in this scenario (RetryDelaySeconds is set to 0).  Please try this command again later." -Level Warning
                }
                elseif ($numRetriesAttempted -lt $maxiumRetriesPermitted)
                {
                    $numRetriesAttempted++
                    $localTelemetryProperties['RetryAttempt'] = $numRetriesAttempted
                    Write-Log -Message "The server has indicated that the result is not yet ready (received status code of [$($result.StatusCode)]).  Will retry in [$retryDelaySeconds] seconds. $($maxiumRetriesPermitted - $numRetriesAttempted) retries remaining." -Level Warning
                    Start-Sleep -Seconds ($retryDelaySeconds)
                    continue # loop back and try this again
                }
                else
                {
                    $message = "Request still not ready after $numRetriesAttempted retries.  Retry limit has been reached as per configuration value 'MaximumRetriesWhenResultNotReady'"
                    Write-Log -Message $message -Level Error
                    throw $message
                }
            }

            # Allow for a delay after a command that may result in a state change in order to
            # increase the reliability of the UT's which attempt multiple successive state change
            # on the same object.
            $stateChangeDelaySeconds = $(Get-GitHubConfiguration -Name 'StateChangeDelaySeconds')
            $stateChangeMethods = @('Delete', 'Post', 'Patch', 'Put')
            if (($stateChangeDelaySeconds -gt 0) -and ($Method -in $stateChangeMethods))
            {
                Start-Sleep -Seconds $stateChangeDelaySeconds
            }

            if ($ExtendedResult)
            {
                $finalResultEx = @{
                    'result' = $finalResult
                    'statusCode' = $result.StatusCode
                    'requestId' = $result.Headers['X-GitHub-Request-Id']
                    'nextLink' = $nextLink
                    'nextPageNumber' = $nextPageNumber
                    'numPages' = $numPages
                    'since' = $since
                    'link' = $result.Headers['Link']
                    'lastModified' = $result.Headers['Last-Modified']
                    'ifNoneMatch' = $result.Headers['If-None-Match']
                    'ifModifiedSince' = $result.Headers['If-Modified-Since']
                    'eTag' = $result.Headers['ETag']
                    'rateLimit' = $result.Headers['X-RateLimit-Limit']
                    'rateLimitRemaining' = $result.Headers['X-RateLimit-Remaining']
                    'rateLimitReset' = $result.Headers['X-RateLimit-Reset']
                }

                return ([PSCustomObject] $finalResultEx)
            }
            else
            {
                return $finalResult
            }
        }
    }
    catch
    {
        $ex = $null
        $message = $null
        $statusCode = $null
        $statusDescription = $null
        $requestId = $null
        $innerMessage = $null
        $rawContent = $null

        if ($_.Exception -is [System.Net.WebException])
        {
            $ex = $_.Exception
            $message = $_.Exception.Message
            $statusCode = $ex.Response.StatusCode.value__ # Note that value__ is not a typo.
            $statusDescription = $ex.Response.StatusDescription
            $innerMessage = $_.ErrorDetails.Message
            try
            {
                $rawContent = Get-HttpWebResponseContent -WebResponse $ex.Response
            }
            catch
            {
                Write-Log -Message "Unable to retrieve the raw HTTP Web Response:" -Exception $_ -Level Warning
            }

            if ($ex.Response.Headers.Count -gt 0)
            {
                $requestId = $ex.Response.Headers['X-GitHub-Request-Id']
            }
        }
        else
        {
            Write-Log -Exception $_ -Level Error
            Set-TelemetryException -Exception $_.Exception -ErrorBucket $errorBucket -Properties $localTelemetryProperties
            throw
        }

        $output = @()
        $output += $message

        if (-not [string]::IsNullOrEmpty($statusCode))
        {
            $output += "$statusCode | $($statusDescription.Trim())"
        }

        if (-not [string]::IsNullOrEmpty($innerMessage))
        {
            try
            {
                $innerMessageJson = ($innerMessage | ConvertFrom-Json)
                if ($innerMessageJson -is [String])
                {
                    $output += $innerMessageJson.Trim()
                }
                elseif (-not [String]::IsNullOrWhiteSpace($innerMessageJson.message))
                {
                    $output += "$($innerMessageJson.message.Trim()) | $($innerMessageJson.documentation_url.Trim())"
                    if ($innerMessageJson.details)
                    {
                        $output += "$($innerMessageJson.details | Format-Table | Out-String)"
                    }
                }
                else
                {
                    # In this case, it's probably not a normal message from the API
                    $output += ($innerMessageJson | Out-String)
                }
            }
            catch [System.ArgumentException]
            {
                # Will be thrown if $innerMessage isn't JSON content
                $output += $innerMessage.Trim()
            }
        }

        # It's possible that the API returned JSON content in its error response.
        if (-not [String]::IsNullOrWhiteSpace($rawContent))
        {
            $output += $rawContent
        }

        if ($statusCode -eq 404)
        {
            $explanation = @('This typically happens when the current user isn''t properly authenticated.',
              'You may need an Access Token with additional scopes checked.')
            $output += ($explanation -join ' ')
        }

        if (-not [String]::IsNullOrEmpty($requestId))
        {
            $localTelemetryProperties['RequestId'] = $requestId
            $message = 'RequestId: ' + $requestId
            $output += $message
            Write-Log -Message $message -Level Verbose
        }

        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        Set-TelemetryException -Exception $ex -ErrorBucket $errorBucket -Properties $localTelemetryProperties
        throw $newLineOutput
    }
    finally
    {
        [Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
    }
}

function Invoke-GHRestMethodMultipleResult
{
<#
    .SYNOPSIS
        A special-case wrapper around Invoke-GHRestMethod that understands GET URI's
        which support the 'top' and 'max' parameters.

    .DESCRIPTION
        A special-case wrapper around Invoke-GHRestMethod that understands GET URI's
        which support the 'top' and 'max' parameters.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER UriFragment
        The unique, tail-end, of the REST URI that indicates what GitHub REST action will
        be performed.  This should *not* include the 'top' and 'max' parameters.  These
        will be automatically added as needed.

    .PARAMETER Description
        A friendly description of the operation being performed for logging and console
        display purposes.

    .PARAMETER AcceptHeader
        Specify the media type in the Accept header.  Different types of commands may require
        different media types.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api as opposed to requesting a new one.

    .PARAMETER TelemetryEventName
        If provided, the successful execution of this REST command will be logged to telemetry
        using this event name.

    .PARAMETER TelemetryProperties
        If provided, the successful execution of this REST command will be logged to telemetry
        with these additional properties.  This will be silently ignored if TelemetryEventName
        is not provided as well.

    .PARAMETER TelemetryExceptionBucket
        If provided, any exception that occurs will be logged to telemetry using this bucket.
        It's possible that users will wish to log exceptions but not success (by providing
        TelemetryEventName) if this is being executed as part of a larger scenario.  If this
        isn't provided, but TelemetryEventName *is* provided, then TelemetryEventName will be
        used as the exception bucket value in the event of an exception.  If neither is specified,
        no bucket value will be used.

    .PARAMETER SinglePage
        By default, this function will automatically call any follow-up "nextLinks" provided by
        the return value in order to retrieve the entire result set.  If this switch is provided,
        only the first "page" of results will be retrieved, and the "nextLink" links will not be
        followed.
        WARNING: This might take a while depending on how many results there are.

    .OUTPUTS
        [PSCustomObject[]] - The result of the REST operation, in whatever form it comes in.

    .EXAMPLE
        Invoke-GHRestMethodMultipleResult -UriFragment "repos/PowerShell/PowerShellForGitHub/issues?state=all" -Description "Get all issues"

        Gets the first set of issues associated with this project,
        with the console window showing progress while awaiting the response
        from the REST request.
#>
    [CmdletBinding()]
    [OutputType([Object[]])]
    param(
        [Parameter(Mandatory)]
        [string] $UriFragment,

        [Parameter(Mandatory)]
        [string] $Description,

        [string] $AcceptHeader = $script:defaultAcceptHeader,

        [string] $AccessToken,

        [string] $TelemetryEventName = $null,

        [hashtable] $TelemetryProperties = @{},

        [string] $TelemetryExceptionBucket = $null,

        [switch] $SinglePage
    )

    $AccessToken = Get-AccessToken -AccessToken $AccessToken

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $errorBucket = $TelemetryExceptionBucket
    if ([String]::IsNullOrEmpty($errorBucket))
    {
        $errorBucket = $TelemetryEventName
    }

    $finalResult = @()

    $currentDescription = $Description
    $nextLink = $UriFragment

    $multiRequestProgressThreshold = Get-GitHubConfiguration -Name 'MultiRequestProgressThreshold'
    $iteration = 0
    $progressId = $null
    try
    {
        do
        {
            $iteration++
            $params = @{
                'UriFragment' = $nextLink
                'Method' = 'Get'
                'Description' = $currentDescription
                'AcceptHeader' = $AcceptHeader
                'ExtendedResult' = $true
                'AccessToken' = $AccessToken
                'TelemetryProperties' = $telemetryProperties
                'TelemetryExceptionBucket' = $errorBucket
            }

            $result = Invoke-GHRestMethod @params
            if ($null -ne $result.result)
            {
                $finalResult += $result.result
            }

            $nextLink = $result.nextLink
            $status = [String]::Empty
            $percentComplete = 0
            if ($result.numPages -eq 0)
            {
                # numPages == 0 is a special case for when the total number of pages is simply unknown.
                # This can happen with getting all GitHub users.
                $status = "Getting additional results [page $iteration of (unknown)]"
                $percentComplete = 10 # No idea what percentage to use in this scenario
            }
            else
            {
                $status = "Getting additional results [page $($result.nextPageNumber)/$($result.numPages)])"
                $percentComplete = (($result.nextPageNumber / $result.numPages) * 100)
            }

            $currentDescription = "$Description ($status)"
            if (($multiRequestProgressThreshold -gt 0) -and
                (($result.numPages -ge $multiRequestProgressThreshold) -or ($result.numPages -eq 0)))
            {
                $progressId = 1
                $progressParams = @{
                    'Activity' = $Description
                    'Status' = $status
                    'PercentComplete' = $percentComplete
                    'Id' = $progressId
                }

                Write-Progress @progressParams
            }
        }
        until ($SinglePage -or ([String]::IsNullOrWhiteSpace($nextLink)))

        # Record the telemetry for this event.
        $stopwatch.Stop()
        if (-not [String]::IsNullOrEmpty($TelemetryEventName))
        {
            $telemetryMetrics = @{ 'Duration' = $stopwatch.Elapsed.TotalSeconds }
            Set-TelemetryEvent -EventName $TelemetryEventName -Properties $TelemetryProperties -Metrics $telemetryMetrics
        }

        return $finalResult
    }
    catch
    {
        throw
    }
    finally
    {
        # Ensure that we complete the progress bar once the command is done, regardless of outcome.
        if ($null -ne $progressId)
        {
            Write-Progress -Activity $Description -Id $progressId -Completed
        }
    }
}

filter Split-GitHubUri
{
<#
    .SYNOPSIS
        Extracts the relevant elements of a GitHub repository Uri and returns the requested element.

    .DESCRIPTION
        Extracts the relevant elements of a GitHub repository Uri and returns the requested element.

        Currently supports retrieving the OwnerName and the RepositoryName, when available.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Uri
        The GitHub repository Uri whose components should be returned.

    .PARAMETER OwnerName
        Returns the Owner Name from the Uri if it can be identified.

    .PARAMETER RepositoryName
        Returns the Repository Name from the Uri if it can be identified.

    .INPUTS
        [String]

    .OUTPUTS
        [PSCustomObject] - The OwnerName and RepositoryName elements from the provided URL

    .EXAMPLE
        Split-GitHubUri -Uri 'https://github.com/microsoft/PowerShellForGitHub'

        PowerShellForGitHub

    .EXAMPLE
        Split-GitHubUri -Uri 'https://github.com/microsoft/PowerShellForGitHub' -RepositoryName

        PowerShellForGitHub

    .EXAMPLE
        Split-GitHubUri -Uri 'https://github.com/microsoft/PowerShellForGitHub' -OwnerName

        microsoft

    .EXAMPLE
        Split-GitHubUri -Uri 'https://github.com/microsoft/PowerShellForGitHub'

        @{'ownerName' = 'microsoft'; 'repositoryName' = 'PowerShellForGitHub'}
#>
    [CmdletBinding(DefaultParameterSetName='RepositoryName')]
    [OutputType([Hashtable])]
    param
    (
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Uri,

        [Parameter(ParameterSetName='OwnerName')]
        [switch] $OwnerName,

        [Parameter(ParameterSetName='RepositoryName')]
        [switch] $RepositoryName
    )

    $components = @{
        ownerName = [String]::Empty
        repositoryName = [String]::Empty
    }

    $hostName = $(Get-GitHubConfiguration -Name "ApiHostName")

    if (($Uri -match "^https?://(?:www.)?$hostName/([^/]+)/?([^/]+)?(?:/.*)?$") -or
        ($Uri -match "^https?://api.$hostName/repos/([^/]+)/?([^/]+)?(?:/.*)?$"))
    {
        $components.ownerName = $Matches[1]
        if ($Matches.Count -gt 2)
        {
            $components.repositoryName = $Matches[2]
        }
    }

    if ($OwnerName)
    {
        return $components.ownerName
    }
    elseif ($RepositoryName)
    {
        return $components.repositoryName
    }
    else
    {
        return $components
    }
}

function Join-GitHubUri
{
<#
    .SYNOPSIS
        Combines the provided repository elements into a repository URL.

    .DESCRIPTION
        Combines the provided repository elements into a repository URL.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OwnerName
        Owner of the repository.

    .PARAMETER RepositoryName
        Name of the repository.

    .OUTPUTS
        [String] - The repository URL.
#>
    [CmdletBinding()]
    [OutputType([String])]
    param
    (
        [Parameter(Mandatory)]
        [string] $OwnerName,

        [Parameter(Mandatory)]
        [string] $RepositoryName
    )


    $hostName = (Get-GitHubConfiguration -Name 'ApiHostName')
    return "https://$hostName/$OwnerName/$RepositoryName"
}

function Resolve-RepositoryElements
{
<#
    .SYNOPSIS
        Determines the OwnerName and RepositoryName from the possible parameter values.

    .DESCRIPTION
        Determines the OwnerName and RepositoryName from the possible parameter values.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER BoundParameters
        The inbound parameters from the calling method.
        This is expecting values that may include 'Uri', 'OwnerName' and 'RepositoryName'
        No need to explicitly provide this if you're using the PSBoundParameters from the
        function that is calling this directly.

    .PARAMETER DisableValidation
        By default, this function ensures that it returns with all elements provided,
        otherwise an exception is thrown.  If this is specified, that validation will
        not occur, and it's possible to receive a result where one or more elements
        have no value.

    .OUTPUTS
        [PSCustomObject] - The OwnerName and RepositoryName elements to be used
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="This was the most accurate name that I could come up with.  Internal only anyway.")]
    param
    (
        $BoundParameters = (Get-Variable -Name PSBoundParameters -Scope 1 -ValueOnly),

        [switch] $DisableValidation
    )

    $validate = -not $DisableValidation
    $elements = @{}

    if ($BoundParameters.ContainsKey('Uri') -and
       ($BoundParameters.ContainsKey('OwnerName') -or $BoundParameters.ContainsKey('RepositoryName')))
    {
        $message = "Cannot specify a Uri AND individual OwnerName/RepositoryName.  Please choose one or the other."
        Write-Log -Message $message -Level Error
        throw $message
    }

    if ($BoundParameters.ContainsKey('Uri'))
    {
        $elements.ownerName = Split-GitHubUri -Uri $BoundParameters.Uri -OwnerName
        if ($validate -and [String]::IsNullOrEmpty($elements.ownerName))
        {
            $message = "Provided Uri does not contain enough information: Owner Name."
            Write-Log -Message $message -Level Error
            throw $message
        }

        $elements.repositoryName = Split-GitHubUri -Uri $BoundParameters.Uri -RepositoryName
        if ($validate -and [String]::IsNullOrEmpty($elements.repositoryName))
        {
            $message = "Provided Uri does not contain enough information: Repository Name."
            Write-Log -Message $message -Level Error
            throw $message
        }
    }
    else
    {
        $elements.ownerName = Resolve-ParameterWithDefaultConfigurationValue -BoundParameters $BoundParameters -Name OwnerName -ConfigValueName DefaultOwnerName -NonEmptyStringRequired:$validate
        $elements.repositoryName = Resolve-ParameterWithDefaultConfigurationValue -BoundParameters $BoundParameters -Name RepositoryName -ConfigValueName DefaultRepositoryName -NonEmptyStringRequired:$validate
    }

    return ([PSCustomObject] $elements)
}

# The list of property names across all of GitHub API v3 that are known to store dates as strings.
$script:datePropertyNames = @(
    'closed_at',
    'committed_at',
    'completed_at',
    'created_at',
    'date',
    'due_on',
    'last_edited_at',
    'last_read_at',
    'merged_at',
    'published_at',
    'pushed_at',
    'starred_at',
    'started_at',
    'submitted_at',
    'timestamp',
    'updated_at'
)

filter ConvertTo-SmarterObject
{
<#
    .SYNOPSIS
        Updates the properties of the input object to be object themselves when the conversion
        is possible.

    .DESCRIPTION
        Updates the properties of the input object to be object themselves when the conversion
        is possible.

        At present, this only attempts to convert properties known to store dates as strings
        into storing them as DateTime objects instead.

    .PARAMETER InputObject
        The object to update

    .INPUTS
        [object]

    .OUTPUTS
        [object]
#>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [object] $InputObject
    )

    if ($null -eq $InputObject)
    {
        return $null
    }

    if (($InputObject -is [int]) -or ($InputObject -is [long]))
    {
        # In some instances, an int/long was being seen as a [PSCustomObject].
        # This attempts to short-circuit extra work we would have done had that happened.
        Write-Output -InputObject $InputObject
    }
    elseif ($InputObject -is [System.Collections.IList])
    {
        $InputObject |
            ConvertTo-SmarterObject |
            Write-Output
    }
    elseif ($InputObject -is [PSCustomObject])
    {
        $clone = DeepCopy-Object -InputObject $InputObject
        $properties = $clone.PSObject.Properties | Where-Object { $null -ne $_.Value }
        foreach ($property in $properties)
        {
            # Convert known date properties from dates to real DateTime objects
            if (($property.Name -in $script:datePropertyNames) -and
                ($property.Value -is [String]) -and
                (-not [String]::IsNullOrWhiteSpace($property.Value)))
            {
                try
                {
                    $property.Value = Get-Date -Date $property.Value
                }
                catch
                {
                    $message = "Unable to convert $($property.Name) value of $($property.Value) to a [DateTime] object.  Leaving as-is."
                    Write-Log -Message $message -Level Verbose
                }
            }

            if ($property.Value -is [System.Collections.IList])
            {
                $property.Value = @(ConvertTo-SmarterObject -InputObject $property.Value)
            }
            elseif ($property.Value -is [PSCustomObject])
            {
                $property.Value = ConvertTo-SmarterObject -InputObject $property.Value
            }
        }

        Write-Output -InputObject $clone
    }
    else
    {
        Write-Output -InputObject $InputObject
    }
}

function Get-MediaAcceptHeader
{
<#
    .SYNOPSIS
        Returns a formatted AcceptHeader based on the requested MediaType.

    .DESCRIPTION
        Returns a formatted AcceptHeader based on the requested MediaType.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER MediaType
        The format in which the API will return the body of the comment or issue.

        Raw  - Return the raw markdown body.
               Response will include body.
               This is the default if you do not pass any specific media type.
        Text - Return a text only representation of the markdown body.
               Response will include body_text.
        Html - Return HTML rendered from the body's markdown.
               Response will include body_html.
        Full - Return raw, text and HTML representations.
               Response will include body, body_text, and body_html.
        Object - Return a json object representation a file or folder.

    .PARAMETER AsJson
        If this switch is specified as +json value is appended to the MediaType header.

    .PARAMETER AcceptHeader
        The accept header that should be included with the MediaType accept header.

    .OUTPUTS
        [String]

    .EXAMPLE
        Get-MediaAcceptHeader -MediaType Raw

        Returns a formatted AcceptHeader for v3 of the response object
#>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [ValidateSet('Raw', 'Text', 'Html', 'Full', 'Object')]
        [string] $MediaType = 'Raw',

        [switch] $AsJson,

        [string] $AcceptHeader
    )

    $resultHeaders = "application/vnd.github.$mediaTypeVersion.$($MediaType.ToLower())"
    if ($AsJson)
    {
        $resultHeaders = $resultHeaders + "+json"
    }

    if (-not [String]::IsNullOrEmpty($AcceptHeader))
    {
        $resultHeaders = "$AcceptHeader,$resultHeaders"
    }

    return $resultHeaders
}

@{
    defaultJsonBodyContentType = 'application/json; charset=UTF-8'
    defaultInFileContentType = 'text/plain'

    # Compiled mostly from https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types/Common_types
    extensionToContentType = @{
        '.3gp'    = 'video/3gpp' # 3GPP audio/video container
        '.3g2'    = 'video/3gpp2' # 3GPP2 audio/video container
        '.7z'     = 'application/x-7z-compressed' # 7-zip archive
        '.aac'    = 'audio/aac' # AAC audio
        '.abw'    = 'application/x-abiword' # AbiWord document
        '.arc'    = 'application/x-freearc' # Archive document (multiple files embedded)
        '.avi'    = 'video/x-msvideo' # AVI: Audio Video Interleave
        '.azw'    = 'application/vnd.amazon.ebook' # Amazon Kindle eBook format
        '.bin'    = 'application/octet-stream' # Any kind of binary data
        '.bmp'    = 'image/bmp' # Windows OS/2 Bitmap Graphics
        '.bz'     = 'application/x-bzip' # BZip archive
        '.bz2'    = 'application/x-bzip2' # BZip2 archive
        '.csh'    = 'application/x-csh' # C-Shell script
        '.css'    = 'text/css' # Cascading Style Sheets (CSS)
        '.csv'    = 'text/csv' # Comma-separated values (CSV)
        '.deb'    = 'application/octet-stream' # Standard Uix archive format
        '.doc'    = 'application/msword' # Microsoft Word
        '.docx'   = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' # Microsoft Word (OpenXML)
        '.eot'    = 'application/vnd.ms-fontobject' # MS Embedded OpenType fonts
        '.epub'   = 'application/epub+zip' # Electronic publication (EPUB)
        '.exe'    = 'application/vnd.microsoft.portable-executable' # Microsoft application executable
        '.gz'     = 'application/x-gzip' # GZip Compressed Archive
        '.gif'    = 'image/gif' # Graphics Interchange Format (GIF)
        '.htm'    = 'text/html' # HyperText Markup Language (HTML)
        '.html'   = 'text/html' # HyperText Markup Language (HTML)
        '.ico'    = 'image/vnd.microsoft.icon' # Icon format
        '.ics'    = 'text/calendar' # iCalendar format
        '.ini'    = 'text/plain' # Text-based configuration file
        '.jar'    = 'application/java-archive' # Java Archive (JAR)
        '.jpeg'   = 'image/jpeg' # JPEG images
        '.jpg'    = 'image/jpeg' # JPEG images
        '.js'     = 'text/javascript' # JavaScript
        '.json'   = 'application/json' # JSON format
        '.jsonld' = 'application/ld+json' # JSON-LD format
        '.mid'    = 'audio/midi' # Musical Instrument Digital Interface (MIDI)
        '.midi'   = 'audio/midi' # Musical Instrument Digital Interface (MIDI)
        '.mjs'    = 'text/javascript' # JavaScript module
        '.mp3'    = 'audio/mpeg' # MP3 audio
        '.mp4'    = 'video/mp4' # MP3 video
        '.mov'    = 'video/quicktime' # Quicktime video
        '.mpeg'   = 'video/mpeg' # MPEG Video
        '.mpg'    = 'video/mpeg' # MPEG Video
        '.mpkg'   = 'application/vnd.apple.installer+xml' # Apple Installer Package
        '.msi'    = 'application/octet-stream' # Windows Installer package
        '.msix'   = 'application/octet-stream' # Windows Installer package
        '.mkv'    = 'video/x-matroska' # Matroska Multimedia Container
        '.odp'    = 'application/vnd.oasis.opendocument.presentation' # OpenDocument presentation document
        '.ods'    = 'application/vnd.oasis.opendocument.spreadsheet' # OpenDocument spreadsheet document
        '.odt'    = 'application/vnd.oasis.opendocument.text' # OpenDocument text document
        '.oga'    = 'audio/ogg' # OGG audio
        '.ogg'    = 'application/ogg' # OGG audio or video
        '.ogv'    = 'video/ogg' # OGG video
        '.ogx'    = 'application/ogg' # OGG
        '.opus'   = 'audio/opus' # Opus audio
        '.otf'    = 'font/otf' # OpenType font
        '.png'    = 'image/png' # Portable Network Graphics
        '.pdf'    = 'application/pdf' # Adobe Portable Document Format (PDF)
        '.php'    = 'application/x-httpd-php' # Hypertext Preprocessor (Personal Home Page)
        '.pkg'    = 'application/octet-stream' # mac OS X installer file
        '.ps1'    = 'text/plain' # PowerShell script file
        '.psd1'   = 'text/plain' # PowerShell module definition file
        '.psm1'   = 'text/plain' # PowerShell module file
        '.ppt'    = 'application/vnd.ms-powerpoint' # Microsoft PowerPoint
        '.pptx'   = 'application/vnd.openxmlformats-officedocument.presentationml.presentation' # Microsoft PowerPoint (OpenXML)
        '.rar'    = 'application/vnd.rar' # RAR archive
        '.rtf'    = 'application/rtf' # Rich Text Format (RTF)
        '.rpm'    = 'application/octet-stream' # Red Hat Linux package format
        '.sh'     = 'application/x-sh' # Bourne shell script
        '.svg'    = 'image/svg+xml' # Scalable Vector Graphics (SVG)
        '.swf'    = 'application/x-shockwave-flash' # Small web format (SWF) or Adobe Flash document
        '.tar'    = 'application/x-tar' # Tape Archive (TAR)
        '.tif'    = 'image/tiff' # Tagged Image File Format (TIFF)
        '.tiff'   = 'image/tiff' # Tagged Image File Format (TIFF)
        '.ts'     = 'video/mp2t' # MPEG transport stream
        '.ttf'    = 'font/ttf' # TrueType Font
        '.txt'    = 'text/plain' # Text (generally ASCII or ISO 8859-n)
        '.vsd'    = 'application/vnd.visio' # Microsoft Visio
        '.vsix'   = 'application/zip' # Visual Studio application package archive
        '.wav'    = 'audio/wav' # Waveform Audio Format
        '.weba'   = 'audio/webm' # WEBM audio
        '.webm'   = 'video/webm' # WEBM video
        '.webp'   = 'image/webp' # WEBP image
        '.woff'   = 'font/woff' # Web Open Font Format (WOFF)
        '.woff2'  = 'font/woff2' # Web Open Font Format (WOFF)
        '.xhtml'  = 'application/xhtml+xml' # XHTML
        '.xls'    = 'application/vnd.ms-excel' # Microsoft Excel
        '.xlsx'   = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' # Microsoft Excel (OpenXML)
        '.xml'    = 'application/xml' # XML
        '.xul'    = 'application/vnd.mozilla.xul+xml' # XUL
        '.zip'    = 'application/zip' # ZIP archive
    }
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDneOgPBai+nrew
# 6kSeVQjj/wC4pHHdobrc0/AMlFjrCKCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
# chVZQMcJAAAAAAGHMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjAwMzA0MTgzOTQ3WhcNMjEwMzAzMTgzOTQ3WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDOt8kLc7P3T7MKIhouYHewMFmnq8Ayu7FOhZCQabVwBp2VS4WyB2Qe4TQBT8aB
# znANDEPjHKNdPT8Xz5cNali6XHefS8i/WXtF0vSsP8NEv6mBHuA2p1fw2wB/F0dH
# sJ3GfZ5c0sPJjklsiYqPw59xJ54kM91IOgiO2OUzjNAljPibjCWfH7UzQ1TPHc4d
# weils8GEIrbBRb7IWwiObL12jWT4Yh71NQgvJ9Fn6+UhD9x2uk3dLj84vwt1NuFQ
# itKJxIV0fVsRNR3abQVOLqpDugbr0SzNL6o8xzOHL5OXiGGwg6ekiXA1/2XXY7yV
# Fc39tledDtZjSjNbex1zzwSXAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUhov4ZyO96axkJdMjpzu2zVXOJcsw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDU4Mzg1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAixmy
# S6E6vprWD9KFNIB9G5zyMuIjZAOuUJ1EK/Vlg6Fb3ZHXjjUwATKIcXbFuFC6Wr4K
# NrU4DY/sBVqmab5AC/je3bpUpjtxpEyqUqtPc30wEg/rO9vmKmqKoLPT37svc2NV
# BmGNl+85qO4fV/w7Cx7J0Bbqk19KcRNdjt6eKoTnTPHBHlVHQIHZpMxacbFOAkJr
# qAVkYZdz7ikNXTxV+GRb36tC4ByMNxE2DF7vFdvaiZP0CVZ5ByJ2gAhXMdK9+usx
# zVk913qKde1OAuWdv+rndqkAIm8fUlRnr4saSCg7cIbUwCCf116wUJ7EuJDg0vHe
# yhnCeHnBbyH3RZkHEi2ofmfgnFISJZDdMAeVZGVOh20Jp50XBzqokpPzeZ6zc1/g
# yILNyiVgE+RPkjnUQshd1f1PMgn3tns2Cz7bJiVUaqEO3n9qRFgy5JuLae6UweGf
# AeOo3dgLZxikKzYs3hDMaEtJq8IP71cX7QXe6lnMmXU/Hdfz2p897Zd+kU+vZvKI
# 3cwLfuVQgK2RZ2z+Kc3K3dRPz2rXycK5XCuRZmvGab/WbrZiC7wJQapgBodltMI5
# GMdFrBg9IeF7/rP4EqVQXeKtevTlZXjpuNhhjuR+2DMt/dWufjXpiW91bo3aH6Ea
# jOALXmoxgltCp1K7hrS6gmsvj94cLRf50QQ4U8Qwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVZzCCFWMCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAYdyF3IVWUDHCQAAAAABhzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgx/0YEI3E
# fsyJ9RzmPCgPxx9XRxG2ubZ7hkClm1zL3m0wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBSJ/i/NlJAIJnM38yH+xAPAyQZjfD4J0UH1cAlWZUd
# cbLW10cfBDqvGUL9EARfkLj3weeUss6MYHOvRjrS0yu+v1LyS+90XLUSKlzEnzZt
# 1+rY8okExkbDG4GIVvRhahoG6PtBv0SoDHHs0+ddBrcp37bZhtEvxFAxRFYog6Xd
# NEOGxpDe45GM+r6PSz2z2eChyK+b5PdkFivpzw3pIGWP/4LLj7w6nkNV3HDJy/i/
# l/uiRpzCyBro1ii3TemCgbQo6I3UfQ6VyU7D2khdYHCViDlej/a5fq2dj3RFyUbv
# 5/njrUxzdeMveL3faNXsSNinRFbWkt1qvP9mqn4SKQYroYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEILslW2Z8hi/JyiQNOFCsTO4Q36ciusG9McVaNBFj
# wkmJAgZf29L2GxQYEzIwMjEwMTA1MTk1MDU2LjI4NlowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjo0NjJGLUUzMTktM0YyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABJMvNAqEXcFyaAAAA
# AAEkMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTQ1N1oXDTIxMDMxNzAxMTQ1N1owgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo0NjJG
# LUUzMTktM0YyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJCbKjgNnhjvMlnRNAtx
# 7X3N5ZZkSfUFULyWsVJ1pnyMsSITimg1q3OQ1Ikf0/3gg8UG5TIRm7wH8sjBtoB3
# nuzFz11CegIFcanYnt050JvnrUTKeAPUR5pLpTeP3QEgL+CWOc4lTg/XxjnQv01F
# D7TTn9DEuO3kp0GQ87Mjd5ssxK0K1q4IWNFAyRpx5n8Vm3Vm1iiVL5FMDUKsl5G/
# SqQdiEDn8cqYbqWMVzWH94PdKdw1mIHToBRCNsR9BHHWzNkSS+R0WRipBSSorKT7
# cuLlEBYhDo8AY3uMGlv0kLRLHASZ+sz2nfkpW2CVt+bHhVmM6/5qiu2f7eYoTYJu
# cFECAwEAAaOCARswggEXMB0GA1UdDgQWBBS7HdFyrGKIhDxvypLA1lD/wGRSsDAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQBo3QzNuNRgzdflwA4U7f3e2CcGlwdg
# 6ii498cBiSrTpWKO3qqz5pvgHAk4hh6y/FLY80R59inLwcVuyD24S3JEdSie4y1t
# C5JptweR1qlxRJCRM4vG7nPtIC4eAMKcXgovu0mTFv7xpFAVpRuvuepR91gIde32
# 8lv1HTTJCV/LBBk83Xi7nCGPF59FxeIrcE32xt4YJgEpEAikeMqvWCTMyPqlmvx9
# J92fxU3cQcw2j2EWwqOD5T3Nz2HWfPV80sihD1A6Y5HhjpS9taDPs7CI58I211F3
# ysegNyOesG3MTrSJHyPMLKYFDxcG1neV0liktv+TW927sUOVczcSUhQLMIIGcTCC
# BFmgAwIBAgIKYQmBKgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcN
# MjUwNzAxMjE0NjU1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0
# VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEw
# RA/xYIiEVEMM1024OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQe
# dGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKx
# Xf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4G
# kbaICDXoeByw6ZnNPOcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEA
# AaOCAeYwggHiMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7
# fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0g
# AQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYB
# BQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUA
# bQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOh
# IW+z66bM9TG+zwXiqf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS
# +7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlK
# kVIArzgPF/UveYFl2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon
# /VWvL/625Y4zu2JfmttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOi
# PPp/fZZqkHimbdLhnPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/
# fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCII
# YdqwUB5vvfHhAN/nMQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0
# cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7a
# KLixqduWsqdCosnPGUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQ
# cdeh0sVV42neV8HR3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+
# NR4Iuto229Nfj950iEkSoYIC0jCCAjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBP
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo0
# NjJGLUUzMTktM0YyMDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAlwPlNCq+Un54UfxLe/wKS1Xc4nqggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOOetK4wIhgPMjAyMTAxMDUxMzQ5MzRaGA8yMDIxMDEwNjEzNDkzNFowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA4560rgIBADAKAgEAAgIfWgIB/zAHAgEAAgITODAK
# AgUA46AGLgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAEJMUrlsD89opF1l
# bMXsqGXAWHHJhBk1RYPRHevM9DJByFGgfBNLkBMKMJ45F8uzMNfBsNeRQLzJIHc+
# MtPshpBMILCWNwMxkZ3lo40qEwmm7kEiiMz/tC6B3oosEgQaTaGf3eqadtnWrboS
# tHkc1NNJuQ/2DKR1+jm6ojjyJ3ArMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEky80CoRdwXJoAAAAAASQwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgwfrsaLxlo4awGXNKbNy/q/aI0TXLp1ALXLHybtanw6gwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBiOOHoohqL+X7Xa/25jp1wTrQxYlYGLszis/nA
# TirjIDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# JMvNAqEXcFyaAAAAAAEkMCIEID3BNgEmggzhBVnlrhiWPLIq7N8ovgrOW/kvWTZx
# a9rhMA0GCSqGSIb3DQEBCwUABIIBAHVjgbTnJ8ypUUHs6ZpkY+w0uIrh9oEOoACv
# +8fB0FrcXrop92RrhV602CHa1y3pjuB/lggFCq+Ms7YVbrKoFLJpglOVs0D0mpaj
# Fob6Lfk80uDYDB0JKSMnJY/qAX9buhGNN9PnUAOg2n2hzGWUiU8jOEWoNZ4fbo6L
# x0yYp36taYxX4UWrbxdCbc+HlmlgIOybEhgcXGY3cKpXw1gqInX8/LAneq/30LI+
# hra9n0B+mBTMqgz+lq6i2B+nCmp6qaiXJjaQ/XhZg+SFHv/YGQ3ViFZR3BtgFLd5
# DKVPrjIjVeRmq81aFygSGmo3O58ZfuscT8plp83WUa9J4xbq8LY=
# SIG # End signature block
