$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleRoot = "$here\..\PSPRTG"
$DefaultsFile = "$here\PSPRTG.Pester.Defaults.json"

If (-not $env:CI) {
    # Load defaults from file (merging into $global:LeanKitPesterTestDefaults
    if (Test-Path $DefaultsFile) {
        $defaults = if ($global:PRTGPesterDefaults) {$global:PRTGPesterDefaults}else {@{}
        };
        (Get-Content $DefaultsFile | Out-String | ConvertFrom-Json).psobject.properties | % {$defaults."$($_.Name)" = $_.Value}

        # Prompt for credentials
        $defaults.PasswordHash = if ($defaults.PasswordHash) {$defaults.PasswordHash}else {Read-Host "PasswordHash"}

        $global:PRTGPesterDefaults = $defaults
    }
    else {
        Write-Error "$DefaultsFile does not exist. Created example file. Please populate with your values";

        # Write example file
        @{
            prtgURL     = 'yourprtgurl.com';
            Username    = "yourprtgusername";
            Hostname    = "myserver";
            TestGroupID = 33948;

        } | ConvertTo-Json | Set-Content $DefaultsFile
        return;
    }
}


Remove-Module PSPRTG -ErrorAction SilentlyContinue

Describe 'Module Tests' {

    It "Module PSPRTG imports cleanly" {
        {Import-Module $ModuleRoot\PSPRTG.psd1 -Force } | Should -Not -Throw
    }

}

Import-Module $ModuleRoot\PSPRTG.psd1 -Force

#Integration tests : Use -ExcludeTag Integration if you do not have a test PRTG system to test against.
Describe "PSPRTG" -tag 'Integration' {

    It "Set-PRTGCredentials Works" {
        Set-PRTGCredentials -UserName $Defaults.Username -PassHash $Defaults.PasswordHash -prtgURL $Defaults.prtgURL | Should -Be $true
    }

    It "Get-PRTGDeviceByHostname Works" {
        $script:Device = Get-PRTGDeviceByHostname -hostname $defaults.Hostname
        $Device.host| Should -Be $defaults.Hostname
    }

    It "Copy-PRTGObject Works" {
        $script:CopiedObject = Copy-PRTGObject -ObjectId $Device.objid -TargetID $defaults.TestGroupID -Name "Test2100" -Type 'device';
        $CopiedObject.name | Should -Be "Test2100"
    }

    It "Set-PRTGObjectProperty Works" {
        $result = Set-PRTGObjectPRoperty -ObjectId $CopiedObject.objid -PropertyName 'host' -PropertyValue "test.fullyqualified.domain.name";
        $result | Should -Be $true
    }

    It "Set-PRTGObjectUnpaused Works" {
        Set-PRTGObjectUnpaused -objectID $CopiedObject.objid | Should -Be $True
    }

    It "Set-PRTGObjectPaused Works" {
        Set-PRTGObjectPaused -objectID $CopiedObject.objid -PauseLength 5 | SHould -Be $True
    }

    It "Get-PRTGObjectStatus Works" {
        $result = Get-PRTGObjectStatus -ObjectId $CopiedObject.objid
        $result.status_raw -gt 0 | Should -Be $true
    }

    It "Remove-PRTGObject Works" {
        Remove-PRTGObject -ObjectId $CopiedObject.objid | Should -Be $true
    }
}

#Mocked unit tests : can be run without requiring a PRTG test system to test against

InModuleScope -ModuleName PSPRTG {
    Describe 'Set-PRTGCredentials' {    
        It 'Should return $true' {
            Set-PRTGCredentials -Username 'someuser' -PassHash '1234abcd' -prtgURL 'fake.prtg.url' | Should -Be $true
        }

        It 'Should set $Global:PRTGURL to https://fake.prtg.url' {
            $Global:PRTGURL | Should -Be 'https://fake.prtg.url'
        }

        It 'Should set $Global:PRTGUserName to someuser' {
            $Global:PRTGUserName | Should -Be 'someuser'
        }

        It 'Should set $Global:PRTGPassHash to 1234abcd' {
            $Global:PRTGPassHash | Should -Be '1234abcd'
        }
    }

    Describe 'Get-PRTGTable' {
        Mock Invoke-WebRequest { }

        $Result = Get-PRTGTable

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    Describe 'Get-PRTGGroups' {
        Mock Invoke-WebRequest { }

        $Result = Get-PRTGGroups

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    Describe 'Get-PRTGDevices' {
        Mock Invoke-WebRequest { }

        $Result = Get-PRTGDevices

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    Describe 'Copy-PRTGObject' {
        Mock Invoke-WebRequest { }
        Mock Get-PRTGTable { }

        $Result = Copy-PRTGObject -ObjectId 1234 -TargetId 2345 -Name FakeName -Type sensor

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
        It 'Should call Get-PRTGTable 1 time' {
            Assert-MockCalled Get-PRTGTable -Times 1 -Exactly
        }
    }

    Describe 'Remove-PRTGObject' {
        Mock Invoke-WebRequest {
            [PSCustomObject]@{
                StatusCode = 200
            }
        }

        $Result = Remove-PRTGObject -ObjectId 1234

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    Describe 'Set-PRTGObjectPaused' {
        Mock Invoke-WebRequest { }

        Context 'Pause indefinitely' {
            $Result = Set-PRTGObjectPaused -ObjectId 1234

            It 'Should call Invoke-WebRequest 1 time' {
                Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
            }
        }
        Context 'Pause for 10 minutes' {
            $Result = Set-PRTGObjectPaused -ObjectId 1234 -PauseLength 10

            It 'Should call Invoke-WebRequest 1 time' {
                Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
            }
        }
    }

    Describe 'Set-PRTGObjectUnpaused' {
        Mock Invoke-WebRequest { }

        $Result = Set-PRTGObjectUnpaused -ObjectId 1234

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    Describe 'Set-PRTGObjectProperty' {
        Mock Invoke-WebRequest { }

        $Result = Set-PRTGObjectProperty -ObjectId 1234 -PropertyName SomeProperty -PropertyValue SomeValue

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
        }
    }

    Describe 'Get-PRTGObjectStatus' {
        Mock Get-PRTGObjectProperty { }

        $Result = Get-PRTGObjectStatus -ObjectId 1234

        It 'Should call Invoke-WebRequest 1 time' {
            Assert-MockCalled Get-PRTGObjectProperty -Times 1 -Exactly
        }
    }
}