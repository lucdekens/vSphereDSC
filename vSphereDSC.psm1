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

enum VmwDatastoreType {
    Local
    NFS
    VMFS
    VVOL
}

enum VmwChildType {
    Datacenter
    Folder
    VMHost
    Cluster
    Datastore
    VSS
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
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
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
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
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
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [VmwFolder]Get()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        return $this

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion

#region VmwFolder Helper Functions
    [bool]TestVmwFolder()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for a $($this.Type) folder, named $($this.Name) at $($this.Path)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeFound = Get-VmwNodeFromPath -Path $nodePath | 
            where {$_.Found -and (Test-VmwFolderType -Node $_.Node -FolderType $this.Type)}

        Write-Verbose -Message "$(Get-Date) Found it ? $($nodeFound -ne $null)" 
        return ($nodeFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwFolder()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            New-VmwFolder -Parent $parent.Node -FolderName $this.Name -FolderType $this.Type
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwFolder()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $folder = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($folder.Found){
            Remove-VmwFolder -Folder $folder.Node
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
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
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $dcPresent = $this.TestVmwDatacenter()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $dcPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating the datacenter $($this.Name) at $($this.Path)"
                $this.NewVmwDatacenter()
            }
        }
        else
        {
            if ($dcPresent)
            {
                Write-Verbose -Message "$(Get-Date) Deleting the datacenter $($this.Name) at $($this.Path)"
                $this.RemoveVmwDatacenter()
            }
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $dcPresent = $this.TestVmwDatacenter()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $dcPresent
        }
        else
        {
            return -not $dcPresent
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
    
    [VmwDatacenter]Get()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        return $this

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion

#region VmwDatacenter Helper Functions
    [bool]TestVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeFound = Get-VmwNodeFromPath -Path $nodePath | where {$_.Found}

        Write-Verbose -Message "$(Get-Date) Found it ? $($nodeFound -ne $null)" 
        return ($nodeFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            New-VmwDatacenter -Parent $parent.Node -DatacenterName $this.Name
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwDatacenter()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $datacenter = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($datacenter.Found){
            Remove-VmwDatacenter -Datacenter $datacenter.Node | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwVMHost
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty()]
    [string]$License
    [DscProperty()]
    [Ensure]$Ensure
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    [DSCProperty(Mandatory)]
    [PSCredential]$eCredential
    [DscProperty()]
    [bool]$MaintenanceMode = $true
    [DscProperty()]
    [bool]$RemoveFromIventory = $true
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $esxPresent = $this.TestVmwVMHost()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $esxPresent)
            {
                Write-Verbose -Message "$(Get-Date) Connecting ESXi node $($this.Path)/$($this.Name)"
                $this.NewVmwVMHost()
            }
        }
        else
        {
            if ($esxPresent)
            {
                Write-Verbose -Message "$(Get-Date) Removing ESXi node $($this.Path)/$($this.Name)"
                $this.RemoveVmwVMHost()
            }
        }
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $esxPresent = $this.TestVmwVMHost()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $esxPresent
        }
        else
        {
            return -not $esxPresent
        }
    }
    
    [VmwVMHost]Get()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        return $this

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion

#region VmwVMHost Helper Functions
    [bool]TestVmwVMHost()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeFound = Get-VmwNodeFromPath -Path $nodePath | where {$_.Found}

        Write-Verbose -Message "$(Get-Date) Found it ? $($nodeFound -ne $null)" 
        return ($nodeFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwVMHost()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found -and (Test-IsParentCorrect -Parent $parent.Node -ChildType ([VmwChildType]::VMHost))){
            $sVMHost = @{
                Parent = $parent.Node
                Name = $this.Name
                Credential = $this.eCredential
                License = $this.License
                Force = $this.Force
                MaintenanceMode = $this.MaintenanceMode
            }
            New-VmwVMHost @sVMHost
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwVMHost()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $vmhost = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($vmhost.Found){
            Remove-VmwVMHost -VMHost $vmhost.Node -Maintenance:$this.MaintenanceMode -InvRemove:$this.RemoveFromIventory | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwCluster
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty()]
    [Ensure]$Ensure
    [DscProperty()]
    [bool]$HA
    [DscProperty()]
    [bool]$DRS
    [DscProperty()]
    [bool]$DPM = $false
    [DscProperty()]
    [bool]$VSAN = $false
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $clusterPresent = $this.TestVmwCluster()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $clusterPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating cluster $($this.Path)/$($this.Name)"
                $this.NewVmwCluster()
            }
        }
        else
        {
            if ($clusterPresent)
            {
                Write-Verbose -Message "$(Get-Date) Removing cluster $($this.Path)/$($this.Name)"
                $this.RemoveVmwCluster()
            }
        }
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $clusterPresent = $this.TestVmwCluster()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $clusterPresent
        }
        else
        {
            return -not $clusterPresent
        }
    }
    
    [VmwCluster]Get()
    {
        return $this.GetVmwCluster()
    }
#endregion

#region VmwCluster Helper Functions
    [bool]TestVmwCluster()
    {
        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeFound = Get-VmwNodeFromPath -Path $nodePath | where {$_.Found}

        Write-Verbose -Message "$(Get-Date) Found it ? $($nodeFound -ne $null)" 
        return ($nodeFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwCluster()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            $sCluster = @{
                Parent = $parent.Node
                Name = $this.Name
                Credential = $this.eCredential
                HA = $this.HA
                DPM = $this.DPM
                DRS = $this.DRS
                VSAN = $this.VSAN
            }
            New-VmwCluster @sCluster
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwCluster()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $cluster = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($cluster.Found){
            Remove-VmwCluster -Cluster $cluster.Node | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwDatastore
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty(Mandatory)]
    [VmwDatastoreType]$DatastoreType
    [DscProperty()]
    [String]$LocalPath
    [DscProperty()]
    [String[]]$NFSHost
    [DscProperty()]
    [String]$NFSPath
    [DscProperty()]
    [String]$NFSAccessMode
    [DscProperty()]
    [String]$NFSVersion
    [DscProperty()]
    [String]$NFSSecurity
    [DscProperty()]
    [String]$DiskName
    [DscProperty()]
    [Int]$Partition
    [DscProperty()]
    [String]$ContainerId
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
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $datastorePresent = $this.TestVmwDatastore()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $datastorePresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating Datastore $($this.Path)/$($this.Name)"
                $this.NewVmwDatastore()
            }
        }
        else
        {
            if ($datastorePresent)
            {
                Write-Verbose -Message "$(Get-Date) Removing Datastore $($this.Path)/$($this.Name)"
                $this.RemoveVmwDatastore()
            }
        }
    }
    
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $datastorePresent = $this.TestVmwDatastore()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $datastorePresent
        }
        else
        {
            return -not $datastorePresent
        }
    }
    
    [VmwDatastore]Get()
    {
        return $this.GetVmwDatastore()
    }
#endregion

#region VmwDatastore Helper Functions
    [bool]TestVmwDatastore()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $dsFound = Get-VmwNodeFromPath -Path $nodePath | where {$_.Found}

        Write-Verbose -Message "$(Get-Date) Found it ? $($dsFound -ne $null)" 
        return ($dsFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwDatastore()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            $sDatastore = @{
                DatastoreType = $this.DatastoreType
                Parent = $parent.Node
                Name = $this.Name
                LocalPath = $this.LocalPath
                NFSHost = $this.NFSHost
                NFSPath = $this.NFSPath
                NFSVersion = $this.NFSVersion
                NFSAccessMode = $this.NFSAccessMode
                NFSSecurity = $this.NFSSecurity
                DiskName = $this.DiskName
                Partition = $this.Partition
                ContainerId = $this.ContainerId
            }
            New-VmwDatastore @sDatastore
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwDatastore()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $ds = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($ds.Found){
            Remove-VmwDatastore -Datastore $ds.Node | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwDatastoreCluster
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $dscPresent = $this.TestVmwDatastoreCluster()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $dscPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating DatastoreCluster $($this.Path)/$($this.Name)"
                $this.NewVmwDatastoreCluster()
            }
        }
        else
        {
            if ($dscPresent)
            {
                Write-Verbose -Message "$(Get-Date) Removing DatastoreCluster $($this.Path)/$($this.Name)"
                $this.RemoveVmwDatastoreCluster()
            }
        }
    }
    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $esxPresent = $this.TestVmwDatastoreCluster()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $esxPresent
        }
        else
        {
            return -not $esxPresent
        }
    }
    [VmwDatastoreCluster]Get()
    {
        return $this
    }
#endregion

#region VmwDatastoreCluster Helper Functions
    [bool]TestVmwDatastoreCluster()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $dscFound = Get-VmwNodeFromPath -Path $nodePath | where {$_.Found}

        Write-Verbose -Message "$(Get-Date) Found it ? $($dscFound -ne $null)" 
        return ($dscFound -ne $null)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwDatastoreCluster()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $parent = Get-VmwNodeFromPath -Path "$($this.Path)"

        # Take action on node
        if($parent.Found){
            $sDSC = @{
                Parent = $parent.Node
                Name = $this.Name
                Credential = $this.eCredential
            }
            New-VmwDatastoreCluster @sDSC
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwDatastoreCluster()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $dsc = Get-VmwNodeFromPath -Path $nodePath

        # Take action on node
        if($dsc.Found){
            Remove-VmwDatastoreCluster -DatastoreCluster $dsc.Node | Out-Null
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwVSS
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty()]
    [int]$MTU
    [DscProperty()]
    [int]$NumberOfPorts
    [DscProperty()]
    [string[]]$ANic
    [DscProperty()]
    [string[]]$SNic
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
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $vssPresent = $this.TestVmwVSS()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            if(-not $vssPresent)
            {
                Write-Verbose -Message "$(Get-Date) Creating VSS $($this.Path)/$($this.Name)"
                $this.NewVmwVSS()
            }
        }
        else
        {
            if ($vssPresent)
            {
                Write-Verbose -Message "$(Get-Date) Removing VSS $($this.Path)/$($this.Name)"
                $this.RemoveVmwVSS()
            }
        }
    }

    [bool]Test()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $vssPresent = $this.TestVmwVSS()

        if ($this.Ensure -eq [Ensure]::Present)
        {
            return $vssPresent
        }
        else
        {
            return -not $vssPresent
        }
    }

    [VmwVSS]Get()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) $('{0}-{1}-{2}' -f $this.vServer,$this.Name,$this.Path)"

        . "$($PSScriptRoot)\vSphereDSCHelper.ps1"

        $this.vSessionId = Connect-VmwVIServer -Server $this.vServer -Credential $this.vCredential -Id $this.vSessionId

        $vssPresent = $this.TestVmwVSS()

        if ($vssPresent)
        {
            $vss = $this.GetVmwVss
            $this.MTU = $vss.Spec.Mtu
            $this.NumberOfPorts = $vss.Spec.numPorts
            $this.ANic = $vss.Policy.NicTeaming.NicOrder.activeNic
            $this.SNic = $vss.Policy.NicTeaming.NicOrder.standbyNic
            $this.Ensure = [Ensure]::Present
        }
        else
        {
            $this.Ensure = [Ensure]::Absent
        }
        
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
        return $this
    }
#endregion

#region VmwVSS Helper Functions
    [bool]TestVmwVSS()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"
        Write-Verbose -Message "$(Get-Date) Looking for $($nodePath)"
        
        $nodeCorrect = $false
        $nodeFound = Get-VmwNodeFromPath -Path $nodePath | where {$_.Found}
        Write-Verbose -Message "$(Get-Date) Found it ? $($nodeFound -ne $null)"
        if($nodeFound.Found){
            $parent = Get-VmwNodeFromPath -Path $this.Path
            $sVSSConfig = @{
                Parent = $parent.Node
                Name = $this.Name
                MTU = $this.MTU
                NumberOfPorts = $this.NumberOfPorts
                ANic = $this.ANic
                SNic = $this.SNic
            }
            $nodeCorrect = Test-VmwVSSConfig @sVSSConfig
            Write-Verbose -Message "$(Get-Date) Config correct ? $($nodeCorrect)"
        }
         
        return ($nodeFound.Found -and $nodeCorrect)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]NewVmwVSS()
    {
        Write-Verbose -Message "$(Get-Date)  $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)"
        Write-Verbose -Message "$(Get-Date) Looking for parent $($this.Path)" 

        $node = Get-VmwNodeFromPath -Path "$($this.Path.TrimEnd('/'))/$($this.Name)"
        $parent = @(Get-VmwNodeFromPath -Path "$($this.Path)")
        $sVSS = @{
            Parent = $parent.Node
            Name = $this.Name
            Credential = $this.eCredential
            MTU = $this.MTU
            NumberOfPorts = $this.NumberOfPorts
            ANic = $this.ANic
            SNic = $this.SNic
        }

        # Node config
        if($node.Found){
            Set-VmwVSSConfig @sVSS
        }
        # Node new
        else{
            # Take action on node
            $parent | %{
                if($_.Found -and (Test-IsParentCorrect -Parent $_.Node -ChildType ([VmwChildType]::VSS))){
                    New-VmwVSS @sVSS
                }
            }
        }

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }

    [void]RemoveVmwVSS()
    {
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">Entering {0}" -f $s[0].FunctionName)" 

        $nodePath = "$($this.Path.TrimEnd('/'))/$($this.Name)"

        $vss = @(Get-VmwNodeFromPath -Path $nodePath)

        # Take action on node
        $vss | %{
            if($_.Found){
                $parent = @(Get-VmwNodeFromPath -Path "$($this.Path)")
                Remove-VmwVSS -Parent $parent -VSS $this.Name | Out-Null
            }
        }
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<Leaving {0}" -f $s[0].FunctionName)" 
    }
#endregion
}

[DscResource()]
class VmwVSSPortgroup
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {}
    [bool]Test()
    {
        return $true
    }
    [VmwVSSPortgroup]Get()
    {
        return $this
    }
#endregion

#region VmwVSSPortgroup Helper Functions
#endregion
}

[DscResource()]
class VmwVDS
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {}
    [bool]Test()
    {
        return $true
    }
    [VmwVDS]Get()
    {
        return $this
    }
#endregion

#region VmwVDS Helper Functions
#endregion
}

[DscResource()]
class VmwVDSPortgroup
{
#region Properties
    [DscProperty(Key)]
    [string]$Name
    [DscProperty(Key)]
    [string]$Path
    [DscProperty(Mandatory)]
    [string]$vServer
    [DscProperty(Mandatory)]
    [PSCredential]$vCredential
    hidden[string]$vSessionId
#endregion

#region DSC Functions
    [void]Set()
    {}
    [bool]Test()
    {
        return $true
    }
    [VmwVDSPortgroup]Get()
    {
        return $this
    }
#endregion

#region VmwVDSPortgroup Helper Functions
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
