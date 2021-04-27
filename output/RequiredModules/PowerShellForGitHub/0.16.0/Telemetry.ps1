# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

# Singleton. Don't directly access this though....always get it
# by calling Get-BaseTelemetryEvent to ensure that it has been initialized and that you're always
# getting a fresh copy.
$script:GHBaseTelemetryEvent = $null

function Get-PiiSafeString
{
<#
    .SYNOPSIS
        If PII protection is enabled, returns back an SHA512-hashed value for the specified string,
        otherwise returns back the original string, untouched.

    .SYNOPSIS
        If PII protection is enabled, returns back an SHA512-hashed value for the specified string,
        otherwise returns back the original string, untouched.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER PlainText
        The plain text that contains PII that may need to be protected.

    .EXAMPLE
        Get-PiiSafeString -PlainText "Hello World"

        Returns back the string "B10A8DB164E0754105B7A99BE72E3FE5" which represents
        the SHA512 hash of "Hello World", but only if the "DisablePiiProtection" configuration
        value is $false.  If it's $true, "Hello World" will be returned.

    .OUTPUTS
        System.String - A SHA512 hash of PlainText will be returned if the "DisablePiiProtection"
                        configuration value is $false, otherwise PlainText will be returned untouched.
#>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $PlainText
    )

    if (Get-GitHubConfiguration -Name DisablePiiProtection)
    {
        return $PlainText
    }
    else
    {
        return (Get-SHA512Hash -PlainText $PlainText)
    }
}

function Get-BaseTelemetryEvent
{
    <#
    .SYNOPSIS
        Returns back the base object for an Application Insights telemetry event.

    .DESCRIPTION
        Returns back the base object for an Application Insights telemetry event.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .EXAMPLE
        Get-BaseTelemetryEvent

        Returns back a base telemetry event, populated with the minimum properties necessary
        to correctly report up to this project's telemetry.  Callers can then add on to the
        event as nececessary.

    .OUTPUTS
        [PSCustomObject]
#>
    [CmdletBinding()]
    param()

    if ($null -eq $script:GHBaseTelemetryEvent)
    {
        if (-not (Get-GitHubConfiguration -Name SuppressTelemetryReminder))
        {
            Write-Log -Message 'Telemetry is currently enabled.  It can be disabled by calling "Set-GitHubConfiguration -DisableTelemetry". Refer to USAGE.md#telemetry for more information. Stop seeing this message in the future by calling "Set-GitHubConfiguration -SuppressTelemetryReminder".'
        }

        $username = Get-PiiSafeString -PlainText $env:USERNAME

        $script:GHBaseTelemetryEvent = [PSCustomObject] @{
            'name' = 'Microsoft.ApplicationInsights.66d83c523070489b886b09860e05e78a.Event'
            'time' = (Get-Date).ToUniversalTime().ToString("O")
            'iKey' = (Get-GitHubConfiguration -Name ApplicationInsightsKey)
            'tags' = [PSCustomObject] @{
                'ai.user.id' = $username
                'ai.session.id' = [System.GUID]::NewGuid().ToString()
                'ai.application.ver' = $MyInvocation.MyCommand.Module.Version.ToString()
                'ai.internal.sdkVersion' = '2.0.1.33027' # The version this schema was based off of.
            }

            'data' = [PSCustomObject] @{
                'baseType' = 'EventData'
                'baseData' = [PSCustomObject] @{
                    'ver' = 2
                    'properties' = [PSCustomObject] @{
                        'DayOfWeek' = (Get-Date).DayOfWeek.ToString()
                        'Username' = $username
                    }
                }
            }
        }
    }

    return $script:GHBaseTelemetryEvent.PSObject.Copy() # Get a new instance, not a reference
}

function Invoke-SendTelemetryEvent
{
<#
    .SYNOPSIS
        Sends an event to Application Insights directly using its REST API.

    .DESCRIPTION
        Sends an event to Application Insights directly using its REST API.

        A very heavy wrapper around Invoke-WebRequest that understands Application Insights and
        how to perform its requests with and without console status updates.  It also
        understands how to parse and handle errors from the REST calls.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER TelemetryEvent
        The raw object representing the event data to send to Application Insights.

    .OUTPUTS
        [PSCustomObject] - The result of the REST operation, in whatever form it comes in.

    .NOTES
        This mirrors Invoke-GHRestMethod extensively, however the error handling is slightly
        different.  There wasn't a clear way to refactor the code to make both of these
        Invoke-* methods share a common base code.  Leaving this as-is to make this file
        easier to share out with other PowerShell projects.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "", Justification="We use global variables sparingly and intentionally for module configuration, and employ a consistent naming convention.")]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject] $TelemetryEvent
    )

    $jsonConversionDepth = 20 # Seems like it should be more than sufficient
    $uri = 'https://dc.services.visualstudio.com/v2/track'
    $method = 'POST'
    $headers = @{'Content-Type' = 'application/json; charset=UTF-8'}

    $body = ConvertTo-Json -InputObject $TelemetryEvent -Depth $jsonConversionDepth -Compress
    $bodyAsBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    try
    {
        Write-Log -Message "Sending telemetry event data to $uri [Timeout = $(Get-GitHubConfiguration -Name WebRequestTimeoutSec))]" -Level Verbose

        $params = @{}
        $params.Add("Uri", $uri)
        $params.Add("Method", $method)
        $params.Add("Headers", $headers)
        $params.Add("UseDefaultCredentials", $true)
        $params.Add("UseBasicParsing", $true)
        $params.Add("TimeoutSec", (Get-GitHubConfiguration -Name WebRequestTimeoutSec))
        $params.Add("Body", $bodyAsBytes)

        # Disable Progress Bar in function scope during Invoke-WebRequest
        $ProgressPreference = 'SilentlyContinue'

        return Invoke-WebRequest @params
    }
    catch
    {
        $ex = $null
        $message = $null
        $statusCode = $null
        $statusDescription = $null
        $innerMessage = $null
        $rawContent = $null

        if ($_.Exception -is [System.Net.WebException])
        {
            $ex = $_.Exception
            $message = $_.Exception.Message
            $statusCode = $ex.Response.StatusCode.value__ # Note that value__ is not a typo.
            $statusDescription = $ex.Response.StatusDescription
            $innerMessage = $_.ErrorDetails.Message
            try
            {
                $rawContent = Get-HttpWebResponseContent -WebResponse $ex.Response
            }
            catch
            {
                Write-Log -Message "Unable to retrieve the raw HTTP Web Response:" -Exception $_ -Level Warning
            }
        }
        else
        {
            Write-Log -Exception $_ -Level Error
            throw
        }

        $output = @()
        $output += $message

        if (-not [string]::IsNullOrEmpty($statusCode))
        {
            $output += "$statusCode | $($statusDescription.Trim())"
        }

        if (-not [string]::IsNullOrEmpty($innerMessage))
        {
            try
            {
                $innerMessageJson = ($innerMessage | ConvertFrom-Json)
                if ($innerMessageJson -is [String])
                {
                    $output += $innerMessageJson.Trim()
                }
                elseif (-not [String]::IsNullOrWhiteSpace($innerMessageJson.itemsReceived))
                {
                    $output += "Items Received: $($innerMessageJson.itemsReceived)"
                    $output += "Items Accepted: $($innerMessageJson.itemsAccepted)"
                    if ($innerMessageJson.errors.Count -gt 0)
                    {
                        $output += "Errors:"
                        $output += ($innerMessageJson.errors | Format-Table | Out-String)
                    }
                }
                else
                {
                    # In this case, it's probably not a normal message from the API
                    $output += ($innerMessageJson | Out-String)
                }
            }
            catch [System.ArgumentException]
            {
                # Will be thrown if $innerMessage isn't JSON content
                $output += $innerMessage.Trim()
            }
        }

        # It's possible that the API returned JSON content in its error response.
        if (-not [String]::IsNullOrWhiteSpace($rawContent))
        {
            $output += $rawContent
        }

        $output += "Original body: $body"
        $newLineOutput = ($output -join [Environment]::NewLine)
        Write-Log -Message $newLineOutput -Level Error
        throw $newLineOutput
    }
}

function Set-TelemetryEvent
{
<#
    .SYNOPSIS
        Posts a new telemetry event for this module to the configured Applications Insights instance.

    .DESCRIPTION
        Posts a new telemetry event for this module to the configured Applications Insights instance.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER EventName
        The name of the event that has occurred.

    .PARAMETER Properties
        A collection of name/value pairs (string/string) that should be associated with this event.

    .PARAMETER Metrics
        A collection of name/value pair metrics (string/double) that should be associated with
        this event.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1"

        Posts a "zFooTest1" event with the default set of properties and metrics.

    .EXAMPLE
        Set-TelemetryEvent "zFooTest1" @{"Prop1" = "Value1"}

        Posts a "zFooTest1" event with the default set of properties and metrics along with an
        additional property named "Prop1" with a value of "Value1".

    .NOTES
        Because of the short-running nature of this module, we always "flush" the events as soon
        as they have been posted to ensure that they make it to Application Insights.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification='Function is not state changing')]
    param(
        [Parameter(Mandatory)]
        [string] $EventName,

        [hashtable] $Properties = @{},

        [hashtable] $Metrics = @{}
    )

    if (Get-GitHubConfiguration -Name DisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via configuration. Skipping reporting event [$EventName]." -Level Verbose
        return
    }

    Write-InvocationLog -ExcludeParameter @('Properties', 'Metrics')

    try
    {
        $telemetryEvent = Get-BaseTelemetryEvent

        Add-Member -InputObject $telemetryEvent.data.baseData -Name 'name' -Value $EventName -MemberType NoteProperty -Force

        # Properties
        foreach ($property in $Properties.GetEnumerator())
        {
            Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name $property.Key -Value $property.Value -MemberType NoteProperty -Force
        }

        # Measurements
        if ($Metrics.Count -gt 0)
        {
            $measurements = @{}
            foreach ($metric in $Metrics.GetEnumerator())
            {
                $measurements[$metric.Key] = $metric.Value
            }

            Add-Member -InputObject $telemetryEvent.data.baseData -Name 'measurements' -Value ([PSCustomObject] $measurements) -MemberType NoteProperty -Force
        }

        $null = Invoke-SendTelemetryEvent -TelemetryEvent $telemetryEvent
    }
    catch
    {
        Write-Log -Level Warning -Message @(
            "Encountered a problem while trying to record telemetry events.",
            "This is non-fatal, but it would be helpful if you could report this problem",
            "to the PowerShellForGitHub team for further investigation:"
            "",
            $_.Exception)
    }
}

function Set-TelemetryException
{
<#
    .SYNOPSIS
        Posts a new telemetry event to the configured Application Insights instance indicating
        that an exception occurred in this this module.

    .DESCRIPTION
        Posts a new telemetry event to the configured Application Insights instance indicating
        that an exception occurred in this this module.

        The Git repo for this module can be found here: http://aka.ms/PowerShellForGitHub

    .PARAMETER Exception
        The exception that just occurred.

    .PARAMETER ErrorBucket
        A property to be added to the Exception being logged to make it easier to filter to
        exceptions resulting from similar scenarios.

    .PARAMETER Properties
        Additional properties that the caller may wish to be associated with this exception.

    .PARAMETER NoFlush
        It's not recommended to use this unless the exception is coming from Flush-TelemetryClient.
        By default, every time a new exception is logged, the telemetry client will be flushed
        to ensure that the event is published to the Application Insights.  Use of this switch
        prevents that automatic flushing (helpful in the scenario where the exception occurred
        when trying to do the actual Flush).

    .EXAMPLE
        Set-TelemetryException $_

        Used within the context of a catch statement, this will post the exception that just
        occurred, along with a default set of properties.

    .NOTES
        Because of the short-running nature of this module, we always "flush" the events as soon
        as they have been posted to ensure that they make it to Application Insights.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification='Function is not state changing.')]
    param(
        [Parameter(Mandatory)]
        [System.Exception] $Exception,

        [string] $ErrorBucket,

        [hashtable] $Properties = @{}
    )

    if (Get-GitHubConfiguration -Name DisableTelemetry)
    {
        Write-Log -Message "Telemetry has been disabled via configuration. Skipping reporting exception." -Level Verbose
        return
    }

    Write-InvocationLog -ExcludeParameter @('Exception', 'Properties', 'NoFlush')

    try
    {
        $telemetryEvent = Get-BaseTelemetryEvent

        $telemetryEvent.data.baseType = 'ExceptionData'
        Add-Member -InputObject $telemetryEvent.data.baseData -Name 'handledAt' -Value 'UserCode' -MemberType NoteProperty -Force

        # Properties
        if (-not [String]::IsNullOrWhiteSpace($ErrorBucket))
        {
            Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name 'ErrorBucket' -Value $ErrorBucket -MemberType NoteProperty -Force
        }

        Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name 'Message' -Value $Exception.Message -MemberType NoteProperty -Force
        Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name 'HResult' -Value ("0x{0}" -f [Convert]::ToString($Exception.HResult, 16)) -MemberType NoteProperty -Force
        foreach ($property in $Properties.GetEnumerator())
        {
            Add-Member -InputObject $telemetryEvent.data.baseData.properties -Name $property.Key -Value $property.Value -MemberType NoteProperty -Force
        }

        # Re-create the stack.  We'll start with what's in Invocation Info since it's already
        # been broken down for us (although it doesn't supply the method name).
        $parsedStack = @(
            [PSCustomObject] @{
                'assembly' = $MyInvocation.MyCommand.Module.Name
                'method' = '<unknown>'
                'fileName' = $Exception.ErrorRecord.InvocationInfo.ScriptName
                'level' = 0
                'line' = $Exception.ErrorRecord.InvocationInfo.ScriptLineNumber
            }
        )

        # And then we'll try to parse ErrorRecord's ScriptStackTrace and make this as useful
        # as possible.
        $stackFrames = $Exception.ErrorRecord.ScriptStackTrace -split [Environment]::NewLine
        for ($i = 0; $i -lt $stackFrames.Count; $i++)
        {
            $frame = $stackFrames[$i]
            if ($frame -match '^at (.+), (.+): line (\d+)$')
            {
                $parsedStack +=  [PSCustomObject] @{
                    'assembly' = $MyInvocation.MyCommand.Module.Name
                    'method' = $Matches[1]
                    'fileName' = $Matches[2]
                    'level' = $i + 1
                    'line' = $Matches[3]
                }
            }
        }

        # Finally, we'll build up the Exception data object.
        $exceptionData = [PSCustomObject] @{
            'id' = (Get-Date).ToFileTime()
            'typeName' = $Exception.GetType().FullName
            'message' = $Exception.Message
            'hasFullStack' = $true
            'parsedStack' = $parsedStack
        }

        Add-Member -InputObject $telemetryEvent.data.baseData -Name 'exceptions' -Value @($exceptionData) -MemberType NoteProperty -Force
        $null = Invoke-SendTelemetryEvent -TelemetryEvent $telemetryEvent
    }
    catch
    {
        Write-Log -Level Warning -Message @(
            "Encountered a problem while trying to record telemetry events.",
            "This is non-fatal, but it would be helpful if you could report this problem",
            "to the PowerShellForGitHub team for further investigation:",
            "",
            $_.Exception)
    }
}

# SIG # Begin signature block
# MIIjkQYJKoZIhvcNAQcCoIIjgjCCI34CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCZ6BQ5vy0BRqCR
# s8h6PjO76x9Z3LOy9oFRF4zOhYAdGaCCDYEwggX/MIID56ADAgECAhMzAAABh3IX
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgmaqhvAVP
# t4EkASKIZiC7bOaG0jOLykqd8fAUx/COhkEwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBvZB60iLol0oZiCE0r4VG8LGIQCmQbWWQUwhHXbOYh
# f2sPEUxK/Z+GsATYtVjSJv3jrwQ8NjQvegys6Z/BA9051P1KKwuMjo6XYykiGjSE
# KRSLfmFzk3lo5hGKdP4XpACDbGs+CKhnqHou+tlAVBd69Z26aHU/zIUXY88yhsZ8
# SJgLWzWKzzHSK5as9UnemusIB1gzB2orhf1hfTIVcnt9MKJwxF/2ZYJMk3Jz6PG9
# ENg0yhs1FBEvEvrKryts3nkI188C4nVhuHEtpADIMSK0PXjrapfySn2o/evcHbPN
# PbODFj4MdEpQ5co8ieLfY0cxZ7/lHaRTO+Z0gurcFb0noYIS8DCCEuwGCisGAQQB
# gjcDAwExghLcMIIS2AYJKoZIhvcNAQcCoIISyTCCEsUCAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIFFiR14sa+C0n44xWFs2KLZECD89VB3YaRDY+hnt
# 0l0RAgZf25dxFMYYEjIwMjEwMTA1MTk1MTU0LjQyWjAEgAIB9KCB1KSB0TCBzjEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEpMCcGA1UECxMgTWlj
# cm9zb2Z0IE9wZXJhdGlvbnMgUHVlcnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOkQ5REUtRTM5QS00M0ZFMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloIIORDCCBPUwggPdoAMCAQICEzMAAAEtLk1BymNlM6AAAAAA
# AS0wDQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAw
# HhcNMTkxMjE5MDExNTA0WhcNMjEwMzE3MDExNTA0WjCBzjELMAkGA1UEBhMCVVMx
# EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoT
# FU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEpMCcGA1UECxMgTWljcm9zb2Z0IE9wZXJh
# dGlvbnMgUHVlcnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkQ5REUt
# RTM5QS00M0ZFMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2aWNl
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqWGN9HVJOphFNLezSLiM
# hxIxX4bg3ShiDCVAr6mXgNUwWavWJNkcUuPdO3tXoX4z8FfHSH2LS67XIGeoKo06
# S4kRFNtWczi7cm9HHOxB8KMF+oP8I3Cgw16SjKUgHPE/nRKSOnWk+ydAEodoI/y2
# C69hXOhNDnirZWlgQ//45hNB4Q+pYWLxaCC+xyS56txQaSFhYzwNX/glTs3+tsOu
# 1qZht7wu2RWJNBhuKBRIICiv0OG0Bm+rwDQDvdcUfZ1/bAOUu0CcoJyxW9dKZnfl
# sCqd43i4RBXLw1B1F4YjW0jpTGgLteeMa8rgxwN0qFq80nsMCdI/n4b8NOR1YP6U
# 3wIDAQABo4IBGzCCARcwHQYDVR0OBBYEFNlsZHxCASH4Tg6K/y9DvjTynYbNMB8G
# A1UdIwQYMBaAFNVjOlyKMZDzQ3t8RhvFM2hahW1VMFYGA1UdHwRPME0wS6BJoEeG
# RWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Rp
# bVN0YVBDQV8yMDEwLTA3LTAxLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUH
# MAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljVGltU3Rh
# UENBXzIwMTAtMDctMDEuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwDQYJKoZIhvcNAQELBQADggEBAH1rA2T3Tqt5wG6g7sTOrsHxQa70SgVe
# IvxpzRtuxkMFj3P/enxq1VlELEc3jdrdYZsIxmgpjFIEfpQKRwNzBch80oRtUzOc
# XWaOlAQZuqFH6s82oddmi1JX6+fzkDGZ58Azdtwu35Y0GkS45lniQ9lVwW0yjhjJ
# CPGg1E+LCan4HQeSFCz+X9UiDRcljqTkVEoT8kURxVjjbno12pRn7eOi7dvg4CS0
# Ta6uvhXpVHDV9986XFlvwzK8Tmaq9NUk5K1XEK6G6qDWsh7yVrWBnmKK4jJZ5+04
# 18zDSdJlyEYuKAN4ifDpd/DCAWcLlCXw9t/aM7EJSW4BhvPKQj4ycGIwggZxMIIE
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
# ZXJhdGlvbnMgUHVlcnRvIFJpY28xJjAkBgNVBAsTHVRoYWxlcyBUU1MgRVNOOkQ5
# REUtRTM5QS00M0ZFMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBTZXJ2
# aWNloiMKAQEwBwYFKw4DAhoDFQCfzl/Hfod7sXS+CbJSXPbDzaXQsaCBgzCBgKR+
# MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMT
# HU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0GCSqGSIb3DQEBBQUAAgUA
# 458h7DAiGA8yMDIxMDEwNTIxMzU0MFoYDzIwMjEwMTA2MjEzNTQwWjB3MD0GCisG
# AQQBhFkKBAExLzAtMAoCBQDjnyHsAgEAMAoCAQACAi4hAgH/MAcCAQACAhENMAoC
# BQDjoHNsAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwKgCjAIAgEA
# AgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEATA3Oz+WE1OTGeNAT
# Rw//Vs0wXCa7wlM+JzP+/mrIT09cyywcSklETut/brqKkC9aNHp1G1TsbJQAZLbT
# tK3vi2Qm31HXR/1H9GRXks0hM388ULkoIhR78cgSEt6CSl7Zl5wsZ8+QOfEhYfFz
# ZCUE4i5CzODp/Kua88z9Wddv9egxggMNMIIDCQIBATCBkzB8MQswCQYDVQQGEwJV
# UzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UE
# ChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGlt
# ZS1TdGFtcCBQQ0EgMjAxMAITMwAAAS0uTUHKY2UzoAAAAAABLTANBglghkgBZQME
# AgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMC8GCSqGSIb3DQEJ
# BDEiBCDbgNxgKsJ5xBV3Ok++AwDLBdBAwulBibVFWsFEAmmY9TCB+gYLKoZIhvcN
# AQkQAi8xgeowgecwgeQwgb0EII7xWnJyfSAHj+KVEA88NtL4KZuqP+4LTXWahzmh
# 4YPBMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24x
# EDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlv
# bjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAEt
# Lk1BymNlM6AAAAAAAS0wIgQgoLAuV6ovPrNJwN+M8vuE7zeatV7WKG9pR7bcJam1
# XtEwDQYJKoZIhvcNAQELBQAEggEABxT0/GtjKYpBdWgRO60imcHV41h8k+T0d/Zi
# gsk2d/H2QwkGETeFMUWkbyzNTTvMDTpmPz13Zx15+SQsqgkLyDQlNj6FSBhJxEXH
# P0edXoJDAR7Vq6+Ob5iNyKCwpJyjlSh7eewHEhxFzqy6xyk5OCW48NrW0rFpT0OB
# JtUQhPIVZKqepEvUdWlZizB72NJoKnT1kcl0NJlHIkX9uiQtzlX6NvjXpiu2XjCx
# D3hHp2+AtPxnKQ6LDigJOhtX/C/YUXlmssSZ+ciffanqCcxVrxS3MfQELgs1My6g
# 97pOHwKgf8IcFhxe4SbY9crSJzL1ahGfUNO+YwtwiQZPtzx2nA==
# SIG # End signature block
