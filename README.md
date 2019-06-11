# SocketHttpRequest #

Submits HTTP requests using sockets. Does NOT perform certificate validation.

## DESCRIPTION ##
    
Submits provided HTTP request to the target IP/FQDN.

No need to update local HOSTS file or modify DNS since connections are made directly to the IP.
    
Useful for testing individual systems that are part of a loadbalanced pool or newly implemented settings such as redirects and security controls.

Does NOT perform certificate validation allowing it to work against self-signed (untrusted) certificates.

Much is from Send-HttpRequest.ps1 in Windows PowerShell Cookbook (O'Reilly) by Lee Holmes (http://www.leeholmes.com/guide)

## PARAMETERS ##

### IP ###

IP address or FQDN of remote target. FQDN must be resolvable.

### Port ###

Destination port to connect to.
        
### HttpRequest ###

HTTP request to send. Below are the two most common methods.

```powershell
$Option1 = "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n"
        
$Option2 = @'
GET / HTTP/1.0
HOST: www.website.com

'@
```
### UseTLS ###

Enable if the destination port uses SSL/TLS.

### FullResponse ###

If enabled, the HTTP response body will be included in the results with empty lines removed.
        
### TlsVersion ###

If using SSL/TLS, specify the version.

Default = tls12

Available options: ssl2, ssl3, tls, tls11, tls12, tls13

REF: https://docs.microsoft.com/en-us/dotnet/api/system.security.authentication.sslprotocols

### IncludeCertificate ###

When enabled, will store the SSL/TLS certificate in the response Hashtable.

### Wait ###

Milliseconds to wait after submitting HTTP request. Consider increasing for high latency requests.

Default = 200

## OUTPUT ##

System.Collections.Hashtable

```
    +---Settings
    |   +---IP
    |   +---Port
    |   +---UseTls
    |   +---FullResponse
    |   +---TlsVersion
    |   +---IncludeCertificate
    |   +---Wait
    +---TimeStamp
    +---Request
    +---Response
    |   +---Certificate
    |   +---Body
    |   +---Headers
    +---StatusCode (parsed from response header)
    |       0   = Initialized
    |       999 = Exception
    +---Exception (present on error StatusCode=999)
```

## EXAMPLES ##

```powershell
Invoke-SocketHttpRequest -IP 10.1.1.1 -Port 80 -HttpRequest "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n"
```

```powershell
Invoke-SocketHttpRequest -IP 10.1.1.1 -Port 443 -HttpRequest "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n" -UseTLS -IncludeCertificate
```

```powershell
$Servers = '10.1.1.1','10.1.1.2','10.1.1.3'
$Results = @()
$Servers | %{ $Results += Invoke-SocketHttpRequest -IP $_ -Port 443 -HttpRequest "GET / HTTP/1.0`r`nHOST: www.website.com`r`n`r`n" -UseTLS -IncludeCertificate }
```

```powershell
$Servers = '10.1.1.1','10.1.1.2','10.1.1.3'
$HttpRequest = @'
GET / HTTP/1.0
HOST: www.website.com

'@
$Results = @()
$Servers | %{ $Results += Invoke-SocketHttpRequest -IP $_ -Port 443 -HttpRequest $HttpRequest -UseTLS -IncludeCertificate }
```

## LINK ##

https://github.com/phbits/SocketHttpRequest
