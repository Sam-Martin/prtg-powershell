function Set-PRTGCredentials{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$prtgURL,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PassHash
    )

    $Global:PRTGURL = "https://$prtgURL";
    $Global:PRTGUserName = $Username
    $Global:PRTGPassHash = $PassHash
    return $true
}

function Get-PRTGTable{
    param(
        [int]$numResults = 99999,
        [string]$columns="objid,device,host",
        [string]$content="devices",
        [string]$SortBy="objid",
        [ValidateSet("Desc","Asc")]
        [string]$SortDirection="Desc",
        [hashtable]$Filters
    )

    $SortDirectionPRTGStyle = if($SortDirection -eq "Desc"){"-"}else{''}

    $body =  @{
        content=$content;
        count=$numResults;
        output="xml";
        columns=$columns;
        sortby="$SortDirectionPRTGStyle$SortBy";
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    foreach($FilterName in $Filters.keys){
        $body.Add($FilterName,$Filters.$FilterName)
    }
    
    # Try to get the PRTG device tree
    try{
        $prtgDeviceTree = [xml](Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/table.xml" -Method Get -Body $Body)
    }catch{
        Write-Error "Failed to get PRTG Device tree $($_.exception.message)";
        return $false;
    }
    return $prtgDeviceTree
}

function Get-PRTGGroups{
    
    return Get-PRTGTable -content "groups" -columns "objid,probe,group,name,downsens,partialdownsens,downacksens,upsens,warnsens,pausedsens,unusualsens"
}

function Get-PRTGDevices{
    return Get-PRTGTable -content "devices" -columns "objid,probe,group,device,host,downsens,partialdownsens,downacksens,upsens,warnsens,pausedsens,unusualsens,undefinedsens"
}

function Get-PRTGDeviceByHostname{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$hostname = $env:computername
    )

    
    # Try to get the PRTG device tree
    try{
        $prtgDeviceTree = Get-PRTGTable -content "devices";
    }catch{
        Write-Error "Failed to get PRTG Device tree $($_.exception.message)";
        return $false;
    }
    
    $fqdn = $null;
    $ipAddress = $null;

    try{
        $fqdn = [System.Net.Dns]::GetHostByName($hostname).HostName;
    }catch{
        Write-Warning "Unable to get the FQDN for $hostname, match likelihood reduced";
    }
    try{
        $ipAddress = [System.Net.Dns]::GetHostAddresses($fqdn) | ?{$_.addressFamily -eq "InterNetwork"}; # Where IP address is ipv4
    }catch{
        Write-Warning "Unable to get the IP for $hostname, match likelihood reduced";
    }

    # Search for a PRTG device that matches either the hostname, the IP, or the FQDN
    $nameSearch = $prtgDeviceTree.devices.item | ?{
        $_.host -like $hostname -or 
        $_.host -eq $ipAddress -or 
        $_.host -like $fqdn
    }

    if(($nameSearch|Measure-Object).Count -eq 1){
    
        Write-Verbose "Found PRTG device #$($nameSearch.objid) - $($nameSearch.device)";

        return $nameSearch
    }else{
        Write-Error "There were $(($nameSearch|Measure-Object).Count) matches for this device in PRTG, need exactly 1";
    }
}

Function Copy-PRTGObject {
    param(
        # ID of the object to copy
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$ObjectId,
        
        # ID of the target parent object
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$TargetID,

        # Name of the newly cloned object
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        # Type of the object to copy
        [Parameter(Mandatory=$true)]
        [ValidateSet("sensor","group","device")]
        [string]$Type

    )

     $body =  @{
        id=$ObjectId;
        name=$Name;
        targetid=$TargetID;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    # Pluralise the type
    $TypePlural = $Type+'s';
    
    # Try to clone the object
    try{
        $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/duplicateobject.htm" -Method Get -Body $Body)
    }catch{
        Write-Error "Failed to clone object $($_.exception.message)";
        return $false;
    }

    # Fetch the ID of the object we just added
    $result = (Get-PRTGTable -numResults 100 -columns "objid,name" -SortBy "objid" -content $TypePlural -Filters @{"filter_name"=$Name}).$TypePlural.item | Sort-Object objid | select -First 1

    return $result
}

function Remove-PRTGObject{
    param(
        # ID of the object to delete
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$ObjectId
    )

    $body =  @{
        id=$ObjectId;
        approve=1;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }
    
    # Try to clone the object
    try{
        $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/deleteobject.htm " -Method Get -Body $Body)
    }catch{
        Write-Error "Failed to delete object $($_.exception.message)";
        return $false;
    }
    if($Result.StatusCode -eq 200){
        return $true
    }else{
        Write-Error "Failed to delete object";
        return $Result.Content
    }

}

function Set-PRTGObjectPaused{
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$ObjectId,
        
        # Length of time in minutes to pause the object, $null for indefinite
        [int]$PauseLength=$null,
        
        # Message to associate with the pause event
        [string]$PauseMessage="Paused by PSPRTG"
    )
    
    $body =  @{
        id=$ObjectId;
        pausemsg=$PauseMessage;
        action=0;
        duration=$PauseLength;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    if($PauseLength){
        $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/pauseobjectfor.htm" -Method Get -Body $Body)
    }else{
        $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/pause.htm" -Method Get -Body $Body)
    }

    return $result
}

function Set-PRTGObjectUnpaused{
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [int]$ObjectId
    )
    
    $body =  @{
        id=$ObjectId;
        action=1;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/pause.htm" -Method Get -Body $Body)
    if($Result.StatusCode -eq 200){
        return $true
    }else{
        return $result
    }
}