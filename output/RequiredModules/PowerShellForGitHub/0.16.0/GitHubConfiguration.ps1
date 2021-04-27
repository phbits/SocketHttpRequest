# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# The GitHub API token is stored in the password field.
[PSCredential] $script:accessTokenCredential = $null

# The location of the file that we'll store any settings that can/should roam with the user.
[string] $script:configurationFilePath = [System.IO.Path]::Combine(
    [System.Environment]::GetFolderPath('ApplicationData'),
    'Microsoft',
    'PowerShellForGitHub',
    'config.json')

# The location of the file that we'll store the Access Token SecureString
# which cannot/should not roam with the user.
[string] $script:accessTokenFilePath = [System.IO.Path]::Combine(
    [System.Environment]::GetFolderPath('LocalApplicationData'),
    'Microsoft',
    'PowerShellForGitHub',
    'accessToken.txt')

# Only tell users about needing to configure an API token once per session.
$script:seenTokenWarningThisSession = $false

# The session-cached copy of the module's configuration properties
[PSCustomObject] $script:configuration = $null

function Initialize-GitHubConfiguration
{
<#
    .SYNOPSIS
        Populates the configuration of the module for this session, loading in any values
        that may have been saved to disk.

    .DESCRIPTION
        Populates the configuration of the module for this session, loading in any values
        that may have been saved to disk.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .NOTES
        Internal helper method.  This is actually invoked at the END of this file.
#>
    [CmdletBinding()]
    param()

    $script:seenTokenWarningThisSession = $false
    $script:configuration = Import-GitHubConfiguration -Path $script:configurationFilePath
}

function Set-GitHubConfiguration
{
<#
    .SYNOPSIS
        Change the value of a configuration property for the PowerShellForGitHub module,
        for the session only, or globally for this user.

    .DESCRIPTION
        Change the value of a configuration property for the PowerShellForGitHub module,
        for the session only, or globally for this user.

        A single call to this method can set any number or combination of properties.

        To change any of the boolean/switch properties to false, specify the switch,
        immediately followed by ":$false" with no space.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER ApiHostName
        The hostname of the GitHub instance to communicate with. Defaults to 'github.com'. Provide a
        different hostname when using a GitHub Enterprise server. Do not include the HTTP/S prefix,
        and do not include 'api'. For example, use "github.contoso.com".

    .PARAMETER ApplicationInsightsKey
        Change the Application Insights instance that telemetry will be reported to (if telemetry
        hasn't been disabled via DisableTelemetry).

    .PARAMETER DefaultOwnerName
        The owner name that should be used with a command that takes OwnerName as a parameter
        when no value has been supplied.

    .PARAMETER DefaultPassThru
        Sets what the default PassThru behavior should be for commands that have a PassThru
        switch.  By default, those commands will not return the result of the command unless
        the user passes in -PassThru.  By setting this value to $true, those commands will
        always behave as if -PassThru had been specified, unless you explicitly specify
        -PassThru:$false on an individual command.

    .PARAMETER DefaultRepositoryName
        The owner name that should be used with a command that takes RepositoryName as a parameter
        when no value has been supplied.

    .PARAMETER DisableLogging
        Specify this switch to stop the module from logging all activity to a log file located
        at the location specified by LogPath.

    .PARAMETER DisablePiiProtection
        Specify this switch to disable the hashing of potential PII data prior to submitting the
        data to telemetry (if telemetry hasn't been disabled via DisableTelemetry).

    .PARAMETER DisablePipelineSupport
        By default, this module will modify all objects returned by the API calls by adding
        additional, consistent properties to those objects which ease pipelining those objects
        into other functions.  This is highly convenient functionality.  You would only want to
        disable this functionality if you are experiencing some edge case problems and are awaiting
        a proper fix.

    .PARAMETER DisableSmarterObjects
        By default, this module will modify all objects returned by the API calls to update
        any properties that can be converted to objects (like strings for Date/Time's being
        converted to real DateTime objects).  Enable this property if you desire getting back
        the unmodified version of the object from the API.

    .PARAMETER DisableTelemetry
        Specify this switch to stop the module from reporting any of its usage (which would be used
        for diagnostics purposes).

    .PARAMETER DisableUpdateCheck
        Specify this switch to stop the daily update check with PowerShellGallery which can
        inform you when there is a newer version of this module available.

    .PARAMETER LogPath
        The location of the log file that all activity will be written to if DisableLogging remains
        $false.

    .PARAMETER LogProcessId
        If specified, the Process ID of the current PowerShell session will be included in each
        log entry.  This can be useful if you have concurrent PowerShell sessions all logging
        to the same file, as it would then be possible to filter results based on ProcessId.

    .PARAMETER LogRequestBody
        If specified, the JSON body of the REST request will be logged to verbose output.
        This can be helpful for debugging purposes.

    .PARAMETER LogTimeAsUtc
        If specified, all times logged will be logged as UTC instead of the local timezone.

    .PARAMETER MaximumRetriesWhenResultNotReady
        Some API requests may take time for GitHub to gather the results, and in the interim,
        a 202 response is returned.  This value indicates the maximum number of times that the
        query will be retried before giving up and failing.  The amount of time between each of
        these requests is controlled by the RetryDelaySeconds configuration value.

    .PARAMETER MultiRequestProgressThreshold
        Some commands may require sending multiple requests to GitHub.  In some situations,
        getting the entirety of the request might take 70+ requests occurring over 20+ seconds.
        A progress bar will be shown (displaying which sub-request is being executed) if the number
        of requests required to complete this command is greater than or equal to this configuration
        value.
        Set to 0 to disable this feature.

    .PARAMETER RetryDelaySeconds
        The number of seconds to wait before retrying a command again after receiving a 202 response.
        The number of times that a retry will occur is controlled by the
        MaximumRetriesWhenResultNotReady configuration value.

    .PARAMETER StateChangeDelaySeconds
        The number of seconds to wait before returning the result after executing a command that
        may result in a state change on the server.  This is intended to only be used during test
        execution in order to increase reliability.

    .PARAMETER SuppressNoTokenWarning
        If an Access Token has not been configured, this module will provide a warning to the user
        informing them of this, once per session.  If it is expected that this module will regularly
        be used without configuring an Access Token, specify this switch to always suppress that
        warning message.

    .PARAMETER SuppressTelemetryReminder
        When telemetry is enabled, a warning will be printed to the console once per session
        informing users that telemetry is occurring.  Setting this value will suppress that
        message from showing up ever again.

    .PARAMETER WebRequestTimeoutSec
        The number of seconds that should be allowed before an API request times out.  A value of
        0 indicates an infinite timeout, however experience has shown that PowerShell doesn't seem
        to always honor inifinite timeouts.  Hence, this value can be configured if need be.

    .PARAMETER SessionOnly
        By default, this method will store the configuration values in a local file so that changes
        persist across PowerShell sessions.  If this switch is provided, the file will not be
        created/updated and the specified configuration changes will only remain in memory/effect
        for the duration of this PowerShell session.

    .EXAMPLE
        Set-GitHubConfiguration -WebRequestTimeoutSec 120 -SuppressNoTokenWarning

        Changes the timeout permitted for a web request to two minutes, and additionally tells
        the module to never warn about no Access Token being configured.  These settings will be
        persisted across future PowerShell sessions.

    .EXAMPLE
        Set-GitHubConfiguration -DisableLogging -SessionOnly

        Disables the logging of any activity to the logfile specified in LogPath, but for this
        session only.

    .EXAMPLE
        Set-GitHubConfiguration -ApiHostName "github.contoso.com"

        Sets all requests to connect to a GitHub Enterprise server running at
        github.contoso.com.
#>
    [CmdletBinding(
        PositionalBinding = $false,
        SupportsShouldProcess)]
    param(
        [ValidatePattern('^(?!https?:)(?!api\.)(?!www\.).*')]
        [string] $ApiHostName,

        [string] $ApplicationInsightsKey,

        [string] $DefaultOwnerName,

        [string] $DefaultPassThru,

        [string] $DefaultRepositoryName,

        [switch] $DisableLogging,

        [switch] $DisablePiiProtection,

        [switch] $DisablePipelineSupport,

        [switch] $DisableSmarterObjects,

        [switch] $DisableTelemetry,

        [switch] $DisableUpdateCheck,

        [string] $LogPath,

        [switch] $LogProcessId,

        [switch] $LogRequestBody,

        [switch] $LogTimeAsUtc,

        [int] $MaximumRetriesWhenResultNotReady,

        [int] $MultiRequestProgressThreshold,

        [int] $RetryDelaySeconds,

        [int] $StateChangeDelaySeconds,

        [switch] $SuppressNoTokenWarning,

        [switch] $SuppressTelemetryReminder,

        [ValidateRange(0, 3600)]
        [int] $WebRequestTimeoutSec,

        [switch] $SessionOnly
    )

    $persistedConfig = $null
    if (-not $SessionOnly)
    {
        $persistedConfig = Read-GitHubConfiguration -Path $script:configurationFilePath
    }

    if (-not $PSCmdlet.ShouldProcess('GitHubConfiguration', 'Set'))
    {
        return
    }

    $properties = Get-Member -InputObject $script:configuration -MemberType NoteProperty | Select-Object -ExpandProperty Name
    foreach ($name in $properties)
    {
        if ($PSBoundParameters.ContainsKey($name))
        {
            $value = $PSBoundParameters.$name
            if ($value -is [switch]) { $value = $value.ToBool() }
            $script:configuration.$name = $value

            if (-not $SessionOnly)
            {
                Add-Member -InputObject $persistedConfig -Name $name -Value $value -MemberType NoteProperty -Force
            }
        }
    }

    if (-not $SessionOnly)
    {
        Save-GitHubConfiguration -Configuration $persistedConfig -Path $script:configurationFilePath
    }
}

function Get-GitHubConfiguration
{
<#
    .SYNOPSIS
        Gets the currently configured value for the requested configuration setting.

    .DESCRIPTION
        Gets the currently configured value for the requested configuration setting.

        Always returns the value for this session, which may or may not be the persisted
        setting (that all depends on whether or not the setting was previously modified
        during this session using Set-GitHubConfiguration -SessionOnly).

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Name
        The name of the configuration whose value is desired.

    .EXAMPLE
        Get-GitHubConfiguration -Name WebRequestTimeoutSec

        Gets the currently configured value for WebRequestTimeoutSec for this PowerShell session
        (which may or may not be the same as the persisted configuration value, depending on
        whether this value was modified during this session with Set-GitHubConfiguration -SessionOnly).
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'ApiHostName',
            'ApplicationInsightsKey',
            'DefaultOwnerName',
            'DefaultPassThru',
            'DefaultRepositoryName',
            'DisableLogging',
            'DisablePiiProtection',
            'DisablePipelineSupport',
            'DisableSmarterObjects',
            'DisableTelemetry',
            'DisableUpdateCheck',
            'LogPath',
            'LogProcessId',
            'LogRequestBody',
            'LogTimeAsUtc',
            'MaximumRetriesWhenResultNotReady',
            'MultiRequestProgressThreshold',
            'RetryDelaySeconds',
            'StateChangeDelaySeconds',
            'SuppressNoTokenWarning',
            'SuppressTelemetryReminder',
            'TestConfigSettingsHash',
            'WebRequestTimeoutSec')]
        [string] $Name
    )

    return $script:configuration.$Name
}

function Save-GitHubConfiguration
{
<#
    .SYNOPSIS
        Serializes the provided settings object to disk as a JSON file.

    .DESCRIPTION
        Serializes the provided settings object to disk as a JSON file.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Configuration
        The configuration object to persist to disk.

    .PARAMETER Path
        The path to the file on disk that Configuration should be persisted to.

    .NOTES
        Internal helper method.

    .EXAMPLE
        Save-GitHubConfiguration -Configuration $config -Path 'c:\foo\config.json'

        Serializes $config as a JSON object to 'c:\foo\config.json'
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $Configuration,

        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not $PSCmdlet.ShouldProcess('GitHub Configuration', 'Save'))
    {
        return
    }

    $null = New-Item -Path $Path -Force
    ConvertTo-Json -InputObject $Configuration |
        Set-Content -Path $Path -Force -ErrorAction SilentlyContinue -ErrorVariable ev

    if (($null -ne $ev) -and ($ev.Count -gt 0))
    {
        $message = "Failed to persist these updated settings to disk.  They will remain for this PowerShell session only."
        Write-Log -Message $message -Level Warning -Exception $ev[0]
    }
}

function Test-PropertyExists
{
<#
    .SYNOPSIS
        Determines if an object contains a property with a specified name.

    .DESCRIPTION
        Determines if an object contains a property with a specified name.

        This is essentially using Get-Member to verify that a property exists,
        but additionally adds a check to ensure that InputObject isn't null.

    .PARAMETER InputObject
        The object to check to see if it has a property named Name.

    .PARAMETER Name
        The name of the property on InputObject that is being tested for.

    .EXAMPLE
        Test-PropertyExists -InputObject $listing -Name 'title'

        Returns $true if $listing is non-null and has a property named 'title'.
        Returns $false otherwise.

    .NOTES
        Internal-only helper method.
#>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification="Exists isn't a noun and isn't violating the intention of this rule.")]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory)]
        [String] $Name
    )

    return (($null -ne $InputObject) -and
            ($null -ne (Get-Member -InputObject $InputObject -Name $Name -MemberType Properties)))
}

function Resolve-PropertyValue
{
<#
    .SYNOPSIS
        Returns the requested property from the provided object, if it exists and is a valid
        value.  Otherwise, returns the default value.

    .DESCRIPTION
        Returns the requested property from the provided object, if it exists and is a valid
        value.  Otherwise, returns the default value.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER InputObject
        The object to check the value of the requested property.

    .PARAMETER Name
        The name of the property on InputObject whose value is desired.

    .PARAMETER Type
        The type of the value stored in the Name property on InputObject.  Used to validate
        that the property has a valid value.

    .PARAMETER DefaultValue
        The value to return if Name doesn't exist on InputObject or is of an invalid type.

    .EXAMPLE
        Resolve-PropertyValue -InputObject $config -Name defaultOwnerName -Type String -DefaultValue $null

        Checks $config to see if it has a property named "defaultOwnerName".  If it does, and it's a
        string, returns that value, otherwise, returns $null (the DefaultValue).
#>
    [CmdletBinding()]
    param(
        [PSCustomObject] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateSet('String', 'Boolean', 'Int32', 'Int64')]
        [String] $Type,

        $DefaultValue
    )

    if ($null -eq $InputObject)
    {
        return $DefaultValue
    }

    $typeType = [String]
    if ($Type -eq 'Boolean') { $typeType = [Boolean] }
    if ($Type -eq 'Int32') { $typeType = [Int32] }
    if ($Type -eq 'Int64') { $typeType = [Int64] }
    $numberEquivalents = @('Int32', 'Int64', 'long', 'int')

    if (Test-PropertyExists -InputObject $InputObject -Name $Name)
    {
        if (($InputObject.$Name -is $typeType) -or
            (($Type -in $numberEquivalents) -and ($InputObject.$Name.GetType().Name -in $numberEquivalents)))
        {
            return $InputObject.$Name
        }
        else
        {
            $message = "The locally cached $Name configuration was not of type $Type (it was $($InputObject.$Name.GetType())).  Reverting to default value."
            Write-Log -Message $message -Level Warning
            return $DefaultValue
        }
    }
    else
    {
        return $DefaultValue
    }
}

function Reset-GitHubConfiguration
{
<#
    .SYNOPSIS
        Clears out the user's configuration file and configures this session with all default
        configuration values.

    .DESCRIPTION
        Clears out the user's configuration file and configures this session with all default
        configuration values.

        This would be the functional equivalent of using this on a completely different computer.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER SessionOnly
        By default, this will delete the location configuration file so that all defaults are used
        again.  If this is specified, then only the configuration values that were made during
        this session will be discarded.

    .EXAMPLE
        Reset-GitHubConfiguration

        Deletes the local configuration file and loads in all default configuration values.

    .NOTES
        This command will not clear your authentication token.
        Please use Clear-GitHubAuthentication to accomplish that.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch] $SessionOnly
    )

    if (-not $PSCmdlet.ShouldProcess('GitHub Configuration', 'Reset'))
    {
        return
    }

    Set-TelemetryEvent -EventName Reset-GitHubConfiguration

    if (-not $SessionOnly)
    {
        $null = Remove-Item -Path $script:configurationFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev

        if (($null -ne $ev) -and ($ev.Count -gt 0) -and ($ev[0].FullyQualifiedErrorId -notlike 'PathNotFound*'))
        {
            $message = "Reset was unsuccessful.  Experienced a problem trying to remove the file [$script:configurationFilePath]."
            Write-Log -Message $message -Level Warning -Exception $ev[0]
        }
    }

    Initialize-GitHubConfiguration

    $message = "This has not cleared your authentication token.  Call Clear-GitHubAuthentication to accomplish that."
    Write-Log -Message $message -Level Verbose
}

function Read-GitHubConfiguration
{
<#
    .SYNOPSIS
        Loads in the default configuration values and returns the deserialized object.

    .DESCRIPTION
        Loads in the default configuration values and returns the deserialized object.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Path
        The file that may or may not exist with a serialized version of the configuration
        values for this module.

    .OUTPUTS
        PSCustomObject

    .NOTES
        Internal helper method.
        No side-effects.

    .EXAMPLE
        Read-GitHubConfiguration -Path 'c:\foo\config.json'

        Returns back an object with the deserialized object contained in the specified file,
        if it exists and is valid.
#>
    [CmdletBinding()]
    param(
        [string] $Path
    )

    $content = Get-Content -Path $Path -Encoding UTF8 -ErrorAction Ignore
    if (-not [String]::IsNullOrEmpty($content))
    {
        try
        {
            return ($content | ConvertFrom-Json)
        }
        catch
        {
            $message = 'The configuration file for this module is in an invalid state.  Use Reset-GitHubConfiguration to recover.'
            Write-Log -Message $message -Level Warning
        }
    }

    return [PSCustomObject]@{}
}

function Import-GitHubConfiguration
{
<#
    .SYNOPSIS
        Loads in the default configuration values, and then updates the individual properties
        with values that may exist in a file.

    .DESCRIPTION
        Loads in the default configuration values, and then updates the individual properties
        with values that may exist in a file.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Path
        The file that may or may not exist with a serialized version of the configuration
        values for this module.

    .OUTPUTS
        PSCustomObject

    .NOTES
        Internal helper method.
        No side-effects.

    .EXAMPLE
        Import-GitHubConfiguration -Path 'c:\foo\config.json'

        Creates a new default config object and updates its values with any that are found
        within a deserialized object from the content in $Path.  The configuration object
        is then returned.
#>
    [CmdletBinding()]
    param(
        [string] $Path
    )

    # Create a configuration object with all the default values.  We can then update the values
    # with any that we find on disk.
    $logPath = [String]::Empty
    $logName = 'PowerShellForGitHub.log'
    $documentsFolder = [System.Environment]::GetFolderPath('MyDocuments')
    $logToLocalAppDataFolder = [System.String]::IsNullOrEmpty($documentsFolder)
    if ($logToLocalAppDataFolder)
    {
        $logPath = Join-Path -Path ([System.Environment]::GetFolderPath('LocalApplicationData')) -ChildPath $logName
    }
    else
    {
        $logPath = Join-Path -Path $documentsFolder -ChildPath $logName
    }

    $config = [PSCustomObject]@{
        'apiHostName' = 'github.com'
        'applicationInsightsKey' = '66d83c52-3070-489b-886b-09860e05e78a'
        'disableLogging' = ([String]::IsNullOrEmpty($logPath))
        'disablePiiProtection' = $false
        'disablePipelineSupport' = $false
        'disableSmarterObjects' = $false
        'disableTelemetry' = $false
        'disableUpdateCheck' = $false
        'defaultOwnerName' = [String]::Empty
        'defaultPassThru' = $false
        'defaultRepositoryName' = [String]::Empty
        'logPath' = $logPath
        'logProcessId' = $false
        'logRequestBody' = $false
        'logTimeAsUtc' = $false
        'maximumRetriesWhenResultNotReady' = 30
        'multiRequestProgressThreshold' = 10
        'retryDelaySeconds' = 30
        'stateChangeDelaySeconds' = 0
        'suppressNoTokenWarning' = $false
        'suppressTelemetryReminder' = $false
        'webRequestTimeoutSec' = 0

        # This hash is generated by using Helper.ps1's Get-Sha512Hash in Tests/Config/Settings.ps1
        # like so:
        #    . ./Helpers.ps1; Get-Sha512Hash -PlainText (Get-Content -Path ./Tests/Config/Settings.ps1 -Raw -Encoding Utf8)
        # The hash is used to identify if the user has made changes to the config file prior to
        # running the UT's locally.  It intentionally cannot be modified via Set-GitHubConfiguration
        # and must be updated directly in the source code here should the default Settings.ps1 file
        # ever be changed.
        'testConfigSettingsHash' = '272EE14CED396100A7AFD23EA21CA262470B7F4D80E47B7ABD90508B86210775F020EEF79D322F4C22A53835F700E1DFD13D0509C1D08DD6F9771B3F0133EDAB'
    }

    $jsonObject = Read-GitHubConfiguration -Path $Path
    Get-Member -InputObject $config -MemberType NoteProperty |
        ForEach-Object {
            $name = $_.Name
            $type = $config.$name.GetType().Name
            $config.$name = Resolve-PropertyValue -InputObject $jsonObject -Name $name -Type $type -DefaultValue $config.$name
        }

    # Let the user know when we had to revert to using the LocalApplicationData folder for the
    # log location (if they haven't already changed its path in their local config).
    $configuredLogPath = $config.logPath
    if ($logToLocalAppDataFolder -and ($logPath -eq $configuredLogPath))
    {
        # Limited instance where we write the warning directly instead of using Write-Log, since
        # Write-Log won't yet be configured.
        $message = "Storing log at non-default location: [$logPath] (no user profile path was found).  You can change this location by calling Set-GitHubConfiguration -LogPath <desiredPathToLogFile>"
        Write-Verbose -Message $message
    }

    return $config
}

function Backup-GitHubConfiguration
{
<#
    .SYNOPSIS
        Exports the user's current configuration file.

    .DESCRIPTION
        Exports the user's current configuration file.

        This is primarily used for unit testing scenarios.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Path
        The path to store the user's current configuration file.

    .PARAMETER Force
        If specified, will overwrite the contents of any file with the same name at the
        location specified by Path.

    .EXAMPLE
        Backup-GitHubConfiguration -Path 'c:\foo\config.json'

        Writes the user's current configuration file to c:\foo\config.json.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Path,

        [switch] $Force
    )

    if (-not $PSCmdlet.ShouldProcess('GitHub Configuration', 'Backup'))
    {
        return
    }

    # Make sure that the path that we're going to be storing the file exists.
    $null = New-Item -Path (Split-Path -Path $Path -Parent) -ItemType Directory -Force

    if (Test-Path -Path $script:configurationFilePath -PathType Leaf)
    {
        $null = Copy-Item -Path $script:configurationFilePath -Destination $Path -Force:$Force
    }
    else
    {
        ConvertTo-Json -InputObject @{} | Set-Content -Path $Path -Force:$Force
    }
}

function Restore-GitHubConfiguration
{
<#
    .SYNOPSIS
        Sets the specified file to be the user's configuration file.

    .DESCRIPTION
        Sets the specified file to be the user's configuration file.

        This is primarily used for unit testing scenarios.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Path
        The path to store the user's current configuration file.

    .EXAMPLE
        Restore-GitHubConfiguration -Path 'c:\foo\config.json'

        Makes the contents of c:\foo\config.json be the user's configuration for the module.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript({
            if (Test-Path -Path $_ -PathType Leaf) { $true }
            else { throw "$_ does not exist." }})]
        [string] $Path
    )

    if (-not $PSCmdlet.ShouldProcess('GitHub Configuration', 'Restore'))
    {
        return
    }

    # Make sure that the path that we're going to be storing the file exists.
    $null = New-Item -Path (Split-Path -Path $script:configurationFilePath -Parent) -ItemType Directory -Force

    $null = Copy-Item -Path $Path -Destination $script:configurationFilePath -Force

    Initialize-GitHubConfiguration
}

function Resolve-ParameterWithDefaultConfigurationValue
{
<#
    .SYNOPSIS
        Some of the configuration properties act as default values to be used for some functions.
        This will determine what the correct final value should be by inspecting the calling
        functions inbound parameters, along with the corresponding configuration value.

    .DESCRIPTION
        Some of the configuration properties act as default values to be used for some functions.
        This will determine what the correct final value should be by inspecting the calling
        functions inbound parameters, along with the corresponding configuration value.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER BoundParameters
        The inbound parameters from the calling method.
        No need to explicitly provide this if you're using the PSBoundParameters from the
        function that is calling this directly.

    .PARAMETER Name
        The name of the parameter in BoundParameters.

    .PARAMETER ConfigValueName
        The name of the configuration property that should be used as default if Name doesn't exist
        in BoundParameters.

    .PARAMETER NonEmptyStringRequired
        If specified, will throw an exception if the resolved value to be returned would end up
        being null or an empty string.

    .EXAMPLE
        Resolve-ParameterWithDefaultConfigurationValue -BoundParameters $PSBoundParameters -Name OwnerName -ConfigValueName DefaultOwnerName

        Checks to see if the OwnerName was provided by the user from the calling method.  If
        so, uses that value. otherwise uses the DefaultOwnerName value currently configured.
#>
    [CmdletBinding()]
    param(
        $BoundParameters = (Get-Variable -Name PSBoundParameters -Scope 1 -ValueOnly),

        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [String] $ConfigValueName,

        [switch] $NonEmptyStringRequired
    )

    $value = $null
    if ($BoundParameters.ContainsKey($Name))
    {
        $value = $BoundParameters[$Name]
        if ($value -is [switch])
        {
            $value = $value.IsPresent
        }
    }
    else
    {
        $value = (Get-GitHubConfiguration -Name $ConfigValueName)
    }

    if ($NonEmptyStringRequired -and [String]::IsNullOrEmpty($value))
    {
        $message = "A value must be provided for $Name either as a parameter, or as a default configuration value ($ConfigValueName) via Set-GitHubConfiguration."
        Write-Log -Message $message -Level Error
        throw $message
    }
    else
    {
        return $value
    }
}

function Set-GitHubAuthentication
{
<#
    .SYNOPSIS
        Allows the user to configure the API token that should be used for authentication
        with the GitHub API.

    .DESCRIPTION
        Allows the user to configure the API token that should be used for authentication
        with the GitHub API.

        The token will be stored on the machine as a SecureString and will automatically
        be read on future PowerShell sessions with this module.  If the user ever wishes
        to remove their authentication from the system, they simply need to call
        Clear-GitHubAuthentication.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Credential
        If provided, instead of prompting the user for their API Token, it will be extracted
        from the password field of this credential object.

    .PARAMETER SessionOnly
        By default, this method will store the provided API Token as a SecureString in a local
        file so that it can be restored automatically in future PowerShell sessions.  If this
        switch is provided, the file will not be created/updated and the authentication information
        will only remain in memory for the duration of this PowerShell session.

    .EXAMPLE
        Set-GitHubAuthentication

        Prompts the user for their GitHub API Token and stores it in a file on the machine as a
        SecureString for use in future PowerShell sessions.

    .EXAMPLE
        $secureString = ("<Your Access Token>" | ConvertTo-SecureString -AsPlainText -Force)
        $cred = New-Object System.Management.Automation.PSCredential "username is ignored", $secureString
        Set-GitHubAuthentication -Credential $cred
        $secureString = $null # clear this out now that it's no longer needed
        $cred = $null # clear this out now that it's no longer needed

        Allows you to specify your access token as a plain-text string ("<Your Access Token>")
        which will be securely stored on the machine for use in all future PowerShell sessions.

    .EXAMPLE
        Set-GitHubAuthentication -SessionOnly

        Prompts the user for their GitHub API Token, but keeps it in memory only for the duration
        of this PowerShell session.

    .EXAMPLE
        Set-GitHubAuthentication -Credential $cred -SessionOnly

        Uses the API token stored in the password field of the provided credential object for
        authentication, but keeps it in memory only for the duration of this PowerShell session..
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUsePSCredentialType", "", Justification="The System.Management.Automation.Credential() attribute does not appear to work in PowerShell v4 which we need to support.")]
    param(
        [PSCredential] $Credential,

        [switch] $SessionOnly
    )

    Write-InvocationLog

    if (-not $PSCmdlet.ShouldProcess('GitHub Authentication', 'Set'))
    {
        return
    }

    if (-not $PSBoundParameters.ContainsKey('Credential'))
    {
        $message = 'Please provide your GitHub API Token in the Password field.  You can enter anything in the username field (it will be ignored).'
        if (-not $SessionOnly)
        {
            $message = $message + '  ***The token is being cached across PowerShell sessions.  To clear caching, call Clear-GitHubAuthentication.***'
        }

        Write-Log -Message $message
        $Credential = Get-Credential -Message $message
    }

    if ([String]::IsNullOrWhiteSpace($Credential.GetNetworkCredential().Password))
    {
        $message = "The API Token was not provided in the password field.  Nothing to do."
        Write-Log -Message $message -Level Error
        throw $message
    }

    $script:accessTokenCredential = $Credential

    if (-not $SessionOnly)
    {
        $null = New-Item -Path $script:accessTokenFilePath -Force
        $script:accessTokenCredential.Password |
            ConvertFrom-SecureString |
            Set-Content -Path $script:accessTokenFilePath -Force
    }
}

function Clear-GitHubAuthentication
{
<#
    .SYNOPSIS
        Clears out any GitHub API token from memory, as well as from local file storage.

    .DESCRIPTION
        Clears out any GitHub API token from memory, as well as from local file storage.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER SessionOnly
        By default, this will clear out the cache in memory, as well as in the local
        configuration file.  If this switch is specified, authentication will be cleared out
        in this session only -- the local configuration file cache will remain
        (and thus still be available in a new PowerShell session).

    .EXAMPLE
        Clear-GitHubAuthentication

        Clears out any GitHub API token from memory, as well as from local file storage.

    .NOTES
        This command will not clear your configuration settings.
        Please use Reset-GitHubConfiguration to accomplish that.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch] $SessionOnly
    )

    Write-InvocationLog

    Set-TelemetryEvent -EventName Clear-GitHubAuthentication

    if (-not $PSCmdlet.ShouldProcess('GitHub Authentication', 'Clear'))
    {
        return
    }

    $script:accessTokenCredential = $null

    if (-not $SessionOnly)
    {
        Remove-Item -Path $script:accessTokenFilePath -Force -ErrorAction SilentlyContinue -ErrorVariable ev

        if (($null -ne $ev) -and
            ($ev.Count -gt 0) -and
            ($ev[0].FullyQualifiedErrorId -notlike 'PathNotFound*'))
        {
            $message = "Experienced a problem trying to remove the file that persists the Access Token [$script:accessTokenFilePath]."
            Write-Log -Message $message -Level Warning -Exception $ev[0]
        }
    }

    $message = "This has not cleared your configuration settings.  Call Reset-GitHubConfiguration to accomplish that."
    Write-Log -Message $message -Level Verbose
}

function Get-AccessToken
{
<#
    .SYNOPSIS
        Retrieves the API token for use in the rest of the module.

    .DESCRIPTION
        Retrieves the API token for use in the rest of the module.

        First will try to use the one that may have been provided as a parameter.
        If not provided, then will try to use the one already cached in memory.
        If still not found, will look to see if there is a file with the API token stored
        as a SecureString.
        Finally, if there is still no available token, none will be used.  The user will then be
        subjected to tighter hourly query restrictions.

        The Git repo for this module can be found here: http://aka.ms/PowershellForGitHub

    .PARAMETER AccessToken
        If provided, this will be returned instead of using the cached/configured value

    .OUTPUTS
        System.String
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="For back-compat with v0.1.0, this still supports the deprecated method of using a global variable for storing the Access Token.")]
    [OutputType([String])]
    param(
        [string] $AccessToken
    )

    if (-not [String]::IsNullOrEmpty($AccessToken))
    {
        return $AccessToken
    }

    if ($null -ne $script:accessTokenCredential)
    {
        $token = $script:accessTokenCredential.GetNetworkCredential().Password

        if (-not [String]::IsNullOrEmpty($token))
        {
            return $token
        }
    }

    $content = Get-Content -Path $script:accessTokenFilePath -ErrorAction Ignore
    if (-not [String]::IsNullOrEmpty($content))
    {
        try
        {
            $secureString = $content | ConvertTo-SecureString

            $message = "Restoring Access Token from file.  This value can be cleared in the future by calling Clear-GitHubAuthentication."
            Write-Log -Message $messsage -Level Verbose
            $script:accessTokenCredential = New-Object System.Management.Automation.PSCredential "<username is ignored>", $secureString
            return $script:accessTokenCredential.GetNetworkCredential().Password
        }
        catch
        {
           $message = 'The Access Token file for this module contains an invalid SecureString (files can''t be shared by users or computers).  Use Set-GitHubAuthentication to update it.'
           Write-Log -Message $message -Level Warning
        }
    }

    if (-not [String]::IsNullOrEmpty($global:gitHubApiToken))
    {
        $message = 'Storing the Access Token in `$global:gitHubApiToken` is insecure and is no longer recommended.  To cache your Access Token for use across future PowerShell sessions, please use Set-GitHubAuthentication instead.'
        Write-Log -Message $message -Level Warning
        return $global:gitHubApiToken
    }

    if ((-not (Get-GitHubConfiguration -Name SuppressNoTokenWarning)) -and
        (-not $script:seenTokenWarningThisSession))
    {
        $script:seenTokenWarningThisSession = $true
        $message = 'This module has not yet been configured with a personal GitHub Access token.  The module can still be used, but GitHub will limit your usage to 60 queries per hour.  You can get a GitHub API token from https://github.com/settings/tokens/new (provide a description and check any appropriate scopes).'
        Write-Log -Message $message -Level Warning
    }

    return $null
}

function Test-GitHubAuthenticationConfigured
{
<#
    .SYNOPSIS
        Indicates if a GitHub API Token has been configured for this module via Set-GitHubAuthentication.

    .DESCRIPTION
        Indicates if a GitHub API Token has been configured for this module via Set-GitHubAuthentication.

        The Git repo for this module can be found here: http://aka.ms/PowershellForGitHub

    .OUTPUTS
        Boolean

    .EXAMPLE
        Test-GitHubAuthenticationConfigured

        Returns $true if the session is authenticated; $false otherwise
#>
    [CmdletBinding()]
    [OutputType([Boolean])]
    param()

    return (-not [String]::IsNullOrWhiteSpace((Get-AccessToken)))
}

Initialize-GitHubConfiguration

# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBm6MsYwy0NzdWV
# fiC/e7xQfce4D50/3uYMdZsvf+G9g6CCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgX77mWD94
# 1DfwLj9fpDhmJuHaAhjBw7Lxtf0wUvXNmwcwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQDESj7pvKcZiqJXTP7QmwMqzZqQjjsJaKHnVYxHNkSK
# rI43o/XcaP6DZpF88wHwgbFaAbwA+VzUdGrVQb4NbbkmmGMbUTw4/4dwsQuxRX+q
# M+TafMdZuYpXdD5ehqFuhDoQ111ptGmEoIHiawqsezJyljaoOY/m0yaM2V8oTFTG
# iFz0E6SIKTdQwOwqf4c88tutxE9qQ1xPyG97/6dvfNkOPm19KgVYRHSrgCm18l4p
# kM+ik7fbj8N9b5yJCEaJlZ9MvoHqkSx0fnpQApnTA/iuaBZLQbOMFqU5QPfzNkWO
# DLFI4JJJBa1eCp2hsXx2MdrQxQVxuUScMTLlGyOFo8bhoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIOQLGwvlJAF3Uifd/6t2ovzyBm0xuEblNutueK1t
# paCDAgZf25dxEbsYEzIwMjEwMTA1MTk1MDUzLjc2NlowBIACAfSggdSkgdEwgc4x
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
# CQQxIgQg26/5uMImaVZG4j1fhIByRIV6tArm78QekLdWIbauDHIwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCCO8Vpycn0gB4/ilRAPPDbS+Cmbqj/uC011moc5
# oeGDwTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# LS5NQcpjZTOgAAAAAAEtMCIEIKCwLleqLz6zScDfjPL7hO83mrVe1ihvaUe23CWp
# tV7RMA0GCSqGSIb3DQEBCwUABIIBADIP4xNlWdxFtDadcubVMlrHPWKHNADZxEwF
# BTIM/NfHXRfxyZD2ndIXCA67mRF8y24p7Fk5JN7mBIB+aVOcrqF43Ci9Wo9QyzLc
# tmR2bnbEVh+DoD4OCaEcVOF4mq1xk1pdzdEy177zoQK2JIcQ+7NCMeZeOBYm2LG7
# gmwNo0TtIlcKmkpda3y/tC06DZkLF10Q40XDRoUku5S5xhCFWnSQBKg0oqpyHWiJ
# U9X7e+nuHG8SPotGoE0XRddsdWs0ON/SjxvgKkpytSR/q4grDsJxJJSQVJuakSHL
# 4qZel63hZ+PPJZEv2LhIumjgTeRlP6BcaLw9xABrXyB8ysEsxtY=
# SIG # End signature block
