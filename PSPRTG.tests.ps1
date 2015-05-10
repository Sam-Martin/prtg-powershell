$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$DefaultsFile = "$here\PSPRTG.Pester.Defaults.json"

# Load defaults from file (merging into $global:LeanKitPesterTestDefaults
if(Test-Path $DefaultsFile){
    $defaults = if($global:PRTGPesterDefaults){$global:PRTGPesterDefaults}else{@{}};
    (Get-Content $DefaultsFile | Out-String | ConvertFrom-Json).psobject.properties | %{$defaults."$($_.Name)" = $_.Value}
    
    # Prompt for credentials
    $defaults.PasswordHash = if($defaults.PasswordHash){$defaults.PasswordHash}else{Read-Host "PasswordHash"}

    $global:PRTGPesterDefaults = $defaults
}else{
    Write-Error "$DefaultsFile does not exist. Created example file. Please populate with your values";
    
    # Write example file
    @{
        prtgURL = 'yourprtgurl.com';
        Username = "yourprtgusername";
        Hostname = "myserver";
        TestGroupID = 33948;

    } | ConvertTo-Json | Set-Content $DefaultsFile
    return;
}

Remove-Module PSPRTG -ErrorAction SilentlyContinue
Import-Module $here\PSPRTG.psd1
    

Describe "PSPRTG" {
    
    It "Set-PRTGCredentials Works"{
        Set-PRTGCredentials -UserName $Defaults.Username -PassHash $Defaults.PasswordHash -prtgURL $Defaults.prtgURL | Should Be $true
    }

    It "Get-PRTGDeviceByHostname Works"{
        $script:Device = Get-PRTGDeviceByHostname -hostname $defaults.Hostname 
        $Device.host| Should Be $defaults.Hostname
    }

    It "Copy-PRTGObject Works"{
        $script:CopiedObject = Copy-PRTGObject -ObjectId $Device.objid -TargetID $defaults.TestGroupID -Name "Test2100" -Type 'device';
        $CopiedObject.name | Should Be "Test2100"
    }

    It "Set-PRTGObjectUnpaused Works"{
        Set-PRTGObjectUnpaused -objectID $Device.objid | SHould Be $True
    }

    It "Set-PRTGObjectPaused Works"{
        Set-PRTGObjectPaused -objectID $Device.objid -PauseLength 5 | SHould Be $True
    }

    It "Remove-PRTGObject Works"{
        Remove-PRTGObject -ObjectId $CopiedObject.objid | Should Be $true
    }
   
} 