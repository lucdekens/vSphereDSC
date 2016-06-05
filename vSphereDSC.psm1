enum Ensure {
   Absent
   Present
}

enum VmwFolderType {
    Yellow
    Blue
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


