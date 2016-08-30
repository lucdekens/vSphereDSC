enum Ensure {
   Absent
   Present
}

enum Active {
    Enabled
    Disabled
}

enum VmwFolderType {
    Yellow
    Blue
}

enum VmwAlarmExpression {
    Event
    Metric
    State
}

enum VmwAlarmTrigger {
    GreenYellow
    YellowRed
    RedYellow
    YellowGreen
}

$PSDefaultParameterValues = @{
    "Get-View:Verbose"=$false
    "Add-PSSnapin:Verbose"=$false
    "Import-Module:Verbose"=$false
}

[DscResource()]
class VmwFolder 
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty()]
    [Ensure]$Ensure
    [DscProperty(Key)]
    [VmwFolderType]$Type
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    [DscProperty()]
    hidden[String]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}-{3}' -f $this.vServer,$this.Name,$this.Path,$this.Type)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $folderPresent = $this.TestVmwFolder()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $folderPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating the folder $($this.Name) at $($this.Path)"
                $this.NewVmwFolder()
            }
        }
        else
        {
            if ($folderPresent)
            {
                Write-Verbose -Message "$(Get-Date) Deleting the folder $($this.Name) at $($this.Path)"
                $this.RemoveVmwFolder()
            }
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}-{3}' -f $this.vServer,$this.Name,$this.Path,$this.Type)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $folderPresent = $this.TestVmwFolder()
        Write-Verbose -Message "$(Get-Date) Folder Present $($folderPresent)"

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $folderPresent
        }
        else
        {
            return -not $folderPresent
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [VmwFolder]Get()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

        return $this.GetVmwFolder()

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion

#region VmwFolder Helper Functions
    [bool]TestVmwFolder()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for a $($this.Type) folder, named $($this.Name) at $($this.Path)" 

        if($this.Path -match "/$"){
            $nodePath = "$($this.Path)$($this.Name)"
        }
        else{
            $nodePath = "$($this.Path)/$($this.Name)"
        }
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeFound = Get-VmwNodeFromPath -Path $nodePath | 
            where {$_.Found -and (Test-VmwFolderType -Node $_.Node -FolderType $this.Type)}

        Write-Verbose -Message "$(Get-Date) Find it ? $($nodeFound -ne $null)" 
        return ($nodeFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwFolder()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            New-VmwFolder -Parent $parent.Node -FolderName $this.Name -FolderType $this.Type
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwFolder()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

        if($this.Path -match "/$"){
            $nodePath = "$($this.Path)$($this.Name)"
        }
        else{
            $nodePath = "$($this.Path)/$($this.Name)"
        }

        $folder = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($folder.Found){
            $folder.Node.Destroy() | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwDatacenter
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty()]
    [Ensure]$Ensure
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        if(!($global:DefaultVIServer.SessionId -eq $this.vSessionId) -or !$global:DefaultVIServer.IsConnected)
        {
            $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential
        }

        $dcPresent = $this.TestVmwDatacenter()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $dcPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating the datacenter $($this.Path)/$($this.Name)"
                $this.NewVmwDatacenter()
            }
        }
        else
        {
            if ($dcPresent)
            {
                Write-Verbose -Message "$(Get-Date) Deleting the datacenter $($this.Path)/$($this.Name)"
                $this.RemoveVmwDatacenter()
            }
        }
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        if(!($global:DefaultVIServer.SessionId -eq $this.vSessionId) -or !$global:DefaultVIServer.IsConnected)
        {
            $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential
        }

        $dcPresent = $this.TestVmwDatacenter()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $dcPresent
        }
        else
        {
            return -not $dcPresent
        }
    }
    
    [VmwDatacenter]Get()
    {
        return $this.GetVmwDatacenter()
    }
#endregion

#region VmwDatacenter Helper Functions
    [bool]TestVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

        if($this.GetVmwDatacenter()){
            return $true
        }    
        else{
            return $false
        }
    }

    [string]GetVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

        $obj = $null
        $sView = @{
              ViewType = 'Datacenter'
              Property = 'Name','Parent'
              Filter = @{
                  Name = $this.Name
              }
        }
        $dc = Get-View @sView
        if($dc){
                $obj = $dc.MoRef.ToString()
        }
        return $obj
    }

    [void]NewVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)"

        $node = Find-VmwLeaf -Path $this.Path
       
        if($node){
            # Take action on node
            $node = Get-View -Id $node -Property Name,ChildEntity
            if(!$node.ChildEntity -or (Get-View -Id $node.ChildEntity -Property Name).Name -notcontains $this.Name){
                $node.CreateDatacenter($this.Name) | Out-Null
            }
        }
    
    }

    [void]RemoveVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)"

        $node = Find-VmwLeaf -Path $this.Path
       
        if($node){
            $node = Get-View -Id $node -Property Name
            $sView = @{
                ViewType = 'Datacenter'
                SearchRoot = $node.MoRef
                Filter = @{
                    Name = $this.Name
                }
                ErrorAction = 'SilentlyContinue'
            }
            $dc = Get-View @sView
            if($dc){
                $dc.Destroy()
             }

        }    
    }
#endregion
}

[DscResource()]
class VmwAlarm 
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty()]
    [Ensure]$Ensure
    [DscProperty()]
    [Active]$Active
    [DscProperty(Key)]
    [VmwAlarmExpression]$Type
    [DscProperty()]
    [VmwAlarmTrigger]$Trigger
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    [DscProperty()]
    hidden[String]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}-{3}' -f $this.vServer,$this.Name,$this.Path,$this.Type)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $alarmPresent = $this.TestAlarm()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $alarmPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating the alarm $($this.Name) at $($this.Path)"
                $this.NewVmwAlarm()
            }
        }
        else
        {
            if ($alarmPresent)
            {
                Write-Verbose -Message "$(Get-Date) Deleting the alarm $($this.Name) at $($this.Path)"
                $this.RemoveVmwAlarm()
            }
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}-{3}' -f $this.vServer,$this.Name,$this.Path,$this.Type)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $alarmPresent = $this.TestVmwAlarm()
        Write-Verbose -Message "$(Get-Date) Alarm Present $($alarmPresent)"

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $alarmPresent
        }
        else
        {
            return -not $alarmPresent
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [VmwAlarm]Get()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

        return $this.GetVmwAlarm()

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion

#region VmwAlarm Helper Functions
    [bool]TestAlarm()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for a $($this.Type) alarm, named $($this.Name) at $($this.Path)" 

        if($this.Path -match "/$"){
            $nodePath = "$($this.Path)$($this.Name)"
        }
        else{
            $nodePath = "$($this.Path)/$($this.Name)"
        }
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeFound = Get-VmwAlarmFromPath -Path $nodePath | 
            where {$_.Found -and (Test-VmwAlarm -Node $_.Node)}

        Write-Verbose -Message "$(Get-Date) Find it ? $($nodeFound -ne $null)" 
        return ($nodeFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwAlarm()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwAlarmFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            New-VmwAlarm -Parent $parent.Node -AlarmName $this.Name
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwAlarm()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

        if($this.Path -match "/$"){
            $nodePath = "$($this.Path)$($this.Name)"
        }
        else{
            $nodePath = "$($this.Path)/$($this.Name)"
        }

        $alarm = Get-VmwAlarmFromPath -Path $nodePath

        # Take action on alarm
        if($alarm.Found){
            $alarm.Node.Destroy() | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}
