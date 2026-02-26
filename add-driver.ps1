<#
.SYNOPSIS
   A script to easily download and add oem driverpacks to install-media created by the mctcli tool.

.DESCRIPTION
    This script downloads OEM driverpacks from Dell, Lenovo, or HP and adds them to a specified USB drive to create a bootable Windows installation media.

.PARAMETER -Architecture
    The architecture of Windows for the driverpacks. Valid values are amd64 or arm64.
    The default is x64.

.PARAMETER -UsbDriveLetter
    The drive letter of the USB drive which holds the bootable media created by mctcli.
    For example "D:".

.PARAMETER -DriverManufacturer
    The manufacturer of the drivers to download. Valid values are "Dell", "Lenovo", "HP".
    The default is not set.

.PARAMETER -DriverModel
    The model of the drivers to download. This is optional and will be used to filter the drivers from the manufacturer.
    For example (Dell) "Latitude-5440" or (Lenovo) "ThinkPad X390" or (HP) "Z6 G5".
    The default is not set.

.PARAMETER -DriverInjectionType
    The type of driver injection to use. Valid values are "AUTOUNATTEND" or "DISM".
    The default is not set.

.PARAMETER -Verbose
   Enable verbose output.

.EXAMPLE
    .\add-driver.ps1 -Architecture amd64 -UsbDriveLetter "D:" -DriverManufacturer Dell -DriverModel "Latitude-7450"
    This command will download the Dell driverpack for the Latitude 7450 model and add it to the USB drive D: under the drivers directory.

.OUTPUTS
    ---

.NOTES
    Use this script to add more driverpacks to a Windows Installation media from PowerShell created by mctcli.

.LINK
    https://github.com/niklasrst/windows-mediacreation-cli

.AUTHOR
    Niklas Rast
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $True)]
    [ValidateSet("amd64", "arm64")]
    [String]$Architecture = "amd64",
    [Parameter(Mandatory = $True)]
    [String]$UsbDriveLetter = "D:",
    [Parameter(Mandatory = $False)]
    [ValidateSet("Dell", "Lenovo", "HP")]
    [String]$DriverManufacturer,
    [Parameter(Mandatory = $False)]
    [String]$DriverModel,
    [Parameter(Mandatory = $False)]
    [ValidateSet("AUTOUNATTEND", "DISM")]
    [String]$DriverInjectionType
)

if ($DriverManufacturer -and $DriverModel -and -not $DriverInjectionType) {
    Write-Error "DriverInjectionType must be specified when DriverManufacturer and DriverModel are set."
    exit 1
}

$CurrentLocation = Get-Location

# Variables
$startTime = Get-Date -Format "HH:mm:ss"
$IsoArchitecture = $null
$SupportedOsVersion = "Win11"
$SupportedOsVersionShort = "W11"
$SupportedOsVersionFull = "Windows 11"
$dismDriverDetectionPath = "$UsbDriveLetter\installwimdrivers.csv"
$scriptTempDir = "C:\mctcli"
$installWimFile = "$scriptTempDir\install.wim"
$installWimTempDir = "C:\mctcli\installwim"
$driverpackTempDir = "C:\mctcli\driverpack"
if (-not (Test-Path -Path $scriptTempDir)) {
    New-Item -ItemType Directory -Path $scriptTempDir | Out-Null
    Write-Verbose "Created temporary directory $scriptTempDir..."
}
if (-not (Test-Path -Path $driverpackTempDir)) {
    New-Item -ItemType Directory -Path $driverpackTempDir | Out-Null
    Write-Verbose "Created temporary directory $driverpackTempDir..."
}
if (-not (Test-Path -Path $installWimTempDir)) {
    New-Item -ItemType Directory -Path $installWimTempDir | Out-Null
    Write-Verbose "Created temporary directory $installWimTempDir..."
}
if (-not (Test-Path -Path $UsbDriveLetter)) {
    Write-Error "The drive $UsbDriveLetter does not exist. Please check the drive letter and try again."
    exit 1
}
if ($DriverInjectionType -eq "DISM") {
    if (-not (Test-Path -Path $dismDriverDetectionPath)) {
        New-Item -Path "$dismDriverDetectionPath" -ItemType File -Force | Out-Null
    } else {
        "`n" | Out-File -FilePath $dismDriverDetectionPath -Append -Force
    }
} 

Set-Location $scriptTempDir

Write-Verbose "Parameters"
Write-Verbose "Architecture: $Architecture"
Write-Verbose "Operating System Version Support: $SupportedOsVersionFull ($SupportedOsVersion / $SupportedOsVersionShort)"
Write-Verbose "UsbDriveLetter: $UsbDriveLetter"
Write-Verbose "DriverManufacturer: $DriverManufacturer"
Write-Verbose "DriverModel: $DriverModel"
Write-Verbose "DriverInjectionType: $DriverInjectionType"
Write-Verbose "Working Directory: $scriptTempDir"
Write-Verbose "------------------------------------------------------"
Write-Verbose "Starting to add driverpack at $startTime"

switch ($Architecture) {
    "amd64" { $IsoArchitecture = "x64" }
    "arm64" { $IsoArchitecture = "A64" }
}
Write-Verbose "Architecture converted to $IsoArchitecture..."

# Mount install.wim file if needed
switch ($DriverInjectionType) {
    "AUTOUNATTEND" {
        # No need to mount install.wim for AUTOUNATTEND
        Write-Verbose "Adding driver directory..."
        New-Item -Path "$UsbDriveLetter" -Name "drivers" -ItemType Directory -Force | Out-Null
    }
    "DISM" {
        Write-Verbose "Mounting install.wim file..."
        try {
            Move-Item -Path "$UsbDriveLetter\sources\install.wim" -Destination $installWimFile -Force -ErrorAction Stop
        }
        catch {
            exit 1
        }

        try {
            Mount-WindowsImage -ImagePath $installWimFile -Path $installWimTempDir -Index 1 | Out-Null
        }
        catch {
            Write-Warning "Mounting setup.wim failed. Please check the file and try again."
            exit 1
        } 
    }
    default {
        # No need to mount install.wim for default which uses AUTOUNATTEND
        Write-Verbose "Adding driver directory..."
        New-Item -Path "$UsbDriveLetter" -Name "drivers" -ItemType Directory -Force | Out-Null
    }
}

switch ($DriverManufacturer) {
    "Dell" 
    {
        if ((Test-NetConnection -ComputerName "dell.com" -Port 80).TcpTestSucceeded -ne $true) {
            Write-Error "Could not connect to Dell which is needed for the drivers. Please ensure connectivity to dell.com and try again."
        } else {
            Write-Verbose "Searching Dell drivers for $DriverModel ..."
            if ($DriverModel -match "\s") {
                Write-Verbose "Replacing spaces in DriverModel with dashes..."
                $DriverModel = $DriverModel -replace '\s', '-'
            }
            Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/driverpackcatalog.cab" -OutFile "$scriptTempDir\delldrivercatalog.cab"
            Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $scriptTempDir\delldrivercatalog.cab $scriptTempDir\delldrivercatalog.xml" -Wait | Out-Null
            Remove-Item -Path "$scriptTempDir\delldrivercatalog.cab" -Force | Out-Null
            $driversXmlPath = "$scriptTempDir\delldrivercatalog.xml"
            [xml]$driversXml = Get-Content -Path $driversXmlPath

            $dellDriverPath = $driversXml.DriverPackManifest.DriverPackage.Path | Where-Object { $_ -match "$DriverModel.*$SupportedOsVersion" } | Select-Object -First 1
            $dellDriverUrl = $baseDownloadUrl + $dellDriverPath
            $dellDriverSetup = $dellDriverPath -replace ".*($($DriverModel).*)", '$1'

            if ($null -eq $dellDriverUrl) {
                Write-Error "No Dell driver found for $DriverModel. Skipping driver download."
            } else {
                Write-Verbose "Found Dell driver URL for $DriverModel $dellDriverUrl"
                Invoke-WebRequest -Uri "https://downloads.dell.com/$($dellDriverUrl)" -OutFile "$scriptTempDir\$dellDriverSetup"
            
                Write-Verbose "Extracting Dell driver $dellDriverSetup to $driverpackTempDir ..."
                Start-Process -FilePath "$scriptTempDir\$dellDriverSetup" -ArgumentList "/s /e=$driverpackTempDir" -Wait

                $oemDriverPackDir = (Get-ChildItem -Path $driverpackTempDir -Directory | Where-Object { $_.Name -match "$($DriverModel).*" }).FullName
                
                switch ($DriverInjectionType) {
                    "AUTOUNATTEND" {
                        Write-Verbose "Copying Dell driver to $UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)..."
                        $oemDriverPackName = (Get-ChildItem -Path $driverpackTempDir -Directory | Where-Object { $_.Name -match "$($DriverModel).*" }).Name
                        $oemDriverMediaDir = $DriverManufacturer + "-" + $oemDriverPackName
                        Copy-Item -Path "$oemDriverPackDir\$SupportedOsVersion\$IsoArchitecture\" -Destination "$UsbDriveLetter\drivers\$oemDriverMediaDir" -Recurse -Force | Out-Null
                    }
                    "DISM" {
                        Write-Verbose "Injecting drivers to install.wim..."
                        Dism.exe /Image:$installWimTempDir /Add-Driver /Driver:$oemDriverPackDir\$SupportedOsVersion\$IsoArchitecture /recurse | Out-Null

                        "$DriverManufacturer,$DriverModel" | Out-File -FilePath $dismDriverDetectionPath -Append -Force
                    }
                    default {
                        $oemDriverPackName = (Get-ChildItem -Path $driverpackTempDir -Directory | Where-Object { $_.Name -match "$($DriverModel).*" }).Name
                        $oemDriverMediaDir = $DriverManufacturer + "-" + $oemDriverPackName
                        Copy-Item -Path "$oemDriverPackDir\$SupportedOsVersion\$IsoArchitecture\" -Destination "$UsbDriveLetter\drivers\$oemDriverMediaDir" -Recurse -Force | Out-Null
                    }
                }
                
                
            }   
        }
    }
    "Lenovo" 
    {
        if ((Test-NetConnection -ComputerName "lenovo.com" -Port 80).TcpTestSucceeded -ne $true) {
            Write-Error "Could not connect to Lenovo which is needed for the drivers. Please ensure connectivity to lenovo.com and try again."
        } else {
            Write-Verbose "Searching Lenovo drivers for $DriverModel ..."
            Invoke-WebRequest -Uri "https://download.lenovo.com/cdrt/td/catalogv2.xml" -OutFile "$scriptTempDir\lenovodrivercatalog.xml"
            $driversXmlPath = "$scriptTempDir\lenovodrivercatalog.xml"
            [xml]$driversXml = Get-Content -Path $driversXmlPath

            $lenovoDriverPath = $driversXml.ModelList.Model | Where-Object { $_.name -match $DriverModel }
            $lenovoDriverPathNode = $lenovoDriverPath.SCCM | Where-Object { $_.os -eq "$SupportedOsVersion" } | Select-Object -Last 1
            $lenovoDriverUrl = $lenovoDriverPathNode.'#text'
            $lenovoDriverSetup = $lenovoDriverUrl -replace '.*/', ''

            if ($null -eq $lenovoDriverUrl) {
                Write-Error "No Lenovo driver found for $DriverModel. Skipping driver download."
            } else {
                Write-Verbose "Found Lenovo driver URL for $DriverModel $lenovoDriverUrl"
                Invoke-WebRequest -Uri $lenovoDriverUrl -OutFile "$scriptTempDir\$lenovoDriverSetup"

                Write-Verbose "Extracting Lenovo driver $lenovoDriverSetup to $driverpackTempDir ..."
                Start-Process -FilePath "$scriptTempDir\$lenovoDriverSetup" -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -Wait
                Move-Item -Path "C:\Drivers" -Destination $driverpackTempDir -Force | Out-Null
                $driverModelPath = $lenovoDriverSetup -replace ".exe", ""
                $extractDir = (Get-ChildItem -Path "$driverpackTempDir\Drivers\SCCM\$($driverModelPath)").FullName

                switch ($DriverInjectionType) {
                    "AUTOUNATTEND" {
                        Write-Verbose "Copying Lenovo driver to $UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)..."
                        New-Item -Path "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -ItemType Directory -Force | Out-Null
                        Copy-Item -Path "$extractDir\*" -Destination "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -Recurse -Force | Out-Null
                    }
                    "DISM" {
                        Write-Verbose "Injecting drivers to install.wim..."
                        Dism.exe /Image:$installWimTempDir /Add-Driver /Driver:$extractDir /recurse | Out-Null

                        "$DriverManufacturer,$DriverModel" | Out-File -FilePath $dismDriverDetectionPath -Append -Force
                    }
                    default {
                        Write-Verbose "Copying Lenovo driver to $UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)..."
                        New-Item -Path "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -ItemType Directory -Force | Out-Null
                        Copy-Item -Path "$extractDir\*" -Destination "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -Recurse -Force | Out-Null
                    }
                }
            }
        }
    }
    "HP" 
    {
        if ((Test-NetConnection -ComputerName "hp.com" -Port 80).TcpTestSucceeded -ne $true) {
            Write-Error "Could not connect to HP which is needed for the drivers. Please ensure connectivity to hp.com and try again."
        } else {
            Write-Verbose "Searching HP drivers for $DriverModel ..."
            Invoke-WebRequest -Uri "https://hpia.hpcloud.hp.com/downloads/driverpackcatalog/HPClientDriverPackCatalog.cab" -OutFile "$scriptTempDir\hpdrivercatalog.cab"
            Start-Process -FilePath "C:\Windows\System32\expand.exe" -ArgumentList "-F:* $scriptTempDir\hpdrivercatalog.cab $scriptTempDir\hpdrivercatalog.xml" -Wait | Out-Null
            Remove-Item -Path "$scriptTempDir\hpdrivercatalog.cab" -Force | Out-Null
            $driversXmlPath = "$scriptTempDir\hpdrivercatalog.xml"
            [xml]$driversXml = Get-Content -Path $driversXmlPath

            $hpDriverPath = $driversXml.NewDataSet.HPClientDriverPackCatalog.SoftPaqList.SoftPaq | Where-Object { ($_.name -match $DriverModel) -and ($_.name -match "$($SupportedOsVersionFull)") } | Sort-Object id | Select-Object -First 1
            $hpDriverUrl = $hpDriverPath.Url
            $hpDriverSetup = $hpDriverUrl -replace '.*/', ''

            if ($null -eq $hpDriverUrl) {
                Write-Error "No HP driver found for $DriverModel. Skipping driver download."
            } else {
                Write-Verbose "Found HP driver URL for $DriverModel $hpDriverUrl"
                Invoke-WebRequest -Uri $hpDriverUrl -OutFile "$scriptTempDir\$hpDriverSetup"

                Write-Verbose "Extracting HP driver $hpDriverSetup to $driverpackTempDir ..."
                Start-Process -FilePath "$scriptTempDir\$hpDriverSetup" -ArgumentList "/s /e /f $driverpackTempDir" -Wait

                $searchString = $DriverModel -replace " ", "*"
                $extractDir = (Get-ChildItem -Path $driverpackTempDir -Directory | Where-Object { $_.Name -like "*$searchString*" } | Get-ChildItem).FullName

                switch ($DriverInjectionType) {
                    "AUTOUNATTEND" {
                        Write-Verbose "Copying HP driver to $UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)..."
                        New-Item -Path "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -ItemType Directory -Force | Out-Null
                        Copy-Item -Path "$($extractDir)\*" -Destination "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -Recurse -Force | Out-Null
                    }
                    "DISM" {
                        Write-Verbose "Injecting drivers to install.wim..."
                        Dism.exe /Image:$installWimTempDir /Add-Driver /Driver:$extractDir /recurse | Out-Null

                        "$DriverManufacturer,$DriverModel" | Out-File -FilePath $dismDriverDetectionPath -Append -Force
                    }
                    default {
                        Write-Verbose "Copying HP driver to $UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)..."
                        New-Item -Path "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -ItemType Directory -Force | Out-Null
                        Copy-Item -Path "$($extractDir)\*" -Destination "$UsbDriveLetter\drivers\$($DriverManufacturer)-$($DriverModel)" -Recurse -Force | Out-Null
                    }
                }  
            }
        }
    }
}

switch ($DriverInjectionType) {
    "AUTOUNATTEND" {
        # No need to unmount install.wim for AUTOUNATTEND
    }
    "DISM" {
        Write-Verbose "Unmount Install WIM..."
        Dismount-WindowsImage -Path $installWimTempDir -Save -CheckIntegrity | Out-Null

        Write-Verbose "Copying Windows install.wim to USB drive $UsbDriveLetter..."
        Move-Item -Path "$installWimFile" -Destination "$UsbDriveLetter\sources\install.wim" -Force | Out-Null
     }
    default {
        # No need to unmount install.wim for default which is AUTOUNATTEND
    }
}

# Cleanup
Write-Verbose "Cleaning up temporary files"
Remove-Item -Path "$installWimTempDir" -Recurse -Force | Out-Null

if (Test-Path -Path "$driverpackTempDir") {
    Remove-Item -Path "$driverpackTempDir" -Recurse -Force | Out-Null
}
if (Test-Path -Path "$scriptTempDir\delldrivercatalog.xml") {
    Remove-Item -Path "$scriptTempDir\delldrivercatalog.xml" -Force | Out-Null
    Remove-Item -Path "$scriptTempDir\$dellDriverSetup" -Force | Out-Null
}
if (Test-Path -Path "$scriptTempDir\lenovodrivercatalog.xml") {
    Remove-Item -Path "$scriptTempDir\lenovodrivercatalog.xml" -Force | Out-Null
    Remove-Item -Path "$scriptTempDir\$lenovoDriverSetup" -Force | Out-Null
}
if (Test-Path -Path "$scriptTempDir\hpdrivercatalog.xml") {
    Remove-Item -Path "$scriptTempDir\hpdrivercatalog.xml" -Force | Out-Null
    Remove-Item -Path "$scriptTempDir\$hpDriverSetup" -Force | Out-Null
}

Set-Location $CurrentLocation
Write-Host ("Finished adding drivers in: {0:hh\:mm\:ss}" -f (New-TimeSpan -Start $startTime -End (Get-Date))) -ForegroundColor Green