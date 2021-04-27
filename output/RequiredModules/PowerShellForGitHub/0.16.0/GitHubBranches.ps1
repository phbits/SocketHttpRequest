# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubBranchTypeName = 'GitHub.Branch'
    GitHubBranchProtectionRuleTypeName = 'GitHub.BranchProtectionRule'
}.GetEnumerator() | ForEach-Object {
    Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
}

filter Get-GitHubRepositoryBranch
{
<#
    .SYNOPSIS
        Retrieve branches for a given GitHub repository.

    .DESCRIPTION
        Retrieve branches for a given GitHub repository.

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

    .PARAMETER Name
        Name of the specific branch to be retrieved.  If not supplied, all branches will be retrieved.

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
        GitHub.Branch
        List of branches within the given repository.

    .EXAMPLE
        Get-GitHubRepositoryBranch -OwnerName microsoft -RepositoryName PowerShellForGitHub

        Gets all branches for the specified repository.

    .EXAMPLE
        $repo = Get-GitHubRepository -OwnerName microsoft -RepositoryName PowerShellForGitHub
        $repo | Get-GitHubRepositoryBranch

        Gets all branches for the specified repository.

    .EXAMPLE
        Get-GitHubRepositoryBranch -Uri 'https://github.com/PowerShell/PowerShellForGitHub' -BranchName master

        Gets information only on the master branch for the specified repository.

    .EXAMPLE
        $repo = Get-GitHubRepository -OwnerName microsoft -RepositoryName PowerShellForGitHub
        $repo | Get-GitHubRepositoryBranch -BranchName master

        Gets information only on the master branch for the specified repository.

    .EXAMPLE
        $repo = Get-GitHubRepository -OwnerName microsoft -RepositoryName PowerShellForGitHub
        $branch = $repo | Get-GitHubRepositoryBranch -BranchName master
        $branch | Get-GitHubRepositoryBranch

        Gets information only on the master branch for the specified repository, and then does it
        again.  This tries to show some of the different types of objects you can pipe into this
        function.
#>
    [CmdletBinding(DefaultParameterSetName = 'Elements')]
    [OutputType({$script:GitHubBranchTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    [Alias('Get-GitHubBranch')]
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

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $BranchName,

        [switch] $ProtectedOnly,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    $uriFragment = "repos/$OwnerName/$RepositoryName/branches"
    if (-not [String]::IsNullOrEmpty($BranchName)) { $uriFragment = $uriFragment + "/$BranchName" }

    $getParams = @()
    if ($ProtectedOnly) { $getParams += 'protected=true' }

    $params = @{
        'UriFragment' = $uriFragment + '?' + ($getParams -join '&')
        'Description' = "Getting branches for $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubBranchAdditionalProperties)
}

filter New-GitHubRepositoryBranch
{
    <#
    .SYNOPSIS
        Creates a new branch for a given GitHub repository.

    .DESCRIPTION
        Creates a new branch for a given GitHub repository.

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

    .PARAMETER BranchName
        The name of the origin branch to create the new branch from.

    .PARAMETER TargetBranchName
        Name of the branch to be created.

    .PARAMETER Sha
        The SHA1 value of the commit that this branch should be based on.
        If not specified, will use the head of BranchName.

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
        GitHub.Repository

    .OUTPUTS
        GitHub.Branch

    .EXAMPLE
        New-GitHubRepositoryBranch -OwnerName microsoft -RepositoryName PowerShellForGitHub -TargetBranchName new-branch

        Creates a new branch in the specified repository from the master branch.

    .EXAMPLE
        New-GitHubRepositoryBranch -Uri 'https://github.com/microsoft/PowerShellForGitHub' -BranchName develop -TargetBranchName new-branch

        Creates a new branch in the specified repository from the 'develop' origin branch.

    .EXAMPLE
        $repo = Get-GithubRepository -Uri https://github.com/You/YourRepo
        $repo | New-GitHubRepositoryBranch -TargetBranchName new-branch

        You can also pipe in a repo that was returned from a previous command.

    .EXAMPLE
        $branch = Get-GitHubRepositoryBranch -OwnerName microsoft -RepositoryName PowerShellForGitHub -BranchName main
        $branch | New-GitHubRepositoryBranch -TargetBranchName beta

        You can also pipe in a branch that was returned from a previous command.

    .EXAMPLE
        New-GitHubRepositoryBranch -Uri 'https://github.com/microsoft/PowerShellForGitHub' -Sha 1c3b80b754a983f4da20e77cfb9bd7f0e4cb5da6 -TargetBranchName new-branch

        You can also create a new branch based off of a specific SHA1 commit value.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'Elements',
        PositionalBinding = $false
    )]
    [OutputType({$script:GitHubBranchTypeName})]
    [Alias('New-GitHubBranch')]
    param(
        [Parameter(ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1,
            ParameterSetName = 'Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $BranchName = 'master',

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            Position = 2)]
        [string] $TargetBranchName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Sha,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    $originBranch = $null

    if (-not $PSBoundParameters.ContainsKey('Sha'))
    {
        try
        {
            $getGitHubRepositoryBranchParms = @{
                OwnerName = $OwnerName
                RepositoryName = $RepositoryName
                BranchName = $BranchName
            }
            if ($PSBoundParameters.ContainsKey('AccessToken'))
            {
                $getGitHubRepositoryBranchParms['AccessToken'] = $AccessToken
            }

            Write-Log -Level Verbose "Getting $BranchName branch for sha reference"
            $originBranch = Get-GitHubRepositoryBranch @getGitHubRepositoryBranchParms
            $Sha = $originBranch.commit.sha
        }
        catch
        {
            # Temporary code to handle current differences in exception object between PS5 and PS7
            $throwObject = $_

            if ($PSVersionTable.PSedition -eq 'Core')
            {
                if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException] -and
                ($_.ErrorDetails.Message | ConvertFrom-Json).message -eq 'Branch not found')
                {
                    $throwObject = "Origin branch $BranchName not found"
                }
            }
            else
            {
                if ($_.Exception.Message -like '*Not Found*')
                {
                    $throwObject = "Origin branch $BranchName not found"
                }
            }

            Write-Log -Message $throwObject -Level Error
            throw $throwObject
        }
    }

    $uriFragment = "repos/$OwnerName/$RepositoryName/git/refs"

    $hashBody = @{
        ref = "refs/heads/$TargetBranchName"
        sha = $Sha
    }

    if (-not $PSCmdlet.ShouldProcess($BranchName, 'Create Repository Branch'))
    {
        return
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Post'
        'Description' = "Creating branch $TargetBranchName for $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethod @params | Add-GitHubBranchAdditionalProperties)
}

filter Remove-GitHubRepositoryBranch
{
    <#
    .SYNOPSIS
        Removes a branch from a given GitHub repository.

    .DESCRIPTION
        Removes a branch from a given GitHub repository.

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

    .PARAMETER BranchName
        Name of the branch to be removed.

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
        GitHub.Repository

    .OUTPUTS
        None

    .EXAMPLE
        Remove-GitHubRepositoryBranch -OwnerName microsoft -RepositoryName PowerShellForGitHub -BranchName develop

        Removes the 'develop' branch from the specified repository.

    .EXAMPLE
        Remove-GitHubRepositoryBranch -OwnerName microsoft -RepositoryName PowerShellForGitHub -BranchName develop -Force

        Removes the 'develop' branch from the specified repository without prompting for confirmation.

    .EXAMPLE
        $branch = Get-GitHubRepositoryBranch -Uri https://github.com/You/YourRepo -BranchName BranchToDelete
        $branch | Remove-GitHubRepositoryBranch -Force

        You can also pipe in a repo that was returned from a previous command.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'Elements',
        PositionalBinding = $false,
        ConfirmImpact = 'High')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    [Alias('Remove-GitHubBranch')]
    [Alias('Delete-GitHubRepositoryBranch')]
    [Alias('Delete-GitHubBranch')]
    param(
        [Parameter(ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1,
            ParameterSetName = 'Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [string] $BranchName,

        [switch] $Force,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    $uriFragment = "repos/$OwnerName/$RepositoryName/git/refs/heads/$BranchName"

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($BranchName, "Remove Repository Branch"))
    {
        return
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Method' = 'Delete'
        'Description' = "Deleting branch $BranchName from $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    Invoke-GHRestMethod @params | Out-Null
}

filter Get-GitHubRepositoryBranchProtectionRule
{
    <#
    .SYNOPSIS
        Retrieve branch protection rules for a given GitHub repository.

    .DESCRIPTION
        Retrieve branch protection rules for a given GitHub repository.

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

    .PARAMETER BranchName
        Name of the specific branch to be retrieved.  If not supplied, all branches will be retrieved.

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
        GitHub.Repository

    .OUTPUTS
        GitHub.BranchProtectionRule

    .EXAMPLE
        Get-GitHubRepositoryBranchProtectionRule -OwnerName microsoft -RepositoryName PowerShellForGitHub -BranchName master

        Retrieves branch protection rules for the master branch of the PowerShellForGithub repository.

    .EXAMPLE
        Get-GitHubRepositoryBranchProtectionRule -Uri 'https://github.com/microsoft/PowerShellForGitHub' -BranchName master

        Retrieves branch protection rules for the master branch of the PowerShellForGithub repository.
#>
    [CmdletBinding(
        PositionalBinding = $false,
        DefaultParameterSetName = 'Elements')]
    [OutputType({ $script:GitHubBranchProtectionRuleTypeName })]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    param(
        [Parameter(ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            Position = 1,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [string] $BranchName,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    $params = @{
        UriFragment = "repos/$OwnerName/$RepositoryName/branches/$BranchName/protection"
        Description = "Getting branch protection status for $RepositoryName"
        Method = 'Get'
        AcceptHeader = $script:lukeCageAcceptHeader
        AccessToken = $AccessToken
        TelemetryEventName = $MyInvocation.MyCommand.Name
        TelemetryProperties = $telemetryProperties
    }

    return (Invoke-GHRestMethod @params | Add-GitHubBranchProtectionRuleAdditionalProperties)
}

filter New-GitHubRepositoryBranchProtectionRule
{
    <#
    .SYNOPSIS
        Creates a branch protection rule for a branch on a given GitHub repository.

    .DESCRIPTION
        Creates a branch protection rules for a branch on a given GitHub repository.

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

    .PARAMETER BranchName
        Name of the specific branch to create the protection rule on.

    .PARAMETER StatusChecks
        The list of status checks to require in order to merge into the branch.

    .PARAMETER RequireUpToDateBranches
        Require branches to be up to date before merging. This setting will not take effect unless
        at least one status check is defined.

    .PARAMETER EnforceAdmins
        Enforce all configured restrictions for administrators.

    .PARAMETER DismissalUsers
        Specify the user names of users who can dismiss pull request reviews. This can only be
        specified for organization-owned repositories.

    .PARAMETER DismissalTeams
        Specify which teams can dismiss pull request reviews.

    .PARAMETER DismissStaleReviews
        If specified, approving reviews when someone pushes a new commit are automatically
        dismissed.

    .PARAMETER RequireCodeOwnerReviews
        Blocks merging pull requests until code owners review them.

    .PARAMETER RequiredApprovingReviewCount
        Specify the number of reviewers required to approve pull requests. Use a number between 1
        and 6.

    .PARAMETER RestrictPushUsers
        Specify which users have push access.

    .PARAMETER RestrictPushTeams
        Specify which teams have push access.

    .PARAMETER RestrictPushApps
        Specify which apps have push access.

    .PARAMETER RequireLinearHistory
        Enforces a linear commit Git history, which prevents anyone from pushing merge commits to a
        branch. Your repository must allow squash merging or rebase merging before you can enable a
        linear commit history.

    .PARAMETER AllowForcePushes
        Permits force pushes to the protected branch by anyone with write access to the repository.

    .PARAMETER AllowDeletions
        Allows deletion of the protected branch by anyone with write access to the repository.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Repository
        GitHub.Branch

    .OUTPUTS
        GitHub.BranchRepositoryRule

    .NOTES
        Protecting a branch requires admin or owner permissions to the repository.

    .EXAMPLE
        New-GitHubRepositoryBranchProtectionRule -OwnerName microsoft -RepositoryName PowerShellForGitHub -BranchName master -EnforceAdmins

        Creates a branch protection rule for the master branch of the PowerShellForGithub repository
        enforcing all configuration restrictions for administrators.

    .EXAMPLE
        New-GitHubRepositoryBranchProtectionRule -Uri 'https://github.com/microsoft/PowerShellForGitHub' -BranchName master -RequiredApprovingReviewCount 1

        Creates a branch protection rule for the master branch of the PowerShellForGithub repository
        requiring one approving review.
#>
    [CmdletBinding(
        PositionalBinding = $false,
        SupportsShouldProcess,
        DefaultParameterSetName = 'Elements')]
    [OutputType({$script:GitHubBranchProtectionRuleTypeName })]
    param(
        [Parameter(ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 1,
            ParameterSetName = 'Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [string] $BranchName,

        [string[]] $StatusChecks,

        [switch] $RequireUpToDateBranches,

        [switch] $EnforceAdmins,

        [string[]] $DismissalUsers,

        [string[]] $DismissalTeams,

        [switch] $DismissStaleReviews,

        [switch] $RequireCodeOwnerReviews,

        [ValidateRange(1, 6)]
        [int] $RequiredApprovingReviewCount,

        [string[]] $RestrictPushUsers,

        [string[]] $RestrictPushTeams,

        [string[]] $RestrictPushApps,

        [switch] $RequireLinearHistory,

        [switch] $AllowForcePushes,

        [switch] $AllowDeletions,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        OwnerName = (Get-PiiSafeString -PlainText $OwnerName)
        RepositoryName = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    $getGitHubRepositoryBranchProtectRuleParms = @{
        OwnerName = $OwnerName
        RepositoryName = $RepositoryName
        BranchName = $BranchName
    }

    $ruleExists = $true

    try
    {
        Get-GitHubRepositoryBranchProtectionRule @getGitHubRepositoryBranchProtectRuleParms |
            Out-Null
    }
    catch
    {
        # Temporary code to handle current differences in exception object between PS5 and PS7
        if ($PSVersionTable.PSedition -eq 'Core')
        {
            if ($_.Exception -is [Microsoft.PowerShell.Commands.HttpResponseException] -and
                ($_.ErrorDetails.Message | ConvertFrom-Json).message -eq 'Branch not protected')
            {
                $ruleExists = $false
            }
            else
            {
                throw $_
            }
        }
        else
        {
            if ($_.Exception.Message -like '*Branch not protected*')
            {
                $ruleExists = $false
            }
            else
            {
                throw $_
            }
        }
    }

    if ($ruleExists)
    {
        $message = ("Branch protection rule for branch $BranchName already exists on Repository " +
            $RepositoryName)
        Write-Log -Message $message -Level Error
        throw $message
    }

    if ($PSBoundParameters.ContainsKey('DismissalTeams') -or
        $PSBoundParameters.ContainsKey('RestrictPushTeams'))
    {
        $teams = Get-GitHubTeam -OwnerName $OwnerName -RepositoryName $RepositoryName
    }

    $requiredStatusChecks = $null
    if ($PSBoundParameters.ContainsKey('StatusChecks') -or
        $PSBoundParameters.ContainsKey('RequireUpToDateBranches'))
    {
        if ($null -eq $StatusChecks)
        {
            $StatusChecks = @()
        }
        $requiredStatusChecks = @{
            strict = $RequireUpToDateBranches.ToBool()
            contexts = $StatusChecks
        }
    }

    $dismissalRestrictions = @{}

    if ($PSBoundParameters.ContainsKey('DismissalUsers'))
    {
        $dismissalRestrictions['users'] = $DismissalUsers
    }
    if ($PSBoundParameters.ContainsKey('DismissalTeams'))
    {
        $dismissalTeamList = $teams | Where-Object -FilterScript { $DismissalTeams -contains $_.name }
        $dismissalRestrictions['teams'] = @($dismissalTeamList.slug)
    }

    $requiredPullRequestReviews = @{}

    if ($PSBoundParameters.ContainsKey('DismissStaleReviews'))
    {
        $requiredPullRequestReviews['dismiss_stale_reviews'] = $DismissStaleReviews.ToBool()
    }
    if ($PSBoundParameters.ContainsKey('RequireCodeOwnerReviews'))
    {
        $requiredPullRequestReviews['require_code_owner_reviews'] = $RequireCodeOwnerReviews.ToBool()
    }
    if ($dismissalRestrictions.count -gt 0)
    {
        $requiredPullRequestReviews['dismissal_restrictions'] = $dismissalRestrictions
    }
    if ($PSBoundParameters.ContainsKey('RequiredApprovingReviewCount'))
    {
        $requiredPullRequestReviews['required_approving_review_count'] = $RequiredApprovingReviewCount
    }

    if ($requiredPullRequestReviews.count -eq 0)
    {
        $requiredPullRequestReviews = $null
    }

    if ($PSBoundParameters.ContainsKey('RestrictPushUsers') -or
        $PSBoundParameters.ContainsKey('RestrictPushTeams') -or
        $PSBoundParameters.ContainsKey('RestrictPushApps'))
    {
        if ($null -eq $RestrictPushUsers)
        {
            $RestrictPushUsers = @()
        }

        if ($null -eq $RestrictPushTeams)
        {
            $restrictPushTeamSlugs = @()
        }
        else
        {
            $restrictPushTeamList = $teams | Where-Object -FilterScript {
                $RestrictPushTeams -contains $_.name }
            $restrictPushTeamSlugs = @($restrictPushTeamList.slug)
        }

        $restrictions = @{
            users = $RestrictPushUsers
            teams = $restrictPushTeamSlugs
        }

        if ($PSBoundParameters.ContainsKey('RestrictPushApps'))
        {
            $restrictions['apps'] = $RestrictPushApps
        }
    }
    else
    {
        $restrictions = $null
    }

    $hashBody = @{
        required_status_checks = $requiredStatusChecks
        enforce_admins = $EnforceAdmins.ToBool()
        required_pull_request_reviews = $requiredPullRequestReviews
        restrictions = $restrictions
    }

    if ($PSBoundParameters.ContainsKey('RequireLinearHistory'))
    {
        $hashBody['required_linear_history'] = $RequireLinearHistory.ToBool()
    }
    if ($PSBoundParameters.ContainsKey('AllowForcePushes'))
    {
        $hashBody['allow_force_pushes'] = $AllowForcePushes.ToBool()
    }
    if ($PSBoundParameters.ContainsKey('AllowDeletions'))
    {
        $hashBody['allow_deletions'] = $AllowDeletions.ToBool()
    }

    if (-not $PSCmdlet.ShouldProcess(
            "'$BranchName' branch of repository '$RepositoryName'",
            'Create GitHub Repository Branch Protection Rule'))
    {
        return
    }

    $jsonConversionDepth = 3

    $params = @{
        UriFragment = "repos/$OwnerName/$RepositoryName/branches/$BranchName/protection"
        Body = (ConvertTo-Json -InputObject $hashBody -Depth $jsonConversionDepth)
        Description = "Setting $BranchName branch protection status for $RepositoryName"
        Method = 'Put'
        AcceptHeader = $script:lukeCageAcceptHeader
        AccessToken = $AccessToken
        TelemetryEventName = $MyInvocation.MyCommand.Name
        TelemetryProperties = $telemetryProperties
    }

    return (Invoke-GHRestMethod @params | Add-GitHubBranchProtectionRuleAdditionalProperties)
}

filter Remove-GitHubRepositoryBranchProtectionRule
{
    <#
    .SYNOPSIS
        Remove branch protection rules from a given GitHub repository.

    .DESCRIPTION
        Remove branch protection rules from a given GitHub repository.

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

    .PARAMETER BranchName
        Name of the specific branch to remove the branch protection rule from.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.Repository
        GitHub.Branch

    .OUTPUTS
        None

    .EXAMPLE
        Remove-GitHubRepositoryBranchProtectionRule -OwnerName microsoft -RepositoryName PowerShellForGitHub -BranchName master

        Removes branch protection rules from the master branch of the PowerShellForGithub repository.

    .EXAMPLE
        Removes-GitHubRepositoryBranchProtection -Uri 'https://github.com/microsoft/PowerShellForGitHub' -BranchName master

        Removes branch protection rules from the master branch of the PowerShellForGithub repository.

    .EXAMPLE
        Removes-GitHubRepositoryBranchProtection -Uri 'https://github.com/master/PowerShellForGitHub' -BranchName master -Force

        Removes branch protection rules from the master branch of the PowerShellForGithub repository
        without prompting for confirmation.
#>
    [CmdletBinding(
        PositionalBinding = $false,
        SupportsShouldProcess,
        DefaultParameterSetName = 'Elements',
        ConfirmImpact = "High")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    [Alias('Delete-GitHubRepositoryBranchProtectionRule')]
    param(
        [Parameter(ParameterSetName = 'Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName = 'Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            Position = 1,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [string] $BranchName,

        [switch] $Force,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
    }

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess("'$BranchName' branch of repository '$RepositoryName'",
            'Remove GitHub Repository Branch Protection Rule'))
    {
        return
    }

    $params = @{
        UriFragment = "repos/$OwnerName/$RepositoryName/branches/$BranchName/protection"
        Description = "Removing $BranchName branch protection rule for $RepositoryName"
        Method = 'Delete'
        AcceptHeader = $script:lukeCageAcceptHeader
        AccessToken = $AccessToken
        TelemetryEventName = $MyInvocation.MyCommand.Name
        TelemetryProperties = $telemetryProperties
    }

    return Invoke-GHRestMethod @params | Out-Null
}

filter Add-GitHubBranchAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Branch objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Branch
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
        [string] $TypeName = $script:GitHubBranchTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            if ($null -ne $item.url)
            {
                $elements = Split-GitHubUri -Uri $item.url
            }
            else
            {
                $elements = Split-GitHubUri -Uri $item.commit.url
            }
            $repositoryUrl = Join-GitHubUri @elements

            Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force

            $branchName = $item.name
            if ($null -eq $branchName)
            {
                $branchName = $item.ref -replace ('refs/heads/', '')
            }

            Add-Member -InputObject $item -Name 'BranchName' -Value $branchName -MemberType NoteProperty -Force

            if ($null -ne $item.commit)
            {
                Add-Member -InputObject $item -Name 'Sha' -Value $item.commit.sha -MemberType NoteProperty -Force
            }
            elseif ($null -ne $item.object)
            {
                Add-Member -InputObject $item -Name 'Sha' -Value $item.object.sha -MemberType NoteProperty -Force
            }
        }

        Write-Output $item
    }
}

filter Add-GitHubBranchProtectionRuleAdditionalProperties
{
    <#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Branch Protection Rule objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        PSCustomObject

    .OUTPUTS
        GitHub.Branch
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '',
        Justification = 'Internal helper that is definitely adding more than one property.')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [PSCustomObject[]] $InputObject,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubBranchProtectionRuleTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            $elements = Split-GitHubUri -Uri $item.url
            $repositoryUrl = Join-GitHubUri @elements
            Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force

            $hostName = $(Get-GitHubConfiguration -Name 'ApiHostName')

            if ($item.url -match "^https?://(?:www\.|api\.|)$hostName/repos/(?:[^/]+)/(?:[^/]+)/branches/([^/]+)/.*$")
            {
                Add-Member -InputObject $item -Name 'BranchName' -Value $Matches[1] -MemberType NoteProperty -Force
            }
        }

        Write-Output $item
    }
}

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAtPAYECQwMAWRW
# YHE2eZEyyFLR/I1X6SjLE6Q9oYOOHqCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgtSnqaTRo
# 9btwQyAT9bZTKLvVPM7HgVua9HfcxfkFT3swQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBjoFzSO3bLASUmI9EShdSIjpF6m3TWC6l+PH72pY7B
# kkozH3VVfav7EQUyNGwsGdMSuYE43w4PeWEkpl0ky0ZYHn5zL7np2CdIkoD+kGkR
# rpOIQgiiooUlaj5eWuhNI+ARNrhxuCmdh/nbH3fG5MqC0puZ5Pa/CrRuUmYfZQ9Q
# t5tUWC+PiSqszgmVz6T2cZJHeqsFOpqztB5nzwcBNLiT+3OIJiVTdQhGswCrWPYu
# +wlaXmy7w89heuG0jNcoHfBZaF+mlP0y+LUSKtbZLDs1cGHzJJkJR/F/vDvfXE4T
# H6Arm3Go5poJXZbxhK/X/C8+kn9m3qGec6KBvkAXtBiLoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEINv/OfTVLVsapg5KI9GHokzKIud4q824EtOG5hOI
# PI4UAgZf29L2GvUYEzIwMjEwMTA1MTk1MDUzLjczOVowBIACAfSggdSkgdEwgc4x
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
# CQQxIgQgs7EabcNoPVfEb0X2iieqTNb6dIv1aJH24EpgyAm0n0IwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBiOOHoohqL+X7Xa/25jp1wTrQxYlYGLszis/nA
# TirjIDCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# JMvNAqEXcFyaAAAAAAEkMCIEID3BNgEmggzhBVnlrhiWPLIq7N8ovgrOW/kvWTZx
# a9rhMA0GCSqGSIb3DQEBCwUABIIBAFCWt4QUFyznFFeVHjgkuZySDyNA4eOABLKu
# zsbxt7auPP4wqHMCA80/k+JtTClnteOB/rB43CmVtJAsv6pxGsjdNas/Sd0+quOb
# GET5NVrEogz91Cgn+fRXIa2y2nSk6olIJDvBwaw9tKViVpNxKYmfUvKeLZgjznPI
# K71JaCNh3dCUgEa5qSlEw3+naJPdxroAL86osoJMndle+9oaH1o36R6CkOVoGZe1
# qh4QqqwTi3e0XQceV0xiHVBitXEJCnLWp1hiBz+PTRGKt4qZQOJutyuq8z22IuD+
# X2whAUc2W7PvcRmd8kdosq7+5BFwfUU7fMdfELTElUOu5ViN7UA=
# SIG # End signature block
