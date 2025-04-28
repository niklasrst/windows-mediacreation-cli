<#
.SYNOPSIS
   A CLI to create Windows Installation media with different versions of Windows.

.DESCRIPTION
   xxx

.PARAMETER -Version
    The version of Windows to download. Valid values are 10 or 11.
    The default is 11.

.PARAMETER -Architecture
    The architecture of Windows to download. Valid values are x64, x86 or arm64.
    The default is x64.

.PARAMETER -Build
    The build number of Windows to download. Valid values are 22621, 22631, 22641, 22651, 22661, 22671, 22681, 22691, 22701, 22711, 22721, 22731, 22741, 22751, 22761, 22771, 22781, 22791.
    The default is the 00000 build.

.PARAMETER -LanguageCode
    The language code of Windows to download. Valid values are en-us, de-de, fr-fr, es-es, it-it, nl-nl, pl-pl, pt-pt, ru-ru, tr-tr, zh-cn, zh-tw.
    The default is en-us.

.PARAMETER -Edition
        The edition of Windows to download. Valid values are CLIENTCONSUMER_RET or CLIENTBUSINESS_VOL.
        The default is CLIENTBUSINESS_VOL.

.PARAMETER -UsbDriveLetter
    The drive letter of the USB drive to create the bootable media.
    For example "E:".

.PARAMETER -Verbose
   Enable verbose output.

.EXAMPLE
    .\wmccli.ps1 -Version 11 -Architecture x64 -Build 22621 -LanguageCode en-us -Edition CLIENTBUSINESS_VOL -UsbDriveLetter E:
    This example downloads the Windows 11 x64 ESD file with build number 22621 in English (US) for the CLIENTBUSINESS_VOL edition and creates a bootable media on the drive E:.

.OUTPUTS
    ---

.NOTES
    Use this script to create a Windows Installation media from PowerShell.

.LINK
    https://github.com/niklasrst/windows-mediacreation-cli

.AUTHOR
    Niklas Rast
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)]
    [ValidateSet("10", "11")]
    [String]$Version = 11,
    [Parameter(Mandatory = $True)]
    [ValidateSet("x64", "x86", "arm64")]
    [String]$Architecture = "x64",
    [Parameter(Mandatory = $True)]
    [ValidateSet("10-21H1", "10-21H2", "10-22H2", "10-23H2", "11-21H2", "11-22H2", "11-23H2", "11-24H2")]
    [String]$Build = "11-24H2",
    [Parameter(Mandatory = $True)]
    [String]$LanguageCode = "en-us",
    [Parameter(Mandatory = $True)]
    [ValidateSet("CLIENTCONSUMER_RET", "CLIENTBUSINESS_VOL")]
    [String]$Edition = "CLIENTBUSINESS_VOL",
    [Parameter(Mandatory = $True)]
    [String]$UsbDriveLetter = "E:"
)

# Settings
$scriptTempDir = "$env:temp\wmccli"
if (-not (Test-Path -Path $scriptTempDir)) {
    New-Item -ItemType Directory -Path $scriptTempDir | Out-Null
}

switch ($Build){
    "10-21H1" { $Build = "19043" }
    "10-21H2" { $Build = "19044" }
    "10-22H2" { $Build = "19045" }
    "10-23H2" { $Build = "19046" }
    "11-21H2" { $Build = "22000" }
    "11-22H2" { $Build = "22621" }
    "11-23H2" { $Build = "22631" }
    "11-24H2" { $Build = "26100" }
    default { $Build = "26100"}
}

switch ($Architecture) {
    "x64" {
        Write-Verbose "Converting x64 to x64"
        $Architecture = "x64" }
    "x86" {
        Write-Verbose "Converting x86 to x86"
        $Architecture = "x86" }
    "arm64" {
        Write-Verbose "Converting arm64 to A64"
        $Architecture = "A64" }
    Default { 
        Write-Error "Missing or invalid architecture. Please use x64, x86 or arm64."
        exit 1
    }
}

# Download Manifests
$windowsManifests = @(
    @{ Name = "Windows10"; Version = "https://go.microsoft.com/fwlink/?LinkId=841361" },
    @{ Name = "Windows11"; Version = "https://go.microsoft.com/fwlink/?LinkId=2156292" }
)

foreach ($manifest in $windowsManifests) {
    $fileName = "$scriptTempDir\$($manifest.Name).cab"
    Write-Verbose "Downloading $($manifest.Name) from $($manifest.Version) to $fileName"
    Invoke-WebRequest -Uri $manifest.Version -OutFile $fileName -Verbose:$Verbose
    Write-Verbose "Extracting $($manifest.Name) to $scriptTempDir\$($manifest.Name)_products.xml"
    Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $fileName $scriptTempDir\$($manifest.Name)_products.xml" -NoNewWindow -Wait
    Write-Verbose "Removing temporary file $fileName"
    Remove-Item -Path $fileName -Force | Out-Null
}

# Construct URL and Download ESD file
$productsFile = "$scriptTempDir\Windows" + $($Version) + "_products.xml"
[xml]$productsXml = Get-Content -Path $productsFile
Write-Verbose "Parsing XML file $productsFile"

$esdUrl = ($productsXml.MCT.Catalogs.Catalog.FirstChild.Files.File.FilePath | Where-Object { $_ -match ".*http.*$Build.*$Edition.*$Architecture.*$LanguageCode.esd" } | Select-Object -First 1)
Write-Verbose "Found ESD URL: $esdUrl"

Write-Verbose "Downloading ESD file from $esdUrl to $scriptTempDir"
Invoke-WebRequest -Uri $esdUrl -OutFile "$scriptTempDir\windows.esd"

TODO: Format USB-Drive and Extract ESD file