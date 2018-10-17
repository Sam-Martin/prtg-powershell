# PSPRTG  
[![GitHub release](https://img.shields.io/github/release/Sam-Martin/prtg-powershell.svg)](https://github.com/Sam-Martin/prtg-powershell/releases/latest) [![GitHub license](https://img.shields.io/github/license/Sam-Martin/prtg-powershell.svg)](LICENSE) ![Test Coverage](https://img.shields.io/badge/coverage-81%25-yellowgreen.svg)  
This PowerShell module provides a series of cmdlets for interacting with the [PRTG API](https://prtg.paessler.com/api.htm?username=demo&password=demodemo&tabid=1), performed by wrapping `Invoke-WebRequest` for the API calls.  
**IMPORTANT:** Neither this module, nor its creator are in any way affiliated with PRTG, or Paessler AG.

## Requirements
Requires PowerShell 3.0 or above as this is when `Invoke-WebRequest` was introduced.

## Usage

This module is published to the PowerShell Gallery, so can be installed via:

```
Install-Module PSPRTG -Scope CurrentUser
```

Alternatively you can download the [latest release](https://github.com/Sam-Martin/prtg-powershell/releases/latest) and  extract the .psm1 and .psd1 files to your PowerShell profile directory (i.e. the `Modules` directory under wherever `$profile` points to in your PS console) and run:  
`Import-Module PSPRTG`  
Once you've done this, all the cmdlets will be at your disposal, you can see a full list using `Get-Command -Module PSPRTG`.

### Example - Cloning a Device
```
# Setup our default authentication
Set-PRTGCredentials -url "myprtgurl.com"  

# Set a Group ID (you can grab this from the URL of the group)
$GroupID = 12345

# Get a Device
$Device = Get-PRTGDeviceByHostname -hostname "MyServer"

# Copy the device
$NewDevice = Copy-PRTGObject -ObjectId $Device.objid -TargetID $GroupID -Name "Test2100" -Type 'device'

# Update the new device's hostname
Set-PRTGObjectProperty -PropertyName "host" -PropertyValue "MyServer.test.com" -ObjectId $NewDevice.objid

```

## Cmdlets


* Copy-PRTGObject
* Get-PRTGDeviceByHostname
* Get-PRTGDevices
* Get-PRTGGroups
* Get-PRTGObjectProperty
* Get-PRTGObjectStatus
* Get-PRTGTable
* Remove-PRTGObject
* Set-PRTGCredentials
* Set-PRTGObjectPaused
* Set-PRTGObjectProperty
* Set-PRTGObjectUnpaused


## Tests
This module comes with [Pester](https://github.com/pester/Pester/) tests for unit testing.

## Scope & Contributing
This module has been created as an abstraction layer to suit my immediate requirements. Contributions are gratefully received though!  
So please submit a pull request or raise an issue or both!
 

## Author
Author:: Sam Martin (<samjackmartin@gmail.com>)
