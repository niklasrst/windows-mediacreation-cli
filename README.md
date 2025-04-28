# 🪟 A Windows Media Creation CLI Tool 🪟

This repo contains my solution of a media creation tool to create Windows Installation media using PowerShell.

## Introduction
I´ve created this script as I wanted to automate the creation of usb-drives with Windows installation media.
So I came up with the idea to create a parameter based PowerShell script to ask for the needed details and then fully automated create a usb-drive, containing the Windows installation media. It currently supports the last 4 versions of Windows 10 and 11.

## How to use it?

```powershell
.\wmccli.ps1 -Version 11 -Architecture "x64" -Build "11-24H2" -LanguageCode "en-us" -Edition "CLIENTBUSINESS_VOL" -UsbDriveLetter "E:"
```

## How it works?
Firstly the script is looking for the windows manifest files:
Windows10 = "https://go.microsoft.com/fwlink/?LinkId=841361"
Windows11 = "https://go.microsoft.com/fwlink/?LinkId=2156292"

Next is to filter the list, based on the parameters to get the version that you want to download.

Once it figured the right download url from the manifest file it will start downloading the right `esd` file.

Lastly it is formatting the usb-drive and placing the installation media on it.

## Roadmap
[] Support for AutoUnattend files
[] Support to inject oem drivers
[] Support to remove unwanted editions from the esd
[] Add Troubleshooting tools for Windows Autopilot

## 🤝 Contributing

Before making your first contribution please see the following guidelines:
1. [Semantic Commit Messages](https://gist.github.com/joshbuchea/6f47e86d2510bce28f8e7f42ae84c716)
1. [Git Tutorials](https://www.youtube.com/playlist?list=PLu-nSsOS6FRIg52MWrd7C_qSnQp3ZoHwW)
1. [Create a PR from a pushed branch](https://learn.microsoft.com/en-us/azure/devops/repos/git/pull-requests?view=azure-devops&tabs=browser#from-a-pushed-branch)

---

Made with ❤️ by [Niklas Rast](https://github.com/niklasrst)