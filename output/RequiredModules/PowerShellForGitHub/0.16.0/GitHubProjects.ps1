# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubProjectTypeName = 'GitHub.Project'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubProject
{
<#
    .SYNOPSIS
        Get the projects for a given GitHub user, repository or organization.

    .DESCRIPTION
        Get the projects for a given GitHub user, repository or organization.

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

    .PARAMETER OrganizationName
        The name of the organization to get projects for.

    .PARAMETER UserName
        The name of the user to get projects for.

    .PARAMETER Project
        ID of the project to retrieve.

    .PARAMETER State
        Only projects with this state are returned.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
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
        GitHub.Project

    .EXAMPLE
        Get-GitHubProject -OwnerName microsoft -RepositoryName PowerShellForGitHub

        Get the projects for the microsoft\PowerShellForGitHub repository.

    .EXAMPLE
        Get-GitHubProject -OrganizationName Microsoft

        Get the projects for the Microsoft organization.

    .EXAMPLE
        Get-GitHubProject -Uri https://github.com/Microsoft/PowerShellForGitHub

        Get the projects for the microsoft\PowerShellForGitHub repository using the Uri.

    .EXAMPLE
        Get-GitHubProject -UserName GitHubUser

        Get the projects for the user GitHubUser.

    .EXAMPLE
        Get-GitHubProject -OwnerName microsoft -RepositoryName PowerShellForGitHub -State Closed

        Get closed projects from the microsoft\PowerShellForGitHub repo.

    .EXAMPLE
        Get-GitHubProject -Project 4378613

        Get a project by id, with this parameter you don't need any other information.
#>
    [CmdletBinding(DefaultParameterSetName = 'Elements')]
    [OutputType({$script:GitHubPullRequestTypeName})]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='ProjectObject')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Organization')]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ParameterSetName = 'User')]
        [string] $UserName,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Project')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='ProjectObject')]
        [Alias('ProjectId')]
        [int64] $Project,

        [ValidateSet('Open', 'Closed', 'All')]
        [string] $State,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = [String]::Empty
    $description = [String]::Empty
    if ($PSCmdlet.ParameterSetName -in @('Project', 'ProjectObject'))
    {
        $telemetryProperties['Project'] = Get-PiiSafeString -PlainText $Project

        $uriFragment = "/projects/$Project"
        $description = "Getting project $project"
    }
    elseif ($PSCmdlet.ParameterSetName -in ('Elements', 'Uri'))
    {
        $elements = Resolve-RepositoryElements
        $OwnerName = $elements.ownerName
        $RepositoryName = $elements.repositoryName

        $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
        $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName

        $uriFragment = "/repos/$OwnerName/$RepositoryName/projects"
        $description = "Getting projects for $RepositoryName"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Organization')
    {
        $telemetryProperties['OrganizationName'] = Get-PiiSafeString -PlainText $OrganizationName

        $uriFragment = "/orgs/$OrganizationName/projects"
        $description = "Getting projects for $OrganizationName"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'User')
    {
        $telemetryProperties['UserName'] = Get-PiiSafeString -PlainText $UserName

        $uriFragment = "/users/$UserName/projects"
        $description = "Getting projects for $UserName"
    }

    if ($PSBoundParameters.ContainsKey('State'))
    {
        $getParams = @()
        $State = $State.ToLower()
        $getParams += "state=$State"

        $uriFragment = "$uriFragment`?" + ($getParams -join '&')
        $description += " with state '$state'"
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'AcceptHeader' = $script:inertiaAcceptHeader
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubProjectAdditionalProperties)

}

filter New-GitHubProject
{
<#
    .SYNOPSIS
        Creates a new GitHub project for the given repository.

    .DESCRIPTION
        Creates a new GitHub project for the given repository.

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

    .PARAMETER OrganizationName
        The name of the organization to create the project under.

    .PARAMETER UserProject
        If this switch is specified creates a project for your user.

    .PARAMETER Name
        The name of the project to create.

    .PARAMETER Description
        Short description for the new project.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
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
        GitHub.Project

    .EXAMPLE
        New-GitHubProject -OwnerName microsoft -RepositoryName PowerShellForGitHub -ProjectName TestProject

        Creates a project called 'TestProject' for the microsoft\PowerShellForGitHub repository.

    .EXAMPLE
        New-GitHubProject -OrganizationName Microsoft -ProjectName TestProject -Description 'This is just a test project'

        Create a project for the Microsoft organization called 'TestProject' with a description.

    .EXAMPLE
        New-GitHubProject -Uri https://github.com/Microsoft/PowerShellForGitHub -ProjectName TestProject

        Create a project for the microsoft\PowerShellForGitHub repository
        using the Uri called 'TestProject'.

    .EXAMPLE
        New-GitHubProject -UserProject -ProjectName 'TestProject'

        Creates a project for the signed in user called 'TestProject'.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'Elements')]
    [OutputType({$script:GitHubPullRequestTypeName})]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Organization')]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ParameterSetName = 'User')]
        [switch] $UserProject,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [Alias('Name')]
        [string] $ProjectName,

        [string] $Description,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}
    $telemetryProperties['ProjectName'] = Get-PiiSafeString -PlainText $ProjectName

    $uriFragment = [String]::Empty
    $apiDescription = [String]::Empty
    if ($PSCmdlet.ParameterSetName -in ('Elements', 'Uri'))
    {
        $elements = Resolve-RepositoryElements
        $OwnerName = $elements.ownerName
        $RepositoryName = $elements.repositoryName

        $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
        $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName

        $uriFragment = "/repos/$OwnerName/$RepositoryName/projects"
        $apiDescription = "Creating project for $RepositoryName"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Organization')
    {
        $telemetryProperties['OrganizationName'] = Get-PiiSafeString -PlainText $OrganizationName

        $uriFragment = "/orgs/$OrganizationName/projects"
        $apiDescription = "Creating project for $OrganizationName"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'User')
    {
        $telemetryProperties['User'] = $true

        $uriFragment = "/user/projects"
        $apiDescription = "Creating project for user"
    }

    $hashBody = @{
        'name' = $ProjectName
    }

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $hashBody.add('body', $Description)
    }

    if (-not $PSCmdlet.ShouldProcess($ProjectName, 'Create GitHub Project'))
    {
        return
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Post'
        'Description' = $apiDescription
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'AcceptHeader' = $script:inertiaAcceptHeader
    }

    return (Invoke-GHRestMethod @params | Add-GitHubProjectAdditionalProperties)
}

filter Set-GitHubProject
{
<#
    .SYNOPSIS
        Modify a GitHub Project.

    .DESCRIPTION
        Modify a GitHub Project.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Project
        ID of the project to modify.

    .PARAMETER Description
        Short description for the project.

    .PARAMETER State
        Set the state of the project.

    .PARAMETER OrganizationPermission
        Set the permission level that determines whether all members of the project's
        organization can see and/or make changes to the project.
        Only available for organization projects.

    .PARAMETER Private
        Sets the visibility of a project board.
        Only available for organization and user projects.
        Note: Updating a project's visibility requires admin access to the project.

    .PARAMETER PassThru
        Returns the updated Project.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
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
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .OUTPUTS
        GitHub.Project

    .EXAMPLE
        Set-GitHubProject -Project 999999 -State Closed

        Set the project with ID '999999' to closed.

    .EXAMPLE
        $project = Get-GitHubProject -OwnerName microsoft -RepositoryName PowerShellForGitHub | Where-Object Name -eq 'TestProject'
        Set-GitHubProject -Project $project.id -State Closed

        Get the ID for the 'TestProject' project for the microsoft\PowerShellForGitHub
        repository and set state to closed.
#>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType({$script:GitHubPullRequestTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [Alias('ProjectId')]
        [int64] $Project,

        [string] $Description,

        [ValidateSet('Open', 'Closed')]
        [string] $State,

        [ValidateSet('Read', 'Write', 'Admin', 'None')]
        [string] $OrganizationPermission,

        [switch] $Private,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = "projects/$Project"
    $apiDescription = "Updating project $Project"

    $hashBody = @{}

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $hashBody.add('body', $Description)
        $apiDescription += " description"
    }

    if ($PSBoundParameters.ContainsKey('State'))
    {
        $hashBody.add('state', $State)
        $apiDescription += ", state to '$State'"
    }

    if ($PSBoundParameters.ContainsKey('Private'))
    {
       $hashBody.add('private', $Private.ToBool())
       $apiDescription += ", private to '$Private'"
    }

    if ($PSBoundParameters.ContainsKey('OrganizationPermission'))
    {
        $hashBody.add('organization_permission', $OrganizationPermission.ToLower())
        $apiDescription += ", organization_permission to '$OrganizationPermission'"
    }

    if (-not $PSCmdlet.ShouldProcess($Project, 'Set GitHub Project'))
    {
        return
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $apiDescription
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'AccessToken' = $AccessToken
        'Method' = 'Patch'
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'AcceptHeader' = $script:inertiaAcceptHeader
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubProjectAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Remove-GitHubProject
{
<#
    .SYNOPSIS
        Removes the projects for a given GitHub repository.

    .DESCRIPTION
        Removes the projects for a given GitHub repository.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Project
        ID of the project to remove.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
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
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .EXAMPLE
        Remove-GitHubProject -Project 4387531

        Remove project with ID '4387531'.

    .EXAMPLE
        Remove-GitHubProject -Project 4387531 -Confirm:$false

        Remove project with ID '4387531' without prompting for confirmation.

    .EXAMPLE
        Remove-GitHubProject -Project 4387531 -Force

        Remove project with ID '4387531' without prompting for confirmation.

    .EXAMPLE
        $project = Get-GitHubProject -OwnerName microsoft -RepositoryName PowerShellForGitHub | Where-Object Name -eq 'TestProject'
        Remove-GitHubProject -Project $project.id

        Get the ID for the 'TestProject' project for the microsoft\PowerShellForGitHub
        repository and then remove the project.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High')]
    [Alias('Delete-GitHubProject')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('ProjectId')]
        [int64] $Project,

        [switch] $Force,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = "projects/$Project"
    $description = "Deleting project $Project"

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Project, 'Remove GitHub Project'))
    {
        return
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AccessToken' = $AccessToken
        'Method' = 'Delete'
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'AcceptHeader' = $script:inertiaAcceptHeader
    }

    return Invoke-GHRestMethod @params
}

filter Add-GitHubProjectAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Project objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Project
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
        [string] $TypeName = $script:GitHubProjectTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            $elements = Split-GitHubUri -Uri $item.html_url
            $repositoryUrl = Join-GitHubUri @elements

            # A "user" project has no associated repository, and adding this in that scenario
            # would cause API-level errors with piping further on,
            if ($elements.OwnerName -ne 'users')
            {
                Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force
            }

            Add-Member -InputObject $item -Name 'ProjectId' -Value $item.id -MemberType NoteProperty -Force

            if ($null -ne $item.creator)
            {
                $null = Add-GitHubUserAdditionalProperties -InputObject $item.creator
            }
        }

        Write-Output $item
    }
}

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDQ3d5+qgotrcB5
# I6J9ONTJE0UpjTnDxJSzoVM78HpOu6CCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgf3P2lB9Z
# m9PxvvQTlGhzDKJG1DNBs0LzmKdmbo8fw4owQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBP9HeNxQlLug2ioCV1R3Apqoun+qZCzzmgwxWMW0+U
# AGIEQ0J8iDvW5jiwlEE0qtJxBpdPQ34iQZMUxXx/MwLQ1vdrCOvNBzSxfgidHsVN
# DFaB4AHCIlswlsfMFzzh6ekHPAXbZIgLl6ZnqB7jfRgKTuH6znWfyMFrRiJnHQqp
# TSBSwhIvcY2dalwKAOmBRragGjhnsS93da9yYrvK/toTLysdHWJEuaBk9i71/q6G
# 9eUHodMhCD+M5FdJpaM1TRKNzke2jnvehjwVNKd9eDtWQyrAkStECkufZXWr6vFC
# pDqNsGJyeOUn4UyFAbjiSV5rkzpp2x7CBYzCppFKu2IpoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIM7jds5o/eJ9ZbLkpV224FoSAr6Wh4Wv0TWPWZ08
# 9cAmAgZf25dxEbwYEzIwMjEwMTA1MTk1MDUzLjg4NFowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpEOURFLUUzOUEtNDNGRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABLS5NQcpjZTOgAAAA
# AAEtMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTUwNFoXDTIxMDMxNzAxMTUwNFowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpEOURF
# LUUzOUEtNDNGRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKlhjfR1STqYRTS3s0i4
# jIcSMV+G4N0oYgwlQK+pl4DVMFmr1iTZHFLj3Tt7V6F+M/BXx0h9i0uu1yBnqCqN
# OkuJERTbVnM4u3JvRxzsQfCjBfqD/CNwoMNekoylIBzxP50Skjp1pPsnQBKHaCP8
# tguvYVzoTQ54q2VpYEP/+OYTQeEPqWFi8WggvsckuercUGkhYWM8DV/4JU7N/rbD
# rtamYbe8LtkViTQYbigUSCAor9DhtAZvq8A0A73XFH2df2wDlLtAnKCcsVvXSmZ3
# 5bAqneN4uEQVy8NQdReGI1tI6UxoC7XnjGvK4McDdKhavNJ7DAnSP5+G/DTkdWD+
# lN8CAwEAAaOCARswggEXMB0GA1UdDgQWBBTZbGR8QgEh+E4Oiv8vQ7408p2GzTAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQB9awNk906recBuoO7Ezq7B8UGu9EoF
# XiL8ac0bbsZDBY9z/3p8atVZRCxHN43a3WGbCMZoKYxSBH6UCkcDcwXIfNKEbVMz
# nF1mjpQEGbqhR+rPNqHXZotSV+vn85AxmefAM3bcLt+WNBpEuOZZ4kPZVcFtMo4Y
# yQjxoNRPiwmp+B0HkhQs/l/VIg0XJY6k5FRKE/JFEcVY4256NdqUZ+3jou3b4OAk
# tE2urr4V6VRw1fffOlxZb8MyvE5mqvTVJOStVxCuhuqg1rIe8la1gZ5iiuIyWeft
# ONfMw0nSZchGLigDeInw6XfwwgFnC5Ql8Pbf2jOxCUluAYbzykI+MnBiMIIGcTCC
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
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpE
# OURFLUUzOUEtNDNGRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAn85fx36He7F0vgmyUlz2w82l0LGggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOOfIewwIhgPMjAyMTAxMDUyMTM1NDBaGA8yMDIxMDEwNjIxMzU0MFowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA458h7AIBADAKAgEAAgIuIQIB/zAHAgEAAgIRDTAK
# AgUA46BzbAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAEwNzs/lhNTkxnjQ
# E0cP/1bNMFwmu8JTPicz/v5qyE9PXMssHEpJRE7rf266ipAvWjR6dRtU7GyUAGS2
# 07St74tkJt9R10f9R/RkV5LNITN/PFC5KCIUe/HIEhLegkpe2ZecLGfPkDnxIWHx
# c2QlBOIuQszg6fyrmvPM/VnXb/XoMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEtLk1BymNlM6AAAAAAAS0wDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgW49pWj7jqhd2je9ARxDLCaJe0thBHA7VRJho99BFcOMwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCCO8Vpycn0gB4/ilRAPPDbS+Cmbqj/uC011moc5
# oeGDwTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# LS5NQcpjZTOgAAAAAAEtMCIEIKCwLleqLz6zScDfjPL7hO83mrVe1ihvaUe23CWp
# tV7RMA0GCSqGSIb3DQEBCwUABIIBAERxRnqj1pgOj4h9mocw60XKCMO5oYxMPku/
# o4H15nQ6wAg5a3xcVl/fBpbft+WSZci+o2IIDYm7FnfHjes1eUTH3kBKiDHan1oI
# gzkLVTwZAiWx0IJCoYPJq9YbYkIqHLBNTkyMOis/LONNObRw+CYxH4aP5fhYO1qI
# BIoHZ35WBdXPcNZ6DjUivmU42uFCuJS0vhPKu61jEUvVbr/m/F2TYCMDpfeQ2WOJ
# lESS8Ab/MyyyI2GCCkNjv8UymDwMHfv+bh25ylq3CW9Kz4d5cljJRoKd9FleeDlN
# rNwSeDHB3GwRPS/mmuB5mKt89TrbnhHLuphQ+EMQzxo6yHBuJlU=
# SIG # End signature block
