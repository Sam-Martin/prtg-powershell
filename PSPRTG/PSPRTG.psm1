function Set-PRTGCredentials{
    [CmdletBinding(SupportsShouldProcess)]
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

    if ($pscmdlet.ShouldProcess($env:COMPUTERNAME)){
        $Global:PRTGURL = "https://$prtgURL";
        $Global:PRTGUserName = $Username
        $Global:PRTGPassHash = $PassHash
        return $true
    }
}

function Get-PRTGTable{
    param(
        [int]$numResults = 99999,
        [string]$columns="objid,device,host",
        [string]$content="devices",
        [string]$SortBy="objid",
        [ValidateSet("Desc","Asc")]
        [string]$SortDirection="Desc",
        [hashtable]$Filters,
		# Added 20170628 JRW
		# Allows you to optionally set Parent Object of table query
		[string]$objectParentID
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

	# Added 20170628 JRW
	# If Parent Object provided, add to body hastable for query
	if (![string]::IsNullOrEmpty($objectParentID)) {
        $body.Add("id",$objectParentID)
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
        [string]$hostname
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
        $ipAddress = [System.Net.Dns]::GetHostAddresses($fqdn) | Where-Object {$_.addressFamily -eq "InterNetwork"}; # Where IP address is ipv4
    }catch{
        Write-Warning "Unable to get the IP for $hostname, match likelihood reduced";
    }

    # Search for a PRTG device that matches either the hostname, the IP, or the FQDN
    $nameSearch = $prtgDeviceTree.devices.item | Where-Object {
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
        [ValidateScript({$_ -gt 0})]
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
    $result = (Get-PRTGTable -numResults 100 -columns "objid,name" -SortBy "objid" -content $TypePlural -Filters @{"filter_name"=$Name}).$TypePlural.item | Sort-Object objid | Select-Object -First 1

    return $result
}

function Remove-PRTGObject{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # ID of the object to delete
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [int]$ObjectId
    )

    $body =  @{
        id=$ObjectId;
        approve=1;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    if ($Pscmdlet.ShouldProcess($ObjectId)) {

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
}

function Set-PRTGObjectPaused{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
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

    if ($Pscmdlet.ShouldProcess($ObjectId)) {

        if($PauseLength){
            $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/pauseobjectfor.htm" -Method Get -Body $Body)
        }else{
            $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/pause.htm" -Method Get -Body $Body)
        }

        return $result
    }
}

function Set-PRTGObjectUnpaused{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [int]$ObjectId
    )

    $body =  @{
        id=$ObjectId;
        action=1;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    if ($Pscmdlet.ShouldProcess($ObjectId)) {

        $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/pause.htm" -Method Get -Body $Body)
        if($Result.StatusCode -eq 200){
            return $true
        }else{
            return $result
        }
    }
}

function Set-PRTGObjectProperty{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [int]$ObjectId,

        # Name of the object's property to set
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName,

        # Value to which to set the property of the object
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyValue
    )

    $body =  @{
        id=$ObjectId;
        name=$PropertyName;
        value=$PropertyValue;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    if ($Pscmdlet.ShouldProcess($ObjectId)) {

        $Result =(Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/setobjectproperty.htm" -Method Get -Body $Body)
        if($Result.StatusCode -eq 200){
            return $true
        }else{
            return $result
        }
    }
}

function Get-PRTGObjectProperty{
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [int]$ObjectId,

        # Name of the object's property to get
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName
    )
    #https://prtg.sdlproducts.com/api/getobjectstatus.htm?id=18425&name=status
    $body =  @{
        id=$ObjectId;
        name=$PropertyName;
        username=$global:PRTGUsername;
        passhash=$global:PRTGPassHash;
    }

    $Result = ([xml](Invoke-WebRequest -UseBasicParsing -Uri "$prtgURL/api/getobjectstatus.htm" -Method Get -Body $Body)).prtg.result
    return $result

}

Function Get-PRTGObjectStatus{
    param(
        # ID of the object to pause/resume
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({$_ -gt 0})]
        [int]$ObjectId
    )

    $StatusMapping = @{
        1="Unknown"
        2="Scanning"
        3="Up"
        4="Warning"
        5="Down"
        6="No Probe"
        7="Paused by User"
        8="Paused by Dependency"
        9="Paused by Schedule"
        10="Unusual"
        11="Not Licensed"
        12="Paused Until"
    }

    try{
        $statusID = (Get-PRTGObjectProperty -ObjectId $ObjectId -PropertyName 'status' -ErrorAction Stop)
    }catch{
        Write-Error "Unable to get object status`r`n$($_.exception.message)";
        return $false;
    }
    $result = @{'objid'=$ObjectId;"status"=$StatusMapping[[int]$statusID];"status_raw"=$statusID}
    return $result
}
