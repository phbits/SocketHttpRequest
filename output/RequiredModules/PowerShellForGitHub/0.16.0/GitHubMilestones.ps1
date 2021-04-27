# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubMilestoneTypeName = 'GitHub.Milestone'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

# For more information refer to:
#  https://github.community/t5/How-to-use-Git-and-GitHub/Milestone-quot-Due-On-quot-field-defaults-to-7-00-when-set-by-v3/m-p/6901
$script:minimumHoursToEnsureDesiredDateInPacificTime = 9

filter Get-GitHubMilestone
{
<#
    .SYNOPSIS
        Get the milestones for a given GitHub repository.

    .DESCRIPTION
        Get the milestones for a given GitHub repository.

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

    .PARAMETER Milestone
        The number of a specific milestone to get. If not supplied, will return back all milestones
        for this repository.

    .PARAMETER Sort
        How to sort the results.

    .PARAMETER Direction
        How to list the results. Ignored without the sort parameter.

    .PARAMETER State
        Only milestones with this state are returned.

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
        GitHub.Milestone

    .EXAMPLE
        Get-GitHubMilestone -OwnerName microsoft -RepositoryName PowerShellForGitHub
        Get the milestones for the microsoft\PowerShellForGitHub project.

    .EXAMPLE
        Get-GitHubMilestone -Uri 'https://github.com/PowerShell/PowerShellForGitHub' -Milestone 1
        Get milestone number 1 for the microsoft\PowerShellForGitHub project.
#>
    [CmdletBinding(DefaultParameterSetName = 'RepositoryElements')]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName='MilestoneElements')]
        [Parameter(
            Mandatory,
            ParameterSetName='RepositoryElements')]
        [string] $OwnerName,

        [Parameter(
            Mandatory,
            ParameterSetName='MilestoneElements')]
        [Parameter(
            Mandatory,
            ParameterSetName='RepositoryElements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='MilestoneUri')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='RepositoryUri')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            ParameterSetName='MilestoneUri')]
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            ParameterSetName='MilestoneElements')]
        [Alias('MilestoneNumber')]
        [int64] $Milestone,

        [Parameter(ParameterSetName='RepositoryUri')]
        [Parameter(ParameterSetName='RepositoryElements')]
        [ValidateSet('Open', 'Closed', 'All')]
        [string] $State,

        [Parameter(ParameterSetName='RepositoryUri')]
        [Parameter(ParameterSetName='RepositoryElements')]
        [ValidateSet('DueOn', 'Completeness')]
        [string] $Sort,

        [Parameter(ParameterSetName='RepositoryUri')]
        [Parameter(ParameterSetName='RepositoryElements')]
        [ValidateSet('Ascending', 'Descending')]
        [string] $Direction,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName
    $uriFragment = [String]::Empty
    $description = [String]::Empty

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
        'ProvidedMilestone' = $PSBoundParameters.ContainsKey('Milestone')
    }

    if ($PSBoundParameters.ContainsKey('Milestone'))
    {
        $uriFragment = "repos/$OwnerName/$RepositoryName/milestones/$Milestone"
        $description = "Getting milestone $Milestone for $RepositoryName"
    }
    else
    {
        $getParams = @()

        if ($PSBoundParameters.ContainsKey('Sort'))
        {
            $sortConverter = @{
                'Completeness' = 'completeness'
                'DueOn' = 'due_on'
            }

            $getParams += "sort=$($sortConverter[$Sort])"

            # We only look at this parameter if the user provided Sort as well.
            if ($PSBoundParameters.ContainsKey('Direction'))
            {
                $directionConverter = @{
                    'Ascending' = 'asc'
                    'Descending' = 'desc'
                }

                $getParams += "direction=$($directionConverter[$Direction])"
            }
        }

        if ($PSBoundParameters.ContainsKey('State'))
        {
            $State = $State.ToLower()
            $getParams += "state=$State"
        }

        $uriFragment = "repos/$OwnerName/$RepositoryName/milestones`?" +  ($getParams -join '&')
        $description = "Getting milestones for $RepositoryName"
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubMilestoneAdditionalProperties)
}

filter New-GitHubMilestone
{
<#
    .SYNOPSIS
        Creates a new GitHub milestone for the given repository.

    .DESCRIPTION
        Creates a new GitHub milestone for the given repository.

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

    .PARAMETER Title
        The title of the milestone.

    .PARAMETER State
        The state of the milestone.

    .PARAMETER Description
        A description of the milestone.

    .PARAMETER DueOn
        The milestone due date.
        GitHub will drop any time provided with this value, therefore please ensure that the
        UTC version of this value has your desired date.

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
        GitHub.Milestone

    .EXAMPLE
        New-GitHubMilestone -OwnerName microsoft -RepositoryName PowerShellForGitHub -Title "Testing this API"

        Creates a new GitHub milestone for the microsoft\PowerShellForGitHub project.

    .NOTES
        For more information on how GitHub handles the dates specified in DueOn, please refer to
        this support forum post:
        https://github.community/t5/How-to-use-Git-and-GitHub/Milestone-quot-Due-On-quot-field-defaults-to-7-00-when-set-by-v3/m-p/6901

        Please note that due to artifacts of how GitHub was originally designed, all timestamps
        in the GitHub database are normalized to Pacific Time.  This means that any dates specified
        that occur before 7am UTC will be considered timestamps for the _previous_ day.

        Given that GitHub drops the _time_ aspect of this DateTime, this function will ensure that
        the requested DueOn date specified is honored by manipulating the time as needed.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements')]
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
            ValueFromPipeline,
            ParameterSetName='Uri')]
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ParameterSetName='Elements')]
        [string] $Title,

        [ValidateSet('Open', 'Closed')]
        [string] $State,

        [string] $Description,

        [DateTime] $DueOn,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
        'Title' =  (Get-PiiSafeString -PlainText $Title)
    }

    $hashBody = @{
        'title' = $Title
    }

    if ($PSBoundParameters.ContainsKey('State'))
    {
        $State = $State.ToLower()
        $hashBody.add('state', $State)
    }

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $hashBody.add('description', $Description)
    }

    if ($PSBoundParameters.ContainsKey('DueOn'))
    {
        # If you set 'due_on' to be '2020-09-24T06:59:00Z', GitHub considers that to be '2020-09-23T07:00:00Z'
        # And if you set 'due_on' to be '2020-09-24T07:01:00Z', GitHub considers that to be '2020-09-24T07:00:00Z'
        # SO....we can't depend on the typical definition of midnight when trying to specify a specific day.
        # Instead, we'll use 9am on the designated date to ensure we're always dealing with the
        # same date that GitHub uses, regardless of the current state of Daylight Savings Time.
        # (See .NOTES for more info)
        $modifiedDueOn = $DueOn.ToUniversalTime().date.AddHours($script:minimumHoursToEnsureDesiredDateInPacificTime)
        $dueOnFormattedTime = $modifiedDueOn.ToString('o')
        $hashBody.add('due_on', $dueOnFormattedTime)
    }

    if (-not $PSCmdlet.ShouldProcess($Title, 'Create GitHub Milestone'))
    {
        return
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/milestones"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Post'
        'Description' = "Creating milestone for $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethod @params | Add-GitHubMilestoneAdditionalProperties)
}

filter Set-GitHubMilestone
{
<#
    .SYNOPSIS
        Update an existing milestone for the given repository.

    .DESCRIPTION
        Update an existing milestone for the given repository.

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

    .PARAMETER Milestone
        The number of a specific milestone to get.

    .PARAMETER Title
        The title of the milestone.

    .PARAMETER State
        The state of the milestone.

    .PARAMETER Description
        A description of the milestone.

    .PARAMETER DueOn
        The milestone due date.
        GitHub will drop any time provided with this value, therefore please ensure that the
        UTC version of this value has your desired date.

    .PARAMETER PassThru
        Returns the updated Milestone.  By default, this cmdlet does not generate any output.
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
        GitHub.Milestone

    .EXAMPLE
        Set-GitHubMilestone -OwnerName microsoft -RepositoryName PowerShellForGitHub -Milestone 1 -Title "Testing this API"

        Update an existing milestone for the microsoft\PowerShellForGitHub project.

    .NOTES
        For more information on how GitHub handles the dates specified in DueOn, please refer to
        this support forum post:
        https://github.community/t5/How-to-use-Git-and-GitHub/Milestone-quot-Due-On-quot-field-defaults-to-7-00-when-set-by-v3/m-p/6901

        Please note that due to artifacts of how GitHub was originally designed, all timestamps
        in the GitHub database are normalized to Pacific Time.  This means that any dates specified
        that occur before 7am UTC will be considered timestamps for the _previous_ day.

        Given that GitHub drops the _time_ aspect of this DateTime, this function will ensure that
        the requested DueOn date specified is honored by manipulating the time as needed.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements')]
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
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Elements')]
        [Alias('MilestoneNumber')]
        [int64] $Milestone,

        [Parameter(
            Mandatory,
            ParameterSetName='Uri')]
        [Parameter(
            Mandatory,
            ParameterSetName='Elements')]
        [string] $Title,

        [ValidateSet('Open', 'Closed')]
        [string] $State,

        [string] $Description,

        [DateTime] $DueOn,

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
        'Title' =  (Get-PiiSafeString -PlainText $Title)
        'Milestone' =  (Get-PiiSafeString -PlainText $Milestone)
    }

    $hashBody = @{
        'title' = $Title
    }

    if ($PSBoundParameters.ContainsKey('State'))
    {
        $State = $State.ToLower()
        $hashBody.add('state', $State)
    }

    if ($PSBoundParameters.ContainsKey('Description'))
    {
        $hashBody.add('description', $Description)
    }

    if ($PSBoundParameters.ContainsKey('DueOn'))
    {
        # If you set 'due_on' to be '2020-09-24T06:59:00Z', GitHub considers that to be '2020-09-23T07:00:00Z'
        # And if you set 'due_on' to be '2020-09-24T07:01:00Z', GitHub considers that to be '2020-09-24T07:00:00Z'
        # SO....we can't depend on the typical definition of midnight when trying to specify a specific day.
        # Instead, we'll use 9am on the designated date to ensure we're always dealing with the
        # same date that GitHub uses, regardless of the current state of Daylight Savings Time.
        # (See .NOTES for more info)
        $modifiedDueOn = $DueOn.ToUniversalTime().date.AddHours($script:minimumHoursToEnsureDesiredDateInPacificTime)
        $dueOnFormattedTime = $modifiedDueOn.ToString('o')
        $hashBody.add('due_on', $dueOnFormattedTime)
    }

    if (-not $PSCmdlet.ShouldProcess($Milestone, 'Set GitHub Milestone'))
    {
        return
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/milestones/$Milestone"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Patch'
        'Description' = "Setting milestone $Milestone for $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubMilestoneAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Remove-GitHubMilestone
{
<#
    .SYNOPSIS
        Deletes a GitHub milestone for the given repository.

    .DESCRIPTION
        Deletes a GitHub milestone for the given repository.

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

    .PARAMETER Milestone
        The number of a specific milestone to delete.

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
        Remove-GitHubMilestone -OwnerName microsoft -RepositoryName PowerShellForGitHub -Milestone 1

        Deletes a GitHub milestone from the microsoft\PowerShellForGitHub project.

    .EXAMPLE
        Remove-GitHubMilestone -OwnerName microsoft -RepositoryName PowerShellForGitHub -Milestone 1 -Confirm:$false

        Deletes a Github milestone from the microsoft\PowerShellForGitHub project. Will not prompt
        for confirmation, as -Confirm:$false was specified.

    .EXAMPLE
        Remove-GitHubMilestone -OwnerName microsoft -RepositoryName PowerShellForGitHub -Milestone 1 -Force

        Deletes a Github milestone from the microsoft\PowerShellForGitHub project. Will not prompt
        for confirmation, as -Force was specified.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName='Elements',
        ConfirmImpact="High")]
    [Alias('Delete-GitHubMilestone')]
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
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Elements')]
        [Alias('MilestoneNumber')]
        [int64] $Milestone,

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
        'Milestone' =  (Get-PiiSafeString -PlainText $Milestone)
    }

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Milestone, 'Remove GitHub Milestone'))
    {
        return
    }

    $params = @{
        'UriFragment' = "repos/$OwnerName/$RepositoryName/milestones/$Milestone"
        'Method' = 'Delete'
        'Description' = "Removing milestone $Milestone for $RepositoryName"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return Invoke-GHRestMethod @params
}

filter Add-GitHubMilestoneAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Milestone objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Milestone
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
        [string] $TypeName = $script:GitHubMilestoneTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            $elements = Split-GitHubUri -Uri $item.html_url
            $repositoryUrl = Join-GitHubUri @elements
            Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force
            Add-Member -InputObject $item -Name 'MilestoneId' -Value $item.id -MemberType NoteProperty -Force
            Add-Member -InputObject $item -Name 'MilestoneNumber' -Value $item.number -MemberType NoteProperty -Force

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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBUBMZi62EgrVXF
# HPVTIL74zODUkVV+FU6DSzez7dJIhKCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgX9mZIqPh
# nikIZZN43AScmBzMkfVElmse5Uk7Lb1Iq6owQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCe94pRLHVj2BhPboWfxSePtH5ekHel+cRMkvrpckm4
# yrKMbnUstTx4DOfjcwzzsqLnbZOD5ohnm5EhA5IKVp4/UHG3hmKyUnGrk5Oawbzs
# upix1yGNr0qCD79X+KtBr/mV4GtiK4CW6FZyb3nFrZ60dBJUSxROYzbAvD0R7mzq
# Vfke6MSCP7BdIpxlX0iTbal2SrPKBoCKguFmSIblrLfxMA9cPnq0kJ+HtqWDZ/BJ
# MQjj3nzF36pDzcv1Fz9u8hDnNExxoQ+6VHTOGC7WrN+i2G5veIAxXFQ6D6Co1Mo/
# 1uCfsNJ8kd8fzVlfP6qIc/gJuQrw7/HRTq6s9CIZUC4CoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIM62fSQGBG7SEjJjleqm/pE/3/rxMkfCCaYEHbR7
# tRE8AgZf24tr7DoYEzIwMjEwMTA1MTk1MDU0LjU2NVowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpGN0E2LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABJYvei2xyJjHdAAAA
# AAElMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTQ1OFoXDTIxMDMxNzAxMTQ1OFowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2
# LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANB7H2N2YFvs4cnBJiYx
# Sitk3ABy/xXLfpOUm7NxXHsb6UWq3bONY4yVI4ySbVegC4nxVnlKEF50ANcMYMrE
# c1mEu7cRbzHmi38g6TqLMtOUAW28hc6DNez8do4zvZccrKQxkcB0v9+lm0BIzk9q
# Waxdfg6XyVeSb2NHnkrnoLur36ENT7a2MYdoTVlaVpuU1RcGFpmC0IkJ3rRTJm+A
# jv+43Nxp+PT9XDZtqK32cMBV3bjK39cJmcdjfJftmweMi4emyX4+kNdqLUPB72nS
# vIJmyX1I4wd7G0gd72qVNu1Zgnxa1Yugf10QxDFUueY88M5WYGPstmFKOLfw31Wn
# P8UCAwEAAaOCARswggEXMB0GA1UdDgQWBBTzqsrlByb5ATk0FcYI8iIIF0Mk+DAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQCTHFk8YSAiACGypk1NmTnxXW9CInmN
# rbEeXlOoYDofCPlKKguDcVIuJOYZX4G0WWlhS2Sd4HiOtmy42ky19tMx0bun/EDI
# hW3C9edNeoqUIPVP0tyv3ilV53McYnMvVNg1DJkkGi4J/OSCTNxw64U595Y9+cxO
# IjlQFbk52ajIc9BYNIYehuhbV1Mqpd4m25UNNhsdMqzjON8IEwWObKVG7nZmmLP7
# 0wF5GPiIB6i7QX/fG8jN6mggqBRYJn2aZWJYSRXAK1MZtXx4rvcp4QTS18xT9hjZ
# SagY9zxjBu6sMR96V6Atb5geR+twYAaV+0Kaq0504t6CEugbRRvH8HuxMIIGcTCC
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
# N0E2LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUARdMv4VBtzYb7cxde8hEpWvahcKeggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOOfFaowIhgPMjAyMTAxMDUyMDQzMjJaGA8yMDIxMDEwNjIwNDMyMlowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA458VqgIBADAKAgEAAgIjXQIB/zAHAgEAAgIRsTAK
# AgUA46BnKgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAKU00xy2Q62Vl0M/
# +8c+f2l25SXxPFKgiGTUmKyJSBnFHanp9NKxeMHKFE6mAzDAmjM2vMJqIKTOo0PR
# pxz4gxBaGkgbMI0B5qanRY9YtcOwsfjJafdJP+LnkWu8nTaCniO8uVGcmNp7rrkB
# Ujg9FWxPcmIc+zgR1zaqInGVHXQPMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEli96LbHImMd0AAAAAASUwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgcUFrttQwIvvbG7mqwSqkRay8a7S4Q12upx3RlhS7gQ8wgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBd38ayLm8wX/qJfYIOH5V+YvlG+poWQXCW6LKN
# 70H3DjCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# JYvei2xyJjHdAAAAAAElMCIEICj1KXREoxy1d/9JI+m1c9jthWOeT04l198fQegk
# 3uwOMA0GCSqGSIb3DQEBCwUABIIBAAetdYQqH1IxtxZxDilSct08jP2HPkjeUduM
# HIva6uQ5CbOa7cKxmSVUYw+V3rqymiWbk7l7HpyBuTYNfUeYhB8UzDoI3hsx+zya
# vDlzVKygJYZ1J8xWYnCESZyCB+7NZlPKJHiC/OTuc/Hot+SVYPX4Vdir2nbxE2Oh
# +xmDEH+DQDSXVW89BaPvmQ9eWj12/vcikt2MNGvo1ELGUFZ5qo2JRJW9DcPmJMfF
# tSU2d3l/aliLra0arM0tr5xJ9I4czzT0txIlu/vFCYjX/PYJLXv6C0PVpuBDKoZ8
# u/Dsc1FI8XFqNTS2S4JNHoZq95+KYOqzsxIm7VIdDaCuADZQ41I=
# SIG # End signature block
