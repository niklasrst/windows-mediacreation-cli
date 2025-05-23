# 🪟 A CLI Media Creation Tool 🪟

This repo contains my solution of a media creation tool to create Windows Installation media using PowerShell.

## Introduction
I´ve created this script as I wanted to automate the creation of usb-drives with Windows installation media.
So I came up with the idea to create a parameter based PowerShell script to ask for the needed details and then fully automated create a usb-drive, containing the Windows installation media. It currently supports the last 4 versions of Windows 11.

## How to use it?

```powershell
.\mctcli.ps1 -Architecture amd64 -Build 24H2 -LanguageCode de-de --RegionCode de-de -Edition Pro -UsbDriveLetter "E:" -Verbose
```

## How it works?
Firstly the script is looking for the windows manifest file for [Windows11](https://go.microsoft.com/fwlink/?LinkId=2156292).

Next is to filter the list, based on the parameters to get the version that you want to download.

Once it figured the right download url from the manifest file it will start downloading the right `esd` file, which will be converted to `.wim` with the edition that you need.

Lastly it is formatting the usb-drive and placing the installation media on it.
I wanted to use `NTFS` as the filesystem hosting the install files as it enables larger `.wim` files and/or driverpacks. So I used the [Rufus Bootloader](https://github.com/pbatard/uefi-ntfs) which will added to a smaller `FAT32` partition on the usb-drive which will initiate the bootsequence and loads the install files from the `NTFS` partition, which both will be created from my script.

## 🤝 Contributing

Before making your first contribution please see the following guidelines:
1. [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716)
1. [Git Tutorials](https://www.youtube.com/playlist?list=PLu-nSsOS6FRIg52MWrd7C_qSnQp3ZoHwW)
1. [Create a PR from a pushed branch](https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests?view=azure-devops&tabs=browser#from-a-pushed-branch)

---

Made with ❤️ by [Niklas Rast](https://github.com/niklasrst)