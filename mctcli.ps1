<#
.SYNOPSIS
   A CLI to create Windows Installation media with different versions of Windows.

.DESCRIPTION
    This script downloads the Windows ESD file from Microsoft and creates a bootable USB drive with the selected version of Windows.

.PARAMETER -Architecture
    The architecture of Windows to download. Valid values are amd64 or arm64.
    The default is x64.

.PARAMETER -Build
    The build number of Windows to download. Valid values are "21H2", "22H2", "23H2", "24H2".
    The default is the 24H2 build.

.PARAMETER -LanguageCode
    The language code of Windows to download. Valid values for example are en-us, de-de, fr-fr, es-es, it-it.
    The default is en-us.

.PARAMETER -RegionCode
    The regional code of Windows to download. Valid values for example are en-us, de-de, fr-fr, es-es, it-it.
    The default is en-us and will be matched to LanuageCode. if not set.

.PARAMETER -Edition
        The edition of Windows to download. Valid values are "Home", "Pro", "Pro N", "Enterprise", "Enterprise N", "Education", "Education N"
        The default is Pro.

.PARAMETER -UsbDriveLetter
    The drive letter of the USB drive to create the bootable media.
    For example "E:".

.PARAMETER -DriverManufacturer
    The manufacturer of the drivers to download. Valid values are "Dell", "Lenovo", "HP".
    The default is not set.

.PARAMETER -DriverModel
    The model of the drivers to download. This is optional and will be used to filter the drivers from the manufacturer.
    For example "XPS 13" for Dell or "ThinkPad X1 Carbon" for Lenovo.

.PARAMETER -Verbose
   Enable verbose output.

.EXAMPLE
    .\mctcli.ps1 -Architecture amd64 -Build 24H2 -LanguageCode de-de -Edition Pro -UsbDriveLetter "E:" -Verbose
    This example downloads the Windows 11 x64 ESD file with build 24H2 in English (US) for the CLIENTBUSINESS_VOL edition and creates a bootable media on the drive D:.

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
    [ValidateSet("amd64", "arm64")]
    [String]$Architecture = "x64",
    [Parameter(Mandatory = $True)]
    [ValidateSet("21H2", "22H2", "23H2", "24H2")]
    [String]$Build = "24H2",
    [Parameter(Mandatory = $True)]
    [String]$LanguageCode = "en-us",
    [Parameter(Mandatory = $False)]
    [String]$RegionCode,
    [Parameter(Mandatory = $True)]
    [ValidateSet("Home", "Pro", "Pro N", "Enterprise", "Enterprise N", "Education", "Education N")]
    [String]$Edition = "Pro",
    [Parameter(Mandatory = $True)]
    [String]$UsbDriveLetter = "D:",
    [Parameter(Mandatory = $False)]
    [ValidateSet("Dell", "Lenovo", "HP")]
    [String]$DriverManufacturer,
    [Parameter(Mandatory = $False)]
    [String]$DriverModel
)

#Requires -RunAsAdministrator
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7 or higher. Please upgrade your PowerShell version."
    exit 1
}
if ((Test-NetConnection -ComputerName "www.microsoft.com" -Port 80).TcpTestSucceeded -ne $true) {
    Write-Error "Could not connect to Microsoft which is needed for the installation media. Please ensure connectivity to Microsoft.com and try again."
    exit 1
}
if ((Test-NetConnection -ComputerName "www.github.com" -Port 80).TcpTestSucceeded -ne $true) {
    Write-Error "Could not connect to Github which is needed for the UEFI drivers. Please ensure connectivity to Github.com and try again."
    exit 1
}
if ([int]((Get-PSDrive -PSProvider 'FileSystem' | Where-Object { $_.Root -eq "$($env:SystemDrive)\" }).Free / 1GB) -lt 10) {
    Write-Error "No enough disk space. Please ensure that at least 10GB of disk space are available and try again."
    exit 1
}

Write-Verbose "Parameters"
Write-Verbose "Architecture: $Architecture"
Write-Verbose "Build: $Build"
Write-Verbose "LanguageCode: $LanguageCode"
Write-Verbose "RegionCode: $RegionCode"
Write-Verbose "Edition: $Edition"
Write-Verbose "UsbDriveLetter: $UsbDriveLetter"
Write-Verbose "DriverManufacturer: $DriverManufacturer"
Write-Verbose "DriverModel: $DriverModel"
Write-Verbose "Working Directory: $env:temp\mctcli"
Write-Verbose "------------------------------------------------------"
Write-Verbose "Starting Windows Media Creation CLI"

# Variables
$IsoArchitecture = $null
$IsoEdition = $null
$BootloaderManufacturer = "Rufus"
$scriptTempDir = "$env:temp\mctcli"
$setupWimTempDir = "$env:temp\mctcli\setupwim"
$bootWimTempDir = "$env:temp\mctcli\bootwim"
$installWimTempDir = "$env:temp\mctcli\installwim"
if (-not (Test-Path -Path $scriptTempDir)) {
    New-Item -ItemType Directory -Path $scriptTempDir | Out-Null
    Write-Verbose "Created temporary directory $scriptTempDir..."
}
if (-not (Test-Path -Path $setupWimTempDir)) {
    New-Item -ItemType Directory -Path $setupWimTempDir | Out-Null
    Write-Verbose "Created temporary directory $setupWimTempDir..."
}
if (-not (Test-Path -Path $bootWimTempDir)) {
    New-Item -ItemType Directory -Path $bootWimTempDir | Out-Null
    Write-Verbose "Created temporary directory $bootWimTempDir..."
}
if (-not (Test-Path -Path $installWimTempDir)) {
    New-Item -ItemType Directory -Path $installWimTempDir | Out-Null
    Write-Verbose "Created temporary directory $installWimTempDir..."
}
if (-not (Test-Path -Path $UsbDriveLetter)) {
    Write-Error "The drive $UsbDriveLetter does not exist. Please check the drive letter and try again."
    exit 1
}
Set-Location $scriptTempDir

switch ($Edition){
    "Home" { $IsoEdition = "CLIENTCONSUMER_RET" }
    "Pro" { $IsoEdition = "CLIENTBUSINESS_VOL" }
    "ProN" { $IsoEdition = "CLIENTBUSINESS_VOL" }
    "Enterprise" { $IsoEdition = "CLIENTBUSINESS_VOL" }
    "EnterpriseN" { $IsoEdition = "CLIENTBUSINESS_VOL" }
    "Education" { $IsoEdition = "CLIENTBUSINESS_VOL" }
    "EducationN" { $IsoEdition = "CLIENTBUSINESS_VOL" }
}

Write-Verbose "Pulling $Edition from $IsoEdition..."

switch ($Build){
    "21H2" { $BuildVer = "22000" }
    "22H2" { $BuildVer = "22621" }
    "23H2" { $BuildVer = "22631" }
    "24H2" { $BuildVer = "26100" }
}
Write-Verbose "Build version converted to $BuildVer..."

switch ($Architecture) {
    "amd64" { $IsoArchitecture = "x64" }
    "arm64" { $IsoArchitecture = "A64" }
}
Write-Verbose "Architecture converted to $IsoArchitecture..."

if (-not $RegionCode -or [string]::IsNullOrWhiteSpace($RegionCode)) {
    $RegionCode = $LanguageCode
    Write-Verbose "RegionCode not specified. Defaulting RegionCode to LanguageCode: $RegionCode ..."
}

# Download Manifest
$Url = "https://go.microsoft.com/fwlink/?LinkId=2156292" 
Write-Verbose "Downloading Manifest from $($Url) to $scriptTempDir..."
Invoke-WebRequest -Uri $Url -OutFile "$scriptTempDir\manifest.cab"
Write-Verbose "Extracting Manifest to $scriptTempDir\manifest_products.xml..."
Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $scriptTempDir\manifest.cab $scriptTempDir\manifest_products.xml" -Wait | Out-Null
Write-Verbose "Removing temporary file $scriptTempDir\manifest.cab..."
Remove-Item -Path "$scriptTempDir\manifest.cab" -Force | Out-Null

# Build Download-URL for ESD file
$productsFile = "$scriptTempDir\manifest_products.xml"
[xml]$productsXml = Get-Content -Path $productsFile
Write-Verbose "Parsing XML file $productsFile..."

$esdUrl = ($productsXml.MCT.Catalogs.Catalog.FirstChild.Files.File.FilePath | Where-Object { $_ -match ".*http.*$BuildVer.*$IsoEdition.*$IsoArchitecture.*$LanguageCode.esd" } | Select-Object -First 1)
Write-Verbose "Found ESD URL: $esdUrl"

$esdVersion = ($Edition + "-" + $LanguageCode + "-" + $Build + "-" + $Architecture).Replace(" ","")
$installEsdFile = "$scriptTempDir\$($esdVersion).esd"
$bootWimFile = "$scriptTempDir\boot.wim"
$setupWimFile = "$scriptTempDir\setup.wim"
$installWimFile = "$scriptTempDir\install.wim"
if (Test-Path -Path $installEsdFile) {
    Write-Verbose "ESD file already exists. Skipping download..."
} else {
    try {
        Write-Verbose "Downloading ESD file from $esdUrl to $scriptTempDir..."
        Invoke-WebRequest -Uri $esdUrl -OutFile $installEsdFile
    }
    catch {
        Write-Error "Failed to download ESD file. Please check the connectivity and try again."
        exit 1
    }
}

# Extract setup.wim
Write-Verbose "Extracting setup from ESD to WIM format..."
if (-not (Test-Path -Path $setupWimFile)) {
    $installWimInfo = Dism.exe /Get-WimInfo /WimFile:$installEsdFile | Out-String
    $setupIndex = ($installWimInfo -split "`n" | ForEach-Object {
        if ($_ -match "Name\s*:\s*Windows Setup Media") {
            $previousLine = $previousLine -replace "Index\s*:\s*", ""
            return $previousLine
        }
        $previousLine = $_
    }) | Select-Object -First 1

    $setupIndex = [int32]$setupIndex

    Write-Verbose "Found setup.wim in index: $setupIndex. Exporting the image to WIM format..."
    Dism /Export-Image /SourceImageFile:$installEsdFile /SourceIndex:$setupIndex /DestinationImageFile:$setupWimFile /Compress:max /CheckIntegrity | Out-Null
} 

# Extract boot.wim
Write-Verbose "Extracting boot from ESD to WIM format..."
if (-not (Test-Path -Path $bootWimFile)) {
    $installWimInfo = Dism.exe /Get-WimInfo /WimFile:$installEsdFile | Out-String
    $bootIndex = ($installWimInfo -split "`n" | ForEach-Object {
        if ($_ -match "Name\s*:\s*Microsoft Windows Setup (.*$Architecture)") {
            $previousLine = $previousLine -replace "Index\s*:\s*", ""
            return $previousLine
        }
        $previousLine = $_
    }) | Select-Object -First 1

    $bootIndex = [int32]$bootIndex

    Write-Verbose "Found boot.wim in index: $bootIndex. Exporting the image to WIM format..."
    Dism /Export-Image /SourceImageFile:$installEsdFile /SourceIndex:$bootIndex /DestinationImageFile:$bootWimFile /Compress:max /CheckIntegrity | Out-Null
}

# Extract install.wim
Write-Verbose "Extracting install from ESD to WIM format..."
if (-not (Test-Path -Path $installWimFile)) {
    $installWimInfo = Dism.exe /Get-WimInfo /WimFile:$installEsdFile | Out-String
    $editionIndex = ($installWimInfo -split "`n" | ForEach-Object {
        if ($_ -match "Name\s*:\s*Windows.*$Edition") {
            $previousLine = $previousLine -replace "Index\s*:\s*", ""
            return $previousLine
        }
        $previousLine = $_
    }) | Select-Object -First 1

    $editionIndex = [int32]$editionIndex

    Write-Verbose "Found install.wim for $Edition in index: $editionIndex. Exporting the image to WIM format..."
    Dism /Export-Image /SourceImageFile:$installEsdFile /SourceIndex:$editionIndex /DestinationImageFile:$installWimFile /Compress:max /CheckIntegrity | Out-Null
} 

# Mount wim file(s)
Write-Verbose "Mounting setup.wim file..."
try {
    Mount-WindowsImage -ImagePath $setupWimFile -Path "$setupWimTempDir" -Index 1 | Out-Null
}
catch {
    Write-Warning "Mounting setup.wim failed. Please check the file and try again."
}

Write-Verbose "Mounting install.wim file..."
$mountInstallWim = "N" #(Read-Host -Prompt "Do you want to mount the install.wim file to inject files/drivers? (Y/N)")
if ($mountInstallWim -eq "Y") {
    try {
        Mount-WindowsImage -ImagePath $installWimFile -Path $installWimTempDir -Index 1 | Out-Null
    }
    catch {
        Write-Warning "Mounting setup.wim failed. Please check the file and try again."
    }
    Read-Host -Prompt "Please copy the files/drivers to $installWimTempDir\drivers and press Enter to continue"
}

# Create bootable USB drive
try {
    Write-Verbose "Formatting USB drive $UsbDriveLetter..."
    $UsbDriveId = (Get-Partition -DriveLetter $UsbDriveLetter.TrimEnd(':')).DiskNumber
    $diskpartClear = @"
    select disk $UsbDriveId
    clean
    exit
"@ | diskpart.exe

    $efiPartition = New-Partition -DiskNumber $UsbDriveId -Size 1024MB -AssignDriveLetter
    $efiPartitionDriveLetter = "$($efiPartition.DriveLetter):"
    Format-Volume -Partition $efiPartition -FileSystem FAT32 -NewFileSystemLabel "boot" -Confirm:$false
    $dataPartition = New-Partition -DiskNumber $UsbDriveId -UseMaximumSize -AssignDriveLetter
    $UsbDriveLetter = "$($dataPartition.DriveLetter):"
    Format-Volume -Partition $dataPartition -FileSystem NTFS -NewFileSystemLabel "windowsmedia" -Confirm:$false

}
catch {
    Write-Error "Failed to format USB drive $UsbDriveLetter. Please check the drive and try again."
    exit 1
}

# Check that the usbdrive was formatted as NTFS
$usbDriveFileSystem = (Get-Volume -DriveLetter $UsbDriveLetter.TrimEnd(':')).FileSystem
if (($usbDriveFileSystem -ne "NTFS") -and ((Get-Disk -Number $UsbDriveId).PartitionStyle) -ne "MBR") {
    Write-Error "USB drive $UsbDriveLetter is not formatted as NTFS in MBR. Please try again"
    exit 1
} else {
    Write-Verbose "USB drive $UsbDriveLetter is corretly formatted as NTFS."
}

# Adding Windows Setup files
Write-Verbose "Copying Windows Setup files to USB drive $UsbDriveLetter..."
Copy-Item -Path "$setupWimTempDir\*" -Destination "$UsbDriveLetter" -Recurse -Force | Out-Null
Move-Item -Path "$UsbDriveLetter\sources\_manifest" -Destination "$UsbDriveLetter\" -Force | Out-Null

Write-Verbose "Adding driver directory..."
New-Item -Path "$UsbDriveLetter" -Name "$UsbDriveLetter" -ItemType Directory -Force | Out-Null

switch ($DriverManufacturer) {
    "Dell" 
    {
        Write-Verbose "Searching Dell drivers for $DriverModel ..."
        Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/driverpackcatalog.cab" -OutFile "$scriptTempDir\delldrivercatalog.cab"
        Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $scriptTempDir\delldrivercatalog.cab $scriptTempDir\delldrivercatalog.xml" -Wait | Out-Null
        Remove-Item -Path "$scriptTempDir\delldrivercatalog.cab" -Force | Out-Null
    }
    "Lenovo" 
    {
        Write-Verbose "Searching Lenovo drivers for $DriverModel ..."
        Invoke-WebRequest -Uri "https://download.lenovo.com/cdrt/td/catalogv2.xml" -OutFile "$scriptTempDir\lenovodrivercatalog.xml"
    }
    "HP" 
    {
        Write-Verbose "Searching HP drivers for $DriverModel ..."
        Invoke-WebRequest -Uri "https://hpia.hpcloud.hp.com/downloads/driverpackcatalog/HPClientDriverPackCatalog.cab" -OutFile "$scriptTempDir\hpdrivercatalog.cab"
        Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $scriptTempDir\hpdrivercatalog.cab $scriptTempDir\hpdrivercatalog.xml" -Wait | Out-Null
        Remove-Item -Path "$scriptTempDir\hpdrivercatalog.cab" -Force | Out-Null
    }
}

Write-Verbose "Unmount Setup WIM..."
Dismount-WindowsImage -Path $setupWimTempDir -Discard | Out-Null

if ($mountInstallWim -eq "Y") {
    Write-Verbose "Unmount Install WIM..."
    Dismount-WindowsImage -Path $installWimTempDir -Save -CheckIntegrity | Out-Null
}

Write-Verbose "Copying Windows boot.wim to USB drive $UsbDriveLetter..."
Copy-Item -Path "$bootWimFile" -Destination "$UsbDriveLetter\sources\boot.wim" -Recurse -Force | Out-Null

Write-Verbose "Copying Windows install.wim to USB drive $UsbDriveLetter..."
Copy-Item -Path "$installWimFile" -Destination "$UsbDriveLetter\sources\install.wim" -Recurse -Force | Out-Null

Write-Verbose "Copying EFI Files to $efipartition.DriveLetter..."
Copy-Item "$UsbDriveLetter\boot" "$efiPartitionDriveLetter\" -Recurse
#Copy-Item "$UsbDriveLetter\efi" "$efiPartitionDriveLetter\" -Recurse
New-Item -Path "$efiPartitionDriveLetter" -Name "efi" -ItemType Directory -Force | Out-Null
New-Item -Path "$efiPartitionDriveLetter\efi" -Name "Boot" -ItemType Directory -Force | Out-Null
New-Item -Path "$efiPartitionDriveLetter\efi" -Name "$BootloaderManufacturer" -ItemType Directory -Force | Out-Null
#https://github.com/pbatard/uefi-ntfs/releases/tag/v2.5
Invoke-WebRequest -Uri "https://github.com/pbatard/uefi-ntfs/releases/download/v2.5/bootaa64.efi" -OutFile "$efiPartitionDriveLetter\efi\Boot\bootaa64.efi"
Invoke-WebRequest -Uri "https://github.com/pbatard/uefi-ntfs/releases/download/v2.5/bootarm.efi" -OutFile "$efiPartitionDriveLetter\efi\Boot\bootarm.efi"
Invoke-WebRequest -Uri "https://github.com/pbatard/uefi-ntfs/releases/download/v2.5/bootia32.efi" -OutFile "$efiPartitionDriveLetter\efi\Boot\bootia32.efi"
Invoke-WebRequest -Uri "https://github.com/pbatard/uefi-ntfs/releases/download/v2.5/bootx64.efi" -OutFile "$efiPartitionDriveLetter\efi\Boot\bootx64.efi"
#https://github.com/pbatard/ntfs-3g/releases
Invoke-WebRequest -Uri "https://github.com/pbatard/ntfs-3g/releases/download/1.7/ntfs_aa64.efi" -OutFile "$efiPartitionDriveLetter\efi\$BootloaderManufacturer\ntfs_aa64.efi"
Invoke-WebRequest -Uri "https://github.com/pbatard/ntfs-3g/releases/download/1.7/ntfs_arm.efi" -OutFile "$efiPartitionDriveLetter\efi\$BootloaderManufacturer\ntfs_arm.efi"
Invoke-WebRequest -Uri "https://github.com/pbatard/ntfs-3g/releases/download/1.7/ntfs_ia32.efi" -OutFile "$efiPartitionDriveLetter\efi\$BootloaderManufacturer\ntfs_ia32.efi"
Invoke-WebRequest -Uri "https://github.com/pbatard/ntfs-3g/releases/download/1.7/ntfs_x64.efi" -OutFile "$efiPartitionDriveLetter\efi\$BootloaderManufacturer\ntfs_x64.efi"
#Copy-Item "$UsbDriveLetter\bootmgr*" "$efiPartitionDriveLetter\" -Recurse -ErrorAction SilentlyContinue
#Copy-Item "$UsbDriveLetter\setup.exe" "$efiPartitionDriveLetter\" -Recurse
#Copy-Item "$UsbDriveLetter\sources\boot.wim" "$efiPartitionDriveLetter\sources\boot.wim" -Force -Recurse
#Copy-Item -Path "$UsbDriveLetter\efi\*" -Destination "$($efipartition.DriveLetter):" -Recurse -Force | Out-Null
#Copy-Item -Path "$UsbDriveLetter\bootmgr" -Destination "$($efipartition.DriveLetter):" -Force | Out-Null
#Copy-Item -Path "$UsbDriveLetter\bootmgr.efi" -Destination "$($efipartition.DriveLetter):" -Force | Out-Null

# Add bootstick tools
Write-Verbose "Cloning Troubleshooting tools..."
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/andrew-s-taylor/WindowsAutopilotInfo/refs/heads/main/Community%20Version/Get-AutopilotDiagnosticsCommunity.ps1" -OutFile "$UsbDriveLetter\Get-AutopilotDiagnosticsCommunity.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/andrew-s-taylor/WindowsAutopilotInfo/refs/heads/main/Community%20Version/get-windowsautopilotinfocommunity.ps1" -OutFile "$UsbDriveLetter\Get-WindowsAutopilotInfoCommunity.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/petripaavola/Get-IntuneManagementExtensionDiagnostics/refs/heads/main/Get-IntuneManagementExtensionDiagnostics.ps1" -OutFile "$UsbDriveLetter\Get-IntuneManagementExtensionDiagnostics.ps1"

Write-Verbose "Creating autounattend.xml file..."
$languageHexMap = @{
    'en-US' = '0409'
    'nl-NL' = '0413'
    'fr-FR' = '040c'
    'de-DE' = '0407'
    'it-IT' = '0410'
    'ja-JP' = '0411'
    'es-ES' = '0c0a'
    'ar-SA' = '0401'
    'zh-CN' = '0804'
    'zh-HK' = '0c04'
    'zh-TW' = '0404'
    'cs-CZ' = '0405'
    'da-DK' = '0406'
    'fi-FI' = '040b'
    'el-GR' = '0408'
    'he-IL' = '040d'
    'hu-HU' = '040e'
    'ko-KR' = '0412'
    'nb-NO' = '0414'
    'pl-PL' = '0415'
    'pt-BR' = '0416'
    'pt-PT' = '0816'
    'ru-RU' = '0419'
    'sv-SE' = '041d'
    'tr-TR' = '041f'
    'bg-BG' = '0402'
    'hr-HR' = '041a'
    'et-EE' = '0425'
    'lv-LV' = '0426'
    'lt-LT' = '0427'
    'ro-RO' = '0418'
    'sr-Latn-CS' = '081a'
    'sk-SK' = '041b'
    'sl-SI' = '0424'
    'th-TH' = '041e'
    'uk-UA' = '0422'
    'af-ZA' = '0436'
    'sq-AL' = '041c'
    'am-ET' = '045e'
    'hy-AM' = '042b'
    'as-IN' = '044d'
    'az-Latn-AZ' = '042c'
    'eu-ES' = '042d'
    'be-BY' = '0423'
    'bn-BD' = '0845'
    'bn-IN' = '0445'
    'bs-Cyrl-BA' = '201a'
    'bs-Latn-BA' = '141a'
    'ca-ES' = '0403'
    'fil-PH' = '0464'
    'gl-ES' = '0456'
    'ka-GE' = '0437'
    'gu-IN' = '0447'
    'ha-Latn-NG' = '0468'
    'hi-IN' = '0439'
    'is-IS' = '040f'
    'ig-NG' = '0470'
    'id-ID' = '0421'
    'iu-Latn-CA' = '085d'
    'ga-IE' = '083c'
    'xh-ZA' = '0434'
    'zu-ZA' = '0435'
    'kn-IN' = '044b'
    'kk-KZ' = '043f'
    'km-KH' = '0453'
    'rw-RW' = '0487'
    'sw-KE' = '0441'
    'kok-IN' = '0457'
    'ky-KG' = '0440'
    'lo-LA' = '0454'
    'lb-LU' = '046e'
    'mk-MK' = '042f'
    'ms-BN' = '083e'
    'ms-MY' = '043e'
    'ml-IN' = '044c'
    'mt-MT' = '043a'
    'mi-NZ' = '0481'
    'mr-IN' = '044e'
    'ne-NP' = '0461'
    'nn-NO' = '0814'
    'or-IN' = '0448'
    'ps-AF' = '0463'
    'fa-IR' = '0429'
    'pa-IN' = '0446'
    'quz-PE' = '0c6b'
    'sr-Cyrl-CS' = '0c1a'
    'nso-ZA' = '046c'
    'tn-ZA' = '0432'
    'si-LK' = '045b'
    'ta-IN' = '0449'
    'tt-RU' = '0444'
    'te-IN' = '044a'
    'ur-PK' = '0420'
    'uz-Latn-UZ' = '0443'
    'vi-VN' = '042a'
    'cy-GB' = '0452'
    'wo-SN' = '0488'
    'yo-NG' = '046a'
}
$localeId = $languageHexMap["$($RegionCode)"] + ":0000" + $languageHexMap["$($RegionCode)"]
Write-Verbose "Using SetupUILanguage: $LanguageCode, InputLocale: $localeId, SystemLocale: $LanguageCode, UILanguage: $LanguageCode, UserLocale: $LanguageCode, OSImage: $Edition..."
$autounattendXml= @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SetupUILanguage>
                <UILanguage>$LanguageCode</UILanguage>
            </SetupUILanguage>
            <InputLocale>$localeId</InputLocale>
            <SystemLocale>$RegionCode</SystemLocale>
            <UILanguage>$LanguageCode</UILanguage>
            <UILanguageFallback>$LanguageCode</UILanguageFallback>
            <UserLocale>$RegionCode</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                    <CreatePartitions>
                        <!-- Windows RE Tools partition -->
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Size>300</Size>
                        </CreatePartition>
                        <!-- System partition (ESP) -->
                        <CreatePartition wcm:action="add">
                            <Order>2</Order>
                            <Type>EFI</Type>
                            <Size>100</Size>
                        </CreatePartition>
                        <!-- Microsoft reserved partition (MSR) -->
                        <CreatePartition wcm:action="add">
                            <Order>3</Order>
                            <Type>MSR</Type>
                            <Size>128</Size>
                        </CreatePartition>
                        <!-- Windows partition -->
                        <CreatePartition wcm:action="add">
                            <Order>4</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <!-- Windows RE Tools partition -->
                        <ModifyPartition wcm:action="add">
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                            <Label>WINRE</Label>
                            <Format>NTFS</Format>
                            <TypeID>DE94BBA4-06D1-4D40-A16A-BFD50179D6AC</TypeID>
                        </ModifyPartition>
                        <!-- System partition (ESP) -->
                        <ModifyPartition wcm:action="add">
                            <Order>2</Order>
                            <PartitionID>2</PartitionID>
                            <Label>System</Label>
                            <Format>FAT32</Format>
                        </ModifyPartition>
                        <!-- MSR partition does not need to be modified -->
                        <ModifyPartition wcm:action="add">
                            <Order>3</Order>
                            <PartitionID>3</PartitionID>
                        </ModifyPartition>
                        <!-- Windows partition -->
                        <ModifyPartition wcm:action="add">
                            <Order>4</Order>
                            <PartitionID>4</PartitionID>
                            <Label>OS</Label>
                            <Letter>C</Letter>
                            <Format>NTFS</Format>
                        </ModifyPartition>
                    </ModifyPartitions>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <!-- Windows edition -->
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/NAME</Key>
                            <Value>Windows 11 $Edition</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>4</PartitionID>
                    </InstallTo>
                    <InstallToAvailablePartition>false</InstallToAvailablePartition>
                </OSImage>
            </ImageInstall>
            <UserData>
                <ProductKey>
                    <!-- Do not uncomment the Key element if you are using trial ISOs -->
                    <!-- You must uncomment the Key element (and optionally insert your own key) if you are using retail or volume license ISOs -->
                    <Key></Key>
                    <WillShowUI>Never</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
                <FullName></FullName>
                <Organization></Organization>
            </UserData>
            <UseConfigurationSet>true</UseConfigurationSet>
        </component>
    </settings>
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-PnpCustomizationsNonWinPE" processorArchitecture="$Architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DriverPaths>
                <PathAndCredentials wcm:action="add" wcm:keyValue="1">
                    <Path>%configsetroot%\drivers</Path>
                </PathAndCredentials>
            </DriverPaths>
        </component>
    </settings>
</unattend>
"@
$autounattendXml | Set-Content -Path "$UsbDriveLetter\autounattend.xml" -Force

# Cleanup
Write-Verbose "Cleaning up temporary files"
Remove-Item -Path $installWimFile -Force | Out-Null
Remove-Item -Path $setupWimFile -Force | Out-Null
Remove-Item -Path $bootWimFile -Force | Out-Null
Remove-Item -Path $productsFile -Force | Out-Null
Remove-Item -Path $installWimTempDir -Recurse -Force | Out-Null
Remove-Item -Path $bootWimTempDir -Recurse -Force | Out-Null
Remove-Item -Path $setupWimTempDir -Recurse -Force | Out-Null
if (Test-Path -Path "$scriptTempDir\hpdrivercatalog.xml") {
    Remove-Item -Path "$scriptTempDir\hpdrivercatalog.xml" -Force | Out-Null
}
if (Test-Path -Path "$scriptTempDir\lenovodrivercatalog.xml") {
    Remove-Item -Path "$scriptTempDir\lenovodrivercatalog.xml" -Force | Out-Null
}
if (Test-Path -Path "$scriptTempDir\delldrivercatalog.xml") {
    Remove-Item -Path "$scriptTempDir\delldrivercatalog.xml" -Force | Out-Null
}

Write-Host "Finished Windows Media Creation CLI" -ForegroundColor Green