# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubLabelTypeName = 'GitHub.Label'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubLabel
{
<#
    .SYNOPSIS
        Retrieve label(s) of a given GitHub repository.

    .DESCRIPTION
        Retrieve label(s) of a given GitHub repository.

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

    .PARAMETER Label
        Name of the specific label to be retrieved.  If not supplied, all labels will be retrieved.
        Emoji and codes are supported.  For more information, see here: https://www.webpagefx.com/tools/emoji-cheat-sheet/

    .PARAMETER Issue
        If provided, will return all of the labels for this particular issue.

    .PARAMETER MilestoneNumber
        If provided, will return all of the labels assigned to issues for this particular milestone.

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
        GitHub.Label

    .EXAMPLE
        Get-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub

        Gets the information for every label from the microsoft\PowerShellForGitHub project.

    .EXAMPLE
        Get-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel

        Gets the information for the label named "TestLabel" from the microsoft\PowerShellForGitHub
        project.

    .NOTES
        There were a lot of complications with the ParameterSets with this function due to pipeline
        input.  For the time being, the ParameterSets have been simplified and the validation of
        parameter combinations is happening within the function itself.
#>
    [CmdletBinding(DefaultParameterSetName = 'NameUri')]
    [OutputType({$script:GitHubLabelTypeName})]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('LabelName')]
        [string] $Label,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('IssueNumber')]
        [int64] $Issue,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int64] $MilestoneNumber,

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

    # There were a lot of complications trying to get pipelining working right when using all of
    # the necessary ParameterSets, so we'll do internal parameter validation instead until someone
    # can figure out the right way to do the parameter sets here _with_ pipeline support.
    if ($PSBoundParameters.ContainsKey('Label') -or
        $PSBoundParameters.ContainsKey('Issue') -or
        $PSBoundParameters.ContainsKey('MilestoneNumber'))
    {
        if (-not ($PSBoundParameters.ContainsKey('Label') -xor
            $PSBoundParameters.ContainsKey('Issue') -xor
            $PSBoundParameters.ContainsKey('MilestoneNumber')))
        {
            $message = 'Label, Issue and Milestone are mutually exclusive.  Only one can be specified in a single command.'
            Write-Log -Message $message -Level Error
            throw $message
        }
    }

    $uriFragment = [String]::Empty
    $description = [String]::Empty

    if ($PSBoundParameters.ContainsKey('Issue'))
    {
        $uriFragment = "/repos/$OwnerName/$RepositoryName/issues/$Issue/labels"
        $description = "Getting labels for Issue $Issue in $RepositoryName"
    }
    elseif ($PSBoundParameters.ContainsKey('MilestoneNumber'))
    {
        $uriFragment = "/repos/$OwnerName/$RepositoryName/milestones/$MilestoneNumber/labels"
        $description = "Getting labels for issues in Milestone $MilestoneNumber in $RepositoryName"
    }
    else
    {
        $uriFragment = "repos/$OwnerName/$RepositoryName/labels/$Label"

        if ($PSBoundParameters.ContainsKey('Name'))
        {
            $description = "Getting label $Label for $RepositoryName"
        }
        else
        {
            $description = "Getting labels for $RepositoryName"
        }
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AcceptHeader' = $script:symmetraAcceptHeader
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubLabelAdditionalProperties)
}

filter New-GitHubLabel
{
<#
    .SYNOPSIS
        Create a new label on a given GitHub repository.

    .DESCRIPTION
        Create a new label on a given GitHub repository.

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

    .PARAMETER Label
        Name of the label to be created.
        Emoji and codes are supported.
        For more information, see here: https://www.webpagefx.com/tools/emoji-cheat-sheet/

    .PARAMETER Color
        Color (in HEX) for the new label.

    .PARAMETER Description
        A short description of the label.

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
        GitHub.Label

    .EXAMPLE
        New-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -Color BBBBBB

        Creates a new, grey-colored label called "TestLabel" in the PowerShellForGitHub project.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements')]
    [OutputType({$script:GitHubLabelTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
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
            ValueFromPipeline)]
        [Alias('LabelName')]
        [string] $Label,

        [Parameter(Mandatory)]
        [ValidateScript({if ($_ -match '^#?[ABCDEF0-9]{6}$') { $true } else { throw "Color must be provided in hex." }})]
        [Alias('LabelColor')]
        [string] $Color = "EEEEEE",

        [string] $Description,

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

    # Be robust to users who choose to provide a color in hex by specifying the leading # sign
    # (by just stripping it out).
    if ($Color.StartsWith('#'))
    {
        $Color = $Color.Substring(1)
    }

    $hashBody = @{
        'name' = $Label
        'color' = $Color
        'description' = $Description
    }

    if (-not $PSCmdlet.ShouldProcess($Label, 'Create GitHub Label'))
    {
        return
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/labels"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Post'
        'Description' = "Creating label $Label in $RepositoryName"
        'AcceptHeader' = $script:symmetraAcceptHeader
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethod @params | Add-GitHubLabelAdditionalProperties)
}

filter Remove-GitHubLabel
{
<#
    .SYNOPSIS
        Deletes a label from a given GitHub repository.

    .DESCRIPTION
        Deletes a label from a given GitHub repository.

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

    .PARAMETER Label
        Name of the label to be deleted.
        Emoji and codes are supported.  For more information, see here: https://www.webpagefx.com/tools/emoji-cheat-sheet/

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
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .EXAMPLE
        Remove-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel

        Removes the label called "TestLabel" from the PowerShellForGitHub project.

    .EXAMPLE
        $label = $repo | Get-GitHubLabel -Label 'Test Label' -Color '#AAAAAA'
        $label | Remove-GitHubLabel

        Removes the label we just created using the pipeline, but will prompt for confirmation
        because neither -Confirm:$false nor -Force was specified.

    .EXAMPLE
        Remove-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -Confirm:$false

        Removes the label called "TestLabel" from the PowerShellForGitHub project.
        Will not prompt for confirmation, as -Confirm:$false was specified.

    .EXAMPLE
        Remove-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -Force

        Removes the label called "TestLabel" from the PowerShellForGitHub project.
        Will not prompt for confirmation, as -Force was specified.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements',
        ConfirmImpact="High")]
    [Alias('Delete-GitHubLabel')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
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
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('LabelName')]
        [string] $Label,

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

    if (-not $PSCmdlet.ShouldProcess($Label, 'Remove GitHub label'))
    {
        return
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/labels/$Label"
        'Method' = 'Delete'
        'Description' = "Deleting label $Label from $RepositoryName"
        'AcceptHeader' = $script:symmetraAcceptHeader
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return Invoke-GHRestMethod @params
}

filter Set-GitHubLabel
{
<#
    .SYNOPSIS
        Updates an existing label on a given GitHub repository.

    .DESCRIPTION
        Updates an existing label on a given GitHub repository.

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

    .PARAMETER Label
        Current name of the label to be updated.
        Emoji and codes are supported.
        For more information, see here: https://www.webpagefx.com/tools/emoji-cheat-sheet/

    .PARAMETER NewName
        New name for the label being updated.
        Emoji and codes are supported.
        For more information, see here: https://www.webpagefx.com/tools/emoji-cheat-sheet/

    .PARAMETER Color
        Color (in HEX) for the new label.

    .PARAMETER Description
        A short description of the label.

    .PARAMETER PassThru
        Returns the updated Label.  By default, this cmdlet does not generate any output.
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
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .OUTPUTS
        GitHub.Label

    .EXAMPLE
        Set-GitHubLabel  -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -NewName NewTestLabel -Color BBBB00

        Updates the existing label called TestLabel in the PowerShellForGitHub project to be called
        'NewTestLabel' and be colored yellow.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements')]
    [OutputType({$script:GitHubLabelTypeName})]
    [Alias('Update-GitHubLabel')] # Non-standard usage of the Update verb, but done to avoid a breaking change post 0.14.0
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
            ValueFromPipelineByPropertyName)]
        [Alias('LabelName')]
        [string] $Label,

        [Alias('NewLabelName')]
        [string] $NewName,

        [Alias('LabelColor')]
        [ValidateScript({if ($_ -match '^#?[ABCDEF0-9]{6}$') { $true } else { throw "Color must be provided in hex." }})]
        [string] $Color = "EEEEEE",

        [string] $Description,

        [switch] $PassThru,

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

    # Be robust to users who choose to provide a color in hex by specifying the leading # sign
    # (by just stripping it out).
    if ($Color.StartsWith('#'))
    {
        $Color = $Color.Substring(1)
    }

    $hashBody = @{}
    if ($PSBoundParameters.ContainsKey('NewName')) { $hashBody['name'] = $NewName }
    if ($PSBoundParameters.ContainsKey('Description')) { $hashBody['description'] = $Description }
    if ($PSBoundParameters.ContainsKey('Color')) { $hashBody['color'] = $Color }

    if (-not $PSCmdlet.ShouldProcess($Label, 'Update GitHub Label'))
    {
        return
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/labels/$Label"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Patch'
        'Description' = "Updating label $Label"
        'AcceptHeader' = $script:symmetraAcceptHeader
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubLabelAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Initialize-GitHubLabel
{
<#
    .SYNOPSIS
        Replaces the entire set of Labels on the given GitHub repository to match the provided list
        of Labels.

    .DESCRIPTION
        Replaces the entire set of Labels on the given GitHub repository to match the provided list
        of Labels.

        Will update the color/description for any Labels already in the repository that match the
        name of a Label in the provided list.  All other existing Labels will be removed, and then
        new Labels will be created to match the others in the Label list.

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

    .PARAMETER Label
        The array of Labels (name, color, description) that the repository should be aligning to.
        A default list of labels will be used if no Labels are provided.

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

    .EXAMPLE
        Initialize-GitHubLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label @(@{'name' = 'TestLabel'; 'color' = 'EEEEEE'}, @{'name' = 'critical'; 'color' = 'FF000000'; 'description' = 'Needs immediate attention'})

        Removes any labels not in this Label array, ensure the current assigned color and descriptions
        match what's in the array for the labels that do already exist, and then creates new labels
        for any remaining ones in the Label list.

    .NOTES
        This method does not rename any existing labels, as it doesn't have any context regarding
        which Label the new name is for.  Therefore, it is possible that by running this function
        on a repository with Issues that have already been assigned Labels, you may experience data
        loss as a minor correction to you (maybe fixing a typo) will result in the old Label being
        removed (and thus unassigned from existing Issues) and then the new one created.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
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
        [object[]] $Label,

        [string] $AccessToken
    )

    Write-InvocationLog

    if (($null -eq $Label) -or ($Label.Count -eq 0))
    {
        $Label = $script:defaultGitHubLabels
    }

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $commonParams = @{
        'OwnerName' = $OwnerName
        'RepositoryName' = $RepositoryName
        'AccessToken' = $AccessToken
    }

    $labelNames = $Label.name
    $existingLabels = Get-GitHubLabel @commonParams
    $existingLabelNames = $existingLabels.name

    if (-not $PSCmdlet.ShouldProcess(($Label -join ', '), 'Set GitHub Label'))
    {
        return
    }

    foreach ($labelToConfigure in $Label)
    {
        if ($labelToConfigure.name -notin $existingLabelNames)
        {
            # Create label if it doesn't exist
            $newGitHubLabelParms = @{
                Label = $labelToConfigure.name
                Color = $labelToConfigure.color
                Confirm = $false
                WhatIf = $false
            }

            $null = New-GitHubLabel @newGitHubLabelParms @commonParams
        }
        else
        {
            # Update label's color if it already exists
            $setGitHubLabelParms = @{
                Label = $labelToConfigure.name
                NewName = $labelToConfigure.name
                Color = $labelToConfigure.color
                Confirm = $false
                WhatIf = $false
            }

            $null = Set-GitHubLabel @setGitHubLabelParms @commonParams
        }
    }

    foreach ($labelName in $existingLabelNames)
    {
        if ($labelName -notin $labelNames)
        {
            # Remove label if it exists but is not in desired label list
            $removeGitHubLabelParms = @{
                Label = $labelName
                Confirm = $false
                WhatIf = $false
            }

            $null = Remove-GitHubLabel @removeGitHubLabelParms @commonParams
        }
    }
}

function Add-GitHubIssueLabel
{
<#
    .SYNOPSIS
        Adds a label to an issue in the given GitHub repository.

    .DESCRIPTION
        Adds a label to an issue in the given GitHub repository.

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

    .PARAMETER Issue
        Issue number to add the label to.

    .PARAMETER Label
        Array of label names to add to the issue

    .PARAMETER PassThru
        Returns the added Label.  By default, this cmdlet does not generate any output.
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
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .OUTPUTS
        GitHub.Label

    .EXAMPLE
        Add-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1 -Label $labels

        Adds labels to an issue in the PowerShellForGitHub project.

    .NOTES
        This is implemented as a function rather than a filter because the ValueFromPipeline
        parameter (Name) is itself an array which we want to ensure is processed only a single time.
        This API endpoint doesn't add labels to a repository, it replaces the existing labels with
        the new set provided, so we need to make sure that we have all the requested labels available
        to us at the time that the API endpoint is called.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements')]
    [OutputType({$script:GitHubLabelTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('IssueNumber')]
        [int64] $Issue,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)]
        [Alias('LabelName')]
        [ValidateNotNullOrEmpty()]
        [string[]] $Label,

        [switch] $PassThru,

        [string] $AccessToken
    )

    begin
    {
        $labelNames = @()
    }

    process
    {
        foreach ($name in $Label)
        {
            $labelNames += $name
        }
    }

    end
    {
        Write-InvocationLog

        $elements = Resolve-RepositoryElements
        $OwnerName = $elements.ownerName
        $RepositoryName = $elements.repositoryName

        $telemetryProperties = @{
            'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
            'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
            'LabelCount' = $Label.Count
        }

        $hashBody = @{
            'labels' = $labelNames
        }

        if (-not $PSCmdlet.ShouldProcess(($Label -join ', '), 'Add GitHub Issue Label'))
        {
            return
        }

        $params = @{
            'UriFragment' = "repos/$OwnerName/$RepositoryName/issues/$Issue/labels"
            'Body' = (ConvertTo-Json -InputObject $hashBody)
            'Method' = 'Post'
            'Description' = "Adding labels to issue $Issue in $RepositoryName"
            'AcceptHeader' = $script:symmetraAcceptHeader
            'AccessToken' = $AccessToken
            'TelemetryEventName' = $MyInvocation.MyCommand.Name
            'TelemetryProperties' = $telemetryProperties
        }

        $result = (Invoke-GHRestMethod @params | Add-GitHubLabelAdditionalProperties)
        if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        {
            return $result
        }
    }
}

function Set-GitHubIssueLabel
{
<#
    .SYNOPSIS
        Replaces labels on an issue in the given GitHub repository.

    .DESCRIPTION
        Replaces labels on an issue in the given GitHub repository.

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

    .PARAMETER Issue
        Issue number to replace the labels.

    .PARAMETER Label
        Array of label names that will be set on the issue.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER PassThru
        Returns the updated Label.  By default, this cmdlet does not generate any output.
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
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .OUTPUTS
        GitHub.Label

    .EXAMPLE
        Set-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1 -Label $labels

        Replaces labels on an issue in the PowerShellForGitHub project.

    .EXAMPLE
        ('help wanted', 'good first issue') | Set-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1

        Replaces labels on an issue in the PowerShellForGitHub project
        with 'help wanted' and 'good first issue'.

    .EXAMPLE
        Set-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1 -Confirm:$false

        Removes all labels from issue 1 in the PowerShellForGitHub project.
        Will not prompt for confirmation, as -Confirm:$false was specified.

        This is the same result as having called
        Remove-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1 -Confirm:$false

    .EXAMPLE
        Set-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1 -Force

        Removes all labels from issue 1 in the PowerShellForGitHub project.
        Will not prompt for confirmation, as -Force was specified.

        This is the same result as having called
        Remove-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Issue 1 -Force

    .NOTES
        This is implemented as a function rather than a filter because the ValueFromPipeline
        parameter (Name) is itself an array which we want to ensure is processed only a single time.
        This API endpoint doesn't add labels to a repository, it replaces the existing labels with
        the new set provided, so we need to make sure that we have all the requested labels available
        to us at the time that the API endpoint is called.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'Elements')]
    [OutputType({$script:GitHubLabelTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
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
            ValueFromPipelineByPropertyName)]
        [Alias('IssueNumber')]
        [int64] $Issue,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('LabelName')]
        [string[]] $Label,

        [switch] $Force,

        [switch] $PassThru,

        [string] $AccessToken
    )

    begin
    {
        $labelNames = @()
    }

    process
    {
        foreach ($name in $Label)
        {
            $labelNames += $name
        }
    }

    end
    {
        Write-InvocationLog

        $elements = Resolve-RepositoryElements
        $OwnerName = $elements.ownerName
        $RepositoryName = $elements.repositoryName

        $telemetryProperties = @{
            'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
            'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
            'LabelCount' = $Label.Count
        }

        $hashBody = @{
            'labels' = $labelNames
        }

        $shouldProcessMessage = "Set GitHub Issue Label(s) $($Label -join ', ')"

        if ([System.String]::IsNullOrEmpty($Label))
        {
            $ConfirmPreference = 'Low'
            $shouldProcessMessage = 'Remove all GitHub Issue Labels'
        }

        if ($Force -and (-not $Confirm))
        {
            $ConfirmPreference = 'None'
        }

        if (-not $PSCmdlet.ShouldProcess("Issue #$Issue", $shouldProcessMessage))
        {
            return
        }

        $params = @{
            'UriFragment' = "repos/$OwnerName/$RepositoryName/issues/$Issue/labels"
            'Body' = (ConvertTo-Json -InputObject $hashBody)
            'Method' = 'Put'
            'Description' = "Replacing labels to issue $Issue in $RepositoryName"
            'AcceptHeader' = $script:symmetraAcceptHeader
            'AccessToken' = $AccessToken
            'TelemetryEventName' = $MyInvocation.MyCommand.Name
            'TelemetryProperties' = $telemetryProperties
        }

        $result = (Invoke-GHRestMethod @params | Add-GitHubLabelAdditionalProperties)
        if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
        {
            return $result
        }
    }
}

filter Remove-GitHubIssueLabel
{
<#
    .SYNOPSIS
        Deletes a label from an issue in the given GitHub repository.

    .DESCRIPTION
        Deletes a label from an issue in the given GitHub repository.

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

    .PARAMETER Issue
        Issue number to remove the label from.

    .PARAMETER Label
        Name of the label to be deleted. If not provided, will delete all labels on the issue.
        Emoji and codes are supported.
        For more information, see here: https://www.webpagefx.com/tools/emoji-cheat-sheet/

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
        GitHub.Reaction
        GitHub.Release
        GitHub.ReleaseAsset
        GitHub.Repository

    .EXAMPLE
        Remove-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -Issue 1

        Removes the label called "TestLabel" from issue 1 in the PowerShellForGitHub project.

    .EXAMPLE
        Remove-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -Issue 1 -Confirm:$false

        Removes the label called "TestLabel" from issue 1 in the PowerShellForGitHub project.
        Will not prompt for confirmation, as -Confirm:$false was specified.

    .EXAMPLE
        Remove-GitHubIssueLabel -OwnerName microsoft -RepositoryName PowerShellForGitHub -Label TestLabel -Issue 1 -Force

        Removes the label called "TestLabel" from issue 1 in the PowerShellForGitHub project.
        Will not prompt for confirmation, as -Force was specified.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements',
        ConfirmImpact="High")]
    [Alias('Delete-GitHubLabel')]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('IssueNumber')]
        [int64] $Issue,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('LabelName')]
        [string] $Label,

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

    $description = [String]::Empty
    if ($PSBoundParameters.ContainsKey('Label'))
    {
        $description = "Deleting label $Label from issue $Issue in $RepositoryName"
    }
    else
    {
        $description = "Deleting all labels from issue $Issue in $RepositoryName"
    }

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Label, 'Remove GitHub Issue label'))
    {
        return
    }

    $params = @{
        'UriFragment' = "/repos/$OwnerName/$RepositoryName/issues/$Issue/labels/$Label"
        'Method' = 'Delete'
        'Description' = $description
        'AcceptHeader' = $script:symmetraAcceptHeader
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return Invoke-GHRestMethod @params
}

filter Add-GitHubLabelAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Label objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER RepositoryUrl
        Optionally supplied if the Label object doesn't have this value already
        (as is the case for GitHub.LabelSummary).

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Label
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

        [string] $RepositoryUrl,

        [ValidateNotNullOrEmpty()]
        [string] $TypeName = $script:GitHubLabelTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            if (-not [System.String]::IsNullOrEmpty($item.url))
            {
                $elements = Split-GitHubUri -Uri $item.url
                $RepositoryUrl = Join-GitHubUri @elements
            }

            Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $RepositoryUrl -MemberType NoteProperty -Force

            if ($null -ne $item.id)
            {
                Add-Member -InputObject $item -Name 'LabelId' -Value $item.id -MemberType NoteProperty -Force
            }

            Add-Member -InputObject $item -Name 'LabelName' -Value $item.name -MemberType NoteProperty -Force
        }

        Write-Output $item
    }
}

# A set of labels that a project might want to initially populate their repository with
# Used by Set-GitHubLabel when no Label list is provided by the user.
# This list exists to support v0.1.0 users.
$script:defaultGitHubLabels = @(
    @{
        'name' = 'pri:lowest'
        'color' = '4285F4'
    },
    @{
        'name' = 'pri:low'
        'color' = '4285F4'
    },
    @{
        'name' = 'pri:medium'
        'color' = '4285F4'
    },
    @{
        'name' = 'pri:high'
        'color' = '4285F4'
    },
    @{
        'name' = 'pri:highest'
        'color' = '4285F4'
    },
    @{
        'name' = 'bug'
        'color' = 'fc2929'
    },
    @{
        'name' = 'duplicate'
        'color' = 'cccccc'
    },
    @{
        'name' = 'enhancement'
        'color' = '121459'
    },
    @{
        'name' = 'up for grabs'
        'color' = '159818'
    },
    @{
        'name' = 'question'
        'color' = 'cc317c'
    },
    @{
        'name' = 'discussion'
        'color' = 'fe9a3d'
    },
    @{
        'name' = 'wontfix'
        'color' = 'dcb39c'
    },
    @{
        'name' = 'in progress'
        'color' = 'f0d218'
    },
    @{
        'name' = 'ready'
        'color' = '145912'
    }
)

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCByMZePM4uqMoEn
# +KmS4gM0LrWi36rl9DD0+LU5efIVGKCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgWedXwhsp
# u/v1cMX1VrHi+h3KqDgoxDG5tN2wConMErcwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCqOdutETSA98rETFWb3wKCLGwo764l39C+QW70BmW1
# c0eKYdkXkzqei0YKqZHXeJ6KajDz91/xOR3gqeyaw0li1SISwnMmPSUVSZ+6zFtS
# LQ/1ZZ8cv7xcXp09suLqXC0s9QctTmoCr68Y2SFtWudgCEHjcizl8hHztxcFpP71
# XV34bNK8L2B8GMUfyywpus2lvdM/BQYuxOsb5eit0f4c+rYXxj5MRyLNt8oDDkX5
# aeIlugEOJC+I6w1MBREdy0AHCvwoSgF3W8G0nfshHSgZ9bj0kGOWxb+JamQBLp7m
# yMTShpfQxUpWfRfiWfTQcO8XxESeiVf1nOs6kiURRC5qoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIJD6lKTMFRnAUyYIUW1nBQir7l603IMMv7mynGMv
# yfxOAgZf25oj+xcYEzIwMjEwMTA1MTk1MDU1Ljk2OVowBIACAfSggdSkgdEwgc4x
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
# CQQxIgQgO3RhRgxnW7Q+DFZu1/pNILTj5GEDehP/XE3zdKiLkCowgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBDmDWEWvc6fhs5t4Woo5Q+FMFCcaIgV4yUP4Cp
# uBmLmTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# KugXlviGp++jAAAAAAEqMCIEIH2jzt1Yv9t70Lv0ufD8m03qKX6QoK++mcXnW8K+
# YCydMA0GCSqGSIb3DQEBCwUABIIBADFB13fNWPnNfg1Z3N2SkyklNi0BsI3uHdyQ
# Eo0ZVgICZc0y0SJqXqwujZOwifi5MfcZmkFUbfIRMd3tcas14HowRNxFudOkSetB
# tf3Q9TjtIYKg9pX7iD+FGJ00YI4vNnBMDGVY5deHNl4xHdnbjoOLuZXnyfz5JJOD
# M8yNboco4AbUAdkbm4iZJlI/+HzqsagIuT0WhYihv9hHq5RVyPmQ7flS8r65ljTz
# /TYSk7rL2S3T3Ny5QTaEKVuVBK7mptcVNQWdymooTGjVqqcpZUEVpxhpsAGxFTUS
# N6krfeU1XCjo7drRtIXX+taGaVjb/ZDINHLfQdVc8QIJ2RwoSDk=
# SIG # End signature block
