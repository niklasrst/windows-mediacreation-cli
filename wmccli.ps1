<#
.SYNOPSIS
   A CLI to create Windows Installation media with different versions of Windows.

.DESCRIPTION
    This script downloads the Windows ESD file from Microsoft and creates a bootable USB drive with the selected version of Windows.

.PARAMETER -Version
    The version of Windows to download. Valid values are 10 or 11.
    The default is 11.

.PARAMETER -Architecture
    The architecture of Windows to download. Valid values are amd64 or arm64.
    The default is x64.

.PARAMETER -Build
    The build number of Windows to download. Valid values are 22621, 22631, 22641, 22651, 22661, 22671, 22681, 22691, 22701, 22711, 22721, 22731, 22741, 22751, 22761, 22771, 22781, 22791.
    The default is the 00000 build.

.PARAMETER -LanguageCode
    The language code of Windows to download. Valid values for example are en-us, de-de, fr-fr, es-es, it-it.
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
    .\wmccli.ps1 -Version 11 -Architecture amd64 -Build 22621 -LanguageCode en-us -Edition CLIENTBUSINESS_VOL -UsbDriveLetter E:
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
    [ValidateSet("amd64", "arm64")]
    [String]$Architecture = "x64",
    [Parameter(Mandatory = $True)]
    [ValidateSet("10-21H1", "10-21H2", "10-22H2", "10-23H2", "11-21H2", "11-22H2", "11-23H2", "11-24H2")]
    [String]$Build = "11-24H2",
    [Parameter(Mandatory = $True)]
    [ValidateSet("en-us", "de-de")]
    [String]$LanguageCode = "en-us",
    [Parameter(Mandatory = $True)]
    [ValidateSet("CLIENTCONSUMER_RET", "CLIENTBUSINESS_VOL")]
    [String]$Edition = "CLIENTBUSINESS_VOL",
    [Parameter(Mandatory = $True)]
    [String]$UsbDriveLetter = "E:"
)

#Requires -RunAsAdministrator

Write-Verbose "Parameters"
Write-Verbose "Version: $Version"
Write-Verbose "Architecture: $Architecture"
Write-Verbose "Build: $Build"
Write-Verbose "LanguageCode: $LanguageCode"
Write-Verbose "Edition: $Edition"
Write-Verbose "UsbDriveLetter: $UsbDriveLetter"
Write-Verbose "Working Directory: $env:temp\wmccli"
Write-Verbose "------------------------------------------------------"
Write-Verbose "Starting Windows Media Creation CLI"

# Variables
$IsoArchitecture = $null
$scriptTempDir = "$env:temp\wmccli"
$setupWimTempDir = "$env:temp\wmccli\setupwim"
$installWimTempDir = "$env:temp\wmccli\installwim"
Set-Location $scriptTempDir
if (-not (Test-Path -Path $scriptTempDir)) {
    New-Item -ItemType Directory -Path $scriptTempDir | Out-Null
    Write-Verbose "Created temporary directory $scriptTempDir..."
}
if (-not (Test-Path -Path $setupWimTempDir)) {
    New-Item -ItemType Directory -Path $setupWimTempDir | Out-Null
    Write-Verbose "Created temporary directory $setupWimTempDir..."
}
if (-not (Test-Path -Path $installWimTempDir)) {
    New-Item -ItemType Directory -Path $installWimTempDir | Out-Null
    Write-Verbose "Created temporary directory $installWimTempDir..."
}

if (-not (Test-Path -Path $UsbDriveLetter)) {
    Write-Error "The drive $UsbDriveLetter does not exist. Please check the drive letter and try again."
    exit 1
}

switch ($Build){
    "10-21H1" { $BuildVer = "19043" }
    "10-21H2" { $BuildVer = "19044" }
    "10-22H2" { $BuildVer = "19045" }
    "10-23H2" { $BuildVer = "19046" }
    "11-21H2" { $BuildVer = "22000" }
    "11-22H2" { $BuildVer = "22621" }
    "11-23H2" { $BuildVer = "22631" }
    "11-24H2" { $BuildVer = "26100" }
}
Write-Verbose "Build version converted to $BuildVer..."

switch ($Architecture) {
    "amd64" { $IsoArchitecture = "x64" }
    "arm64" { $IsoArchitecture = "A64" }
}
Write-Verbose "Architecture converted to $IsoArchitecture..."

# Download Manifests
switch ($Version) {
    "10" 
    { 
        $Url = "https://go.microsoft.com/fwlink/?LinkId=841361" 
    }
    "11" 
    { 
        $Url = "https://go.microsoft.com/fwlink/?LinkId=2156292" 
    }
}
Write-Verbose "Downloading $($Version) from $($Url) to $scriptTempDir..."
Invoke-WebRequest -Uri $Url -OutFile "$scriptTempDir\$($Version).cab" -Verbose:$Verbose
Write-Verbose "Extracting $($Version) to $scriptTempDir\$($Version)_products.xml..."
Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $scriptTempDir\$($Version).cab $scriptTempDir\$($Version)_products.xml" -Wait | Out-Null
Write-Verbose "Removing temporary file $scriptTempDir\$($Version).cab..."
Remove-Item -Path "$scriptTempDir\$($Version).cab" -Force | Out-Null

# Construct URL and Download ESD file
$productsFile = "$scriptTempDir\$($Version)_products.xml"
[xml]$productsXml = Get-Content -Path $productsFile
Write-Verbose "Parsing XML file $productsFile..."

$esdUrl = ($productsXml.MCT.Catalogs.Catalog.FirstChild.Files.File.FilePath | Where-Object { $_ -match ".*http.*$BuildVer.*$Edition.*$IsoArchitecture.*$LanguageCode.esd" } | Select-Object -First 1)
Write-Verbose "Found ESD URL: $esdUrl"

Write-Verbose "Downloading ESD file from $esdUrl to $scriptTempDir..."
$installVer = "win$($Version)-$($BuildVer)-$($Edition)-$($IsoArchitecture)-$($LanguageCode)"
$installEsdFile = "$scriptTempDir\install.esd"
$setupWimFile = "$scriptTempDir\setup.wim"
$installWimFile = "$scriptTempDir\install.wim"
if (Test-Path -Path $installEsdFile) {
    Write-Verbose "ESD file already exists. Skipping download..."
} else {
    try {
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
    Dism /Export-Image /SourceImageFile:$installEsdFile /SourceIndex:1 /DestinationImageFile:$setupWimFile /Compress:max /CheckIntegrity | Out-Null
    Write-Verbose "Exported setup.wim..."
} 

# Extract install.wim
Write-Verbose "Extracting install from ESD to WIM format..."
if (-not (Test-Path -Path $installWimFile)) {
    Dism.exe /Get-WimInfo /WimFile:$installEsdFile
    $index = Read-Host -Prompt "Please enter Index number of the Windows Edition that you want to export (for example 8)"
    Dism /Export-Image /SourceImageFile:$installEsdFile /SourceIndex:$index /DestinationImageFile:$installWimFile /Compress:max /CheckIntegrity | Out-Null
    
    $installWimInfo = Dism.exe /Get-WimInfo /WimFile:$installWimFile | Out-String
    $wimEditionName = ($installWimInfo -split "`n" | Where-Object { $_ -match "Name\s*:\s*(.+)" }) -replace "Name\s*:\s*", ""
    Write-Verbose "Exported install.wim for: $wimEditionName"
} 


# Mount wim file(s)
Write-Verbose "Mounting setup.wim file..."
try {
    Mount-WindowsImage -ImagePath $setupWimFile -Path "$setupWimTempDir" -Index 1 | Out-Null
}
catch {
    Write-Warning "Mounting setup.wim failed. Please check the file and try again."
    exit 1
}

Write-Verbose "Mounting install.wim file..."
$mountInstallWim = (Read-Host -Prompt "Do you want to mount the install.wim file to inject files/drivers? (Y/N)")
if ($mountInstallWim -eq "Y") {
    try {
        Mount-WindowsImage -ImagePath $installWimFile -Path $installWimTempDir -Index 1 | Out-Null
    }
    catch {
        Write-Warning "Mounting setup.wim failed. Please check the file and try again."
        exit 1
    }
    Read-Host -Prompt "Please copy the files/drivers to $installWimTempDir\drivers and press Enter to continue"
}

# Create bootable USB drive
Write-Verbose "Formatting USB drive $UsbDriveLetter..."
$UsbDriveId = (Get-Partition -DriveLetter $UsbDriveLetter.TrimEnd(':')).DiskNumber
Clear-Disk -Number $UsbDriveId -RemoveData -Confirm:$false
$partition = New-Partition -DiskNumber $UsbDriveId -UseMaximumSize -DriveLetter $UsbDriveLetter.TrimEnd(':')
$partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel "$($installVer)" -Confirm:$false

# Adding Windows Setup files
Write-Verbose "Copying Windows Setup files to USB drive $UsbDriveLetter..."
Copy-Item -Path "$setupWimTempDir\*" -Destination "$UsbDriveLetter" -Recurse -Force | Out-Null

Write-Verbose "Adding driver directory..."
New-Item -Path "$UsbDriveLetter" -Name "drivers" -ItemType Directory -Force | Out-Null

Write-Verbose "Unmount Setup WIM..."
Dismount-WindowsImage -Path $setupWimTempDir -Discard | Out-Null

if ($mountInstallWim -eq "Y") {
    Write-Verbose "Unmount Install WIM..."
    Dismount-WindowsImage -Path $installWimTempDir -Save -CheckIntegrity | Out-Null
}

# Add bootstick tools
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
$localeId = $languageHexMap["$($LanguageCode)"] + ":0000" + $languageHexMap["$($LanguageCode)"]
Write-Verbose "Using SetupUILanguage: $LanguageCode, InputLocale: $localeId, SystemLocale: $LanguageCode, UILanguage: $LanguageCode, UserLocale: $LanguageCode, OSImage: $wimEditionName..."
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
            <SystemLocale>$LanguageCode</SystemLocale>
            <UILanguage>$LanguageCode</UILanguage>
            <UILanguageFallback>$LanguageCode</UILanguageFallback>
            <UserLocale>$LanguageCode</UserLocale>
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
                            <Value>$wimEditionName</Value>
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
#Write-Verbose "Cleaning up temporary files"
#Remove-Item -Path $scriptTempDir -Recurse -Force | Out-Null

Write-Host "Finished Windows Media Creation CLI" -ForegroundColor Green