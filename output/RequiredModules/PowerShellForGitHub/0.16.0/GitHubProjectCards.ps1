# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

@{
    GitHubProjectCardTypeName = 'GitHub.ProjectCard'
 }.GetEnumerator() | ForEach-Object {
     Set-Variable -Scope Script -Option ReadOnly -Name $_.Key -Value $_.Value
 }

filter Get-GitHubProjectCard
{
<#
    .SYNOPSIS
        Get the cards for a given GitHub Project Column.

    .DESCRIPTION
        Get the cards for a given GitHub Project Column.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Column
        ID of the column to retrieve cards for.

    .PARAMETER State
        Only cards with this State are returned.
        Options are all, archived, or NotArchived (default).

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.ProjectCard
        GitHub.ProjectColumn

    .OUTPUTS
        GitHub.ProjectCard

    .EXAMPLE
        Get-GitHubProjectCard -Column 999999

        Get the the not_archived cards for column 999999.

    .EXAMPLE
        Get-GitHubProjectCard -Column 999999 -State All

        Gets all the cards for column 999999, no matter the State.

    .EXAMPLE
        Get-GitHubProjectCard -Column 999999 -State Archived

        Gets the archived cards for column 999999.

    .EXAMPLE
        Get-GitHubProjectCard -Card 999999

        Gets the card with ID 999999.
#>
    [CmdletBinding(DefaultParameterSetName = 'Card')]
    [OutputType({$script:GitHubProjectCardTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Column')]
        [Alias('ColumnId')]
        [int64] $Column,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Card')]
        [Alias('CardId')]
        [int64] $Card,

        [ValidateSet('All', 'Archived', 'NotArchived')]
        [Alias('ArchivedState')]
        [string] $State = 'NotArchived',

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = [String]::Empty
    $description = [String]::Empty

    if ($PSCmdlet.ParameterSetName -eq 'Column')
    {
        $telemetryProperties['Column'] = $true

        $uriFragment = "/projects/columns/$Column/cards"
        $description = "Getting cards for column $Column"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Card')
    {
        $telemetryProperties['Card'] = $true

        $uriFragment = "/projects/columns/cards/$Card"
        $description = "Getting project card $Card"
    }

    if ($PSBoundParameters.ContainsKey('State'))
    {
        $getParams = @()
        $Archived = $State.ToLower().Replace('notarchived','not_archived')
        $getParams += "archived_state=$Archived"

        $uriFragment = "$uriFragment`?" + ($getParams -join '&')
        $description += " with State '$Archived'"
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $description
        'AccessToken' = $AccessToken
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'AcceptHeader' = $script:inertiaAcceptHeader
    }

    return (Invoke-GHRestMethodMultipleResult @params | Add-GitHubProjectCardAdditionalProperties)
}

filter New-GitHubProjectCard
{
<#
    .SYNOPSIS
        Creates a new card for a GitHub project.

    .DESCRIPTION
        Creates a new card for a GitHub project.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Column
        ID of the column to create a card for.

    .PARAMETER Note
        The name of the column to create.

    .PARAMETER IssueId
        The ID of the issue you want to associate with this card (not to be confused with
        the Issue _number_ which you see in the URL and can refer to with a hashtag).

    .PARAMETER PullRequestId
        The ID of the pull request you want to associate with this card (not to be confused with
        the Pull Request _number_ which you see in the URL and can refer to with a hashtag).

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.IssueComment
        GitHub.Issue
        GitHub.PullRequest
        GitHub.ProjectCard
        GitHub.ProjectColumn

    .OUTPUTS
        GitHub.ProjectCard

    .EXAMPLE
        New-GitHubProjectCard -Column 999999 -Note 'Note on card'

        Creates a card on column 999999 with the note 'Note on card'.

    .EXAMPLE
        New-GitHubProjectCard -Column 999999 -IssueId 888888

        Creates a card on column 999999 for the issue with ID 888888.

    .EXAMPLE
        New-GitHubProjectCard -Column 999999 -PullRequestId 888888

        Creates a card on column 999999 for the pull request with ID 888888.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'Note')]
    [OutputType({$script:GitHubProjectCardTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('ColumnId')]
        [int64] $Column,

        [Parameter(
            Mandatory,
            ParameterSetName = 'Note')]
        [Alias('Content')]
        [string] $Note,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'Issue')]
        [int64] $IssueId,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName = 'PullRequest')]
        [int64] $PullRequestId,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = "/projects/columns/$Column/cards"
    $apiDescription = "Creating project card"

    if ($PSCmdlet.ParameterSetName -eq 'Note')
    {
        $telemetryProperties['Note'] = $true

        $hashBody = @{
            'note' = $Note
        }
    }
    elseif ($PSCmdlet.ParameterSetName -in ('Issue', 'PullRequest'))
    {
        $contentType = $PSCmdlet.ParameterSetName
        $telemetryProperties['ContentType'] = $contentType

        $hashBody = @{
            'content_type' = $contentType
        }

        if ($PSCmdlet.ParameterSetName -eq 'Issue')
        {
            $hashBody['content_id'] = $IssueId
        }
        else
        {
            $hashBody['content_id'] = $PullRequestId
        }
    }

    if (-not $PSCmdlet.ShouldProcess($Column, 'Create GitHub Project Card'))
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

    return (Invoke-GHRestMethod @params | Add-GitHubProjectCardAdditionalProperties)
}

filter Set-GitHubProjectCard
{
<#
    .SYNOPSIS
        Modify a GitHub Project Card.

    .DESCRIPTION
        Modify a GitHub Project Card.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Card
        ID of the card to modify.

    .PARAMETER Note
        The note content for the card.  Only valid for cards without another type of content,
        so this cannot be specified if the card already has a content_id and content_type.

    .PARAMETER Archive
        Archive a project card.

    .PARAMETER Restore
        Restore a project card.

    .PARAMETER PassThru
        Returns the updated Project Card.  By default, this cmdlet does not generate any output.
        You can use "Set-GitHubConfiguration -DefaultPassThru" to control the default behavior
        of this switch.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.ProjectCard

    .OUTPUTS
        GitHub.ProjectCard

    .EXAMPLE
        Set-GitHubProjectCard -Card 999999 -Note UpdatedNote

        Sets the card note to 'UpdatedNote' for the card with ID 999999.

    .EXAMPLE
        Set-GitHubProjectCard -Card 999999 -Archive

        Archives the card with ID 999999.

    .EXAMPLE
        Set-GitHubProjectCard -Card 999999 -Restore

        Restores the card with ID 999999.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        DefaultParameterSetName = 'Note')]
    [OutputType({$script:GitHubProjectCardTypeName})]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('CardId')]
        [int64] $Card,

        [Alias('Content')]
        [string] $Note,

        [Parameter(ParameterSetName = 'Archive')]
        [switch] $Archive,

        [Parameter(ParameterSetName = 'Restore')]
        [switch] $Restore,

        [switch] $PassThru,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = "/projects/columns/cards/$Card"
    $apiDescription = "Updating card $Card"

    $hashBody = @{}

    if ($PSBoundParameters.ContainsKey('Note'))
    {
        $telemetryProperties['Note'] = $true
        $hashBody.add('note', $Note)
    }

    if ($Archive)
    {
        $telemetryProperties['Archive'] = $true
        $hashBody.add('archived', $true)
    }

    if ($Restore)
    {
        $telemetryProperties['Restore'] = $true
        $hashBody.add('archived', $false)
    }

    if (-not $PSCmdlet.ShouldProcess($Card, 'Set GitHub Project Card'))
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

    $result = (Invoke-GHRestMethod @params | Add-GitHubProjectCardAdditionalProperties)
    if (Resolve-ParameterWithDefaultConfigurationValue -Name PassThru -ConfigValueName DefaultPassThru)
    {
        return $result
    }
}

filter Remove-GitHubProjectCard
{
<#
    .SYNOPSIS
        Removes a project card.

    .DESCRIPTION
        Removes a project card.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Card
        ID of the card to remove.

    .PARAMETER Force
        If this switch is specified, you will not be prompted for confirmation of command execution.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.ProjectCard

    .EXAMPLE
        Remove-GitHubProjectCard -Card 999999

        Remove project card with ID 999999.

    .EXAMPLE
        Remove-GitHubProjectCard -Card 999999 -Confirm:$False

        Remove project card with ID 999999 without prompting for confirmation.

    .EXAMPLE
        Remove-GitHubProjectCard -Card 999999 -Force

        Remove project card with ID 999999 without prompting for confirmation.
#>
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact = 'High')]
    [Alias('Delete-GitHubProjectCard')]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('CardId')]
        [int64] $Card,

        [switch] $Force,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = "/projects/columns/cards/$Card"
    $description = "Deleting card $Card"

    if ($Force -and (-not $Confirm))
    {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess($Card, 'Remove GitHub Project Card'))
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

filter Move-GitHubProjectCard
{
<#
    .SYNOPSIS
        Move a GitHub Project Card.

    .DESCRIPTION
        Move a GitHub Project Card.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Card
        ID of the card to move.

    .PARAMETER Top
        Moves the card to the top of the column.

    .PARAMETER Bottom
        Moves the card to the bottom of the column.

    .PARAMETER After
        Moves the card to the position after the card ID specified.

    .PARAMETER Column
        The ID of a column in the same project to move the card to.

    .PARAMETER AccessToken
        If provided, this will be used as the AccessToken for authentication with the
        REST Api.  Otherwise, will attempt to use the configured value or will run unauthenticated.

    .INPUTS
        GitHub.ProjectCard
        GitHub.ProjectColumn

    .EXAMPLE
        Move-GitHubProjectCard -Card 999999 -Top

        Moves the project card with ID 999999 to the top of the column.

    .EXAMPLE
        Move-GitHubProjectCard -Card 999999 -Bottom

        Moves the project card with ID 999999 to the bottom of the column.

    .EXAMPLE
        Move-GitHubProjectCard -Card 999999 -After 888888

        Moves the project card with ID 999999 to the position after the card ID 888888.
        Within the same column.

    .EXAMPLE
        Move-GitHubProjectCard -Card 999999 -After 888888 -Column 123456

        Moves the project card with ID 999999 to the position after the card ID 888888, in
        the column with ID 123456.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName)]
        [Alias('CardId')]
        [int64] $Card,

        [switch] $Top,

        [switch] $Bottom,

        [int64] $After,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('ColumnId')]
        [int64] $Column,

        [string] $AccessToken
    )

    Write-InvocationLog

    $telemetryProperties = @{}

    $uriFragment = "/projects/columns/cards/$Card/moves"
    $apiDescription = "Updating card $Card"

    if (-not ($Top -xor $Bottom -xor ($After -gt 0)))
    {
        $message = 'You must use one (and only one) of the parameters Top, Bottom or After.'
        Write-Log -Message $message -level Error
        throw $message
    }
    elseif ($Top)
    {
        $position = 'top'
    }
    elseif ($Bottom)
    {
        $position = 'bottom'
    }
    else
    {
        $position = "after:$After"
    }

    $hashBody = @{
        'position' = $Position
    }

    if ($PSBoundParameters.ContainsKey('Column'))
    {
        $telemetryProperties['Column'] = $true
        $hashBody.add('column_id', $Column)
    }

    if (-not $PSCmdlet.ShouldProcess($Card, 'Move GitHub Project Card'))
    {
        return
    }

    $params = @{
        'UriFragment' = $uriFragment
        'Description' = $apiDescription
        'Body' = (ConvertTo-Json -InputObject $hashBody)
        'AccessToken' = $AccessToken
        'Method' = 'Post'
        'TelemetryEventName' = $MyInvocation.MyCommand.Name
        'TelemetryProperties' = $telemetryProperties
        'AcceptHeader' = $script:inertiaAcceptHeader
    }

    return Invoke-GHRestMethod @params
}


filter Add-GitHubProjectCardAdditionalProperties
{
<#
    .SYNOPSIS
        Adds type name and additional properties to ease pipelining to GitHub Project Card objects.

    .PARAMETER InputObject
        The GitHub object to add additional properties to.

    .PARAMETER TypeName
        The type that should be assigned to the object.

    .INPUTS
        [PSCustomObject]

    .OUTPUTS
        GitHub.ProjectCard
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
        [string] $TypeName = $script:GitHubProjectCardTypeName
    )

    foreach ($item in $InputObject)
    {
        $item.PSObject.TypeNames.Insert(0, $TypeName)

        if (-not (Get-GitHubConfiguration -Name DisablePipelineSupport))
        {
            Add-Member -InputObject $item -Name 'CardId' -Value $item.id -MemberType NoteProperty -Force

            if ($item.project_url -match '^.*/projects/(\d+)$')
            {
                $projectId = $Matches[1]
                Add-Member -InputObject $item -Name 'ProjectId' -Value $projectId -MemberType NoteProperty -Force
            }

            if ($item.column_url -match '^.*/columns/(\d+)$')
            {
                $columnId = $Matches[1]
                Add-Member -InputObject $item -Name 'ColumnId' -Value $columnId -MemberType NoteProperty -Force
            }

            if ($null -ne $item.content_url)
            {
                $elements = Split-GitHubUri -Uri $item.content_url
                $repositoryUrl = Join-GitHubUri @elements
                Add-Member -InputObject $item -Name 'RepositoryUrl' -Value $repositoryUrl -MemberType NoteProperty -Force

                if ($item.content_url -match '^.*/issues/(\d+)$')
                {
                    $issueNumber = $Matches[1]
                    Add-Member -InputObject $item -Name 'IssueNumber' -Value $issueNumber -MemberType NoteProperty -Force
                }
                elseif ($item.content_url -match '^.*/pull/(\d+)$')
                {
                    $pullRequestNumber = $Matches[1]
                    Add-Member -InputObject $item -Name 'PullRequestNumber' -Value $pullRequestNumber -MemberType NoteProperty -Force
                }
            }

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
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCK+cg24/Q2MaD7
# eJeXWJhFQCmQpOphE2kG20e/dz0ftKCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgAxrlyJm1
# vlRGk+k7wD0Mb0d7zYuciJzYY7Ne+LKHDM0wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQC2HDOLpLCN8eqRrAvVhGFl2v32mUxaRv3+7eT4HTjR
# Bcnl2zMVwxgfJ+2ZfOF6boAKSyvsinNFI6PAQh9CJB87I/N8XKOZPqkOAqyfeMqx
# 8+e3C4lEyrCLsJvBvxt3W7zrziFtkYf4rp+5LLvblNMHwQYJB4K289RWgxFUT+Cz
# OZN7MgI48wLER0S9aaE4LDG/V4qWum2ZETMLMOzLAqhBkKpECKc7ieSmPjrgd5dC
# ekFqnl2oUdvfqC2EVpZsKaeNaSFfTWeVFUivN/1flXu9D0V/UFcx+g/FhHWpagkz
# znoZrTCteeaGU9O0ivuWO1dDKcFRPLZJNKzUkRHROrTDoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIOOLR13ZQ4WYZmcCkIXeobtFtPRdtuAMUSnp+Pw2
# Ia0jAgZf25oj+xEYEzIwMjEwMTA1MTk1MDU1LjE0MVowBIACAfSggdSkgdEwgc4x
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
# CQQxIgQgQX3M/srgnS8zCKIKcfdtEkRsqzE5PHsdCzPeyizp5ywwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCBDmDWEWvc6fhs5t4Woo5Q+FMFCcaIgV4yUP4Cp
# uBmLmTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# KugXlviGp++jAAAAAAEqMCIEIH2jzt1Yv9t70Lv0ufD8m03qKX6QoK++mcXnW8K+
# YCydMA0GCSqGSIb3DQEBCwUABIIBAHBlnP27ribwPMACXYejyuZsVYFlyIYXwv3L
# nzDiL6IhNftRV7rOqzjm0DuaHFVjEZ4rTQKDPqqcBIHVr+8ZFEDlNgVaMQj7oG7D
# khxu+y7CjEw97pz9f+F5NIyQO2Exw8OirQRI7/VZUftcNXA6Uk1emclrBhlDhQ4H
# UMchzUTM83TsCOtTkeskmOTvnGVkcG7St9S/X6L5iuZrFHdnrqc1iYocoQl1B3jM
# jxpKqbYv2uXaymMGMBW3vm578gWtudoA8aoL+Ry+OHCyVg4H0+cwgGIVK8YlAgLE
# mdPqdvgtr5i7v2Buj5JRQ0edkslJnTt+7z4DI2VGiF+h+rAAsu8=
# SIG # End signature block
