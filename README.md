# 🪟 A Media Creation Tool CLI 🪟

This repo contains my solution of a media creation tool to create Windows Installation media using PowerShell.

![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/niklasrst/windows-mediacreation-cli/total)

<span style="color:cornflowerblue;font-weight:bold">🛈  HINT</span><br/>
    If you want to use the script, grab the latest release as the script version in the code is work-in-progress.

## Introduction
I´ve created this script as I wanted to automate the creation of usb-drives with Windows installation media.
So I came up with the idea to create a parameter based PowerShell script to ask for the needed details and then fully automated create a usb-drive, containing the Windows installation media. It currently supports the latest versions of Windows 11.

## How to use it?
Use this command to run the script with the minimal required set of parameters.
```powershell
# Minimal parameter setup
.\mctcli.ps1 -Architecture amd64 -Build 24H2 -LanguageCode "en-us" -RegionCode "en-us" -Edition Pro -UsbDriveLetter "E:"
```

Currently the `mctcli.ps1` script only supports to download one oem enterprise driver pack. If you need to add more drivers, use the `add-drivers.ps1` script like this 
```powershell
.\add-driver.ps1 -Architecture amd64 -UsbDriveLetter "D:" -DriverManufacturer Dell -DriverModel "Latitude-7450" -DriverInjectionType DISM
```
It also supports `Dell`, `Lenovo` and `HP` as manufacturers.

<span style="color:cornflowerblue;font-weight:bold">🛈  HINT</span><br/>
    Because of a Bug/Known issue I´ve split the solution in 3 branches.
    [main](https://github.com/niklasrst/windows-mediacreation-cli/tree/main) has a new switch `-DriverInjectionType` to control if you want to use the autounattend.xml file with the `drivers`-folder to apply driver files to the system, or use dism to inject the drivers in the `install.wim` file. Starting at Windows 11 24H2 it seems to be broken to use a `drivers`-folder to apply driver files to the system because of a switch in the setup process. So you can use this switch or switch to one of the branches [autounattend-driver-injection](https://github.com/niklasrst/windows-mediacreation-cli/tree/autounattend-driver-injection) or [dism-driver-injection](https://github.com/niklasrst/windows-mediacreation-cli/tree/dism-driver-injection) to use dedicated methods of driver injection. <br><br>
    Hopefully Microsoft makes the way using autounattend.xml working again in the next Windows release but until then we can use the classic dism way. When using DISM to inject drivers the tool will create a `installwimdrivers.csv` located at `\sources\` on the usb-drive which includes the driver manufacturer and model so that you later can check which drivers are installed in the `wim`.

### Parameter defenitions
Check out the following section to learn what the parameters are used for.
``` powershell
#.PARAMETER -Architecture
    The architecture of Windows to download. Valid values are amd64 or arm64.
    The default is x64.

#.PARAMETER -Build
    The build number of Windows to download. Valid values are "24H2".
    The default is the 24H2 build.

#.PARAMETER -LanguageCode
    The language code of Windows to download. Valid values for example are en-us, de-de, fr-fr, es-es, it-it.
    The default is en-us.

#.PARAMETER -RegionCode
    The regional code of Windows to download. Valid values for example are en-us, de-de, fr-fr, es-es, it-it.
    The default is en-us and will be matched to LanuageCode. if not set.

#.PARAMETER -Edition
        The edition of Windows to download. Valid values are "Home", "Pro", "Pro N", "Enterprise", "Enterprise N", "Education", "Education N"
        The default is Pro.

#.PARAMETER -UsbDriveLetter
    The drive letter of the USB drive to create the bootable media.
    For example "E:".

#.PARAMETER -DriverManufacturer
    The manufacturer of the drivers to download. Valid values are "Dell", "Lenovo", "HP".
    The default is not set.

#.PARAMETER -DriverModel
    The model of the drivers to download. This is optional and will be used to filter the drivers from the manufacturer.
    For example (Dell) "Latitude-5440" or (Lenovo) "ThinkPad X390" or (HP) "Z6 G5".
    The default is not set.

#.PARAMETER -DriverInjectionType
    The type of driver injection to use. Valid values are "AUTOUNATTEND" or "DISM".
    The default is not set.

#.PARAMETER -Verbose
   Enable verbose output. I recommend using this parameter, as it exactly shows you what the script does and where it currently is.
```

## How it works?

Check out my blog post to learn how this solution works:
[MCTCLI](https://niklasrast.io/blog/post-0088)

## 🤝 Contributing

Before making your first contribution please see the following guidelines:
1. [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716)
1. [Git Tutorials](https://www.youtube.com/playlist?list=PLu-nSsOS6FRIg52MWrd7C_qSnQp3ZoHwW)

---

Made with ❤️ by [Niklas Rast](https://github.com/niklasrst)