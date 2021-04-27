# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubTeamTypeName = 'GitHub.Team'
    GitHubTeamSummaryTypeName = 'GitHub.TeamSummary'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubTeam
{
<#
    .SYNOPSIS
        Retrieve a team or teams within an organization or repository on GitHub.

    .DESCRIPTION
        Retrieve a team or teams within an organization or repository on GitHub.

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
        The name of the organization.

    .PARAMETER TeamName
        The name of the specific team to retrieve.
        Note: This will be slower than querying by TeamSlug since it requires retrieving
        all teams first.

    .PARAMETER TeamSlug
        The slug (a unique key based on the team name) of the specific team to retrieve.

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
        GitHub.Organization
        GitHub.PullRequest
        GitHub.Project
        GitHub.ProjectCard
        GitHub.ProjectColumn
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository
        GitHub.Team

    .OUTPUTS
        GitHub.Team
        GitHub.TeamSummary

    .EXAMPLE
        Get-GitHubTeam -OrganizationName PowerShell
#>
    [CmdletBinding(DefaultParameterSetName = 'Elements')]
    [OutputType(
        {$script:GitHubTeamTypeName},
        {$script:GitHubTeamSummaryTypeName})]
    param
    (
        [Parameter(ParameterSetName='Elements')]
        [Parameter(ParameterSetName='TeamName')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [Parameter(ParameterSetName='TeamName')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName='TeamName')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Organization')]
        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName='TeamName')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='TeamSlug')]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ParameterSetName='TeamName')]
        [ValidateNotNullOrEmpty()]
        [string] $TeamName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='TeamSlug')]
        [ValidateNotNullOrEmpty()]
        [string] $TeamSlug,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = [String]::Empty
    $description = [String]::Empty
    $teamType = [String]::Empty

    if ($PSBoundParameters.ContainsKey('TeamName') -and
        (-not $PSBoundParameters.ContainsKey('OrganizationName')))
    {
        $elements = Resolve-RepositoryElements
        $OwnerName = $elements.ownerName
        $RepositoryName = $elements.repositoryName
    }

    if ((-not [String]::IsNullOrEmpty($OwnerName)) -and
        (-not [String]::IsNullOrEmpty($RepositoryName)))
    {
        $telemetryProperties['OwnerName'] = Get-PiiSafeString -PlainText $OwnerName
        $telemetryProperties['RepositoryName'] = Get-PiiSafeString -PlainText $RepositoryName

        $uriFragment = "/repos/$OwnerName/$RepositoryName/teams"
        $description = "Getting teams for $RepositoryName"
        $teamType = $script:GitHubTeamSummaryTypeName
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'TeamSlug')
    {
        $telemetryProperties['TeamSlug'] = Get-PiiSafeString -PlainText $TeamSlug

        $uriFragment = "/orgs/$OrganizationName/teams/$TeamSlug"
        $description = "Getting team $TeamSlug"
        $teamType = $script:GitHubTeamTypeName
    }
    else
    {
        $telemetryProperties['OrganizationName'] = Get-PiiSafeString -PlainText $OrganizationName

        $uriFragment = "/orgs/$OrganizationName/teams"
        $description = "Getting teams in $OrganizationName"
        $teamType = $script:GitHubTeamSummaryTypeName
    }

    $params = @{
        'UriFragment' = $uriFragment
        'AcceptHeader' = $script:hellcatAcceptHeader
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = Invoke-GHRestMethodMultipleResult @params |
        Add-GitHubTeamAdditionalProperties -TypeName $teamType

    if ($PSBoundParameters.ContainsKey('TeamName'))
    {
        $team = $result | Where-Object -Property name -eq $TeamName

        if ($null -eq $team)
        {
            $message = "Team '$TeamName' not found"
            Write-Log -Message $message -Level Error
            throw $message
        }
        else
        {
            $uriFragment = "/orgs/$($team.OrganizationName)/teams/$($team.slug)"
            $description = "Getting team $($team.slug)"

            $params = @{
                UriFragment = $uriFragment
                Description =  $description
                Method = 'Get'
                AccessToken = $AccessToken
                TelemetryEventName = $MyInvocation.MyCommand.Name
                TelemetryProperties = $telemetryProperties
            }

            $result = Invoke-GHRestMethod @params | Add-GitHubTeamAdditionalProperties
        }
    }

    return $result
}

filter Get-GitHubTeamMember
{
<#
    .SYNOPSIS
        Retrieve list of team members within an organization.

    .DESCRIPTION
        Retrieve list of team members within an organization.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OrganizationName
        The name of the organization.

    .PARAMETER TeamName
        The name of the team in the organization.

    .PARAMETER TeamSlug
        The slug (a unique key based on the team name) of the team in the organization.

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
        GitHub.Team

    .OUTPUTS
        GitHub.User

    .EXAMPLE
        $members = Get-GitHubTeamMember -Organization PowerShell -TeamName Everybody
#>
    [CmdletBinding(DefaultParameterSetName = 'Slug')]
    [OutputType({$script:GitHubUserTypeName})]
    param
    (
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String] $OrganizationName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Name')]
        [ValidateNotNullOrEmpty()]
        [String] $TeamName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Slug')]
        [string] $TeamSlug,

        [string] $AccessToken
    )

    Write-InvocationLog

    if ($PSCmdlet.ParameterSetName -eq 'Name')
    {
        $teams = Get-GitHubTeam -OrganizationName $OrganizationName -AccessToken $AccessToken
        $team = $teams | Where-Object {$_.name -eq $TeamName}
        if ($null -eq $team)
        {
            $message = "Unable to find the team [$TeamName] within the organization [$OrganizationName]."
            Write-Log -Message $message -Level Error
            throw $message
        }

        $TeamSlug = $team.slug
    }

    $telemetryProperties = @{
        'OrganizationName' = (Get-PiiSafeString -PlainText $OrganizationName)
        'TeamName' = (Get-PiiSafeString -PlainText $TeamName)
        'TeamSlug' = (Get-PiiSafeString -PlainText $TeamSlug)
    }

    $params = @{
        'UriFragment' = "orgs/$OrganizationName/teams/$TeamSlug/members"
        'Description' = "Getting members of team $TeamSlug"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubUserAdditionalProperties)
}

function New-GitHubTeam
{
<#
    .SYNOPSIS
        Creates a team within an organization on GitHub.

    .DESCRIPTION
        Creates a team within an organization on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OrganizationName
        The name of the organization to create the team in.

    .PARAMETER TeamName
        The name of the team.

    .PARAMETER Description
        The description for the team.

    .PARAMETER MaintainerName
        A list of GitHub user names for organization members who will become team maintainers.

    .PARAMETER RepositoryName
        The name of repositories to add the team to.

    .PARAMETER Privacy
        The level of privacy this team should have.

    .PARAMETER ParentTeamName
        The name of a team to set as the parent team.

    .PARAMETER ParentTeamId
        The ID of the team to set as the parent team.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Team
        GitHub.User
        System.String

    .OUTPUTS
        GitHub.Team

    .EXAMPLE
        New-GitHubTeam -OrganizationName PowerShell -TeamName 'Developers'

        Creates a new GitHub team called 'Developers' in the 'PowerShell' organization.

    .EXAMPLE
        $teamName = 'Team1'
        $teamName | New-GitHubTeam -OrganizationName PowerShell

        You can also pipe in a team name that was returned from a previous command.

    .EXAMPLE
        $users = Get-GitHubUsers -OrganizationName PowerShell
        $users | New-GitHubTeam -OrganizationName PowerShell -TeamName 'Team1'

        You can also pipe in a list of GitHub users that were returned from a previous command.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false,
        DefaultParameterSetName = 'ParentId'
    )]
    [OutputType({$script:GitHubTeamTypeName})]
    param
    (
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $TeamName,

        [string] $Description,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('UserName')]
        [string[]] $MaintainerName,

        [string[]] $RepositoryName,

        [ValidateSet('Secret', 'Closed')]
        [string] $Privacy,

        [Parameter(ParameterSetName='ParentName')]
        [string] $ParentTeamName,

        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName='ParentId')]
        [Alias('TeamId')]
        [int64] $ParentTeamId,

        [string] $AccessToken
    )

    begin
    {
        $maintainerNames = @()
    }

    process
    {
        foreach ($user in $MaintainerName)
        {
            $maintainerNames += $user
        }
    }

    end
    {
        Write-InvocationLog

        $telemetryProperties = @{
            OrganizationName = (Get-PiiSafeString -PlainText $OrganizationName)
            TeamName = (Get-PiiSafeString -PlainText $TeamName)
        }

        $uriFragment = "/orgs/$OrganizationName/teams"

        $hashBody = @{
            name = $TeamName
        }

        if ($PSBoundParameters.ContainsKey('Description')) { $hashBody['description'] = $Description }
        if ($PSBoundParameters.ContainsKey('RepositoryName'))
        {
            $repositoryFullNames = @()
            foreach ($repository in $RepositoryName)
            {
                $repositoryFullNames += "$OrganizationName/$repository"
            }
            $hashBody['repo_names'] = $repositoryFullNames
        }
        if ($PSBoundParameters.ContainsKey('Privacy')) { $hashBody['privacy'] = $Privacy.ToLower() }
        if ($MaintainerName.Count -gt 0)
        {
            $hashBody['maintainers'] = $maintainerNames
        }
        if ($PSBoundParameters.ContainsKey('ParentTeamName'))
        {
            $getGitHubTeamParms = @{
                OrganizationName = $OrganizationName
                TeamName = $ParentTeamName
            }
            if ($PSBoundParameters.ContainsKey('AccessToken'))
            {
                $getGitHubTeamParms['AccessToken'] = $AccessToken
            }

            $team = Get-GitHubTeam @getGitHubTeamParms
            $ParentTeamId = $team.id
        }

        if ($ParentTeamId -gt 0)
        {
            $hashBody['parent_team_id'] = $ParentTeamId
        }

        if (-not $PSCmdlet.ShouldProcess($TeamName, 'Create GitHub Team'))
        {
            return
        }

        $params = @{
            UriFragment = $uriFragment
            Body = (ConvertTo-Json -InputObject $hashBody)
            Method = 'Post'
            Description =  "Creating $TeamName"
            AccessToken = $AccessToken
            TelemetryEventName = $MyInvocation.MyCommand.Name
            TelemetryProperties = $telemetryProperties
        }

        return (Invoke-GHRestMethod @params | Add-GitHubTeamAdditionalProperties)
    }
}

filter Set-GitHubTeam
{
<#
    .SYNOPSIS
        Updates a team within an organization on GitHub.

    .DESCRIPTION
        Updates a team within an organization on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OrganizationName
        The name of the team's organization.

    .PARAMETER TeamName
        The name of the team.

        When TeamSlug is specified, specifying a name here that is different from the existing
        name will cause the team to be renamed. TeamSlug and TeamName are specified for you
        automatically when piping in a GitHub.Team object, so a rename would only occur if
        intentionally specify this parameter and provide a different name.

    .PARAMETER TeamSlug
        The slug (a unique key based on the team name) of the team to update.

    .PARAMETER Description
        The description for the team.

    .PARAMETER Privacy
        The level of privacy this team should have.

    .PARAMETER ParentTeamName
        The name of a team to set as the parent team.

    .PARAMETER ParentTeamId
        The ID of the team to set as the parent team.

    .PARAMETER PassThru
        Returns the updated GitHub Team.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Organization
        GitHub.Team

    .OUTPUTS
        GitHub.Team

    .EXAMPLE
        Set-GitHubTeam -OrganizationName PowerShell -TeamName Developers -Description 'New Description'

        Updates the description for the 'Developers' GitHub team in the 'PowerShell' organization.

    .EXAMPLE
        $team = Get-GitHubTeam -OrganizationName PowerShell -TeamName Developers
        $team | Set-GitHubTeam -Description 'New Description'

        You can also pipe in a GitHub team that was returned from a previous command.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false,
        DefaultParameterSetName = 'ParentName'
    )]
    [OutputType( { $script:GitHubTeamTypeName } )]
    param
    (
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string] $TeamName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $TeamSlug,

        [string] $Description,

        [ValidateSet('Secret','Closed')]
        [string] $Privacy,

        [Parameter(ParameterSetName='ParentTeamName')]
        [string] $ParentTeamName,

        [Parameter(ParameterSetName='ParentTeamId')]
        [int64] $ParentTeamId,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{
        OrganizationName = (Get-PiiSafeString -PlainText $OrganizationName)
        TeamSlug = (Get-PiiSafeString -PlainText $TeamSlug)
        TeamName = (Get-PiiSafeString -PlainText $TeamName)
    }

    if ((-not $PSBoundParameters.ContainsKey('TeamSlug')) -or
        $PSBoundParameters.ContainsKey('ParentTeamName'))
    {
        $getGitHubTeamParms = @{
            OrganizationName = $OrganizationName
        }
        if ($PSBoundParameters.ContainsKey('AccessToken'))
        {
            $getGitHubTeamParms['AccessToken'] = $AccessToken
        }

        $orgTeams = Get-GitHubTeam @getGitHubTeamParms

        if ($PSBoundParameters.ContainsKey('TeamName'))
        {
            $team = $orgTeams | Where-Object -Property name -eq $TeamName
            $TeamSlug = $team.slug
        }
    }

    $uriFragment = "/orgs/$OrganizationName/teams/$TeamSlug"

    $hashBody = @{
        name = $TeamName
    }

    if ($PSBoundParameters.ContainsKey('Description')) { $hashBody['description'] = $Description }
    if ($PSBoundParameters.ContainsKey('Privacy')) { $hashBody['privacy'] = $Privacy.ToLower() }
    if ($PSBoundParameters.ContainsKey('ParentTeamName'))
    {
        $parentTeam = $orgTeams | Where-Object -Property name -eq $ParentTeamName
        $hashBody['parent_team_id'] = $parentTeam.id
    }
    elseif ($PSBoundParameters.ContainsKey('ParentTeamId'))
    {
        if ($ParentTeamId -gt 0)
        {
            $hashBody['parent_team_id'] = $ParentTeamId
        }
        else
        {
            $hashBody['parent_team_id'] = $null
        }
    }

    if (-not $PSCmdlet.ShouldProcess($TeamSlug, 'Set GitHub Team'))
    {
        return
    }

    $params = @{
        UriFragment = $uriFragment
        Body = (ConvertTo-Json -InputObject $hashBody)
        Method = 'Patch'
        Description =  "Updating $TeamName"
        AccessToken = $AccessToken
        TelemetryEventName = $MyInvocation.MyCommand.Name
        TelemetryProperties = $telemetryProperties
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubTeamAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Rename-GitHubTeam
{
<#
    .SYNOPSIS
        Renames a team within an organization on GitHub.

    .DESCRIPTION
        Renames a team within an organization on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OrganizationName
        The name of the team's organization.

    .PARAMETER TeamName
        The existing name of the team.

    .PARAMETER TeamSlug
        The slug (a unique key based on the team name) of the team to update.

    .PARAMETER NewTeamName
        The new name for the team.

    .PARAMETER PassThru
        Returns the updated GitHub Team.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Organization
        GitHub.Team

    .OUTPUTS
        GitHub.Team

    .EXAMPLE
        Rename-GitHubTeam -OrganizationName PowerShell -TeamName Developers -NewTeamName DeveloperTeam

        Renames the 'Developers' GitHub team in the 'PowerShell' organization to be 'DeveloperTeam'.

    .EXAMPLE
        $team = Get-GitHubTeam -OrganizationName PowerShell -TeamName Developers
        $team | Rename-GitHubTeam -NewTeamName 'DeveloperTeam'

        You can also pipe in a GitHub team that was returned from a previous command.

    .NOTES
        This is a helper/wrapper for Set-GitHubTeam which can also rename a GitHub Team.
#>
    [CmdletBinding(
        PositionalBinding = $false,
        DefaultParameterSetName = 'TeamSlug')]
    [OutputType( { $script:GitHubTeamTypeName } )]
    param
    (
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2,
            ParameterSetName='TeamName')]
        [ValidateNotNullOrEmpty()]
        [string] $TeamName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='TeamSlug')]
        [ValidateNotNullOrEmpty()]
        [string] $TeamSlug,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string] $NewTeamName,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    if (-not $PSBoundParameters.ContainsKey('TeamSlug'))
    {
        $team = Get-GitHubTeam -OrganizationName $OrganizationName -TeamName $TeamName -AccessToken:$AccessToken
        $TeamSlug = $team.slug
    }

    $params = @{
        OrganizationName = $OrganizationName
        TeamSlug = $TeamSlug
        TeamName = $NewTeamName
        PassThru = (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        AccessToken = $AccessToken
    }

    return Set-GitHubTeam @params
}

filter Remove-GitHubTeam
{
<#
    .SYNOPSIS
        Removes a team from an organization on GitHub.

    .DESCRIPTION
        Removes a team from an organization on GitHub.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER OrganizationName
        The name of the organization the team is in.

    .PARAMETER TeamName
        The name of the team to remove.

    .PARAMETER TeamSlug
        The slug (a unique key based on the team name) of the team to remove.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Organization
        GitHub.Team

    .OUTPUTS
        None

    .EXAMPLE
        Remove-GitHubTeam -OrganizationName PowerShell -TeamName Developers

        Removes the 'Developers' GitHub team from the 'PowerShell' organization.

    .EXAMPLE
        Remove-GitHubTeam -OrganizationName PowerShell -TeamName Developers -Force

        Removes the 'Developers' GitHub team from the 'PowerShell' organization without prompting.

    .EXAMPLE
        $team = Get-GitHubTeam -OrganizationName PowerShell -TeamName Developers
        $team | Remove-GitHubTeam -Force

        You can also pipe in a GitHub team that was returned from a previous command.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false,
        ConfirmImpact = 'High',
        DefaultParameterSetName = 'TeamSlug')]
    [Alias('Delete-GitHubTeam')]
    param
    (
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $OrganizationName,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            Position = 2,
            ParameterSetName='TeamName')]
        [ValidateNotNullOrEmpty()]
        [string] $TeamName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='TeamSlug')]
        [ValidateNotNullOrEmpty()]
        [string] $TeamSlug,

        [switch] $Force,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{
        OrganizationName = (Get-PiiSafeString -PlainText $RepositoryName)
        TeamSlug = (Get-PiiSafeString -PlainText $TeamSlug)
        TeamName = (Get-PiiSafeString -PlainText $TeamName)
    }

    if ($PSBoundParameters.ContainsKey('TeamName'))
    {
        $getGitHubTeamParms = @{
            OrganizationName = $OrganizationName
            TeamName = $TeamName
        }
        if ($PSBoundParameters.ContainsKey('AccessToken'))
        {
            $getGitHubTeamParms['AccessToken'] = $AccessToken
        }

        $team = Get-GitHubTeam @getGitHubTeamParms
        $TeamSlug = $team.slug
    }

    $uriFragment = "/orgs/$OrganizationName/teams/$TeamSlug"

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($TeamName, 'Remove Github Team'))
    {
        return
    }

    $params = @{
        UriFragment = $uriFragment
        Method = 'Delete'
        Description =  "Deleting $TeamSlug"
        AccessToken = $AccessToken
        TelemetryEventName = $MyInvocation.MyCommand.Name
        TelemetryProperties = $telemetryProperties
    }

    Invoke-GHRestMethod @params | Out-Null
}

filter Add-GitHubTeamAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Team objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Team
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
        [string] $TypeName = $script:GitHubTeamTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            Add-Member -InputObject $item -Name 'TeamName' -Value $item.name -MemberType NoteProperty -Force
            Add-Member -InputObject $item -Name 'TeamId' -Value $item.id -MemberType NoteProperty -Force
            Add-Member -InputObject $item -Name 'TeamSlug' -Value $item.slug -MemberType NoteProperty -Force

            $organizationName = [String]::Empty
            if ($item.organization)
            {
                $organizationName = $item.organization.login
            }
            else
            {
                $hostName = $(Get-GitHubConfiguration -Name 'ApiHostName')

                if ($item.html_url -match "^https?://$hostName/orgs/([^/]+)/.*$")
                {
                    $organizationName = $Matches[1]
                }
            }

            Add-Member -InputObject $item -Name 'OrganizationName' -Value $organizationName -MemberType NoteProperty -Force

            # Apply these properties to any embedded parent teams as well.
            if ($null -ne $item.parent)
            {
                $null = Add-GitHubTeamAdditionalProperties -InputObject $item.parent
            }
        }

        Write-Output $item
    }
}

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDusFBOFNJl7wBU
# nCPAOK2gCwbxAIl35s1QZjzz1O8oMKCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg+rL14iTq
# /yL8EHdQz2ekeGCM09XjLzfNs8ti3kwUYTwwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCJ0MdL8zSG1lWsJOweCTnrsPwSSwXbotJCZCUhdDXf
# Cx/PZbFKTbA61VCquzJz6/v2y35K5tMXC1HP28XvKdh6/BP8inmt7hSdhOLJeT+I
# sdtUuDCh3k1UUTRAu5HFt9kXQHA76TA/c4HBFqCLbLphY7btGv4uuBa6fbxmu1d5
# fatVChG6K+6mjIop8OAxbXZcxa+dKIke071jFdZBK2VGxg8xwo0KbkntmN/fUUjN
# rFRxDK8GlHLvvt8AIZlGRqlgGhRCzpQE2F3pw7EZqdkID616jujSR9SeGAPJj6Vs
# nL2Np1p79K7PpK/kFeClqjnBlwNwYbchbjIQep/fqYBfoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIJU7RMTb1/oo64IdqETH4EZpwrIQtOB3SAWd1isU
# 8DubAgZf29L2HvIYEzIwMjEwMTA1MTk1MTU0LjQzNFowBIACAfSggdSkgdEwgc4x
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
# CQQxIgQgHrNNP8iw+3y5t0i7URNsFRfYgvrT6d/RCoLKxOVqJ+4wgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBiOOHoohqL+X7Xa/25jp1wTrQxYlYGLszis/nA
# TirjIDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# JMvNAqEXcFyaAAAAAAEkMCIEID3BNgEmggzhBVnlrhiWPLIq7N8ovgrOW/kvWTZx
# a9rhMA0GCSqGSIb3DQEBCwUABIIBAAs+ODHL0Z7etLuj423F+22hAVhS1QwNAclr
# TJyXxHezkp24uY0MBs/xK1p/qYUsA5cppYSkDq/hnXzRiAA3lt4SeYY6n8DPT9Wl
# kadqs9SGYfcjpumQrNBY1VpFh2wUG+A/4xVM8ONn2R88jrVpKarnaVZEWi9cW3Gt
# iDlfIeZWBCXw6ZGBUc7SY5x/t6Ylwe0/nyH3PFcuj6WdKTn5nv4jejLv6PW1qkVB
# U4lvSsEItQqawolpGE8/wg6+rIEO3nxCnG3aHrJ7D4JljkoRShNHKkkPGGKTnawJ
# Hg4LxqZBfkzvg1y+m8Ib6OLO9QBU9xUFPL2mLV0sVnlZ0kXQgDI=
# SIG # End signature block
