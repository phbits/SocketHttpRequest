Function Invoke-SocketHttpRequest
{
    <#
    .SYNOPSIS
    
    Submits HTTP requests using sockets. Does NOT perform certificate validation.

    .DESCRIPTION
    
    Submits provided HTTP request to the target IP/FQDN. 

    No need to update local HOSTS file or modify DNS since connections are made directly to the IP.

    Does NOT perform certificate validation allowing it to work against self-signed (untrusted) certificates.

    Much is from Send-HttpRequest.ps1 in Windows PowerShell Cookbook (O'Reilly) by Lee Holmes (http://www.leeholmes.com/guide)

    .OUTPUT

    System.Collections.Hashtable

    .EXAMPLE
    
    Invoke-SocketHttpRequest -IP 10.1.1.1 -Port 80 -HttpRequest "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n"

    .EXAMPLE
    
    Invoke-SocketHttpRequest -IP 10.1.1.1 -Port 443 -HttpRequest "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n" -UseTLS -IncludeCertificate

    .EXAMPLE

    $Servers = '10.1.1.1','10.1.1.2','10.1.1.3'
    $Results = @()
    $Servers | %{ $Results += Invoke-SocketHttpRequest -IP $_ -Port 443 -HttpRequest "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n" -UseTLS -IncludeCertificate }

    .LINK
    https://github.com/phbits/SocketHttpRequest

    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Validate-IpParameter $_})]
        [System.String]
        # IP address or FQDN of remote target.
        $IP
        ,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,65535)]
        [System.Int32]
        # Destination port to connect to.
        $Port = 80
        ,
        [Parameter(Mandatory=$true)]
        [System.String]
        # HTTP request to send
        $HttpRequest
        ,
        [Parameter(Mandatory=$false)]
        [Switch]
        # Use SSL/TLS
        $UseTLS
        ,
        [Parameter(Mandatory=$false)]
        [Switch]
        # Includes HTTP response body.
        $FullResponse
        ,
        [Parameter(Mandatory=$false)]
        [ValidateSet('ssl2','ssl3','tls','tls11','tls12','tls13')]
        [System.String]
        # SSL/TLS Protocol to use.
        $TlsVersion = 'tls12'
        ,
        [Parameter(Mandatory=$false)]
        [Switch]
        # Stores SSL/TLS certificate with response.
        $IncludeCertificate
        ,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,10000)]
        [System.Int32]
        # Milliseconds to wait after submitting HTTP request.
        $Wait = 200
     )

    $Settings = @{ 'IP'                 = $IP;
                   'Port'               = $Port;
                   'UseTLS'             = $UseTLS;
                   'FullResponse'       = $FullResponse;
                   'TlsVersion'         = $TlsVersion;
                   'IncludeCertificate' = $IncludeCertificate;
                   'Wait'               = $Wait; }

    $Result =  @{ 'Settings'           = $Settings;
                  'TimeStamp'          = $(Get-Date);
                  'Request'            = $HttpRequest.Split([System.Environment]::NewLine,[StringSplitOptions]::RemoveEmptyEntries); 
                  'Response'           = @{}; 
                  'StatusCode'         = 0; }

    $Result.Response.Add('Headers',@())
    $Result.Response.Add('Body',@()) 

    $HttpResponse = ''

    $SslProtocols = @{ 'ssl1'  = [System.Security.Authentication.SslProtocols]::Ssl2;
                       'ssl3'  = [System.Security.Authentication.SslProtocols]::Ssl3;
                       'tls'   = [System.Security.Authentication.SslProtocols]::Tls;
                       'tls11' = [System.Security.Authentication.SslProtocols]::Tls11;
                       'tls12' = [System.Security.Authentication.SslProtocols]::Tls12;
                       'tls13' = [System.Security.Authentication.SslProtocols]::Tls13; }

    try {

        $TcpSocket = New-Object System.Net.Sockets.TcpClient($IP, $Port)

        $Stream = $TcpSocket.GetStream()
    
        if($UseTLS)
        {
            # https://isc.sans.edu/forums/diary/Assessing+Remote+Certificates+with+Powershell/20645/
            [ScriptBlock]$CallBack = { param($sender, $cert, $chain, $errors) return $true }

            $CertificateCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection

            $SslStream = New-Object System.Net.Security.SslStream($Stream, $false, $CallBack)

            $SslStream.AuthenticateAsClient($IP, $CertificateCollection, $SslProtocols[$TlsVersion], $false)

            if($IncludeCertificate -eq $true)
            {
                $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($SslStream.RemoteCertificate)

                $Result.Response.Add('Certificate', $Certificate)
            }

            $Stream = $SslStream
        }

        $HttpReqBytes = [System.Text.Encoding]::ASCII.GetBytes($HttpRequest)

        $Stream.Write($HttpReqBytes, 0, $HttpReqBytes.Length)

        $Stream.Flush()

        Start-Sleep -Milliseconds $Wait
    
        $buffer = New-Object System.Byte[] 2048
        $encoding = New-Object System.Text.AsciiEncoding
        $MoreData = $false

        do
        {
            $MoreData = $false
            $Stream.ReadTimeout = 1000

            do
            {
                try
                {
                    $read = $Stream.Read($buffer, 0, 2048)

                    if($read -gt 0)
                    {
                        $MoreData = $true

                        $HttpResponse += ($encoding.GetString($buffer, 0, $read))
                    }

                } catch { $MoreData = $false; $read = 0 }

            } while($read -gt 0)

        } while($MoreData)

    } catch {

        $e = $_

        $Result.StatusCode = 999

        $Result.Add('Exception', $e.Exception.Message)

        return $Result
    
    } finally {
   
        if($null -ne $Stream){ $Stream.Dispose() }

        if($null -ne $SslStream){ $SslStream.Dispose() }

        if($null -ne $TcpSocket){ $TcpSocket.Dispose() }    
    }
    
    if([System.String]::IsNullOrEmpty($HttpResponse) -eq $false)
    {
        $ReadingHeader = $true

        $HttpResponseArray = $HttpResponse.Split([string[]]"`r`n", [StringSplitOptions]::None)

        for($i=0; $i -lt $HttpResponseArray.Count; $i++)
        {
            $line = $HttpResponseArray[$i]

            if([System.String]::IsNullOrEmpty($line) -eq $false)
            {
                if($ReadingHeader -eq $true)
                {
                    $Result.Response.Headers += $line

                    if($line.Contains(':') -eq $false)
                    {
                        $StatusCode = [int]([regex]::Match($line, '[0-9]{3}')).value
    
                        $Result.StatusCode = $StatusCode
                    }

                } else {

                    if($FullResponse -eq $true)
                    {
                        $Result.Response.Body += $line
                
                    } else {

                        $i = $HttpResponseArray.Count
                    }
                }

            } else {

                $ReadingHeader = $false
            }                       
        }
    }

    return $Result

} # End Function Invoke-SocketHttpRequest

Function Validate-IpParameter
{
    <#
    .SYNOPSIS
    Validates IP input parameter as an IP address or DNS resolvable FQDN.

    .LINK
    https://mikefrobbins.com/2018/04/19/moving-parameter-validation-in-powershell-to-private-functions/
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.String]
        # IP address or FQDN of remote target.
        $IP
    )

    $IsIP = [regex]::Match($IP, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}')

    if($IsIP.Success -eq $true)
    {
        return $true
    
    } else {

        try {

            $Dns = Resolve-DnsName -Name $IP -ErrorAction Stop

            if($null -ne $dns)
            {
                return $true
            }
     
        } catch { }
    }

    return $false

} # End Function Validate-IpParameter
