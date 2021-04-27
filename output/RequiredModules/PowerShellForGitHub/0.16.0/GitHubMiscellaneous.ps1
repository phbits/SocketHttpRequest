# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubRateLimitTypeName = 'GitHub.RateLimit'
    GitHubLicenseTypeName = 'GitHub.License'
    GitHubEmojiTypeName = 'GitHub.Emoji'
    GitHubCodeOfConductTypeName = 'GitHub.CodeOfConduct'
    GitHubGitignoreTypeName = 'GitHub.Gitignore'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

function Get-GitHubRateLimit
{
<#
    .SYNOPSIS
        Gets the current rate limit status for the GitHub API based on the currently configured
        authentication (Access Token).

    .DESCRIPTION
        Gets the current rate limit status for the GitHub API based on the currently configured
        authentication (Access Token).

        Use Set-GitHubAuthentication to change your current authentication (Access Token).

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .OUTPUTS
        GitHub.RateLimit
        Limits returned are _per hour_.

        The Search API has a custom rate limit, separate from the rate limit
        governing the rest of the REST API. The GraphQL API also has a custom
        rate limit that is separate from and calculated differently than rate
        limits in the REST API.

        For these reasons, the Rate Limit API response categorizes your rate limit.
        Under resources, you'll see three objects:

        The core object provides your rate limit status for all non-search-related resources
        in the REST API.
        The search object provides your rate limit status for the Search API.
        The graphql object provides your rate limit status for the GraphQL API.

        Deprecation notice
        The rate object is deprecated.
        If you're writing new API client code or updating existing code,
        you should use the core object instead of the rate object.
        The core object contains the same information that is present in the rate object.

    .EXAMPLE
        Get-GitHubRateLimit
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubRateLimitTypeName})]
    param(
        [string] $AccessToken
    )

    Write-InvocationLog

    $params = @{
        'UriFragment' = 'rate_limit'
        'Method' = 'Get'
        'Description' = "Getting your API rate limit"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
    }

    $result = Invoke-GHRestMethod @params
    $result.PSObject.TypeNames.Insert(0, $script:GitHubRateLimitTypeName)
    return $result
}

function ConvertFrom-GitHubMarkdown
{
<#
    .SYNOPSIS
        Converts arbitrary Markdown into HTML.

    .DESCRIPTION
        Converts arbitrary Markdown into HTML.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Content
        The Markdown text to render to HTML.  Content must be 400 KB or less.

    .PARAMETER Mode
        The rendering mode for the Markdown content.

        Markdown - Renders Content in plain Markdown, just like README.md files are rendered

        GitHubFlavoredMarkdown - Creates links for user mentions as well as references to
        SHA-1 hashes, issues, and pull requests.

    .PARAMETER Context
        The repository to use when creating references in 'githubFlavoredMarkdown' mode.
        Specify as [ownerName]/[repositoryName].

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        [String]

    .OUTPUTS
        [String] The HTML version of the Markdown content.

    .EXAMPLE
        ConvertFrom-GitHubMarkdown -Content '**Bolded Text**' -Mode Markdown

        Returns back '<p><strong>Bolded Text</strong></p>'
#>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if ([System.Text.Encoding]::UTF8.GetBytes($_).Count -lt 400000) { $true }
            else { throw "Content must be less than 400 KB." }})]
        [string] $Content,

        [ValidateSet('Markdown', 'GitHubFlavoredMarkdown')]
        [string] $Mode = 'markdown',

        [string] $Context,

        [string] $AccessToken
    )

    begin
    {
        Write-InvocationLog

        $telemetryProperties = @{
            'Mode' = $Mode
        }

        $modeConverter = @{
            'Markdown' = 'markdown'
            'GitHubFlavoredMarkdown' = 'gfm'
        }
    }

    process
    {
        $hashBody = @{
            'text' = $Content
            'mode' = $modeConverter[$Mode]
        }

        if (-not [String]::IsNullOrEmpty($Context)) { $hashBody['context'] = $Context }

        $params = @{
            'UriFragment' = 'markdown'
            'Body' = (ConvertTo-Json -InputObject $hashBody)
            'Method' = 'Post'
            'Description' = "Converting Markdown to HTML"
            'AccessToken' = $AccessToken
            'TelemetryEventName' = $MyInvocation.MyCommand.Name
            'TelemetryProperties' = $telemetryProperties
        }

        Write-Output -InputObject (Invoke-GHRestMethod @params)
    }
}

filter Get-GitHubLicense
{
<#
    .SYNOPSIS
        Gets a license list or license content from GitHub.

    .DESCRIPTION
        Gets a license list or license content from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OwnerName
        Owner of the repository.
        If not supplied here, the DefaultOwnerName configuration property value will be used.

    .PARAMETER RepositoryName
        Name of the repository.
        If not supplied here, the DefaultRepositoryName configuration property value will be used.

    .PARAMETER Uri
        Uri for the repository.
        The OwnerName and RepositoryName will be extracted from here instead of needing to provide
        them individually.

    .PARAMETER Key
        The key of the license to retrieve the content for.  If not specified, all licenses
        will be returned.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        [String]
        GitHub.Branch
        GitHub.Content
        GitHub.Event
        GitHub.Issue
        GitHub.IssueComment
        GitHub.Label
        GitHub.Milestone
        GitHub.PullRequest
        GitHub.Project
        GitHub.ProjectCard
        GitHub.ProjectColumn
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .OUTPUTS
        GitHub.License

    .EXAMPLE
        Get-GitHubLicense

        Returns metadata about popular open source licenses

    .EXAMPLE
        Get-GitHubLicense -Key mit

        Gets the content of the mit license file

    .EXAMPLE
        Get-GitHubLicense -OwnerName microsoft -RepositoryName PowerShellForGitHub

        Gets the content of the license file for the microsoft\PowerShellForGitHub repository.
        It may be necessary to convert the content of the file.  Check the 'encoding' property of
        the result to know how 'content' is encoded.  As an example, to convert from Base64, do
        the following:

        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($result.content))
#>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType({$script:GitHubLicenseTypeName})]
    [OutputType({$script:GitHubContentTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Individual')]
        [Alias('LicenseKey')]
        [string] $Key,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    # Intentionally disabling validation because parameter sets exist that both require
    # OwnerName/RepositoryName (to get that repo's License) as well as don't (to get
    # all known Licenses).  We'll do additional parameter validation within the function.
    $elements = Resolve-RepositoryElements -DisableValidation
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $uriFragment = 'licenses'
    $description = 'Getting all licenses'

    if ($PSBoundParameters.ContainsKey('Key'))
    {
        $telemetryProperties['Key'] = $Name
        $uriFragment = "licenses/$Key"
        $description = "Getting the $Key license"
    }
    elseif ((-not [String]::IsNullOrEmpty($OwnerName)) -and (-not [String]::IsNullOrEmpty($RepositoryName)))
    {
        $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
        $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName
        $uriFragment = "repos/$OwnerName/$RepositoryName/license"
        $description = "Getting the license for $RepositoryName"
    }
    elseif ([String]::IsNullOrEmpty($OwnerName) -xor [String]::IsNullOrEmpty($RepositoryName))
    {
        $message = 'When specifying OwnerName and/or RepositorName, BOTH must be specified.'
        Write-Log -Message $message -Level Error
        throw $message
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Method' = 'Get'
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = Invoke-GHRestMethod @params
    foreach ($item in $result)
    {
        if ($PSCmdlet.ParameterSetName -in ('Elements', 'Uri'))
        {
            $null = $item | Add-GitHubContentAdditionalProperties

            # Add the decoded Base64 content directly to the object as an additional String property
            $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($item.content))
            Add-Member -InputObject $item -NotePropertyName "contentAsString" -NotePropertyValue $decoded

            $item.license.PSObject.TypeNames.Insert(0, $script:GitHubLicenseTypeName)

            if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
            {
                Add-Member -InputObject $item -Name 'LicenseKey' -Value $item.license.key -MemberType NoteProperty -Force
            }
        }
        else
        {
            $item.PSObject.TypeNames.Insert(0, $script:GitHubLicenseTypeName)
            if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
            {
                Add-Member -InputObject $item -Name 'LicenseKey' -Value $item.key -MemberType NoteProperty -Force
            }
        }
    }

    return $result
}

function Get-GitHubEmoji
{
<#
    .SYNOPSIS
        Gets all the emojis available to use on GitHub.

    .DESCRIPTION
        Gets all the emojis available to use on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .OUTPUTS
        GitHub.Emoji

    .EXAMPLE
        Get-GitHubEmoji
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubEmojiTypeName})]
    param(
        [string] $AccessToken
    )

    Write-InvocationLog

    $params = @{
        'UriFragment' = 'emojis'
        'Method' = 'Get'
        'Description' = "Getting all GitHub emojis"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
    }

    $result = Invoke-GHRestMethod @params
    $result.PSObject.TypeNames.Insert(0, $script:GitHubEmojiTypeName)
    return $result
}

filter Get-GitHubCodeOfConduct
{
<#
    .SYNOPSIS
        Gets Codes of Conduct or a specific Code of Conduct from GitHub.

    .DESCRIPTION
        Gets Codes of Conduct or a specific Code of Conduct from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OwnerName
        Owner of the repository.
        If not supplied here, the DefaultOwnerName configuration property value will be used.

    .PARAMETER RepositoryName
        Name of the repository.
        If not supplied here, the DefaultRepositoryName configuration property value will be used.

    .PARAMETER Uri
        Uri for the repository.
        The OwnerName and RepositoryName will be extracted from here instead of needing to provide
        them individually.

    .PARAMETER Key
        The unique key of the Code of Conduct to retrieve the content for.  If not specified, all
        Codes of Conduct will be returned.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        [String]
        GitHub.Branch
        GitHub.Content
        GitHub.Event
        GitHub.Issue
        GitHub.IssueComment
        GitHub.Label
        GitHub.Milestone
        GitHub.PullRequest
        GitHub.Project
        GitHub.ProjectCard
        GitHub.ProjectColumn
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .OUTPUTS
        GitHub.CodeOfConduct

    .EXAMPLE
        Get-GitHubCodeOfConduct

        Returns metadata about popular Codes of Conduct

    .EXAMPLE
        Get-GitHubCodeOfConduct -Key citizen_code_of_conduct

        Gets the content of the 'Citizen Code of Conduct'

    .EXAMPLE
        Get-GitHubCodeOfConduct -OwnerName microsoft -RepositoryName PowerShellForGitHub

        Gets the content of the Code of Conduct file for the microsoft\PowerShellForGitHub repository
        if one is detected.

        It may be necessary to convert the content of the file.  Check the 'encoding' property of
        the result to know how 'content' is encoded.  As an example, to convert from Base64, do
        the following:

        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($result.content))
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubCodeOfConductTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Individual')]
        [Alias('CodeOfConductKey')]
        [string] $Key,

        [string] $AccessToken
    )

    Write-InvocationLog

    # Intentionally disabling validation because parameter sets exist that both require
    # OwnerName/RepositoryName (to get that repo's Code of Conduct) as well as don't (to get
    # all known Codes of Conduct).  We'll do additional parameter validation within the function.
    $elements = Resolve-RepositoryElements -DisableValidation
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{}

    $uriFragment = 'codes_of_conduct'
    $description = 'Getting all Codes of Conduct'

    if ($PSBoundParameters.ContainsKey('Key'))
    {
        $telemetryProperties['Key'] = $Name
        $uriFragment = "codes_of_conduct/$Key"
        $description = "Getting the $Key Code of Conduct"
    }
    elseif ((-not [String]::IsNullOrEmpty($OwnerName)) -and (-not [String]::IsNullOrEmpty($RepositoryName)))
    {
        $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
        $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName
        $uriFragment = "repos/$OwnerName/$RepositoryName/community/code_of_conduct"
        $description = "Getting the Code of Conduct for $RepositoryName"
    }
    elseif ([String]::IsNullOrEmpty($OwnerName) -xor [String]::IsNullOrEmpty($RepositoryName))
    {
        $message = 'When specifying OwnerName and/or RepositorName, BOTH must be specified.'
        Write-Log -Message $message -Level Error
        throw $message
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Method' = 'Get'
        'AcceptHeader' = $script:scarletWitchAcceptHeader
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = Invoke-GHRestMethod @params
    foreach ($item in $result)
    {
        $item.PSObject.TypeNames.Insert(0, $script:GitHubCodeOfConductTypeName)
        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            Add-Member -InputObject $item -Name 'CodeOfConductKey' -Value $item.key -MemberType NoteProperty -Force
        }
    }

    return $result
}

filter Get-GitHubGitIgnore
{
<#
    .SYNOPSIS
        Gets the list of available .gitignore templates, or their content, from GitHub.

    .DESCRIPTION
        Gets the list of available .gitignore templates, or their content, from GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Name
        The name of the .gitignore template whose content should be fetched.
        Not providing this will cause a list of all available templates to be returned.

    .PARAMETER RawContent
        If specified, the raw content of the specified .gitignore file will be returned.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        [String]

    .OUTPUTS
        GitHub.Gitignore

    .EXAMPLE
        Get-GitHubGitIgnore

        Returns the list of all available .gitignore templates.

    .EXAMPLE
        Get-GitHubGitIgnore -Name VisualStudio

        Returns the content of the VisualStudio.gitignore template.
#>
    [CmdletBinding()]
    [OutputType({$script:GitHubGitignoreTypeName})]
    param(
        [Parameter(
            ValueFromPipeline,
            ParameterSetName='Individual')]
        [string] $Name,

        [Parameter(ParameterSetName='Individual')]
        [switch] $RawContent,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = 'gitignore/templates'
    $description = 'Getting all gitignore templates'
    if ($PSBoundParameters.ContainsKey('Name'))
    {
        $telemetryProperties['Name'] = $Name
        $uriFragment = "gitignore/templates/$Name"
        $description = "Getting $Name.gitignore"
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Method' = 'Get'
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    if ($RawContent)
    {
        $params['AcceptHeader'] = (Get-MediaAcceptHeader -MediaType 'Raw')
    }

    $result = Invoke-GHRestMethod @params
    if ($PSBoundParameters.ContainsKey('Name') -and (-not $RawContent))
    {
        $result.PSObject.TypeNames.Insert(0, $script:GitHubGitignoreTypeName)
    }

    if ($RawContent)
    {
        $result = [System.Text.Encoding]::UTF8.GetString($result)
    }

    return $result
}

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAv70/v4WwBWAtI
# EHPuWXkLoXG+DY79noz4SYvvm5mCk6CCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgvEy8+EIX
# vQIs0pYciopzZd4qy50pWoBIY8ZzJMCQkLUwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQDKAlDPswxtnogVMBT6HXcVULckyUaxf96DumwKJpWO
# t+EsrVOnDh7rLZlx6YNA3Go21YvkG+1yysft/DuwTI54QyrmM5qjbkkRa2J5qTqw
# 5CqxwFvQjzEyon4KoAGbbqzLdeI9GTIhjNKYqOgCY12ww6+o6LzkgZ7in82XRPEK
# hx0okkZ6tF44H9EPtXASC9qsLBFXFCb0ORX9ZcJlcOGx1YwCRCLJGZMevVIDOPEn
# Ubx0VlXnrufZryKKHqqA40gGVlcWAtFIjHwhQCoQRtt6fFPhR8WwaxzShCxhrduA
# fleL8N8LPvaUeSplnukqock0px/PwnCGCTjJYXNUOtBooYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIIjDExd/C7a6eroIudNtXk3by0dNIV+9d/bdzAxM
# XPloAgZf24oa5vUYEzIwMjEwMTA1MTk1MDU1LjM0NFowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjowQTU2LUUzMjktNEQ0RDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABJy9uo++RqBmoAAAA
# AAEnMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTQ1OVoXDTIxMDMxNzAxMTQ1OVowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjowQTU2
# LUUzMjktNEQ0RDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAPgB3nERnk6fS40vvWeD
# 3HCgM9Ep4xTIQiPnJXE9E+HkZVtTsPemoOyhfNAyF95E/rUvXOVTUcJFL7Xb16jT
# KPXONsCWY8DCixSDIiid6xa30TiEWVcIZRwiDlcx29D467OTav5rA1G6TwAEY5rQ
# jhUHLrOoJgfJfakZq6IHjd+slI0/qlys7QIGakFk2OB6mh/ln/nS8G4kNRK6Do4g
# xDtnBSFLNfhsSZlRSMDJwFvrZ2FCkaoexd7rKlUNOAAScY411IEqQeI1PwfRm3aW
# bS8IvAfJPC2Ah2LrtP8sKn5faaU8epexje7vZfcZif/cbxgUKStJzqbdvTBNc93n
# /Z8CAwEAAaOCARswggEXMB0GA1UdDgQWBBTl9JZVgF85MSRbYlOJXbhY022V8jAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQAKyo180VXHBqVnjZwQy7NlzXbo2+W5
# qfHxR7ANV5RBkRkdGamkwUcDNL+DpHObFPJHa0oTeYKE0Zbl1MvvfS8RtGGdhGYG
# CJf+BPd/gBCs4+dkZdjvOzNyuVuDPGlqQ5f7HS7iuQ/cCyGHcHYJ0nXVewF2Lk+J
# lrWykHpTlLwPXmCpNR+gieItPi/UMF2RYTGwojW+yIVwNyMYnjFGUxEX5/DtJjRZ
# mg7PBHMrENN2DgO6wBelp4ptyH2KK2EsWT+8jFCuoKv+eJby0QD55LN5f8SrUPRn
# K86fh7aVOfCglQofo5ABZIGiDIrg4JsV4k6p0oBSIFOAcqRAhiH+1spCMIIGcTCC
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
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjow
# QTU2LUUzMjktNEQ0RDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAs5W4TmyDHMRM7iz6mgGojqvXHzOggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOOfFGswIhgPMjAyMTAxMDUyMDM4MDNaGA8yMDIxMDEwNjIwMzgwM1owdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA458UawIBADAKAgEAAgIk0AIB/zAHAgEAAgISOTAK
# AgUA46Bl6wIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAIKb7nBUilgRcOPz
# iidP5oYD+WU6mmb4twLM3THNV07GBBxUGcI4E6zaXxCEnDdHfBsP/8L0CtI/Y0x0
# uFxMbym9cHVB+sHa2cQ7XBozHfhzSspP1TKSYgzSV1O2HgT/mmd7XABEjgTC7Wg8
# 5RCUc6LFcPW4SmU6kgLim2kUfzNQMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEnL26j75GoGagAAAAAAScwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgxwS7umK15d3WEjxtkdzOq37djkJZpDKSa8BG41uqRsowgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCAbkuhLEoYdahb/BUyVszO2VDi6kB3MSaof/+8u
# 7SM+IjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# Jy9uo++RqBmoAAAAAAEnMCIEIOjt0lAB3MK6zqPBDyYDfBZhMS+L3qQrHvC0W2OK
# enQPMA0GCSqGSIb3DQEBCwUABIIBAOUxnSdWuNvwGz3gCATzxjDPPLtEYvxinNdB
# +0045J7Y8mdoqfCftVLDEi5ghDN9oovR4EpUU5lzQwrOSzEbbLbDr3TlW/BSiftF
# C02uCUkWjeWGYtFvuKXGUP5ralx3eh1lNvOdGH/5nsmwIQejk7r8/m/lcToyruEm
# j/7nFbFbIRSC3/8s2TfwgGVfKD6CkIRV0TqI3CyTiO+gs5l4670g4P/ZJ7OQ6FB3
# 2aUSwfIpX2sUEOt7FdI5mrNrYuF/nK1j5wrGOVe+KHHLc/FVJPNLOidhlBKhPuFa
# SThpNK2ivBJjDV4Rfsji46kNNnr/EOJ5onxHGFO1mUTZUJtNMIQ=
# SIG # End signature block
