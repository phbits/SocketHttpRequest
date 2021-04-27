# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubUserTypeName = 'GitHub.User'
    GitHubUserContextualInformationTypeName = 'GitHub.UserContextualInformation'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubUser
{
<#
    .SYNOPSIS
        Retrieves information about the specified user on GitHub.

    .DESCRIPTION
        Retrieves information about the specified user on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER UserName
        The GitHub user to retrieve information for.
        If not specified, will retrieve information on all GitHub users
        (and may take a while to complete).

    .PARAMETER Current
        If specified, gets information on the current user.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .NOTES
        The email key in the following response is the publicly visible email address from the
        user's GitHub profile page.  You only see publicly visible email addresses when
        authenticated with GitHub.

        When setting up your profile, a user can select a primary email address to be public
        which provides an email entry for this endpoint.  If the user does not set a public
        email address for email, then it will have a value of null.

    .INPUTS
        GitHub.User

    .OUTPUTS
        GitHub.User

    .EXAMPLE
        Get-GitHubUser -UserName octocat

        Gets information on just the user named 'octocat'

    .EXAMPLE
        'octocat', 'PowerShellForGitHubTeam' | Get-GitHubUser

        Gets information on the users named 'octocat' and 'PowerShellForGitHubTeam'

    .EXAMPLE
        Get-GitHubUser

        Gets information on every GitHub user.

    .EXAMPLE
        Get-GitHubUser -Current

        Gets information on the current authenticated user.
#>
    [CmdletBinding(DefaultParameterSetName = 'ListAndSearch')]
    [OutputType({$script:GitHubUserTypeName})]
    param(
        [Parameter(
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            ParameterSetName='ListAndSearch')]
        [Alias('Name')]
        [Alias('User')]
        [string] $UserName,

        [Parameter(ParameterSetName='Current')]
        [switch] $Current,

        [string] $AccessToken
    )

    Write-InvocationLog

    $params = @{
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
    }

    if ($Current)
    {
        return (Invoke-GHRestMethod -UriFragment "user" -Description "Getting current authenticated user" -Method 'Get' @params |
            Add-GitHubUserAdditionalProperties)
    }
    elseif ([String]::IsNullOrEmpty($UserName))
    {
        return (Invoke-GHRestMethodMultipleResult -UriFragment 'users' -Description 'Getting all users' @params |
            Add-GitHubUserAdditionalProperties)
    }
    else
    {
        return (Invoke-GHRestMethod -UriFragment "users/$UserName" -Description "Getting user $UserName" -Method 'Get' @params |
            Add-GitHubUserAdditionalProperties)
    }
}

filter Get-GitHubUserContextualInformation
{
<#
    .SYNOPSIS
        Retrieves contextual information about the specified user on GitHub.

    .DESCRIPTION
        Retrieves contextual information about the specified user on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER User
        The GitHub user to retrieve information for.

    .PARAMETER OrganizationId
        The ID of an Organization.  When provided, this returns back the context for the user
        in relation to this Organization.

    .PARAMETER RepositoryId
        The ID for a Repository.  When provided, this returns back the context for the user
        in relation to this Repository.

    .PARAMETER IssueId
        The ID for a Issue.  When provided, this returns back the context for the user
        in relation to this Issue.
        NOTE: This is the *id* of the issue and not the issue *number*.

    .PARAMETER PullRequestId
        The ID for a PullRequest.  When provided, this returns back the context for the user
        in relation to this Pull Request.
        NOTE: This is the *id* of the pull request and not the pull request *number*.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Issue
        GitHub.Organization
        GitHub.PullRequest
        GitHub.Repository
        GitHub.User

    .OUTPUTS
        GitHub.UserContextualInformation

    .EXAMPLE
        Get-GitHubUserContextualInformation -User octocat

    .EXAMPLE
        Get-GitHubUserContextualInformation -User octocat -RepositoryId 1300192

    .EXAMPLE
        $repo = Get-GitHubRepository -OwnerName microsoft -RepositoryName 'PowerShellForGitHub'
        $repo | Get-GitHubUserContextualInformation -User octocat

    .EXAMPLE
        Get-GitHubIssue -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 70 |
            Get-GitHubUserContextualInformation -User octocat
#>
    [CmdletBinding(DefaultParameterSetName = 'NoContext')]
    [OutputType({$script:GitHubUserContextualInformationTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [Alias('User')]
        [string] $UserName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Organization')]
        [int64] $OrganizationId,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Repository')]
        [int64] $RepositoryId,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Issue')]
        [int64] $IssueId,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='PullRequest')]
        [int64] $PullRequestId,

        [string] $AccessToken
    )

    Write-InvocationLog

    $getParams = @()

    $contextType = [String]::Empty
    $contextId = 0
    if ($PSCmdlet.ParameterSetName -ne 'NoContext')
    {
        if ($PSCmdlet.ParameterSetName -eq 'Organization')
        {
            $getParams += 'subject_type=organization'
            $getParams += "subject_id=$OrganizationId"

            $contextType = 'OrganizationId'
            $contextId = $OrganizationId
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Repository')
        {
            $getParams += 'subject_type=repository'
            $getParams += "subject_id=$RepositoryId"

            $contextType = 'RepositoryId'
            $contextId = $RepositoryId
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Issue')
        {
            $getParams += 'subject_type=issue'
            $getParams += "subject_id=$IssueId"

            $contextType = 'IssueId'
            $contextId = $IssueId
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'PullRequest')
        {
            $getParams += 'subject_type=pull_request'
            $getParams += "subject_id=$PullRequestId"

            $contextType = 'PullRequestId'
            $contextId = $PullRequestId
        }
    }

    $params = @{
        'UriFragment' = "users/$UserName/hovercard`?" + ($getParams -join '&')
        'Method' = 'Get'
        'Description' = "Getting hovercard information for $UserName"
        'AcceptHeader' = $script:hagarAcceptHeader
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
    }

    $result = Invoke-GHRestMethod @params
    foreach ($item in $result.contexts)
    {
        $item.PSObject.TypeNames.Insert(0, $script:GitHubUserContextualInformationTypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            Add-Member -InputObject $item -Name 'UserName' -Value $UserName -MemberType NoteProperty -Force
            if ($PSCmdlet.ParameterSetName -ne 'NoContext')
            {
                Add-Member -InputObject $item -Name $contextType -Value $contextId -MemberType NoteProperty -Force
            }
        }
    }

    return $result
}

function Set-GitHubProfile
{
<#
    .SYNOPSIS
        Updates profile information for the current authenticated user on GitHub.

    .DESCRIPTION
        Updates profile information for the current authenticated user on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Name
        The new name of the user.

    .PARAMETER Email
        The publicly visible email address of the user.

    .PARAMETER Blog
        The new blog URL of the user.

    .PARAMETER Company
        The new company of the user.

    .PARAMETER Location
        The new location of the user.

    .PARAMETER Bio
        The new short biography of the user.

    .PARAMETER Hireable
        Specify to indicate a change in hireable availability for the current authenticated user's
        GitHub profile.  To change to "not hireable", specify -Hireable:$false

    .PARAMETER PassThru
        Returns the updated User Profile.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .OUTPUTS
        GitHub.User

    .EXAMPLE
        Set-GitHubProfile -Location 'Seattle, WA' -Hireable:$false

        Updates the current user to indicate that their location is "Seattle, WA" and that they
        are not currently hireable.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType({$script:GitHubUserTypeName})]
    [Alias('Update-GitHubCurrentUser')] # Non-standard usage of the Update verb, but done to avoid a breaking change post 0.14.0
    param(
        [string] $Name,

        [string] $Email,

        [string] $Blog,

        [string] $Company,

        [string] $Location,

        [string] $Bio,

        [switch] $Hireable,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    $hashBody = @{}
    if ($PSBoundParameters.ContainsKey('Name')) { $hashBody['name'] = $Name }
    if ($PSBoundParameters.ContainsKey('Email')) { $hashBody['email'] = $Email }
    if ($PSBoundParameters.ContainsKey('Blog')) { $hashBody['blog'] = $Blog }
    if ($PSBoundParameters.ContainsKey('Company')) { $hashBody['company'] = $Company }
    if ($PSBoundParameters.ContainsKey('Location')) { $hashBody['location'] = $Location }
    if ($PSBoundParameters.ContainsKey('Bio')) { $hashBody['bio'] = $Bio }
    if ($PSBoundParameters.ContainsKey('Hireable')) { $hashBody['hireable'] = $Hireable.ToBool() }

    if (-not $PSCmdlet.ShouldProcess('Update Current GitHub User'))
    {
        return
    }

    $params = @{
        'UriFragment' = 'user'
        'Method' = 'Patch'
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Description' = "Updating current authenticated user"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubUserAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Add-GitHubUserAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub User objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .PARAMETER Name
        The name of the user.  This information might be obtainable from InputObject, so this
        is optional based on what InputObject contains.

    .PARAMETER Id
        The ID of the user.  This information might be obtainable from InputObject, so this
        is optional based on what InputObject contains.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.User
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Internal helper that is definitely adding more than one property.")]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [PSCustomObject[]] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubUserTypeName,

        [string] $Name,

        [int64] $Id
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            $userName = $item.login
            if ([String]::IsNullOrEmpty($userName) -and $PSBoundParameters.ContainsKey('Name'))
            {
                $userName = $Name
            }

            if (-not [String]::IsNullOrEmpty($userName))
            {
                Add-Member -InputObject $item -Name 'UserName' -Value $userName -MemberType NoteProperty -Force
            }

            $userId = $item.id
            if (($userId -eq 0) -and $PSBoundParameters.ContainsKey('Id'))
            {
                $userId = $Id
            }

            if ($userId -ne 0)
            {
                Add-Member -InputObject $item -Name 'UserId' -Value $userId -MemberType NoteProperty -Force
            }
        }

        Write-Output $item
    }
}

# SIG # Begin signature block
# MIIjkAYJKoZIhvcNAQcCoIIjgTCCI30CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAIWCae/xRqMZJo
# sHzkkJ+kEVjUD7WbX+Ykk+yk9G6idaCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVZTCCFWECAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAYdyF3IVWUDHCQAAAAABhzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgCPX7KibA
# GCrs/P8r3lsy2xCK+sObhVGHwlrlEm69LYIwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQDL9zChwXv4s+JGIRp3njv7I6csOFTcX4LmafQO0wcc
# mfiJxO9/0PYbtzDfBrIjNut5x+WL+x9cvmktlQW3zm4VxfS76D1dSqU6rkTrkoLM
# zHhvMtIdyqlkWBMGfi0lUTvy5KXH39wAJkSSXExbLYnb+qPrX051SAjXExr0n7lK
# 9fcYD3aet20T4XHBUAQdv2M0cqbhvKTH1hUp4bjqJR1NKUqJ4brwMxzy/qlkZNi6
# 79dLXHHi7AnuqHjvDibTXEGkHaqKDLQ/GJWRJK6Hi6MRt2JHyxBvymjz48S50FAg
# FgELG13m7kOzWAT8k3OdxAiR/8dMigoN+k8vrhwd/+f1oYIS7zCCEusGCisGAQQB
# gjcDAwExghLbMIIS1wYJKoZIhvcNAQcCoIISyDCCEsQCAQMxDzANBglghkgBZQME
# AgEFADCCAVMGCyqGSIb3DQEJEAEEoIIBQgSCAT4wggE6AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEINaAqdpTerSkBhia1IkDVHke4ujRONtsJ7kOw+YQ
# ooapAgZf25d7xzYYETIwMjEwMTA1MTk1MTU0LjlaMASAAgH0oIHUpIHRMIHOMQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNy
# b3NvZnQgT3BlcmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRT
# UyBFU046Rjg3QS1FMzc0LUQ3QjkxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0
# YW1wIFNlcnZpY2Wggg5EMIIE9TCCA92gAwIBAgITMwAAAS+xpxd5VpQXhwAAAAAB
# LzANBgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAe
# Fw0xOTEyMTkwMTE1MDZaFw0yMTAzMTcwMTE1MDZaMIHOMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3BlcmF0
# aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046Rjg3QS1F
# Mzc0LUQ3QjkxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2Uw
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCofFZL1SMFw/LJ9M09pxHc
# hGfVDR2OwAmzmQOKGwB7w9YWrsPStWdpUVhvpvAK7PZd+RqDF3T4LITN4WSkFn4a
# y5xffxg2aIpYXNi4TKjT17NOqwCfGDgweotAoNQhQmJ8jmL8sFymN8RiTdPQ4D11
# n3MxJtj/2t65q1zKyuRBXN2ocawudXPlLgDClfcScsyVS0oT8DwSZfgo3TAzyX9u
# A2VyGHnN4AjdsXmp9QxQiNIGqiaazHi+DptSmNgGTCIATxJKGNTewCOXu8m5CC/P
# jM94p4o2+Kw05F5POs7VMMuG3XNTMinto9qHU/kCAwNvjPHDEyBpSp+xMg9jTV1P
# AgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUppf1UaQTRZADA4qnKKlovOY/6pYwHwYD
# VR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZF
# aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGlt
# U3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcw
# AoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQ
# Q0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEF
# BQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAeKuopb9kpRryQ/+3W36CCmQTtoumAMHJ
# MOe06Qq7dvkgMdnXBeyb0TAj4SwkoKo8jXCUbONHBFz2y3c2TCR83L+9wBey+plm
# V4NmgYxtUnOajOI4xP58CF/guv6HZuf2rFOCSJRQrlGY86nYq9fB5EVUL3th8FdJ
# Qlx0LPld5vQ8sgPW+i0iJNxjhWbuxddVssf+XVV4rDz0z8IfSV3zA/Vte9zNfmWc
# nJjtN5VHOBtRYpYKcVjXYFp/wzvWYaFucjevgVHXZyeHAnAo3IPLAea5LTz/KVWQ
# EO2lKpAHqqPhbgpAFAHSUREgqUecIEj7VbxTzIzjRN+g2yrX85H4hzCCBnEwggRZ
# oAMCAQICCmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1
# MDcwMTIxNDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ
# 1aUKAIKF++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP
# 8WCIhFRDDNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRh
# Z5FfgVSxz5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39
# dx898Fd1rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2
# iAg16HgcsOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGj
# ggHmMIIB4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xG
# G8UzaFqFbVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGG
# MA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186a
# GMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsG
# AQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraS9jZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB
# /wSBlTCBkjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUF
# BwICMDQeMiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0A
# ZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFv
# s+umzPUxvs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5
# U4zM9GASinbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFS
# AK84Dxf1L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1V
# ry/+tuWOM7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6
# f32WapB4pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35j
# WSUPei45V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHa
# sFAeb73x4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLN
# HfS4hQEegPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4
# sanblrKnQqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHX
# odLFVeNp3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUe
# CLraNtvTX4/edIhJEqGCAtIwggI7AgEBMIH8oYHUpIHRMIHOMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSkwJwYDVQQLEyBNaWNyb3NvZnQgT3Bl
# cmF0aW9ucyBQdWVydG8gUmljbzEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046Rjg3
# QS1FMzc0LUQ3QjkxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZp
# Y2WiIwoBATAHBgUrDgMCGgMVADPwmQlKXJUPan6/698vaLCCD0pkoIGDMIGApH4w
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwDQYJKoZIhvcNAQEFBQACBQDj
# nyHvMCIYDzIwMjEwMTA1MjEzNTQzWhgPMjAyMTAxMDYyMTM1NDNaMHcwPQYKKwYB
# BAGEWQoEATEvMC0wCgIFAOOfIe8CAQAwCgIBAAICKCgCAf8wBwIBAAICEPkwCgIF
# AOOgc28CAQAwNgYKKwYBBAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAqAKMAgCAQAC
# AwehIKEKMAgCAQACAwGGoDANBgkqhkiG9w0BAQUFAAOBgQBwmsS0XVhqQ59bAzPW
# tWq37QlHUxCu91lUF4t0wmEyeoM9Tr/aeQ1mmlTKgfyz34j4OGEOPI5NxHhMwYUb
# OU00nu20yqr3jcU8FZbAripUAeuA1KduvYTRbry7eUjCF0s7wFIj9RfwlSiMV/Vw
# m4QwbzvyTJuGmCcXkB3zisM1gDGCAw0wggMJAgEBMIGTMHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAABL7GnF3lWlBeHAAAAAAEvMA0GCWCGSAFlAwQC
# AQUAoIIBSjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwLwYJKoZIhvcNAQkE
# MSIEIAT/W9sZbekFv5Uk7uACV4F0DguL8ZisROKlrrpZHVzkMIH6BgsqhkiG9w0B
# CRACLzGB6jCB5zCB5DCBvQQgQuUXnBmb7oJ71V4PNM5axr9bld+SzZPh/XQY9woR
# T70wgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAS+x
# pxd5VpQXhwAAAAABLzAiBCB6i2rXWAWGpgtnWZbqyQstcbuau/osvHzisC0tbQtV
# 2jANBgkqhkiG9w0BAQsFAASCAQAfVR2+DEqs2b32fpBnrZgGP6M4T9XyQ6/n/nm4
# whOt9nGlAGhk+lb8Q2Cq64OSVO6kWBqVQO5godWqKSgKyttcp8vgpJ3G/cVdvhkz
# kDiHOsDW0C/DBUXTrTslHIRvpOwR6qe2p3KJU/ynvGYeuGQZMyqWgR7dnLZx85t0
# rrs0gFvtcisGQQqWOLyBofKcsvuSFCorBVsnETzSCBeX78GFAMZ98Iq6lz96Zqqo
# tc3+76X9p2q9jQcLu9ODE0gyGAigAJiq9OGx5+YixghScZPuAo94AznM6oIQ/2yb
# Y+SMLpXAupwXqyy5ZYxcy9Zmz8ZMLQdkhMwfdhClBLYeginE
# SIG # End signature block
