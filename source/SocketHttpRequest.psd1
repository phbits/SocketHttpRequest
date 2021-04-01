
@{

RootModule = 'Source\SocketHttpRequest.psm1'

ModuleVersion = '1.0'

GUID = '7c101bd9-c55e-4192-a101-5ccdaa51c79e'

Author = 'phbits'

CompanyName = 'phbits'

Copyright = '(c) 2019 phbits. All rights reserved.'

Description = 'Submits HTTP requests using sockets. Does NOT perform certificate validation.'

PowerShellVersion = '5.1'

FunctionsToExport = 'Invoke-SocketHttpRequest'

PrivateData = @{

    PSData = @{

        Tags = 'Sockets','HTTP','HTTPS','SSL','TLS','Testing'

        LicenseUri = 'https://github.com/phbits/SocketHttpRequest/blob/master/LICENSE'

        ProjectUri = 'https://github.com/phbits/SocketHttpRequest'

    } # End of PSData hashtable

} # End of PrivateData hashtable

}
