# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubGistTypeName = 'GitHub.Gist'
    GitHubGistCommitTypeName = 'GitHub.GistCommit'
    GitHubGistForkTypeName = 'GitHub.GistFork'
    GitHubGistSummaryTypeName = 'GitHub.GistSummary'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubGist
{
<#
    .SYNOPSIS
        Retrieves gist information from GitHub.

    .DESCRIPTION
        Retrieves gist information from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific gist that you wish to retrieve.

    .PARAMETER Sha
        The specific revision of the gist that you wish to retrieve.

    .PARAMETER Forks
        Gets the forks of the specified gist.

    .PARAMETER Commits
        Gets the commits of the specified gist.

    .PARAMETER UserName
        Gets public gists for the specified user.

    .PARAMETER Path
        Download the files that are part of the specified gist to this path.

    .PARAMETER Force
        If downloading files, this will overwrite any files with the same name in the provided path.

    .PARAMETER Current
        Gets the authenticated user's gists.

    .PARAMETER Starred
        Gets the authenticated user's starred gists.

    .PARAMETER Public
        Gets public gists sorted by most recently updated to least recently updated.
        The results will be limited to the first 3000.

    .PARAMETER Since
        Only gists updated at or after this time are returned.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        GitHub.Gist
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .EXAMPLE
        Get-GitHubGist -Starred

        Gets all starred gists for the current authenticated user.

    .EXAMPLE
        Get-GitHubGist -Public -Since ((Get-Date).AddDays(-2))

        Gets all public gists that have been updated within the past two days.

    .EXAMPLE
        Get-GitHubGist -Gist 6cad326836d38bd3a7ae

        Gets octocat's "hello_world.rb" gist.
#>
    [CmdletBinding(
        DefaultParameterSetName='Current',
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistTypeName})]
    [OutputType({$script:GitHubGistCommitTypeName})]
    [OutputType({$script:GitHubGistForkTypeName})]
    [OutputType({$script:GitHubGistSummaryTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Id',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Download',
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [Parameter(ParameterSetName='Id')]
        [Parameter(ParameterSetName='Download')]
        [ValidateNotNullOrEmpty()]
        [string] $Sha,

        [Parameter(ParameterSetName='Id')]
        [switch] $Forks,

        [Parameter(ParameterSetName='Id')]
        [switch] $Commits,

        [Parameter(
            Mandatory,
            ParameterSetName='User')]
        [ValidateNotNullOrEmpty()]
        [string] $UserName,

        [Parameter(
            Mandatory,
            ParameterSetName='Download',
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(ParameterSetName='Download')]
        [switch] $Force,

        [Parameter(ParameterSetName='Current')]
        [switch] $Current,

        [Parameter(ParameterSetName='Current')]
        [switch] $Starred,

        [Parameter(ParameterSetName='Public')]
        [switch] $Public,

        [Parameter(ParameterSetName='User')]
        [Parameter(ParameterSetName='Current')]
        [Parameter(ParameterSetName='Public')]
        [DateTime] $Since,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = [String]::Empty
    $description = [String]::Empty
    $outputType = $script:GitHubGistSummaryTypeName

    if ($PSCmdlet.ParameterSetName -in ('Id', 'Download'))
    {
        $telemetryProperties['ById'] = $true

        if ($PSBoundParameters.ContainsKey('Sha'))
        {
            if ($Forks -or $Commits)
            {
                $message = 'Cannot check for forks or commits of a specific SHA.  Do not specify SHA if you want to list out forks or commits.'
                Write-Log -Message $message -Level Error
                throw $message
            }

            $telemetryProperties['SpecifiedSha'] = $true

            $uriFragment = "gists/$Gist/$Sha"
            $description = "Getting gist $Gist with specified Sha"
            $outputType = $script:GitHubGistTypeName
        }
        elseif ($Forks)
        {
            $uriFragment = "gists/$Gist/forks"
            $description = "Getting forks of gist $Gist"
            $outputType = $script:GitHubGistForkTypeName
        }
        elseif ($Commits)
        {
            $uriFragment = "gists/$Gist/commits"
            $description = "Getting commits of gist $Gist"
            $outputType = $script:GitHubGistCommitTypeName
        }
        else
        {
            $uriFragment = "gists/$Gist"
            $description = "Getting gist $Gist"
            $outputType = $script:GitHubGistTypeName
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'User')
    {
        $telemetryProperties['ByUserName'] = $true

        $uriFragment = "users/$UserName/gists"
        $description = "Getting public gists for $UserName"
        $outputType = $script:GitHubGistSummaryTypeName
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Current')
    {
        $telemetryProperties['CurrentUser'] = $true
        $outputType = $script:GitHubGistSummaryTypeName

        if ((Test-GitHubAuthenticationConfigured) -or (-not [String]::IsNullOrEmpty($AccessToken)))
        {
            if ($Starred)
            {
                $uriFragment = 'gists/starred'
                $description = 'Getting starred gists for current authenticated user'
            }
            else
            {
                $uriFragment = 'gists'
                $description = 'Getting gists for current authenticated user'
            }
        }
        else
        {
            if ($Starred)
            {
                $message = 'Starred can only be specified for authenticated users.  Either call Set-GitHubAuthentication first, or provide a value for the AccessToken parameter.'
                Write-Log -Message $message -Level Error
                throw $message
            }

            $message = 'Specified -Current, but not currently authenticated.  Either call Set-GitHubAuthentication first, or provide a value for the AccessToken parameter.'
            Write-Log -Message $message -Level Error
            throw $message
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Public')
    {
        $telemetryProperties['Public'] = $true
        $outputType = $script:GitHubGistSummaryTypeName

        $uriFragment = "gists/public"
        $description = 'Getting public gists'
    }

    $getParams = @()
    $sinceFormattedTime = [String]::Empty
    if ($null -ne $Since)
    {
        $sinceFormattedTime = $Since.ToUniversalTime().ToString('o')
        $getParams += "since=$sinceFormattedTime"
    }

    $params = @{
        'UriFragment' = $uriFragment + '?' +  ($getParams -join '&')
        'Description' =  $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = (Invoke-GHRestMethodMultipleResult @params |
        Add-GitHubGistAdditionalProperties -TypeName $outputType)

    if ($PSCmdlet.ParameterSetName -eq 'Download')
    {
        Save-GitHubGist -GistObject $result -Path $Path -Force:$Force
    }
    else
    {
        if ($result.truncated -eq $true)
        {
            $message = @(
                'Response has been truncated.  The API will only return the first 3000 gist results',
                'the first 300 files within the gist, and the first 1 Mb of an individual',
                'file.  If the file has been truncated, you can call',
                '(Invoke-WebRequest -UseBasicParsing -Method Get -Uri <raw_url>).Content)',
                'where <raw_url> is the value of raw_url for the file in question.  Be aware that',
                'for files larger than 10 Mb, you''ll need to clone the gist via the URL provided',
                'by git_pull_url.')

            Write-Log -Message ($message -join ' ') -Level Warning
        }

        return $result
    }
}

function Save-GitHubGist
{
<#
    .SYNOPSIS
        Downloads the contents of a gist to the specified file path.

    .DESCRIPTION
        Downloads the contents of a gist to the specified file path.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER GistObject
        The Gist PSCustomObject

    .PARAMETER Path
        Download the files that are part of the specified gist to this path.

    .PARAMETER Force
        If downloading files, this will overwrite any files with the same name in the provided path.

    .NOTES
        Internal-only helper
#>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $GistObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [switch] $Force
    )

    # First, check to see if the response is missing files.
    if ($GistObject.truncated)
    {
        $message = @(
            'Gist response has been truncated.  The API will only return information on',
            'the first 300 files within a gist. To download this entire gist,',
            'you''ll need to clone it via the URL provided by git_pull_url',
            "[$($GistObject.git_pull_url)].")

        Write-Log -Message ($message -join ' ') -Level Error
        throw $message
    }

    # Then check to see if there are files we won't be able to download
    $files = $GistObject.files | Get-Member -Type NoteProperty | Select-Object -ExpandProperty Name
    foreach ($fileName in $files)
    {
        if ($GistObject.files.$fileName.truncated -and
            ($GistObject.files.$fileName.size -gt 10mb))
        {
            $message = @(
                "At least one file ($fileName) in this gist is larger than 10mb.",
                'In order to download this gist, you''ll need to clone it via the URL',
                "provided by git_pull_url [$($GistObject.git_pull_url)].")

            Write-Log -Message ($message -join ' ') -Level Error
            throw $message
        }
    }

    # Finally, we're ready to directly save the non-truncated files,
    # and download the ones that are between 1 - 10mb.
    $originalSecurityProtocol = [Net.ServicePointManager]::SecurityProtocol
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    try
    {
        $headers = @{}
        $AccessToken = Get-AccessToken -AccessToken $AccessToken
        if (-not [String]::IsNullOrEmpty($AccessToken))
        {
            $headers['Authorization'] = "token $AccessToken"
        }

        $Path = Resolve-UnverifiedPath -Path $Path
        $null = New-Item -Path $Path -ItemType Directory -Force
        foreach ($fileName in $files)
        {
            $filePath = Join-Path -Path $Path -ChildPath $fileName
            if ((Test-Path -Path $filePath -PathType Leaf) -and (-not $Force))
            {
                $message = "File already exists at path [$filePath].  Choose a different path or specify -Force"
                Write-Log -Message $message -Level Error
                throw $message
            }

            if ($GistObject.files.$fileName.truncated)
            {
                # Disable Progress Bar in function scope during Invoke-WebRequest
                $ProgressPreference = 'SilentlyContinue'

                $webRequestParams = @{
                    UseBasicParsing = $true
                    Method = 'Get'
                    Headers = $headers
                    Uri = $GistObject.files.$fileName.raw_url
                    OutFile = $filePath
                }

                Invoke-WebRequest @webRequestParams
            }
            else
            {
                $stream = New-Object -TypeName System.IO.StreamWriter -ArgumentList ($filePath)
                try
                {
                    $stream.Write($GistObject.files.$fileName.content)
                }
                finally
                {
                    $stream.Close()
                }
            }
        }
    }
    finally
    {
        [Net.ServicePointManager]::SecurityProtocol = $originalSecurityProtocol
    }
}

filter Remove-GitHubGist
{
<#
    .SYNOPSIS
        Removes/deletes a gist from GitHub.

    .DESCRIPTION
        Removes/deletes a gist from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific gist that you wish to retrieve.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .EXAMPLE
        Remove-GitHubGist -Gist 6cad326836d38bd3a7ae

        Removes octocat's "hello_world.rb" gist (assuming you have permission).

    .EXAMPLE
        Remove-GitHubGist -Gist 6cad326836d38bd3a7ae -Confirm:$false

        Removes octocat's "hello_world.rb" gist (assuming you have permission).
        Will not prompt for confirmation, as -Confirm:$false was specified.

    .EXAMPLE
        Remove-GitHubGist -Gist 6cad326836d38bd3a7ae -Force

        Removes octocat's "hello_world.rb" gist (assuming you have permission).
        Will not prompt for confirmation, as -Force was specified.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false,
        ConfirmImpact = 'High')]
    [Alias('Delete-GitHubGist')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [switch] $Force,

        [string] $AccessToken
    )

    Write-InvocationLog

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Gist, "Delete gist"))
    {
        return
    }

    $telemetryProperties = @{}
    $params = @{
        'UriFragment' = "gists/$Gist"
        'Method' = 'Delete'
        'Description' =  "Removing gist $Gist"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return Invoke-GHRestMethod @params
}

filter Copy-GitHubGist
{
<#
    .SYNOPSIS
        Forks a gist from GitHub.

    .DESCRIPTION
        Forks a gist from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific gist that you wish to fork.

    .PARAMETER PassThru
        Returns the newly created gist fork.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        GitHub.GistSummary

    .EXAMPLE
        Copy-GitHubGist -Gist 6cad326836d38bd3a7ae

        Forks octocat's "hello_world.rb" gist.

    .EXAMPLE
        $result = Fork-GitHubGist -Gist 6cad326836d38bd3a7ae -PassThru

        Forks octocat's "hello_world.rb" gist.  This is using the alias for the command.
        The result is the same whether you use Copy-GitHubGist or Fork-GitHubGist.
        Specifying the -PassThru switch enables you to get a reference to the newly created fork.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistSummaryTypeName})]
    [Alias('Fork-GitHubGist')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    if (-not $PSCmdlet.ShouldProcess($Gist, "Forking gist"))
    {
        return
    }

    $telemetryProperties = @{}
    $params = @{
        'UriFragment' = "gists/$Gist/forks"
        'Method' = 'Post'
        'Description' =  "Forking gist $Gist"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = (Invoke-GHRestMethod @params |
        Add-GitHubGistAdditionalProperties -TypeName $script:GitHubGistSummaryTypeName)

    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Set-GitHubGistStar
{
<#
    .SYNOPSIS
        Changes the starred state of a gist on GitHub for the current authenticated user.

    .DESCRIPTION
        Changes the starred state of a gist on GitHub for the current authenticated user.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific Gist that you wish to change the starred state for.

    .PARAMETER Star
        Include this switch to star the gist.  Exclude the switch (or use -Star:$false) to
        remove the star.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .EXAMPLE
        Set-GitHubGistStar -Gist 6cad326836d38bd3a7ae -Star

        Stars octocat's "hello_world.rb" gist.

    .EXAMPLE
        Set-GitHubGistStar -Gist 6cad326836d38bd3a7ae

        Unstars octocat's "hello_world.rb" gist.

    .EXAMPLE
        Get-GitHubGist -Gist 6cad326836d38bd3a7ae | Set-GitHubGistStar -Star:$false

        Unstars octocat's "hello_world.rb" gist.

#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [switch] $Star,

        [string] $AccessToken
    )

    Write-InvocationLog
    Set-TelemetryEvent -EventName $MyInvocation.MyCommand.Name

    $PSBoundParameters.Remove('Star')
    if ($Star)
    {
        return Add-GitHubGistStar @PSBoundParameters
    }
    else
    {
        return Remove-GitHubGistStar @PSBoundParameters
    }
}

filter Add-GitHubGistStar
{
<#
    .SYNOPSIS
        Star a gist from GitHub.

    .DESCRIPTION
        Star a gist from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific Gist that you wish to star.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .EXAMPLE
        Add-GitHubGistStar -Gist 6cad326836d38bd3a7ae

        Stars octocat's "hello_world.rb" gist.

    .EXAMPLE
        Star-GitHubGist -Gist 6cad326836d38bd3a7ae

        Stars octocat's "hello_world.rb" gist.  This is using the alias for the command.
        The result is the same whether you use Add-GitHubGistStar or Star-GitHubGist.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [Alias('Star-GitHubGist')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [string] $AccessToken
    )

    Write-InvocationLog

    if (-not $PSCmdlet.ShouldProcess($Gist, "Starring gist"))
    {
        return
    }

    $telemetryProperties = @{}
    $params = @{
        'UriFragment' = "gists/$Gist/star"
        'Method' = 'Put'
        'Description' =  "Starring gist $Gist"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return Invoke-GHRestMethod @params
}

filter Remove-GitHubGistStar
{
<#
    .SYNOPSIS
        Unstar a gist from GitHub.

    .DESCRIPTION
        Unstar a gist from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific gist that you wish to unstar.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .EXAMPLE
        Remove-GitHubGistStar -Gist 6cad326836d38bd3a7ae

        Unstars octocat's "hello_world.rb" gist.

    .EXAMPLE
        Unstar-GitHubGist -Gist 6cad326836d38bd3a7ae

        Unstars octocat's "hello_world.rb" gist.  This is using the alias for the command.
        The result is the same whether you use Remove-GitHubGistStar or Unstar-GitHubGist.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [Alias('Unstar-GitHubGist')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [string] $AccessToken
    )

    Write-InvocationLog

    if (-not $PSCmdlet.ShouldProcess($Gist, "Unstarring gist"))
    {
        return
    }

    $telemetryProperties = @{}
    $params = @{
        'UriFragment' = "gists/$Gist/star"
        'Method' = 'Delete'
        'Description' =  "Unstarring gist $Gist"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return Invoke-GHRestMethod @params
}

filter Test-GitHubGistStar
{
<#
    .SYNOPSIS
        Checks if a gist from GitHub is starred.

    .DESCRIPTION
        Checks if a gist from GitHub is starred.
        Will return $false if it isn't starred, as well as if it couldn't be checked
        (due to permissions or non-existence).

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID of the specific gist that you wish to check.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        Boolean indicating if the gist was both found and determined to be starred.

    .EXAMPLE
        Test-GitHubGistStar -Gist 6cad326836d38bd3a7ae

        Returns $true if the gist is starred, or $false if isn't starred or couldn't be checked
        (due to permissions or non-existence).
#>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType([bool])]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}
    $params = @{
        'UriFragment' = "gists/$Gist/star"
        'Method' = 'Get'
        'Description' =  "Checking if gist $Gist is starred"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'ExtendedResult' = $true
    }

    try
    {
        $response = Invoke-GHRestMethod @params
        return $response.StatusCode -eq 204
    }
    catch
    {
        return $false
    }
}

filter New-GitHubGist
{
<#
    .SYNOPSIS
        Creates a new gist on GitHub.

    .DESCRIPTION
        Creates a new gist on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER File
        An array of filepaths that should be part of this gist.
        Use this when you have multiple files that should be part of a gist, or when you simply
        want to reference an existing file on disk.

    .PARAMETER FileName
        The name of the file that Content should be stored in within the newly created gist.

    .PARAMETER Content
        The content of a single file that should be part of the gist.

    .PARAMETER Description
        A descriptive name for this gist.

    .PARAMETER Public
        When specified, the gist will be public and available for anyone to see.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        String - Filename(s) of file(s) that should be the content of the gist.

    .OUTPUTS
        GitHub.GitDetail

    .EXAMPLE
        New-GitHubGist -FileName 'sample.txt' -Content 'Body of my file.' -Description 'This is my gist!' -Public

        Creates a new public gist with a single file named 'sample.txt' that has the body of "Body of my file."

    .EXAMPLE
        New-GitHubGist -File 'c:\files\foo.txt' -Description 'This is my gist!'

        Creates a new private gist with a single file named 'foo.txt'.  Will populate it with the
        content of the file at c:\files\foo.txt.

    .EXAMPLE
        New-GitHubGist -File ('c:\files\foo.txt', 'c:\other\bar.txt', 'c:\octocat.ps1') -Description 'This is my gist!'

        Creates a new private gist with a three files named 'foo.txt', 'bar.txt' and 'octocat.ps1'.
        Each will be populated with the content from the file on disk at the specified location.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='FileRef',
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ParameterSetName='FileRef',
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string[]] $File,

        [Parameter(
            Mandatory,
            ParameterSetName='Content',
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName,

        [Parameter(
            Mandatory,
            ParameterSetName='Content',
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $Content,

        [string] $Description,

        [switch] $Public,

        [string] $AccessToken
    )

    begin
    {
        $files = @{}
    }

    process
    {
        foreach ($path in $File)
        {
            $path = Resolve-UnverifiedPath -Path $path
            if (-not (Test-Path -Path $path -PathType Leaf))
            {
                $message = "Specified file [$path] could not be found or was inaccessible."
                Write-Log -Message $message -Level Error
                throw $message
            }

            $content = [System.IO.File]::ReadAllText($path)
            $fileName = (Get-Item -Path $path).Name

            if ($files.ContainsKey($fileName))
            {
                $message = "You have specified more than one file with the same name [$fileName].  gists don't have a concept of directory structures, so please ensure each file has a unique name."
                Write-Log -Message $message -Level Error
                throw $message
            }

            $files[$fileName] = @{ 'content' = $Content }
        }
    }

    end
    {
        Write-InvocationLog

        $telemetryProperties = @{}

        if ($PSCmdlet.ParameterSetName -eq 'Content')
        {
            $files[$FileName] = @{ 'content' = $Content }
        }

        if (($files.Keys.StartsWith('gistfile') | Where-Object { $_ -eq $true }).Count -gt 0)
        {
            $message = "Don't name your files starting with 'gistfile'. This is the format of the automatic naming scheme that Gist uses internally."
            Write-Log -Message $message -Level Error
            throw $message
        }

        $hashBody = @{
            'description' = $Description
            'public' = $Public.ToBool()
            'files' = $files
        }

        if (-not $PSCmdlet.ShouldProcess('Create new gist'))
        {
            return
        }

        $params = @{
            'UriFragment' = "gists"
            'Body' = (ConvertTo-Json -InputObject $hashBody)
            'Method' = 'Post'
            'Description' =  "Creating a new gist"
            'AccessToken' = $AccessToken
            'TelemetryEventName' = $MyInvocation.MyCommand.Name
            'TelemetryProperties' = $telemetryProperties
        }

        return (Invoke-GHRestMethod @params |
            Add-GitHubGistAdditionalProperties -TypeName $script:GitHubGistTypeName)
    }
}

filter Set-GitHubGist
{
<#
    .SYNOPSIS
        Updates a gist on GitHub.

    .DESCRIPTION
        Updates a gist on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID for the gist to update.

    .PARAMETER Update
        A hashtable of files to update in the gist.
        The key should be the name of the file in the gist as it exists right now.
        The value should be another hashtable with the following optional key/value pairs:
            fileName - Specify a new name here if you want to rename the file.
            filePath - Specify a path to a file on disk if you wish to update the contents of the
                       file in the gist with the contents of the specified file.
                       Should not be specified if you use 'content' (below)
            content  - Directly specify the raw content that the file in the gist should be updated with.
                       Should not be used if you use 'filePath' (above).

    .PARAMETER Delete
        A list of filenames that should be removed from this gist.

    .PARAMETER Description
        New description for this gist.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER PassThru
        Returns the updated gist.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        GitHub.GistDetail

    .EXAMPLE
        Set-GitHubGist -Gist 6cad326836d38bd3a7ae -Description 'This is my newer description'

        Updates the description for the specified gist.

    .EXAMPLE
        Set-GitHubGist -Gist 6cad326836d38bd3a7ae -Delete 'hello_world.rb' -Force

        Deletes the 'hello_world.rb' file from the specified gist without prompting for confirmation.

    .EXAMPLE
        Set-GitHubGist -Gist 6cad326836d38bd3a7ae -Delete 'hello_world.rb' -Description 'This is my newer description'

        Deletes the 'hello_world.rb' file from the specified gist and updates the description.

    .EXAMPLE
        Set-GitHubGist -Gist 6cad326836d38bd3a7ae -Update @{'hello_world.rb' = @{ 'fileName' = 'hello_universe.rb' }}

        Renames the 'hello_world.rb' file in the specified gist to be 'hello_universe.rb'.

    .EXAMPLE
        Set-GitHubGist -Gist 6cad326836d38bd3a7ae -Update @{'hello_world.rb' = @{ 'fileName' = 'hello_universe.rb' }}

        Renames the 'hello_world.rb' file in the specified gist to be 'hello_universe.rb'.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Content',
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [hashtable] $Update,

        [string[]] $Delete,

        [string] $Description,

        [switch] $Force,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $files = @{}

    $shouldProcessMessage = 'Update gist'

    # Mark the files that should be deleted.
    if ($Delete.Count -gt 0)
    {
        $ConfirmPreference = 'Low'
        $shouldProcessMessage = 'Update gist (and remove files)'

        foreach ($toDelete in $Delete)
        {
            $files[$toDelete] = $null
        }
    }

    # Then figure out which ones need content updates and/or file renames
    if ($null -ne $Update)
    {
        foreach ($toUpdate in $Update.GetEnumerator())
        {
            $currentFileName = $toUpdate.Key

            $providedContent = $toUpdate.Value.Content
            $providedFileName = $toUpdate.Value.FileName
            $providedFilePath = $toUpdate.Value.FilePath

            if (-not [String]::IsNullOrWhiteSpace($providedContent))
            {
                $files[$currentFileName] = @{ 'content' = $providedContent }
            }

            if (-not [String]::IsNullOrWhiteSpace($providedFilePath))
            {
                if (-not [String]::IsNullOrWhiteSpace($providedContent))
                {
                    $message = "When updating a file [$currentFileName], you cannot provide both a path to a file [$providedFilePath] and the raw content."
                    Write-Log -Message $message -Level Error
                    throw $message
                }

                $providedFilePath = Resolve-Path -Path $providedFilePath
                if (-not (Test-Path -Path $providedFilePath -PathType Leaf))
                {
                    $message = "Specified file [$providedFilePath] could not be found or was inaccessible."
                    Write-Log -Message $message -Level Error
                    throw $message
                }

                $newContent = [System.IO.File]::ReadAllText($providedFilePath)
                $files[$currentFileName] = @{ 'content' = $newContent }
            }

            # The user has chosen to rename the file.
            if (-not [String]::IsNullOrWhiteSpace($providedFileName))
            {
                $files[$currentFileName] = @{ 'filename' = $providedFileName }
            }
        }
    }

    $hashBody = @{}
    if (-not [String]::IsNullOrWhiteSpace($Description)) { $hashBody['description'] = $Description }
    if ($files.Keys.count -gt 0) { $hashBody['files'] = $files }

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Gist, $shouldProcessMessage))
    {
        return
    }

    $ConfirmPreference = 'None'
    $params = @{
        'UriFragment' = "gists/$Gist"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Patch'
        'Description' =  "Updating gist $Gist"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    try
    {
        $result = (Invoke-GHRestMethod @params |
            Add-GitHubGistAdditionalProperties -TypeName $script:GitHubGistTypeName)

        if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        {
            return $result
        }
    }
    catch
    {
        if ($_.Exception.Message -like '*(422)*')
        {
            $message = 'This error can happen if you try to delete a file that doesn''t exist.  Be aware that casing matters.  ''A.txt'' is not the same as ''a.txt''.'
            Write-Log -Message $message -Level Warning
        }

        throw
    }
}

function Set-GitHubGistFile
{
<#
    .SYNOPSIS
        Updates content of file(s) in an existing gist on GitHub,
        or adds them if they aren't already part of the gist.

    .DESCRIPTION
        Updates content of file(s) in an existing gist on GitHub,
        or adds them if they aren't already part of the gist.

        This is a helper function built on top of Set-GitHubGist.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID for the gist to update.

    .PARAMETER File
        An array of filepaths that should be part of this gist.
        Use this when you have multiple files that should be part of a gist, or when you simply
        want to reference an existing file on disk.

    .PARAMETER FileName
        The name of the file that Content should be stored in within the newly created gist.

    .PARAMETER Content
        The content of a single file that should be part of the gist.

    .PARAMETER PassThru
        Returns the updated gist.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        GitHub.Gist

    .EXAMPLE
        Set-GitHubGistFile -Gist 1234567 -Content 'Body of my file.' -FileName 'sample.txt'

        Adds a file named 'sample.txt' that has the body of "Body of my file." to the existing
        specified gist, or updates the contents of 'sample.txt' in the gist if is already there.

    .EXAMPLE
        Set-GitHubGistFile -Gist 1234567 -File 'c:\files\foo.txt'

        Adds the file 'foo.txt' to the existing specified gist, or updates its content if it
        is already there.

    .EXAMPLE
        Set-GitHubGistFile -Gist 1234567 -File ('c:\files\foo.txt', 'c:\other\bar.txt', 'c:\octocat.ps1')

        Adds all three files to the existing specified gist, or updates the contents of the files
        in the gist if they are already there.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Content',
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistTypeName})]
    [Alias('Add-GitHubGistFile')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="This is a helper method for Set-GitHubGist which will handle ShouldProcess.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ParameterSetName='FileRef',
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string[]] $File,

        [Parameter(
            Mandatory,
            ParameterSetName='Content',
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName,

        [Parameter(
            Mandatory,
            ParameterSetName='Content',
            Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string] $Content,

        [switch] $PassThru,

        [string] $AccessToken
    )

    begin
    {
        $files = @{}
    }

    process
    {
        foreach ($path in $File)
        {
            $path = Resolve-UnverifiedPath -Path $path
            if (-not (Test-Path -Path $path -PathType Leaf))
            {
                $message = "Specified file [$path] could not be found or was inaccessible."
                Write-Log -Message $message -Level Error
                throw $message
            }

            $fileName = (Get-Item -Path $path).Name
            $files[$fileName] = @{ 'filePath' = $path }
        }
    }

    end
    {
        Write-InvocationLog
        Set-TelemetryEvent -EventName $MyInvocation.MyCommand.Name

        if ($PSCmdlet.ParameterSetName -eq 'Content')
        {
            $files[$FileName] = @{ 'content' = $Content }
        }

        $params = @{
            'Gist' = $Gist
            'Update' = $files
            'PassThru' = (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
            'AccessToken' = $AccessToken
        }

        return (Set-GitHubGist @params)
    }
}

function Remove-GitHubGistFile
{
<#
    .SYNOPSIS
        Removes one or more files from an existing gist on GitHub.

    .DESCRIPTION
        Removes one or more files from an existing gist on GitHub.

        This is a helper function built on top of Set-GitHubGist.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID for the gist to update.

    .PARAMETER FileName
        An array of filenames (no paths, just names) to remove from the gist.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER PassThru
        Returns the updated gist.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        GitHub.Gist

    .EXAMPLE
        Remove-GitHubGistFile -Gist 1234567 -FileName ('foo.txt')

        Removes the file 'foo.txt' from the specified gist.

    .EXAMPLE
        Remove-GitHubGistFile -Gist 1234567 -FileName ('foo.txt') -Force

        Removes the file 'foo.txt' from the specified gist without prompting for confirmation.

    .EXAMPLE
        @('foo.txt', 'bar.txt') | Remove-GitHubGistFile -Gist 1234567

        Removes the files 'foo.txt' and 'bar.txt' from the specified gist.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistTypeName})]
    [Alias('Delete-GitHubGistFile')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="This is a helper method for Set-GitHubGist which will handle ShouldProcess.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string[]] $FileName,

        [switch] $Force,

        [switch] $PassThru,

        [string] $AccessToken
    )

    begin
    {
        $files = @()
    }

    process
    {
        foreach ($name in $FileName)
        {
            $files += $name
        }
    }

    end
    {
        Write-InvocationLog
        Set-TelemetryEvent -EventName $MyInvocation.MyCommand.Name

        $params = @{
            'Gist' = $Gist
            'Delete' = $files
            'Force' = $Force
            'Confirm' = ($Confirm -eq $true)
            'PassThru' = (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
            'AccessToken' = $AccessToken
        }

        return (Set-GitHubGist @params)
    }
}

filter Rename-GitHubGistFile
{
<#
    .SYNOPSIS
        Renames a file in a gist on GitHub.

    .DESCRIPTION
        Renames a file in a gist on GitHub.

        This is a helper function built on top of Set-GitHubGist.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Gist
        The ID for the gist to update.

    .PARAMETER FileName
        The current file in the gist to be renamed.

    .PARAMETER NewName
        The new name of the file for the gist.

    .PARAMETER PassThru
        Returns the updated gist.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Gist
        GitHub.GistComment
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary

    .OUTPUTS
        GitHub.Gist

    .EXAMPLE
        Rename-GitHubGistFile -Gist 1234567 -FileName 'foo.txt' -NewName 'bar.txt'

        Renames the file 'foo.txt' to 'bar.txt' in the specified gist.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubGistTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="This is a helper method for Set-GitHubGist which will handle ShouldProcess.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="PassThru is accessed indirectly via Resolve-ParameterWithDefaultConfigurationValue")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [Alias('GistId')]
        [ValidateNotNullOrEmpty()]
        [string] $Gist,

        [Parameter(
            Mandatory,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $FileName,

        [Parameter(
            Mandatory,
            Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string] $NewName,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog
    Set-TelemetryEvent -EventName $MyInvocation.MyCommand.Name

    $params = @{
        'Gist' = $Gist
        'Update' = @{$FileName = @{ 'fileName' = $NewName }}
        'PassThru' = (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        'AccessToken' = $AccessToken
    }

    return (Set-GitHubGist @params)
}

filter Add-GitHubGistAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Gist objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Gist
        GitHub.GistCommit
        GitHub.GistFork
        GitHub.GistSummary
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubGistTypeName})]
    [OutputType({$script:GitHubGistFormTypeName})]
    [OutputType({$script:GitHubGistSummaryTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Internal helper that is definitely adding more than one property.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [PSCustomObject[]] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubGistSummaryTypeName
    )

    if ($TypeName -eq $script:GitHubGistCommitTypeName)
    {
        return Add-GitHubGistCommitAdditionalProperties -InputObject $InputObject
    }
    elseif ($TypeName -eq $script:GitHubGistForkTypeName)
    {
        return Add-GitHubGistForkAdditionalProperties -InputObject $InputObject
    }

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            Add-Member -InputObject $item -Name 'GistId' -Value $item.id -MemberType NoteProperty -Force

            @('user', 'owner') |
                ForEach-Object {
                    if ($null -ne $item.$_)
                    {
                        $null = Add-GitHubUserAdditionalProperties -InputObject $item.$_
                    }
                }

            if ($null -ne $item.forks)
            {
                $item.forks = Add-GitHubGistForkAdditionalProperties -InputObject $item.forks
            }

            if ($null -ne $item.history)
            {
                $item.history = Add-GitHubGistCommitAdditionalProperties -InputObject $item.history
            }
        }

        Write-Output $item
    }
}

filter Add-GitHubGistCommitAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub GistCommit objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.GistCommit
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubGistCommitTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Internal helper that is definitely adding more than one property.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [PSCustomObject[]] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubGistCommitTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            $hostName = $(Get-GitHubConfiguration -Name 'ApiHostName')
            if ($item.url -match "^https?://(?:www\.|api\.|)$hostName/gists/([^/]+)/(.+)$")
            {
                $id = $Matches[1]
                $sha = $Matches[2]

                if ($sha -ne $item.version)
                {
                    $message = "The gist commit url no longer follows the expected pattern.  Please contact the PowerShellForGitHubTeam: $item.uri"
                    Write-Log -Message $message -Level Warning
                }
            }

            Add-Member -InputObject $item -Name 'GistId' -Value $id -MemberType NoteProperty -Force
            Add-Member -InputObject $item -Name 'Sha' -Value $item.version -MemberType NoteProperty -Force

            $null = Add-GitHubUserAdditionalProperties -InputObject $item.user
        }

        Write-Output $item
    }
}

filter Add-GitHubGistForkAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Gist Fork objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.GistFork
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubGistForkTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Internal helper that is definitely adding more than one property.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [PSCustomObject[]] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubGistForkTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            Add-Member -InputObject $item -Name 'GistId' -Value $item.id -MemberType NoteProperty -Force

            # See here for why we need to work with both 'user' _and_ 'owner':
            # https://github.community/t/gist-api-v3-documentation-incorrect-for-forks/122545
            @('user', 'owner') |
            ForEach-Object {
                if ($null -ne $item.$_)
                {
                    $null = Add-GitHubUserAdditionalProperties -InputObject $item.$_
                }
            }
        }

        Write-Output $item
    }
}
# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAh4sA9mSDSlaxQ
# 2s4kYld7oPdDLqa5eOOehJlvmRGoE6CCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg7nU78cZl
# tZE8hgW14yZhw4ELMnLZBNueFjtNyGVQ5yQwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCWkKpGdh9pTMuru3Bmy7ybOUXpmCKdUOlSas0XckAN
# +RqQrNEhJFpEnWwPb/O6pYCRhCSeTphg2fQjxGvIkoR/6C7QP5W1jfVgQFY4S9rq
# kYnI6KF2BOU8wIAnztvCPMw4hdESegGC2O7Z9rIdAEUZzrs0th6Ud7c1AXXOiPJR
# bekNQBuDWGcZWAWTb2rcfMF1MHjKqZGdF2njGqOEy2VQaZZ//6VucISzNY0U/DWl
# 5UC5smMUS06TKCEfaiwTlYSRVpp1L8/Ju1wDp36sQBbqo+dcTXeYlu1UoG4wcCGL
# zxIldT6zyWR1t2GgvMD8TU4etFEJPbj+bbDRi9KNlL7PoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIEZbT3V4yWRTShiWsjQ1NaAHPaCyz9E9sxRKK4vk
# vuKoAgZf25oj+xAYEzIwMjEwMTA1MTk1MDU1LjA0N1owBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpGNzdGLUUzNTYtNUJBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABKugXlviGp++jAAAA
# AAEqMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTUwMloXDTIxMDMxNzAxMTUwMlowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGNzdG
# LUUzNTYtNUJBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJ/flYGkhdJtxSsHBu9l
# mXF/UXxPF7L45nEhmtd01KDosWbY8y54BN7+k9DMvzqToP39v8/Z+NtEzKj8Bf5E
# QoG1/pJfpzCJe80HZqyqMo0oQ9EugVY6YNVNa2T1u51d96q1hFmu1dgxt8uD2g7I
# pBQdhS2tpc3j3HEzKvV/vwEr7/BcTuwqUHqrrBgHc971epVR4o5bNKsjikawmMw9
# D/tyrTciy3F9Gq9pEgk8EqJfOdAabkanuAWTjlmBhZtRiO9W1qFpwnu9G5qVvdNK
# RKxQdtxMC04pWGfnxzDac7+jIql532IEC5QSnvY84szEpxw31QW/LafSiDmAtYWH
# pm8CAwEAAaOCARswggEXMB0GA1UdDgQWBBRw9MUtdCs/rhN2y9EkE6ZI9O8TaTAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQCKwDT0CnHVo46OWyUbrPIj8QIcf+PT
# jBVYpKg1K2D15Z6xEuvmf+is6N8gj9f1nkFIALvh+iGkx8GgGa/oA9IhXNEFYPNF
# aHwHan/UEw1P6Tjdaqy3cvLC8f8zE1CR1LhXNofq6xfoT9HLGFSg9skPLM1TQ+RA
# QX9MigEm8FFlhhsQ1iGB1399x8d92h9KspqGDnO96Z9Aj7ObDtdU6RoZrsZkiRQN
# nXmnX1I+RuwtLu8MN8XhJLSl5wqqHM3rqaaMvSAISVtKySpzJC5Zh+5kJlqFdSiI
# HW8Q+8R6EWG8ILb9Pf+w/PydyK3ZTkVXUpFA+JhWjcyzphVGw9ffj0YKMIIGcTCC
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
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpG
# NzdGLUUzNTYtNUJBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUA6rLmrKHyIMP76ePl321xKUJ3YX+ggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOOfJJMwIhgPMjAyMTAxMDUyMTQ2NTlaGA8yMDIxMDEwNjIxNDY1OVowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA458kkwIBADAKAgEAAgIIkQIB/zAHAgEAAgIRmTAK
# AgUA46B2EwIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAJpK4CcEj0sxKz+y
# zqg6/4rZcyw8oOX8C1YxZAPgvRzgZg7RQbaNxp+mKHsAEnCTSwet8jijUJkcxC7g
# ToG6f4DE7pejG+7Pf2aowNUB4qxiOy4Tl1q3al1ktp/roOsDi2Cem2Q348iQLw8S
# e6eDDkRsrklPD9Czsn/zVpT3smcIMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEq6BeW+Ian76MAAAAAASowDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgWW8hN6xVaYp3/Fwh39lPc6FWcBqfd6MVIZhx7VWKICUwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBDmDWEWvc6fhs5t4Woo5Q+FMFCcaIgV4yUP4Cp
# uBmLmTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# KugXlviGp++jAAAAAAEqMCIEIH2jzt1Yv9t70Lv0ufD8m03qKX6QoK++mcXnW8K+
# YCydMA0GCSqGSIb3DQEBCwUABIIBACU2B5nJlJm7A/MAMGPaRoOMu768sbjwVxXH
# Ss6Jugyy1jPBzHhzogQkYnR3bXjUhO6cXjqZyzj1zgSbfa+rSMNMrNEuNpyCEGku
# sC6InfN6u+w5KhHHAJ8FKaUsfahEUQXGIWG0tmMnrDQAMQ5zWL/xHbSXmZ/4S8hT
# mUcQaFonzlpj2g1vgA4F9FCJZCXKr/qwLkfea9y6O9OD5wIiXPRPCH2qceiTcZam
# FJ3ne9y0G/AjVJ42ZapuHvZYViY6aCEwSEOk/8EiM2/VNaBOzCS9uHrY78PQoWSK
# K2nqc8YIiSP2o48gGjP7aiFoRCywnrbFAl4HhrrOn5pV2fS5tfA=
# SIG # End signature block
