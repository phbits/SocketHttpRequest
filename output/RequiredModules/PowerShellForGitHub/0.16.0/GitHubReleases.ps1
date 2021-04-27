# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubReleaseTypeName = 'GitHub.Release'
    GitHubReleaseAssetTypeName = 'GitHub.ReleaseAsset'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubRelease
{
<#
    .SYNOPSIS
        Retrieves information about a release or list of releases on GitHub.

    .DESCRIPTION
        Retrieves information about a release or list of releases on GitHub.

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

    .PARAMETER Release
        The ID of a specific release.
        This is an optional parameter which can limit the results to a single release.

    .PARAMETER Latest
        Retrieve only the latest release.
        This is an optional parameter which can limit the results to a single release.

    .PARAMETER Tag
        Retrieves a list of releases with the associated tag.
        This is an optional parameter which can filter the list of releases.

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
        GitHub.Release

    .EXAMPLE
        Get-GitHubRelease

        Gets all releases for the default configured owner/repository.

    .EXAMPLE
        Get-GitHubRelease -Release 12345

        Get a specific release for the default configured owner/repository

    .EXAMPLE
        Get-GitHubRelease -OwnerName dotnet -RepositoryName core

        Gets all releases from the dotnet\core repository.

    .EXAMPLE
        Get-GitHubRelease -Uri https://github.com/microsoft/PowerShellForGitHub

        Gets all releases from the microsoft/PowerShellForGitHub repository.

    .EXAMPLE
        Get-GitHubRelease -OwnerName dotnet -RepositoryName core -Latest

        Gets the latest release from the dotnet\core repository.

    .EXAMPLE
        Get-GitHubRelease -Uri https://github.com/microsoft/PowerShellForGitHub -Tag 0.8.0

        Gets the release tagged with 0.8.0 from the microsoft/PowerShellForGitHub repository.

    .NOTES
        Information about published releases are available to everyone. Only users with push
        access will receive listings for draft releases.
#>
    [CmdletBinding(DefaultParameterSetName='Elements')]
    [OutputType({$script:GitHubReleaseTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [Parameter(ParameterSetName="Elements-ReleaseId")]
        [Parameter(ParameterSetName="Elements-Latest")]
        [Parameter(ParameterSetName="Elements-Tag")]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [Parameter(ParameterSetName="Elements-ReleaseId")]
        [Parameter(ParameterSetName="Elements-Latest")]
        [Parameter(ParameterSetName="Elements-Tag")]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri')]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName="Uri-ReleaseId")]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName="Uri-Latest")]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName="Uri-Tag")]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName="Elements-ReleaseId")]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName="Uri-ReleaseId")]
        [Alias('ReleaseId')]
        [int64] $Release,

        [Parameter(
            Mandatory,
            ParameterSetName='Elements-Latest')]
        [Parameter(
            Mandatory,
            ParameterSetName='Uri-Latest')]
        [switch] $Latest,

        [Parameter(
            Mandatory,
            ParameterSetName='Elements-Tag')]
        [Parameter(
            Mandatory,
            ParameterSetName='Uri-Tag')]
        [string] $Tag,

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

    $uriFragment = "repos/$OwnerName/$RepositoryName/releases"
    $description = "Getting releases for $OwnerName/$RepositoryName"

    if ($PSBoundParameters.ContainsKey('Release'))
    {
        $telemetryProperties['ProvidedRelease'] = $true

        $uriFragment += "/$Release"
        $description = "Getting release information for $Release from $OwnerName/$RepositoryName"
    }

    if ($Latest)
    {
        $telemetryProperties['GetLatest'] = $true

        $uriFragment += "/latest"
        $description = "Getting latest release from $OwnerName/$RepositoryName"
    }

    if (-not [String]::IsNullOrEmpty($Tag))
    {
        $telemetryProperties['ProvidedTag'] = $true

        $uriFragment += "/tags/$Tag"
        $description = "Getting releases tagged with $Tag from $OwnerName/$RepositoryName"
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubReleaseAdditionalProperties)
}

filter New-GitHubRelease
{
<#
    .SYNOPSIS
        Create a new release for a repository on GitHub.

    .DESCRIPTION
        Create a new release for a repository on GitHub.

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

    .PARAMETER Tag
        The name of the tag.  The tag will be created around the committish if it doesn't exist
        in the remote, and will need to be synced back to the local repository afterwards.

    .PARAMETER Committish
        The committish value that determines where the Git tag is created from.
        Can be any branch or commit SHA.  Unused if the Git tag already exists.
        Will default to the repository's default branch (usually 'master').

    .PARAMETER Name
        The name of the release.

    .PARAMETER Body
        Text describing the contents of the tag.

    .PARAMETER Draft
        Specifies if this should be a draft (unpublished) release or a published one.

    .PARAMETER PreRelease
        Indicates if this should be identified as a pre-release or as a full release.

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
        GitHub.Release

    .EXAMPLE
        New-GitHubRelease -OwnerName microsoft -RepositoryName PowerShellForGitHub -Tag 0.12.0

    .NOTES
        Requires push access to the repository.

        This endpoind triggers notifications.  Creating content too quickly using this endpoint
        may result in abuse rate limiting.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubReleaseTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 1)]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            Position = 2)]
        [string] $Tag,

        [Alias('Sha')]
        [Alias('BranchName')]
        [Alias('Commitish')] # git documentation says "committish", but GitHub uses "commitish"
        [string] $Committish,

        [string] $Name,

        [Alias('Description')]
        [string] $Body,

        [switch] $Draft,

        [switch] $PreRelease,

        [string] $AccessToken
    )

    Write-InvocationLog

    $elements = Resolve-RepositoryElements
    $OwnerName = $elements.ownerName
    $RepositoryName = $elements.repositoryName

    $telemetryProperties = @{
        'OwnerName' = (Get-PiiSafeString -PlainText $OwnerName)
        'RepositoryName' = (Get-PiiSafeString -PlainText $RepositoryName)
        'ProvidedCommittish' = ($PSBoundParameters.ContainsKey('Committish'))
        'ProvidedName' = ($PSBoundParameters.ContainsKey('Name'))
        'ProvidedBody' = ($PSBoundParameters.ContainsKey('Body'))
        'ProvidedDraft' = ($PSBoundParameters.ContainsKey('Draft'))
        'ProvidedPreRelease' = ($PSBoundParameters.ContainsKey('PreRelease'))
    }

    $hashBody = @{
        'tag_name' = $Tag
    }

    if ($PSBoundParameters.ContainsKey('Committish')) { $hashBody['target_commitish'] = $Committish }
    if ($PSBoundParameters.ContainsKey('Name')) { $hashBody['name'] = $Name }
    if ($PSBoundParameters.ContainsKey('Body')) { $hashBody['body'] = $Body }
    if ($PSBoundParameters.ContainsKey('Draft')) { $hashBody['draft'] = $Draft.ToBool() }
    if ($PSBoundParameters.ContainsKey('PreRelease')) { $hashBody['prerelease'] = $PreRelease.ToBool() }

    $params = @{
        'UriFragment' = "/repos/$OwnerName/$RepositoryName/releases"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Post'
        'Description' = "Creating release at $Tag"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    if (-not $PSCmdlet.ShouldProcess($Tag, "Create release for $RepositoryName at tag"))
    {
        return
    }

    return (Invoke-GHRestMethod @params | Add-GitHubReleaseAdditionalProperties)
}

filter Set-GitHubRelease
{
<#
    .SYNOPSIS
        Edits a release for a repository on GitHub.

    .DESCRIPTION
        Edits a release for a repository on GitHub.

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

    .PARAMETER Release
        The ID of the release to edit.

    .PARAMETER Tag
        The name of the tag.

    .PARAMETER Committish
        The committish value that determines where the Git tag is created from.
        Can be any branch or commit SHA.  Unused if the Git tag already exists.
        Will default to the repository's default branch (usually 'master').

    .PARAMETER Name
        The name of the release.

    .PARAMETER Body
        Text describing the contents of the tag.

    .PARAMETER Draft
        Specifies if this should be a draft (unpublished) release or a published one.

    .PARAMETER PreRelease
        Indicates if this should be identified as a pre-release or as a full release.

    .PARAMETER PassThru
        Returns the updated GitHub Release.  By default, this cmdlet does not generate any output.
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
        GitHub.Release

    .EXAMPLE
        Set-GitHubRelease -OwnerName microsoft -RepositoryName PowerShellForGitHub -Tag 0.12.0 -Body 'Adds core support for Projects'

    .NOTES
        Requires push access to the repository.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubReleaseTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 1)]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [Alias('ReleaseId')]
        [int64] $Release,

        [string] $Tag,

        [Alias('Sha')]
        [Alias('BranchName')]
        [Alias('Commitish')] # git documentation says "committish", but GitHub uses "commitish"
        [string] $Committish,

        [string] $Name,

        [Alias('Description')]
        [string] $Body,

        [switch] $Draft,

        [switch] $PreRelease,

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
        'ProvidedTag' = ($PSBoundParameters.ContainsKey('Tag'))
        'ProvidedCommittish' = ($PSBoundParameters.ContainsKey('Committish'))
        'ProvidedName' = ($PSBoundParameters.ContainsKey('Name'))
        'ProvidedBody' = ($PSBoundParameters.ContainsKey('Body'))
        'ProvidedDraft' = ($PSBoundParameters.ContainsKey('Draft'))
        'ProvidedPreRelease' = ($PSBoundParameters.ContainsKey('PreRelease'))
    }

    $hashBody = @{}
    if ($PSBoundParameters.ContainsKey('Tag')) { $hashBody['tag_name'] = $Tag }
    if ($PSBoundParameters.ContainsKey('Committish')) { $hashBody['target_commitish'] = $Committish }
    if ($PSBoundParameters.ContainsKey('Name')) { $hashBody['name'] = $Name }
    if ($PSBoundParameters.ContainsKey('Body')) { $hashBody['body'] = $Body }
    if ($PSBoundParameters.ContainsKey('Draft')) { $hashBody['draft'] = $Draft.ToBool() }
    if ($PSBoundParameters.ContainsKey('PreRelease')) { $hashBody['prerelease'] = $PreRelease.ToBool() }

    $params = @{
        'UriFragment' = "/repos/$OwnerName/$RepositoryName/releases/$Release"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Patch'
        'Description' = "Creating release at $Tag"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    if (-not $PSCmdlet.ShouldProcess($Release, "Update GitHub Release"))
    {
        return
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubReleaseAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Remove-GitHubRelease
{
<#
    .SYNOPSIS
        Removes a release from a repository on GitHub.

    .DESCRIPTION
        Removes a release from a repository on GitHub.

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

    .PARAMETER Release
        The ID of the release to remove.

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
        Remove-GitHubRelease -OwnerName microsoft -RepositoryName PowerShellForGitHub -Release 1234567890

    .EXAMPLE
        Remove-GitHubRelease -OwnerName microsoft -RepositoryName PowerShellForGitHub -Release 1234567890 -Confirm:$false

        Will not prompt for confirmation, as -Confirm:$false was specified.

    .NOTES
        Requires push access to the repository.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false,
        ConfirmImpact='High')]
    [Alias('Delete-GitHubRelease')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 1)]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [Alias('ReleaseId')]
        [int64] $Release,

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

    $params = @{
        'UriFragment' = "/repos/$OwnerName/$RepositoryName/releases/$Release"
        'Method' = 'Delete'
        'Description' = "Deleting release $Release"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Release, "Remove GitHub Release"))
    {
        return
    }

    return Invoke-GHRestMethod @params
}

filter Get-GitHubReleaseAsset
{
<#
    .SYNOPSIS
        Gets a a list of assets for a release, or downloads a single release asset.

    .DESCRIPTION
        Gets a a list of assets for a release, or downloads a single release asset.

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

    .PARAMETER Release
        The ID of a specific release to see the assets for.

    .PARAMETER Asset
        The ID of the specific asset to download.

    .PARAMETER Path
        The path where the downloaded asset should be stored.

    .PARAMETER Force
        If specified, will overwrite any file located at Path when downloading Asset.

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
        GitHub.ReleaseAsset

    .EXAMPLE
        Get-GitHubReleaseAsset -OwnerName microsoft -RepositoryName PowerShellForGitHub -Release 1234567890

        Gets a list of all the assets associated with this release

    .EXAMPLE
        Get-GitHubReleaseAsset -OwnerName microsoft -RepositoryName PowerShellForGitHub -Asset 1234567890 -Path 'c:\users\PowerShellForGitHub\downloads\asset.zip' -Force

        Downloads the asset 1234567890 to 'c:\users\PowerShellForGitHub\downloads\asset.zip' and
        overwrites the file that may already be there.
#>
    [CmdletBinding(PositionalBinding = $false)]
    [OutputType({$script:GitHubReleaseAssetTypeName})]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    param(
        [Parameter(ParameterSetName='Elements-List')]
        [Parameter(ParameterSetName='Elements-Info')]
        [Parameter(ParameterSetName='Elements-Download')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements-List')]
        [Parameter(ParameterSetName='Elements-Info')]
        [Parameter(ParameterSetName='Elements-Download')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri-Info',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri-Download',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri-List',
            Position = 1)]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Elements-List',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri-List',
            Position = 2)]
        [Alias('ReleaseId')]
        [int64] $Release,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Elements-Info',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Elements-Download',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri-Info',
            Position = 2)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri-Download',
            Position = 2)]
        [Alias('AssetId')]
        [int64] $Asset,

        [Parameter(
            Mandatory,
            ParameterSetName='Elements-Download',
            Position = 2)]
        [Parameter(
            Mandatory,
            ParameterSetName='Uri-Download',
            Position = 3)]
        [string] $Path,

        [Parameter(ParameterSetName='Elements-Download')]
        [Parameter(ParameterSetName='Uri-Download')]
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

    $uriFragment = [String]::Empty
    $description = [String]::Empty
    $shouldSave = $false
    $acceptHeader = $script:defaultAcceptHeader
    if ($PSCmdlet.ParameterSetName -in ('Elements-List', 'Uri-List'))
    {
        $uriFragment = "/repos/$OwnerName/$RepositoryName/releases/$Release/assets"
        $description = "Getting list of assets for release $Release"
    }
    elseif ($PSCmdlet.ParameterSetName -in ('Elements-Info', 'Uri-Info'))
    {
        $uriFragment = "/repos/$OwnerName/$RepositoryName/releases/assets/$Asset"
        $description = "Getting information about release asset $Asset"
    }
    elseif ($PSCmdlet.ParameterSetName -in ('Elements-Download', 'Uri-Download'))
    {
        $uriFragment = "/repos/$OwnerName/$RepositoryName/releases/assets/$Asset"
        $description = "Downloading release asset $Asset"
        $shouldSave = $true
        $acceptHeader = 'application/octet-stream'

        $Path = Resolve-UnverifiedPath -Path $Path
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Method' = 'Get'
        'Description' = $description
        'AcceptHeader' = $acceptHeader
        'Save' = $shouldSave
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = Invoke-GHRestMethod @params

    if ($PSCmdlet.ParameterSetName -in ('Elements-Download', 'Uri-Download'))
    {
        Write-Log -Message "Moving [$($result.FullName)] to [$Path]" -Level Verbose
        return (Move-Item -Path $result -Destination $Path -Force:$Force -ErrorAction Stop -PassThru)
    }
    else
    {
        return ($result | Add-GitHubReleaseAssetAdditionalProperties)
    }
}

filter New-GitHubReleaseAsset
{
<#
    .SYNOPSIS
        Uploads a new asset for a release on GitHub.

    .DESCRIPTION
        Uploads a new asset for a release on GitHub.

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

    .PARAMETER Release
        The ID of the release that the asset is for.

    .PARAMETER UploadUrl
        The value of 'upload_url' from getting the asset details.

    .PARAMETER Path
        The path to the file to upload as a new asset.

    .PARAMETER Label
        An alternate short description of the asset.  Used in place of the filename.

    .PARAMETER ContentType
        The MIME Media Type for the file being uploaded.  By default, this will be inferred based
        on the file's extension.  If the extension is not known by this module, it will fallback to
        using text/plain.  You may specify a ContentType here to override the module's logic.

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
        GitHub.ReleaseAsset

    .EXAMPLE
        New-GitHubReleaseAsset -OwnerName microsoft -RepositoryName PowerShellForGitHub -Release 123456 -Path 'c:\foo.zip'

        Uploads the file located at 'c:\foo.zip' to the 123456 release in microsoft/PowerShellForGitHub

    .EXAMPLE
        $release = New-GitHubRelease -OwnerName microsoft -RepositoryName PowerShellForGitHub -Tag 'stable'
        $release | New-GitHubReleaseAsset -Path 'c:\bar.txt'

        Creates a new release tagged as 'stable' and then uploads 'c:\bar.txt' as an asset for
        that release.

    .NOTES
        GitHub renames asset filenames that have special characters, non-alphanumeric characters,
        and leading or trailing periods. Get-GitHubReleaseAsset lists the renamed filenames.

        If you upload an asset with the same filename as another uploaded asset, you'll receive
        an error and must delete the old file before you can re-upload the new asset.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubReleaseAssetTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 1)]
        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName='UploadUrl')]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Elements',
            Position = 1)]
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 2)]
        [Parameter(
            ValueFromPipelineByPropertyName,
            ParameterSetName='UploadUrl')]
        [Alias('ReleaseId')]
        [int64] $Release,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='UploadUrl',
            Position = 1)]
        [string] $UploadUrl,

        [Parameter(
            Mandatory,
            ValueFromPipeline)]
        [ValidateScript(
            {if (Test-Path -Path $_ -PathType Leaf) { $true }
            else { throw "$_ does not exist or is inaccessible." }})]
        [string] $Path,

        [string] $Label,

        [string] $ContentType,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{
        'ProvidedUploadUrl' = ($PSBoundParameters.ContainsKey('UploadUrl'))
        'ProvidedLabel' = ($PSBoundParameters.ContainsKey('Label'))
        'ProvidedContentType' = ($PSBoundParameters.ContainsKey('ContentType'))
    }

    # If UploadUrl wasn't provided, we'll need to query for it first.
    if ([String]::IsNullOrEmpty($UploadUrl))
    {
        $elements = Resolve-RepositoryElements
        $OwnerName = $elements.ownerName
        $RepositoryName = $elements.repositoryName

        $telemetryProperties['OwnerName'] = (Get-PiiSafeString -PlainText $OwnerName)
        $telemetryProperties['RepositoryName'] = (Get-PiiSafeString -PlainText $RepositoryName)

        $params = @{
            'OwnerName' = $OwnerName
            'RepositoryName' = $RepositoryName
            'Release' = $Release
            'AccessToken' = $AccessToken
        }

        $releaseInfo = Get-GitHubRelease @params
        $UploadUrl = $releaseInfo.upload_url
    }

    # Remove the '{name,label}' from the Url if it's there
    if ($UploadUrl -match '(.*){')
    {
        $UploadUrl = $Matches[1]
    }

    $Path = Resolve-UnverifiedPath -Path $Path
    $file = Get-Item -Path $Path
    $fileName = $file.Name
    $fileNameEncoded = [Uri]::EscapeDataString($fileName)
    $queryParams = @("name=$fileNameEncoded")

    if ($PSBoundParameters.ContainsKey('Label'))
    {
        $labelEncoded = [Uri]::EscapeDataString($Label)
        $queryParams += "label=$labelEncoded"
    }

    if (-not $PSCmdlet.ShouldProcess($Path, "Create new GitHub Release Asset"))
    {
        return
    }

    $params = @{
        'UriFragment' = $UploadUrl + '?' + ($queryParams -join '&')
        'Method' = 'Post'
        'Description' = "Uploading release asset: $fileName"
        'InFile' = $Path
        'ContentType' = $ContentType
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    return (Invoke-GHRestMethod @params | Add-GitHubReleaseAssetAdditionalProperties)
}

filter Set-GitHubReleaseAsset
{
<#
    .SYNOPSIS
        Edits an existing asset for a release on GitHub.

    .DESCRIPTION
        Edits an existing asset for a release on GitHub.

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

    .PARAMETER Asset
        The ID of the asset being updated.

    .PARAMETER Name
        The new filename of the asset.

    .PARAMETER Label
        An alternate short description of the asset.  Used in place of the filename.

    .PARAMETER PassThru
        Returns the updated Release Asset.  By default, this cmdlet does not generate any output.
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
        GitHub.ReleaseAsset

    .EXAMPLE
        Set-GitHubReleaseAsset -OwnerName microsoft -RepositoryName PowerShellForGitHub -Asset 123456 -Name bar.zip

        Renames the asset 123456 to be 'bar.zip'.

    .NOTES
        Requires push access to the repository.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false)]
    [OutputType({$script:GitHubReleaseAssetTypeName})]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 1)]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [Alias('AssetId')]
        [int64] $Asset,

        [string] $Name,

        [string] $Label,

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
        'ProvidedName' = ($PSBoundParameters.ContainsKey('Name'))
        'ProvidedLabel' = ($PSBoundParameters.ContainsKey('Label'))
    }

    $hashBody = @{}
    if ($PSBoundParameters.ContainsKey('Name')) { $hashBody['name'] = $Name }
    if ($PSBoundParameters.ContainsKey('Label')) { $hashBody['label'] = $Label }

    if (-not $PSCmdlet.ShouldProcess($Asset, "Update GitHub Release Asset"))
    {
        return
    }

    $params = @{
        'UriFragment' = "/repos/$OwnerName/$RepositoryName/releases/assets/$Asset"
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'Method' = 'Patch'
        'Description' = "Editing asset $Asset"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    $result = (Invoke-GHRestMethod @params | Add-GitHubReleaseAssetAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Remove-GitHubReleaseAsset
{
<#
    .SYNOPSIS
        Removes an asset from a release on GitHub.

    .DESCRIPTION
        Removes an asset from a release on GitHub.

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

    .PARAMETER Asset
        The ID of the asset to remove.

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
        Remove-GitHubReleaseAsset -OwnerName microsoft -RepositoryName PowerShellForGitHub -Asset 1234567890

    .EXAMPLE
        Remove-GitHubReleaseAsset -OwnerName microsoft -RepositoryName PowerShellForGitHub -Asset 1234567890 -Confirm:$false

        Will not prompt for confirmation, as -Confirm:$false was specified.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        PositionalBinding = $false,
        ConfirmImpact='High')]
    [Alias('Delete-GitHubReleaseAsset')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSReviewUnusedParameter", "", Justification="The Uri parameter is only referenced by Resolve-RepositoryElements which get access to it from the stack via Get-Variable -Scope 1.")]
    param(
        [Parameter(ParameterSetName='Elements')]
        [string] $OwnerName,

        [Parameter(ParameterSetName='Elements')]
        [string] $RepositoryName,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Uri',
            Position = 1)]
        [Alias('RepositoryUrl')]
        [string] $Uri,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            Position = 2)]
        [Alias('AssetId')]
        [int64] $Asset,

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

    $params = @{
        'UriFragment' = "/repos/$OwnerName/$RepositoryName/releases/assets/$Asset"
        'Method' = 'Delete'
        'Description' = "Deleting asset $Asset"
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
    }

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Asset, "Delete GitHub Release Asset"))
    {
        return
    }

    return Invoke-GHRestMethod @params
}

filter Add-GitHubReleaseAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Release objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.Release
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
        [string] $TypeName = $script:GitHubReleaseTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            if (-not [String]::IsNullOrEmpty($item.html_url))
            {
                $elements = Split-GitHubUri -Uri $item.html_url
                $repositoryUrl = Join-GitHubUri @elements
                Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force
            }

            Add-Member -InputObject $item -Name 'ReleaseId' -Value $item.id -MemberType NoteProperty -Force
            Add-Member -InputObject $item -Name 'UploadUrl' -Value $item.upload_url -MemberType NoteProperty -Force

            if ($null -ne $item.author)
            {
                $null = Add-GitHubUserAdditionalProperties -InputObject $item.author
            }
        }

        Write-Output $item
    }
}

filter Add-GitHubReleaseAssetAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Release Asset objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.ReleaseAsset
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
        [string] $TypeName = $script:GitHubReleaseAssetTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            $elements = Split-GitHubUri -Uri $item.url
            $repositoryUrl = Join-GitHubUri @elements
            Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force

            Add-Member -InputObject $item -Name 'AssetId' -Value $item.id -MemberType NoteProperty -Force

            if ($null -ne $item.uploader)
            {
                $null = Add-GitHubUserAdditionalProperties -InputObject $item.uploader
            }
        }

        Write-Output $item
    }
}

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDQm35nX5jiXyCp
# pA/dQ7I2irZNuoqduXf7vV+b/SjTPqCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgs+CgcFxR
# nmTvxoZqq5W52XXImW9ZMvbYRng3DkK1SL4wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCslo84brpDGuyWmuxfmZgaOriiaAx/9IOXpUhw2PaM
# NqLjmQ6KZ4VT/Tuk72fu4ZKUFsGg+96I9khUA9rZpk5vpgbD/AKqqPLphbu5cqow
# xn1TKWVnoyoKG5/7otzomrqF5ga7myPw4OE9pJqZ5vYhHt1KX4/ARFsDGFeZtCEy
# PgGaCYwO1rbf5WinS5pG5kH/m60hI31YcFDvBa6j2/e4TB4tMT0ksAWD18zZkEIO
# VD3+KcCA0r9uj/xVpK/9ky5d2ce6feki7hMtm9kC51pgyoYtc1xhfzw7mQjxziyV
# yHcX2L9O4vGiE5atmZ3gGBinGAgmu2XSqjNvOqF1AhLkoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIOF77tKjXwBh9vX9i2WIv88vXWhhgBt7TfYd8NJm
# Zk0iAgZf25jrm/UYEzIwMjEwMTA1MTk1MDU0LjM4MVowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjozMkJELUUzRDUtM0IxRDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABLqjSGQeT9GvoAAAA
# AAEuMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTE5MTIxOTAxMTUwNVoXDTIxMDMxNzAxMTUwNVowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjozMkJE
# LUUzRDUtM0IxRDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK7TTKJRU196LFIjMQ9q
# /UjpPhz43m5RnHgHAVp2YGni74+ltsYoO1nZ58rTbJhCQ8GYHy8B4devgbqqYPQN
# U3i+drpEtEcNLbsMr4MEq3SM+vO3a6QMFd1lDRy7IQLPJNLKvcM69Nt7ku1YyM5N
# nPNDcRJsnUb/8Yx/zcW5cWjnoj8s9fQ93BPf/J74qM1ql2CdzQV74PBisMP/tppA
# nSuNwo8I7+uWr6vfpBynSWDvJeMDrcsa62Xsm7DbB1NnSsPGAGt3RzlBV9KViciz
# e4U3fo4chdoB2+QLu17PaEmj07qq700CG5XJkpEYOjedNFiByApF7YRvQrOZQ07Q
# YiMCAwEAAaOCARswggEXMB0GA1UdDgQWBBSGmokmTguJN7uqSTQ1UhLwt1RObDAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQCN4ARqpzCuutNqY2nWJDDXj35iaidl
# gtJ/bspYsAX8atJl19IfUKIzTuuSVU3caXZ6/YvMMYMcbsNa/4J28us23K6PWZAl
# jIj0G8QtwDMlQHjrKnrcr4FBAz6ZqvB6SrN3/Wbb0QSK/OlxsU0mfD7z87R2JM4g
# wKJvH6EILuAEtjwUGSB1NKm3Twrm51fCD0jxvWxzaUS2etvMPrh8DNrrHLJBR3UH
# vg/NXS2IzdQn20xjjsW0BUAiTf+NCRpxUvu/j80Nb1++vnejibfpQJ2IlXiJdIi+
# Hb+OL3XOr8MaDDSYOaRFAIfcoq3VPi4BkvSC8QGrvhjAZafkE7R6L5FJMIIGcTCC
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
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoz
# MkJELUUzRDUtM0IxRDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUA+1/CN6BILeU1yDGo+b6WkpLoQpuggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOOfI3AwIhgPMjAyMTAxMDUyMTQyMDhaGA8yMDIxMDEwNjIxNDIwOFowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA458jcAIBADAKAgEAAgIgiwIB/zAHAgEAAgIShjAK
# AgUA46B08AIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBADO/v1LhYSIRa+pw
# moY4T/Wn9rGRbxSt6xluXO+NOlHsK6alpNz+tlOTXXZ4zAkQW0rgPp10q82qE+hV
# KLWiEOHxIbR9AGfCCFAWzLuso28D2tFupc3CtpWvlXhcFFJKE98fPBQCo/WrwbTA
# An+B9iLg1m5osrpdQzPUv1oVNPm2MYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAEuqNIZB5P0a+gAAAAAAS4wDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgXP9rfNhmT6szYfKHG9PQbTw7GiQG+p/58Vx4Lqszdz8wgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCDa/s3O8YhWiqpVN0kTeK+x2m0RAh17JpR6DiFo
# TILJKTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# LqjSGQeT9GvoAAAAAAEuMCIEILD8Woq3rjCz7I8y8FkuHNEsftt3u/A/W70cl/6w
# 8ienMA0GCSqGSIb3DQEBCwUABIIBABGZF/6STNYw6zLy3yx4Q/Nm1H3xLnRC+tFy
# KaRcs6YK5tsp2NiaVjlM3PCr+AX55BKgBJTtZxR1jx2fyZKDtqPFa0y2UG+oVrgK
# izn1bw/nQLr6n4yf7g46jIlwAPShoo4poWYliolLJUPNVQKS4exugSp7vYrTj9cY
# JgaXv3hW4yRg6RaLcv3RI4G4cxuyPX4EO0yCncK6ToXRMza2b0oMOlEqNeKmRbtJ
# zI2lT9CKiaIuEWbwacTOqJNegOc3ebXuoVWQGyRB3cRYgFv6Pm19mmTk/L0aI3pV
# UCREP2gi23FObXUuyLCognIMLRzbooLmTUN5iXLcmyYMtIx4SZ0=
# SIG # End signature block
