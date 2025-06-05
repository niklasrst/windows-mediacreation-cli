# 🪟 A Media Creation Tool CLI 🪟

This repo contains my solution of a media creation tool to create Windows Installation media using PowerShell.

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
.\add-driver.ps1 -Architecture amd64 -UsbDriveLetter "D:" -DriverManufacturer Dell -DriverModel "Latitude-7450"
```
It also supports `Dell`, `Lenovo` and `HP` as manufacturers.

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

#.PARAMETER -Verbose
   Enable verbose output. I recommend using this parameter, as it exactly shows you what the script does and where it currently is.
```

## How it works?

<span style="color:cornflowerblue;font-weight:bold">🛈  HINT</span><br/>
    I will update this part to tell you very granulary how the script works and what id does ;)

1. Firstly the script is looking for the windows manifest file for [Windows11](https://go.microsoft.com/fwlink/?LinkId=2156292).

2. Next is to filter the list, based on the parameters to get the version that you want to download.

3. Once it figured the right download url from the manifest file it will start downloading the right `esd` file, which will be converted to `.wim` with the edition that you need.

4. Lastly it is formatting the usb-drive and placing the installation media on it.
I wanted to use `NTFS` as the filesystem hosting the install files as it enables larger `.wim` files and/or driverpacks. So I used the [Rufus Bootloader](https://github.com/pbatard/uefi-ntfs) which will added to a smaller `FAT32` partition on the usb-drive which will initiate the bootsequence and loads the install files from the `NTFS` partition, which both will be created from my script.

## 🤝 Contributing

Before making your first contribution please see the following guidelines:
1. [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716)
1. [Git Tutorials](https://www.youtube.com/playlist?list=PLu-nSsOS6FRIg52MWrd7C_qSnQp3ZoHwW)

---

Made with ❤️ by [Niklas Rast](https://github.com/niklasrst)