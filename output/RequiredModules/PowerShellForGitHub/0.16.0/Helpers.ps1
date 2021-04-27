# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

function Get-SHA512Hash
{
<#
    .SYNOPSIS
        Gets the SHA512 hash of the requested string.

    .DESCRIPTION
        Gets the SHA512 hash of the requested string.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER PlainText
        The plain text that you want the SHA512 hash for.

    .EXAMPLE
        Get-SHA512Hash -PlainText "Hello World"

        Returns back the string "2C74FD17EDAFD80E8447B0D46741EE243B7EB74DD2149A0AB1B9246FB30382F27E853D8585719E0E67CBDA0DAA8F51671064615D645AE27ACB15BFB1447F459B"
        which represents the SHA512 hash of "Hello World"

    .OUTPUTS
        System.String - A SHA512 hash of the provided string
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $PlainText
    )

    $sha512= New-Object -TypeName System.Security.Cryptography.SHA512CryptoServiceProvider
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding
    return [System.BitConverter]::ToString($sha512.ComputeHash($utf8.GetBytes($PlainText))) -replace '-', ''
}


function Write-Log
{
<#
    .SYNOPSIS
        Writes logging information to screen and log file simultaneously.

    .DESCRIPTION
        Writes logging information to screen and log file simultaneously.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Message
        The message(s) to be logged. Each element of the array will be written to a separate line.

        This parameter supports pipelining but there are no
        performance benefits to doing so. For more information, see the .NOTES for this
        cmdlet.

    .PARAMETER Level
        The type of message to be logged.

    .PARAMETER Indent
        The number of spaces to indent the line in the log file.

    .PARAMETER Path
        The log file path.
        Defaults to $env:USERPROFILE\Documents\PowerShellForGitHub.log

    .PARAMETER Exception
        If present, the exception information will be logged after the messages provided.
        The actual string that is logged is obtained by passing this object to Out-String.

    .EXAMPLE
        Write-Log -Message "Everything worked." -Path C:\Debug.log

        Writes the message "Everything worked." to the screen as well as to a log file at "c:\Debug.log",
        with the caller's username and a date/time stamp prepended to the message.

    .EXAMPLE
        Write-Log -Message ("Everything worked.", "No cause for alarm.") -Path C:\Debug.log

        Writes the following message to the screen as well as to a log file at "c:\Debug.log",
        with the caller's username and a date/time stamp prepended to the message:

        Everything worked.
        No cause for alarm.

    .EXAMPLE
        Write-Log -Message "There may be a problem..." -Level Warning -Indent 2

        Writes the message "There may be a problem..." to the warning pipeline indented two spaces,
        as well as to the default log file with the caller's username and a date/time stamp
        prepended to the message.

    .EXAMPLE
        try { $null.Do() }
        catch { Write-Log -Message ("There was a problem.", "Here is the exception information:") -Exception $_ -Level Error }

        Logs the message:

        Write-Log : 2018-01-23 12:57:37 : dabelc : There was a problem.
        Here is the exception information:
        You cannot call a method on a null-valued expression.
        At line:1 char:7
        + try { $null.Do() } catch { Write-Log -Message ("There was a problem." ...
        +       ~~~~~~~~~~
            + CategoryInfo          : InvalidOperation: (:) [], RuntimeException
            + FullyQualifiedErrorId : InvokeMethodOnNull

    .INPUTS
        System.String

    .NOTES
        The "LogPath" configuration value indicates where the log file will be created.
        The "" determines if log entries will be made to the log file.
           If $false, log entries will ONLY go to the relevant output pipeline.

        Note that, although this function supports pipeline input to the -Message parameter,
        there is NO performance benefit to using the pipeline. This is because the pipeline
        input is simply accumulated and not acted upon until all input has been received.
        This behavior is intentional, in order for a statement like:
            "Multiple", "messages" | Write-Log -Exception $ex -Level Error
        to make sense.  In this case, the cmdlet should accumulate the messages and, at the end,
        include the exception information.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We need to be able to access the PID for logging purposes, and it is accessed via a global variable.")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidOverwritingBuiltInCmdlets", "", Justification="Write-Log is an internal function being incorrectly exported by PSDesiredStateConfiguration.  See PowerShell/PowerShell#7209")]
    param(
        [Parameter(ValueFromPipeline)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [AllowNull()]
        [string[]] $Message = @(),

        [ValidateSet('Error', 'Warning', 'Informational', 'Verbose', 'Debug')]
        [string] $Level = 'Informational',

        [ValidateRange(1, 30)]
        [Int16] $Indent = 0,

        [IO.FileInfo] $Path = (Get-GitHubConfiguration -Name LogPath),

        [System.Management.Automation.ErrorRecord] $Exception
    )

    begin
    {
        # Accumulate the list of Messages, whether by pipeline or parameter.
        $messages = @()
    }

    process
    {
        foreach ($m in $Message)
        {
            $messages += $m
        }
    }

    end
    {
        if ($null -ne $Exception)
        {
            # If we have an exception, add it after the accumulated messages.
            $messages += Out-String -InputObject $Exception
        }
        elseif ($messages.Count -eq 0)
        {
            # If no exception and no messages, we should early return.
            return
        }

        # Finalize the string to be logged.
        $finalMessage = $messages -join [Environment]::NewLine

        # Build the console and log-specific messages.
        $date = Get-Date
        $dateString = $date.ToString("yyyy-MM-dd HH:mm:ss")
        if (Get-GitHubConfiguration -Name LogTimeAsUtc)
        {
            $dateString = $date.ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ssZ")
        }

        $consoleMessage = '{0}{1}' -f
            (" " * $Indent),
            $finalMessage

        if (Get-GitHubConfiguration -Name LogProcessId)
        {
            $maxPidDigits = 10 # This is an estimate (see https://stackoverflow.com/questions/17868218/what-is-the-maximum-process-id-on-windows)
            $pidColumnLength = $maxPidDigits + "[]".Length
            $logFileMessage = "{0}{1} : {2, -$pidColumnLength} : {3} : {4} : {5}" -f
                (" " * $Indent),
                $dateString,
                "[$global:PID]",
                $env:username,
                $Level.ToUpper(),
                $finalMessage
        }
        else
        {
            $logFileMessage = '{0}{1} : {2} : {3} : {4}' -f
                (" " * $Indent),
                $dateString,
                $env:username,
                $Level.ToUpper(),
                $finalMessage
        }

        # Write the message to screen/log.
        # Note that the below logic could easily be moved to a separate helper function, but a conscious
        # decision was made to leave it here. When this cmdlet is called with -Level Error, Write-Error
        # will generate a WriteErrorException with the origin being Write-Log. If this call is moved to
        # a helper function, the origin of the WriteErrorException will be the helper function, which
        # could confuse an end user.
        switch ($Level)
        {
            # Need to explicitly say SilentlyContinue here so that we continue on, given that
            # we've assigned a script-level ErrorActionPreference of "Stop" for the module.
            'Error'   { Write-Error $consoleMessage -ErrorAction SilentlyContinue }
            'Warning' { Write-Warning $consoleMessage }
            'Verbose' { Write-Verbose $consoleMessage }
            'Debug'   { Write-Debug $consoleMessage }
            'Informational'    {
                # We'd prefer to use Write-Information to enable users to redirect that pipe if
                # they want, unfortunately it's only available on v5 and above.  We'll fallback to
                # using Write-Host for earlier versions (since we still need to support v4).
                if ($PSVersionTable.PSVersion.Major -ge 5)
                {
                    Write-Information $consoleMessage -InformationAction Continue
                }
                else
                {
                    Write-InteractiveHost $consoleMessage
                }
            }
        }

        try
        {
            if (-not (Get-GitHubConfiguration -Name DisableLogging))
            {
                if ([String]::IsNullOrWhiteSpace($Path))
                {
                    Write-Warning 'Logging is currently enabled, however no path has been specified for the log file.  Use "Set-GitHubConfiguration -LogPath" to set the log path, or "Set-GitHubConfiguration -DisableLogging" to disable logging.'
                }
                else
                {
                    $logFileMessage | Out-File -FilePath $Path -Append -WhatIf:$false -Confirm:$false
                }
            }
        }
        catch
        {
            $output = @()
            $output += "Failed to add log entry to [$Path]. The error was:"
            $output += Out-String -InputObject $_

            if (Test-Path -Path $Path -PathType Leaf)
            {
                # The file exists, but likely is being held open by another process.
                # Let's do best effort here and if we can't log something, just report
                # it and move on.
                $output += "This is non-fatal, and your command will continue.  Your log file will be missing this entry:"
                $output += $consoleMessage
                Write-Warning ($output -join [Environment]::NewLine)
            }
            else
            {
                # If the file doesn't exist and couldn't be created, it likely will never
                # be valid.  In that instance, let's stop everything so that the user can
                # fix the problem, since they have indicated that they want this logging to
                # occur.
                throw ($output -join [Environment]::NewLine)
            }
        }
    }
}

$script:alwaysRedactParametersForLogging = @(
    'AccessToken' # Would be a security issue
)

$script:alwaysExcludeParametersForLogging = @(
)

function Write-InvocationLog
{
<#
    .SYNOPSIS
        Writes a log entry for the invoke command.

    .DESCRIPTION
        Writes a log entry for the invoke command.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER InvocationInfo
        The '$MyInvocation' object from the calling function.
        No need to explicitly provide this if you're trying to log the immediate function this is
        being called from.

    .PARAMETER RedactParameter
        An optional array of parameter names that should be logged, but their values redacted.

    .PARAMETER ExcludeParameter
        An optional array of parameter names that should simply not be logged.

    .EXAMPLE
        Write-InvocationLog -Invocation $MyInvocation

    .EXAMPLE
        Write-InvocationLog -Invocation $MyInvocation -ExcludeParameter @('Properties', 'Metrics')

    .NOTES
        The actual invocation line will not be _completely_ accurate as converted parameters will
        be in JSON format as opposed to PowerShell format.  However, it should be sufficient enough
        for debugging purposes.

        ExcludeParameter will always take precedence over RedactParameter.
#>
    [CmdletBinding()]
    param(
        [Management.Automation.InvocationInfo] $Invocation = (Get-Variable -Name MyInvocation -Scope 1 -ValueOnly),

        [string[]] $RedactParameter,

        [string[]] $ExcludeParameter
    )

    $jsonConversionDepth = 20 # Seems like it should be more than sufficient

    # Build up the invoked line, being sure to exclude and/or redact any values necessary
    $params = @()
    foreach ($param in $Invocation.BoundParameters.GetEnumerator())
    {
        if ($param.Key -in ($script:alwaysExcludeParametersForLogging + $ExcludeParameter))
        {
            continue
        }

        if ($param.Key -in ($script:alwaysRedactParametersForLogging + $RedactParameter))
        {
            $params += "-$($param.Key) <redacted>"
        }
        else
        {
            if ($param.Value -is [switch])
            {
                $params += "-$($param.Key):`$$($param.Value.ToBool().ToString().ToLower())"
            }
            else
            {
                $params += "-$($param.Key) $(ConvertTo-Json -InputObject $param.Value -Depth $jsonConversionDepth -Compress)"
            }
        }
    }

    Write-Log -Message "[$($Invocation.MyCommand.Module.Version)] Executing: $($Invocation.MyCommand) $($params -join ' ')" -Level Verbose
}

function DeepCopy-Object
{
<#
    .SYNOPSIS
        Creates a deep copy of a serializable object.

    .DESCRIPTION
        Creates a deep copy of a serializable object.
        By default, PowerShell performs shallow copies (simple references)
        when assigning objects from one variable to another.  This will
        create full exact copies of the provided object so that they
        can be manipulated independently of each other, provided that the
        object being copied is serializable.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER InputObject
        The object that is to be copied.  This must be serializable or this will fail.

    .EXAMPLE
        $bar = DeepCopy-Object -InputObject $foo
        Assuming that $foo is serializable, $bar will now be an exact copy of $foo, but
        any changes that you make to one will not affect the other.

    .RETURNS
        An exact copy of the PSObject that was just deep copied.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification="Intentional.  This isn't exported, and needed to be explicit relative to Copy-Object.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $InputObject
    )

    $memoryStream = New-Object System.IO.MemoryStream
    $binaryFormatter = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
    $binaryFormatter.Serialize($memoryStream, $InputObject)
    $memoryStream.Position = 0
    $DeepCopiedObject = $binaryFormatter.Deserialize($memoryStream)
    $memoryStream.Close()

    return $DeepCopiedObject
}

function New-TemporaryDirectory
{
<#
    .SYNOPSIS
        Creates a new subdirectory within the users's temporary directory and returns the path.

    .DESCRIPTION
        Creates a new subdirectory within the users's temporary directory and returns the path.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .EXAMPLE
        New-TemporaryDirectory
        Creates a new directory with a GUID under $env:TEMP

    .OUTPUTS
        System.String - The path to the newly created temporary directory
#>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Justification="Methods called within here make use of PSShouldProcess, and the switch is passed on to them inherently.")]
    param()

    $parentTempPath = [System.IO.Path]::GetTempPath()
    $tempFolderPath = [String]::Empty
    do
    {
        $guid = [System.Guid]::NewGuid()
        $tempFolderPath = Join-Path -Path $parentTempPath -ChildPath $guid
    }
    while (Test-Path -Path $tempFolderPath -PathType Container)

    Write-Log -Message "Creating temporary directory: $tempFolderPath" -Level Verbose
    New-Item -ItemType Directory -Path $tempFolderPath
}

function Write-InteractiveHost
{
<#
    .SYNOPSIS
        Forwards to Write-Host only if the host is interactive, else does nothing.

    .DESCRIPTION
        A proxy function around Write-Host that detects if the host is interactive
        before calling Write-Host. Use this instead of Write-Host to avoid failures in
        non-interactive hosts.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .EXAMPLE
        Write-InteractiveHost "Test"
        Write-InteractiveHost "Test" -NoNewline -f Yellow

    .NOTES
        Boilerplate is generated using these commands:
        # $Metadata = New-Object System.Management.Automation.CommandMetaData (Get-Command Write-Host)
        # [System.Management.Automation.ProxyCommand]::Create($Metadata) | Out-File temp
#>

    [CmdletBinding(
        HelpUri='http://go.microsoft.com/fwlink/?LinkID=113426',
        RemotingCapability='None')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification="This provides a wrapper around Write-Host. In general, we'd like to use Write-Information, but it's not supported on PS 4.0 which we need to support.")]
    param(
        [Parameter(
            Position=0,
            ValueFromPipeline,
            ValueFromRemainingArguments)]
        [System.Object] $Object,

        [switch] $NoNewline,

        [System.Object] $Separator,

        [System.ConsoleColor] $ForegroundColor,

        [System.ConsoleColor] $BackgroundColor
    )

    begin
    {
        $hostIsInteractive = ([Environment]::UserInteractive -and
            ![Bool]([Environment]::GetCommandLineArgs() -like '-noni*') -and
            ((Get-Host).Name -ne 'Default Host'))
    }

    process
    {
        # Determine if the host is interactive
        if ($hostIsInteractive)
        {
            # Special handling for OutBuffer (generated for the proxy function)
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }

            Write-Host @PSBoundParameters
        }
    }
}

function Resolve-UnverifiedPath
{
<#
    .SYNOPSIS
        A wrapper around Resolve-Path that works for paths that exist as well
        as for paths that don't (Resolve-Path normally throws an exception if
        the path doesn't exist.)

    .DESCRIPTION
        A wrapper around Resolve-Path that works for paths that exist as well
        as for paths that don't (Resolve-Path normally throws an exception if
        the path doesn't exist.)

        The Git repo for this module can be found here: https://aka.ms/PowerShellForGitHub

    .EXAMPLE
        Resolve-UnverifiedPath -Path 'c:\windows\notepad.exe'

        Returns the string 'c:\windows\notepad.exe'.

    .EXAMPLE
        Resolve-UnverifiedPath -Path '..\notepad.exe'

        Returns the string 'c:\windows\notepad.exe', assuming that it's executed from
        within 'c:\windows\system32' or some other sub-directory.

    .EXAMPLE
        Resolve-UnverifiedPath -Path '..\foo.exe'

        Returns the string 'c:\windows\foo.exe', assuming that it's executed from
        within 'c:\windows\system32' or some other sub-directory, even though this
        file doesn't exist.

    .OUTPUTS
        [string] - The fully resolved path

#>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $Path
    )

    process
    {
        $resolvedPath = Resolve-Path -Path $Path -ErrorVariable resolvePathError -ErrorAction SilentlyContinue

        if ($null -eq $resolvedPath)
        {
            Write-Output -InputObject ($resolvePathError[0].TargetObject)
        }
        else
        {
            Write-Output -InputObject ($resolvedPath.ProviderPath)
        }
    }
}

function Ensure-Directory
{
<#
    .SYNOPSIS
        A utility function for ensuring a given directory exists.

    .DESCRIPTION
        A utility function for ensuring a given directory exists.

        If the directory does not already exist, it will be created.

    .PARAMETER Path
        A full or relative path to the directory that should exist when the function exits.

    .NOTES
        Uses the Resolve-UnverifiedPath function to resolve relative paths.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseApprovedVerbs", "", Justification = "Unable to find a standard verb that satisfies describing the purpose of this internal helper method.")]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    try
    {
        $Path = Resolve-UnverifiedPath -Path $Path

        if (-not (Test-Path -PathType Container -Path $Path))
        {
            Write-Log -Message "Creating directory: [$Path]" -Level Verbose
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
    catch
    {
        Write-Log -Message "Could not ensure directory: [$Path]" -Level Error

        throw
    }
}

function Get-HttpWebResponseContent
{
<#
    .SYNOPSIS
        Returns the content that may be contained within an HttpWebResponse object.

    .DESCRIPTION
        Returns the content that may be contained within an HttpWebResponse object.

        This would commonly be used when trying to get the potential content
        returned within a failing WebResponse.  Normally, when you call
        Invoke-WebRequest, it returns back a BasicHtmlWebResponseObject which
        directly contains a Content property, however if the web request fails,
        you get a WebException which contains a simpler WebResponse, which
        requires a bit more effort in order to access the raw response content.

    .PARAMETER WebResponse
        An HttpWebResponse object, typically the Response property on a WebException.

    .OUTPUTS
        System.String - The raw content that was included in a WebResponse; $null otherwise.
#>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [System.Net.HttpWebResponse] $WebResponse
    )

    $streamReader = $null

    try
    {
        $content = $null

        if (($null -ne $WebResponse) -and ($WebResponse.ContentLength -gt 0))
        {
            $stream = $WebResponse.GetResponseStream()
            $encoding = [System.Text.Encoding]::UTF8
            if (-not [String]::IsNullOrWhiteSpace($WebResponse.ContentEncoding))
            {
                $encoding = [System.Text.Encoding]::GetEncoding($WebResponse.ContentEncoding)
            }

            $streamReader = New-Object -TypeName System.IO.StreamReader -ArgumentList ($stream, $encoding)
            $content = $streamReader.ReadToEnd()
        }

        return $content
    }
    finally
    {
        if ($null -ne $streamReader)
        {
            $streamReader.Close()
        }
    }
}

# SIG # Begin signature block
# MIIjkQYJKoZIhvcNAQcCoIIjgjCCI34CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD4NC6H7e83lhQH
# 5e4QJEVi02UZbGXPLjGpY52zFYBAYqCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVZjCCFWICAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAYdyF3IVWUDHCQAAAAABhzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg2C04j1ka
# 878ZLZB5xRVRvRTSEJa1/HBdP1JGIYevOgYwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBFn1WsNP9K5609dviZm2zOLQ3QpTqWg3nhwq9Eowcf
# VnXgYUrD2BqSr8MOLIjnD6waCJ+/JnETMrtARAOp85+Oe1wPTog8/Iv8XI6E/cqK
# S439WfRcQrQYO7cSQWLEt0NkcT7iayoxHx8TKDLkYudAtqvOnMCOHY1B9SKSOaMG
# f2WBIR9ZfPI4heLcVuDVW6kndDOBq2gSR3vlECy+a7Lj5juvU6jncNKB1gDSFHAM
# o7D6q5B85QVvn0Y7MBq2O7IvyDNql+MPqNHggHFC50WgeN7x5nbiDCaQc28TbQOI
# jxw4u3jx+BDhlBLiJ2cI1ueCCXbk0VfRzjcIRC8CU/VOoYIS8DCCEuwGCisGAQQB
# gjcDAwExghLcMIIS2AYJKoZIhvcNAQcCoIISyTCCEsUCAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEII6VjLgC/EbF6HrjSsTc4rFXlD/SmoYDS1EkWkUF
# IkJJAgZf29L2GwAYEjIwMjEwMTA1MTk1MDU1LjEyWjAEgAIB9KCB1KSB0TCBzjEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEpMCcGA1UECxMgTWlj
# cm9zb2Z0IE9wZXJhdGlvbnMgUHVlcnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOjQ2MkYtRTMxOS0zRjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloIIORDCCBPUwggPdoAMCAQICEzMAAAEky80CoRdwXJoAAAAA
# ASQwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# HhcNMTkxMjE5MDExNDU3WhcNMjEwMzE3MDExNDU3WjCBzjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEpMCcGA1UECxMgTWljcm9zb2Z0IE9wZXJh
# dGlvbnMgUHVlcnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjQ2MkYt
# RTMxOS0zRjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkJsqOA2eGO8yWdE0C3Ht
# fc3llmRJ9QVQvJaxUnWmfIyxIhOKaDWrc5DUiR/T/eCDxQblMhGbvAfyyMG2gHee
# 7MXPXUJ6AgVxqdie3TnQm+etRMp4A9RHmkulN4/dASAv4JY5ziVOD9fGOdC/TUUP
# tNOf0MS47eSnQZDzsyN3myzErQrWrghY0UDJGnHmfxWbdWbWKJUvkUwNQqyXkb9K
# pB2IQOfxyphupYxXNYf3g90p3DWYgdOgFEI2xH0EcdbM2RJL5HRZGKkFJKispPty
# 4uUQFiEOjwBje4waW/SQtEscBJn6zPad+SlbYJW35seFWYzr/mqK7Z/t5ihNgm5w
# UQIDAQABo4IBGzCCARcwHQYDVR0OBBYEFLsd0XKsYoiEPG/KksDWUP/AZFKwMB8G
# A1UdIwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2hahW1VMFYGA1UdHwRPME0wS6BJoEeG
# RWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Rp
# bVN0YVBDQV8yMDEwLTA3LTAxLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUH
# MAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljVGltU3Rh
# UENBXzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwDQYJKoZIhvcNAQELBQADggEBAGjdDM241GDN1+XADhTt/d7YJwaXB2Dq
# KLj3xwGJKtOlYo7eqrPmm+AcCTiGHrL8UtjzRHn2KcvBxW7IPbhLckR1KJ7jLW0L
# kmm3B5HWqXFEkJEzi8buc+0gLh4AwpxeCi+7SZMW/vGkUBWlG6+56lH3WAh17fby
# W/UdNMkJX8sEGTzdeLucIY8Xn0XF4itwTfbG3hgmASkQCKR4yq9YJMzI+qWa/H0n
# 3Z/FTdxBzDaPYRbCo4PlPc3PYdZ89XzSyKEPUDpjkeGOlL21oM+zsIjnwjbXUXfK
# x6A3I56wbcxOtIkfI8wspgUPFwbWd5XSWKS2/5Nb3buxQ5VzNxJSFAswggZxMIIE
# WaADAgECAgphCYEqAAAAAAACMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9v
# dCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0xMDA3MDEyMTM2NTVaFw0y
# NTA3MDEyMTQ2NTVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqR0NvHcRijog7PwTl/X6f2mUa3RU
# ENWlCgCChfvtfGhLLF/Fw+Vhwna3PmYrW/AVUycEMR9BGxqVHc4JE458YTBZsTBE
# D/FgiIRUQwzXTbg4CLNC3ZOs1nMwVyaCo0UN0Or1R4HNvyRgMlhgRvJYR4YyhB50
# YWeRX4FUsc+TTJLBxKZd0WETbijGGvmGgLvfYfxGwScdJGcSchohiq9LZIlQYrFd
# /XcfPfBXday9ikJNQFHRD5wGPmd/9WbAA5ZEfu/QS/1u5ZrKsajyeioKMfDaTgaR
# togINeh4HLDpmc085y9Euqf03GS9pAHBIAmTeM38vMDJRF1eFpwBBU8iTQIDAQAB
# o4IB5jCCAeIwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFNVjOlyKMZDzQ3t8
# RhvFM2hahW1VMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIB
# hjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fO
# mhjEMFYGA1UdHwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9w
# a2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggr
# BgEFBQcBAQROMEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNv
# bS9wa2kvY2VydHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MIGgBgNVHSAB
# Af8EgZUwgZIwgY8GCSsGAQQBgjcuAzCBgTA9BggrBgEFBQcCARYxaHR0cDovL3d3
# dy5taWNyb3NvZnQuY29tL1BLSS9kb2NzL0NQUy9kZWZhdWx0Lmh0bTBABggrBgEF
# BQcCAjA0HjIgHQBMAGUAZwBhAGwAXwBQAG8AbABpAGMAeQBfAFMAdABhAHQAZQBt
# AGUAbgB0AC4gHTANBgkqhkiG9w0BAQsFAAOCAgEAB+aIUQ3ixuCYP4FxAz2do6Eh
# b7Prpsz1Mb7PBeKp/vpXbRkws8LFZslq3/Xn8Hi9x6ieJeP5vO1rVFcIK1GCRBL7
# uVOMzPRgEop2zEBAQZvcXBf/XPleFzWYJFZLdO9CEMivv3/Gf/I3fVo/HPKZeUqR
# UgCvOA8X9S95gWXZqbVr5MfO9sp6AG9LMEQkIjzP7QOllo9ZKby2/QThcJ8ySif9
# Va8v/rbljjO7Yl+a21dA6fHOmWaQjP9qYn/dxUoLkSbiOewZSnFjnXshbcOco6I8
# +n99lmqQeKZt0uGc+R38ONiU9MalCpaGpL2eGq4EQoO4tYCbIjggtSXlZOz39L9+
# Y1klD3ouOVd2onGqBooPiRa6YacRy5rYDkeagMXQzafQ732D8OE7cQnfXXSYIghh
# 2rBQHm+98eEA3+cxB6STOvdlR3jo+KhIq/fecn5ha293qYHLpwmsObvsxsvYgrRy
# zR30uIUBHoD7G4kqVDmyW9rIDVWZeodzOwjmmC3qjeAzLhIp9cAvVCch98isTtoo
# uLGp25ayp0Kiyc8ZQU3ghvkqmqMRZjDTu3QyS99je/WZii8bxyGvWbWu3EQ8l1Bx
# 16HSxVXjad5XwdHeMMD9zOZN+w2/XU/pnR4ZOC+8z1gFLu8NoFA12u8JJxzVs341
# Hgi62jbb01+P3nSISRKhggLSMIICOwIBATCB/KGB1KSB0TCBzjELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEpMCcGA1UECxMgTWljcm9zb2Z0IE9w
# ZXJhdGlvbnMgUHVlcnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOjQ2
# MkYtRTMxOS0zRjIwMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2
# aWNloiMKAQEwBwYFKw4DAhoDFQCXA+U0Kr5SfnhR/Et7/ApLVdzieqCBgzCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA
# 4560rjAiGA8yMDIxMDEwNTEzNDkzNFoYDzIwMjEwMTA2MTM0OTM0WjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDjnrSuAgEAMAoCAQACAh9aAgH/MAcCAQACAhM4MAoC
# BQDjoAYuAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEAQkxSuWwPz2ikXWVs
# xeyoZcBYccmEGTVFg9Ed68z0MkHIUaB8E0uQEwownjkXy7Mw18Gw15FAvMkgdz4y
# 0+yGkEwgsJY3AzGRneWjjSoTCabuQSKIzP+0LoHeiiwSBBpNoZ/d6pp22datuhK0
# eRzU00m5D/YMpHX6ObqiOPIncCsxggMNMIIDCQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAASTLzQKhF3BcmgAAAAABJDANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCBVP+vOPcoY2KCY8hNNt/o19xuAAPCaDNfoALg1thytRDCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EIGI44eiiGov5ftdr/bmOnXBOtDFiVgYuzOKz+cBO
# KuMgMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAEk
# y80CoRdwXJoAAAAAASQwIgQgPcE2ASaCDOEFWeWuGJY8sirs3yi+Cs5b+S9ZNnFr
# 2uEwDQYJKoZIhvcNAQELBQAEggEAFV6s05VtNBJvithBnASzzVc/R6oHtjDAUOV3
# U+aR97hQJpwlDR8X3QrCm7mS+x2vLoNffukmSuVURRfuUa6PdRjnLqOjLuIay8MV
# JAm9JuxAC7aF1J4rA/qzd2sH9dcUHCTls3d1z3AQhfc1M586ba0bEl4Xskp6PMQ/
# mg8UHy9L0TUi73EBifQBxfkiMyJoGIXSgdeceAp7Dmhk3jjV1OxDXjmo99zEAKxI
# JMAsuQNEGfDL69cs0MmJSdwBr6UBN0bDu0l/HKoM/y/tCDM6RNHYWA5lxpwJ3Te1
# kj973R7N7WBCQLohn0yqRRunmDNqFsbo6XcWeY171Fp0+5H/7g==
# SIG # End signature block
