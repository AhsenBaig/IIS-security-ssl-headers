<#
.SYNOPSIS
# Sets IIS Security headers and TLS

.DESCRIPTION
Sets IIS Security headers and TLS. Also, takes basic backups before applying them.

.NOTES
Review the code and update sections according to your environment.
.LINK
https://github.com/AhsenBaig/IIS-security-ssl-headers

#>

$preHeaders = 'preHeaders_'
$defaultSite = 'Default Site' # Rename this to the default IIS site to apply to.

$backupsFolder = ".\_Backups" # Backup the registry file from IISCryptoCli.

$appsNConfigPath = ".\AppsNConfig" # Contains the IISCryptoCli and the Strict policy

$headerLine = "========================================"
$fileDate = Get-Date -Format 'MM.dd.yyyy-HH_mm'
$fileName = ${preHeaders} + ${fileDate}
Write-Host ${headerLine}
Write-Host "App file to create: ${fileName}"
Write-Host ${headerLine}

$PSPath =  'MACHINE/WEBROOT/APPHOST/' + $defaultSite
$Filter = 'system.webServer/httpProtocol/customHeaders'

# Ensure working with IIS 7 and 7.5(+?)
try {
    If ( ! (Get-module WebAdministration )) {
	    Install-Module WebAdministration -Force
    }    
} 
catch {
    try {
        Import-Module WebAdministration
    } 
    catch {
        Write-Warning "We failed to load the WebAdministration module. This usually resolved by doing one of the following:"
        Write-Warning "1. Install .NET Framework 3.5.1"
        Write-Warning "2. Upgrade to PowerShell 3.0 (or greater)"
        throw ($error | Select-Object -First 1)
    }
} 

Write-Host ${headerLine}
Write-Host "Backup WebConfiguration"
Write-Host ${headerLine}
Backup-WebConfiguration -Name ${fileName}

function CreateHeader {
    param (
        # header
        [String] $headerName,
        # header value
        [String] $headerValue)
    # First check if the header exists
    $customHeadersCollection = Get-WebConfiguration -Filter $Filter -PSPath $PSPath
    $exists = $false
    foreach($path in $customHeadersCollection.GetCollection()){
        if ($path.GetAttributeValue("name") -eq $headerName){
            Write-Host "Header $headerName already exists"
            $exists = $true
            break
        }
    }

    # Delete the header if it exists..
    if ($exists){
        Write-Host "Existing $headerName found (skipping)."
        # remove causes issues atm.
        #Write-Host Remove-WebConfigurationProperty -PSPath $PSPath -Name . -Filter $Filter -AtElement @{name =$headerName }
        
    } else {
        Write-Host "Adding header $headerName with value $headerValue"
        Add-WebConfigurationProperty -pspath $PSPath -filter $Filter -name . -AtElement @{name=$headerName; value=$headerValue}
    }
}

# Add the new header
# NOTES: 
# Change to your domain: https://<yourdomain>
# Uses ';--have i been pwned? api integration.
$headerName = "Content-Security-Policy"               
$HeaderValue = "default-src 'none'; font-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com; connect-src 'self' https://api.pwnedpasswords.com; img-src 'self' https://<yourdomain> data:; style-src 'self' 'unsafe-inline'; base-uri 'self'; form-action https: http:"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

$headerName = "Permissions-Policy"
$headerValue = "camera=(), geolocation=(), microphone=()"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

$headerName = "Referrer-Policy"
$headerValue = "strict-origin-when-cross-origin"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

$HeaderName = "Strict-Transport-Security"
$HeaderValue = "max-age=31536000; includeSubDomains"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

$HeaderName = "X-Content-Type-Options"
$HeaderValue = "nosniff"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

$HeaderName = "X-Frame-Options"
$HeaderValue = "DENY"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

$HeaderName = "X-XSS-Protection"
$HeaderValue = "1; mode=block"
CreateHeader -headerName ${headerName} -headerValue ${headerValue}

Write-Host ${headerLine}
Write-Host "Configure Strict SSL"
Write-Host ${headerLine}
Invoke-Expression ".\${appsNConfigPath}\IISCryptoCli.exe /backup ${backupsFolder}\IIS_Crypto_${fileDate}.reg /template .\${appsNConfigPath}\Our_Strict.ictpl" # /reboot

Write-Host ${headerLine}
Write-Host "NOTE: We must restart computer for SSL policies to take effect"
Write-Host ${headerLine}

restart-computer -Confirm
