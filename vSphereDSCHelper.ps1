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

function Enable-PowerCLI
{
<#
.SYNOPSIS
  Load PowerCLI modules and PSSnapins
.DESCRIPTION
  This function will load all requested PowerCLI
  modules and PSSnapins.
  The function will, depending on the installed PowerCLI version,
  determine what needs to be loaded.
.NOTES
  Author:  Luc Dekens
.PARAMETER Cloud
  Switch to indicate if the Cloud related cmdlets shall be loaded
.PARAMETER InitScript
  The PowerCLI PSSnapin have associated initialisation scripts.
  This switch will indicate if that script needs to be executed or not.
.EXAMPLE
  PS> Enable-PowerCLI
.EXAMPLE
  PS> Enable-PowerCLI -Cloud
#>

    [CmdletBinding()]
    param(
       [switch]$Cloud=$false,
       [switch]$InitScript=$true
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 

    $Global:PSDefaultParameterValues = @{
        "Get-View:Verbose"=$false
        "Add-PSSnapin:Verbose"=$false
        "Import-Module:Verbose"=$false
    }

    $PcliPssnapin = @{
    'VMware.VimAutomation.License' = @(2548067)
    'VMware.DeployAutomation' =@(2548067,3056836,3205540,3737840)
    'VMware.ImageBuilder' = @(2548067,3056836,3205540,3737840)
  }
   
    $PcliModule = @{
    'VMware.VimAutomation.Core' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Vds' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Cloud' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.PCloud' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Cis.Core' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.Storage' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.HA' = @(2548067,3056836,3205540,3737840)
    'VMware.VimAutomation.vROps' = @(3056836,3205540,3737840)
    'VMware.VumAutomation' = @(3056836,3205540,3737840)
    'VMware.VimAutomation.License' = @(3056836,3205540,3737840)
  }
   
    # 32- or 64-bit process
    $procArch = (Get-Process -Id $Global:pid).StartInfo.EnvironmentVariables["PROCESSOR_ARCHITECTURE"]
    if($procArch -eq 'x86'){
      $regPath = 'HKLM:\Software\VMware, Inc.\VMware vSphere PowerCLI'
    }
    else{
      $regPath = 'HKLM:\Software\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI'
    }
     
    # Check if PowerCLI (regular or Tenant) is installed
    if(!(Test-Path -Path $regPath))
    {
      $regPath = $regPath.Replace('VMware vSphere PowerCLI','VMware vSphere PowerCLI for Tenants')
      if(!(Test-Path -Path $regPath))
      {
          Throw 'Can not find a PowerCLI installation!'       
      }
    }
     
    # Get build
    $buildKey = 'InstalledBuild'
    Try{
      $pcliBuild = Get-ItemProperty -Path $regPath -Name $buildKey |
          Select -ExpandProperty $buildKey -ErrorAction Stop
    }
    Catch{
      Throw "PowerCLI doesn't seem to be installed on this system!"
    }
    # Get installation path
    $installPathKey = 'InstallPath'
    Try{
      $pcliInstallPath = Get-ItemProperty -Path $regPath -Name $installPathKey |
          Select -ExpandProperty $installPathKey -ErrorAction Stop
    }
    Catch{
      Throw "PowerCLI doesn't seem to be installed on this system!"
    }
    # Load modules
    if($pcliBuild -ge 2548067)
    {
      $loadedModule = Get-Module -Name VMware* -ErrorAction SilentlyContinue | %{$_.Name}
      if($loadedModule -and $pcliBuild -ge 3737840)
      {
        $loadedModule = $loadedModule | where{$_ -notmatch 'Common$|SDK$'}
      }
     
      $targetModule = $PcliModule.GetEnumerator() | where{$_.Value -contains $pcliBuild} | %{$_.Key}
      $targetModule = $targetModule | where{$loadedModule -notcontains $_}
      if(!$Cloud)
      {
        $targetModule = $targetModule | where{$_ -notmatch 'Cloud'}
      }
      if($targetModule)
      {
        $targetModule | where{$loadedModule -notcontains $_.Name} | %{
          Import-Module -Name $_
        }
      }
    }
     
    # Load PSSnapin
    $loadedSnap = Get-PSSnapin -Name VMware* -ErrorAction SilentlyContinue -Verbose:$false | %{$_.Name}
    if($pcliBuild -ge 3737840)
    {
      $loadedSnap = $loadedSnap | where{$_ -notmatch 'Core$'}
    }
   
    $targetSnap = $PcliPssnapin.GetEnumerator() | where{$_.Value -contains $pcliBuild} | %{$_.Key}
    $targetSnap = $targetSnap | where{$loadedSnap -notcontains $_}
    if(!$Cloud)
    {
      $targetSnap = $targetSnap | where{$_ -notmatch 'Cloud'}
    }
    if($targetSnap)
    {
      $targetSnap | where{$loadedSnap -notcontains $_} | %{
        Add-PSSnapin -Name $_
   
        # Run initialisation script
        if($InitScript)
        {
          $filePath = "{0}Scripts\Initialize-{1}.ps1" -f $pcliInstallPath,$_.ToString().Replace(".", "_")
          if (Test-Path $filePath) {
            & $filePath
          }
        }
      }
    }

#    $global:VerbosePreference = $SaveVerbosePreference

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)"    
}

function Connect-VmwVIServer
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param(
        [string]$Server,
        [PSCredential]$Credential,
        [string]$Id
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Connect with credential $($Credential.UserName)"
    Write-Verbose -Message "$(Get-Date) SessionId $($Id)"

    Enable-PowerCLI
    
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings $false -Confirm:$false | Out-Null
    $srv = Connect-VIServer -Server $Server -Credential $Credential

    Write-Verbose -Message "$(Get-Date) Connected with credential $($Credential.UserName)"
    Write-Verbose -Message "$(Get-Date) $('Got session ID {0}' -f $srv.SessionId)"

    return $srv.SessionId

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Get-VmwNodeFromPath
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [PSObject]$StartNode = (Get-View -Id (Get-View -Id ServiceInstance).Content.RootFolder),
        [String]$Path
    )

    function Get-NodeChild{
        param(
            [VMware.Vim.ManagedEntity]$Node
        )
    
#        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
#        Write-Verbose -Message "$(Get-Date) Node: $($Node.Name)  Type: $($Node.GetType().Name)" 

        $hidden = 'vm','host','network','datastore','Resources'

# Switch uses break to only have one match
# Derived resources shall be high to low (Cluster vs SA Host)
#

        switch($Node){
            {$_ -is [VMware.Vim.Folder]}{
                if($Node.ChildEntity){
                    Get-View -Id $Node.ChildEntity
                }
                break
            }
            {$_ -is [VMware.Vim.Datacenter]}{
                $all = @()
                $all += Get-View -Id $Node.VmFolder
                $all += Get-View -Id $Node.HostFolder
                $all += Get-View -Id $Node.DatastoreFolder
                $all += Get-View -Id $Node.NetworkFolder
                $all = $all | %{
                    if($hidden -contains $_.Name){
                        Get-NodeChild -Node $_
                    }
                    else{
                        $_
                    }
                }
                $all | %{
                    if($_ -is [VMware.Vim.ComputeResource] -and $_ -isnot [VMware.Vim.ClusterComputeResource]){
                        Get-NodeChild -Node $_
                    }
                    else{
                        $_
                    }
                }
                break;
            }
            {$_ -is [VMware.Vim.ClusterComputeResource]}{
                $all = @()
                if($Node.Host){
                    $all += Get-View -Id $Node.Host
                }
                if($Node.ResourcePool){
                    $all += Get-View -Id $Node.ResourcePool
                }
                $all
                break;
            }
            {$_ -is [VMware.Vim.ComputeResource]}{
                $all = @()
                if($Node.ResourcePool){
                    $all += Get-View -Id $Node.ResourcePool
                }
                if($Node.Host){
                    $all += Get-View -Id $node.Host
                }
                $all
                break
            }
            {$_ -is [VMware.Vim.ResourcePool]}{
                $all = @()
                if($Node.ResourcePool){
                    $all += Get-View -Id $Node.ResourcePool
                }
                if($Node.vm){
                    $all += Get-View -Id $Node.vm
                }
                $all
                break
            }
            {$_ -is [VMware.Vim.DistributedVirtualSwitch]}{
                if($Node.Portgroup){
                    Get-View -Id $Node.Portgroup
                }
                break
            }
            {$_ -is [VMware.Vim.HostSystem]}{
                $all = @()
                $all += $_.Config.Network.Vswitch
                $all
                break
            }
        }
#        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Start: $($StartNode.Name)" 
    Write-Verbose -Message "$(Get-Date) Path: $($Path)" 

    $found = $true
 
    # Loop through Path
    $node = @($StartNode)
    foreach($qualifier in $Path.TrimStart('/').Split('/',[StringSplitOptions]::RemoveEmptyEntries)){
        Write-Verbose -Message "$(Get-Date) Qualifier: $($qualifier)"
        $nodeMatch = @($node) | %{
            Get-NodeChild -Node $_ | where{$_.Name -eq $qualifier}
        }
        if(!$nodeMatch){
            $found = $false
            $node = $null
            Write-Verbose -Message "$(Get-Date) No nodematch - break" 
            break
        }
        
        $node = $nodeMatch
    }
 
    Write-Verbose -Message "$(Get-Date) Nodes found $($node.Count)"

    if($node -eq $null){
        return New-Object PSObject -Property @{
            Path = $Path
            Found = $false
            Node = $null
        }
    }
    else{
        @($node) | %{
            return New-Object PSObject -Property @{
                Path = $Path
                Found = $true
                Node = $_
            }
        }
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Test-IsParentCorrect
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [VmwChildType]$ChildType
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose "$(Get-Date) Testing $($Parent) for childtype $($ChildType)"

    $parentOK = $false
    switch($ChildType){
        {$_ -eq [VmwChildType]::Folder} {
            If($Parent -is [VMware.Vim.Folder] -or $Parent -is [VMware.Vim.Datacenter]){
                $parentOK = $true
            }
        }
        {$_ -eq [VmwChildType]::Datacenter} {
            if($Parent -is [VMware.Vim.Folder] -and !(Test-VmwDatacenterIsNested -Node $Parent)){
                $parentOK = $true
            }
        }
        {$_ -eq [VmwChildType]::VMHost} {
            if($Parent -is [VMware.Vim.Datacenter] -or $Parent -is [VMware.Vim.ClusterComputeResource]){
                $parentOK = $true
            }
        }
        {$_ -eq [VmwChildType]::Cluster} {
            if($Parent -is [VMware.Vim.Datacenter]){
                $parentOK = $true
            }
        }
        {$_ -eq [VmwChildType]::Datastore} {
            if($Parent -is [VMware.Vim.Folder] -and $Parent.Name -eq 'Datastore'){
                $parentOK = $true
            }
        }
        {$_ -eq [VmwChildType]::VSS} {
            if($Parent -is [VMware.Vim.HostSystem] -or $Parent -is [VMware.Vim.ClusterComputeResource]){
                $parentOK = $true
            }
        }
    }
    
    Write-Verbose "$(Get-Date) Parent ok ? $($parentOK)"
    return $parentOK

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Test-VmwNodePath
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [PSObject]$StartNode = (Get-View -Id (Get-View -Id ServiceInstance).Content.RootFolder),
        [String]$Path
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Start: $($StartNode.Name)" 
    Write-Verbose -Message "$(Get-Date) Path: $($Path)" 

    $nodeObj = Get-VmwNodeFromPath -StartNode $StartNode -Path $Path
    
    return $nodeObj.Found

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwFolder
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$FolderName,
        [VmwFolderType]$FolderType
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Create a $($FolderType) folder, named $($FolderName), in $($Parent.Name) " 

    if($parent -is [VMware.Vim.Datacenter]){
       if($FolderType -eq [VmwFolderType]::Blue){
           $Parent.UpdateViewData('VmFolder')
           $leaf = Get-view -Id $parent.VmFolder -Property Name
       }
       else{
           $Parent.UpdateViewData('HostFolder')
           $leaf = Get-view -Id $parent.HostFolder -Property Name
       }
    }
    else{
       $leaf = $Parent
    }

    Write-Verbose -Message "$(Get-Date) Creating folder $($FolderName) at $($leaf.Name)" 
    $leaf.CreateFolder($FolderName) | Out-Null

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwFolder
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Folder
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove Folder, named $($Folder.Name)" 

    $Folder.Destroy() | Out-Null

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 

}

function Test-VmwFolderType
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [VMware.Vim.ManagedEntity]$Node,
        [VmwFolderType]$FolderType
    )
    
    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Testing if folder $($Node.Name) is $($FolderType)" 

    if($FolderType -eq [VmwFolderType]::Yellow)
    {
        $targetParent = 'host'
    }
    else
    {
        $targetParent = 'vm'
    }
    
    $si = Get-View -Id ServiceInstance
    $rootFolder = Get-View -Id $si.Content.RootFolder
    
    $foundType = $false
    if($Node.Parent -eq $rootFolder.MoRef -and $FolderType -eq [VmwFolderType]::Yellow){
        $foundType = $true
    }
    else{
        while($Node.Parent -ne $null){
            $Node = Get-View -Id $Node.Parent
            if($Node -is [VMware.Vim.Folder] -and $Node.Name -eq $targetParent){
                $foundType = $true
                break
            }
        }
    }

    Write-Verbose -Message "$(Get-Date) FoundType: $($foundType)" 
    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 

    return $foundType
}

function Test-VmwDatacenterIsNested
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Node
    )

    $isNested = $false
    $parent = $Node.MoRef
    while($parent){
        $parentObj = Get-View -Id $parent -Property Name,Parent
        if($parentObj -is [VMware.Vim.Datacenter]){
            $isNedsted = $true
        }
        $parent = $parentObj.Parent
    }
}

function New-VmwDatacenter
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$DatacenterName
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Create a datacenter, named $($DatacenterName), in $($Parent.Name) " 

    $si = Get-View -Id ServiceInstance
    $rootFolder = Get-View -Id $si.Content.RootFolder

    if($parent -is [VMware.Vim.Folder] -and
       (($parent.MoRef -eq $si.Content.RootFolder) -or 
       (Test-VmwFolderType -Node $Parent -FolderType ([VmwFolderType]::Yellow))) -and
       !(Test-VmwDatacenterIsNested -Node $Parent)){
       
       Write-Verbose -Message "$(Get-Date) Creating datacenter $($DatacenterName) at $($Parent.Name)" 
       $Parent.CreateDatacenter($DatacenterName) | Out-Null
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwDatacenter
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Datacenter
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove Datacenter, named $($VMHost.Name), from $($Parent.Name)" 

    $Datacenter.Destroy() | Out-Null

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwVMHost
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [PSCredential]$Credential,
        [String]$License,
        [Switch]$Force,
        [Switch]$MaintenanceMode
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Add a VMHost, named $($Name), in $($Parent.Name) " 

    $si = Get-View -Id ServiceInstance
    $rootFolder = Get-View -Id $si.Content.RootFolder

    $spec = New-Object VMware.Vim.HostConnectSpec
    $spec.Force = $Force
    $spec.HostName = $Name
    $spec.UserName = $credential.GetNetworkCredential().username
    $spec.Password = $credential.GetNetworkCredential().password

    if($Parent -is [VMware.Vim.Datacenter] -or 
        ($Parent -is [VMware.Vim.Folder] -and 
        (($parent.MoRef -eq $si.Content.RootFolder) -or 
         (Test-VmwFolderType -Node $Parent -FolderType ([VmwFolderType]::Yellow)))))
    {
        if($Parent -is [VMware.Vim.Datacenter]){
            $Parent.UpdateViewData('HostFolder')
            $Parent = Get-View -Id $Parent.HostFolder -Property Name
        }

        $taskMoRef = $Parent.AddStandaloneHost_Task($spec,$null,$true,$License)
    }
    elseif($Parent -is [VMware.Vim.ClusterComputeResource])
    {
        $taskMoRef = $Parent.AddHost_Task($spec,$true,$null,$License)    
    }
    $task = Get-View -Id $taskMoRef -Property Info.CompleteTime
    while(!$task.Info.CompleteTime){
        sleep 1
        $task.UpdateViewData('Info.CompleteTime')
    }
    $task.UpdateViewData('Info.Name','Info.Result')
    if($task.Info.Name -eq 'AddHost_Task'){
        $esx = Get-View -Id $task.Info.Result -Property Name
    }
    else{
        $cResource = Get-View -Id $task.Info.Result -Property Host
        $esx = Get-View -Id $cResource.Host[0] -Property Name
    }
    if($MaintenanceMode){
        Write-Verbose "$(Get-Date) Place/keep ESXi node in maintenace mode"
        $esx.EnterMaintenanceMode(0,$false,$null)
    }
    else{
        Write-Verbose "$(Get-Date) Exit maintenance mode for ESXi node"
        $esx.ExitMaintenanceMode(0)
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwVMHost
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$VMHost,
        [Switch]$Maintenance,
        [Switch]$InvRemove
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove VMHost, named $($VMHost.Name), from $($Parent.Name)" 

    if($Maintenance){
        Write-Verbose -Message "$(Get-Date) Enter maintenance mode on VMHost, named $($VMHost.Name)" 
        $timeout = 0
        $evacuatePoweredOffVms = $true
        $actions = $null
        $VMHost.EnterMaintenanceMode($timeout,$evacuatePoweredOffVms,$actions)
    }

    Write-Verbose -Message "$(Get-Date) Disconnect VMHost, named $($VMHost.Name)" 
    $VMHost.DisconnectHost() | Out-Null

    if($InvRemove){
        Write-Verbose -Message "$(Get-Date) Destroy VMHost, named $($VMHost.Name)" 
        $VMHost.Destroy()
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwCluster
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [PSCredential]$Credential,
        [Switch]$HA,
        [Switch]$DPM,
        [Switch]$DRS,
        [Switch]$VSAN
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Add a Cluster, named $($Name), in $($Parent.Name) " 

    if($Parent -is [VMware.Vim.Datacenter]){
        $Parent.UpdateViewData('HostFolder')
        $Parent = Get-View -Id $Parent.HostFolder -Property Name
    }

    $spec = New-Object VMware.Vim.ClusterConfigSpecEx

    $spec.DasConfig = New-Object VMware.Vim.ClusterDasConfigInfo
    $spec.DasConfig.Enabled = $HA
    $spec.DasConfig.HostMonitoring = [VMware.Vim.ClusterDasConfigInfoServiceState]::enabled
    $spec.DasConfig.VmMonitoring = [VMware.Vim.ClusterDasConfigInfoVmMonitoringState]::vmMonitoringDisabled
    $spec.DasConfig.AdmissionControlEnabled = $false
    $spec.DasConfig.AdmissionControlPolicy = New-Object VMware.Vim.ClusterFailoverLevelAdmissionControlPolicy
    $spec.DasConfig.AdmissionControlPolicy.FailOverLevel = 1
    $spec.DasConfig.HBDatastoreCandidatePolicy = [VMware.Vim.ClusterDasConfigInfoHBDatastoreCandidate]::allFeasibleDsWithUserPreference

    $spec.DpmConfig = New-Object VMware.Vim.ClusterDpmConfigInfo
    $spec.DpmConfig.Enabled = $DPM

    $spec.DrsConfig = New-Object VMware.Vim.ClusterDrsConfigInfo
    $spec.DrsConfig.Enabled = $DRS

    $spec.VsanConfig = New-Object VMware.Vim.VsanClusterConfigInfo
    $spec.VsanConfig.Enabled = $VSAN

    $Parent.CreateClusterEx($Name,$spec)    

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwCluster
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Cluster
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove Cluster, named $($Name), from $($Parent.Name)" 

    $options = @()
#    $options += New-Object VMware.Vim.OptionValue

    if($Cluster.host){
        $options = @()
#        $options += New-Object VMware.Vim.OptionValue
        $cluster.ClusterEnterMaintenanceMode($Cluster.host,$options)
    }
    $cluster.Destroy()

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwDatastore
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [VmwDatastoreType]$DatastoreType,
        [PSCredential]$Credential,
        [Parameter(ParameterSetName=’Local’)]
        [String]$LocalPath,
        [Parameter(ParameterSetName=’NFS’)]
        [String[]]$NFSHost,
        [Parameter(ParameterSetName=’NFS’)]
        [String]$NFSPath,
        [Parameter(ParameterSetName=’NFS’)]
        [ValidateSet('NFS','NFS41')]
        [String]$NFSVersion,
        [Parameter(ParameterSetName=’NFS’)]
        [ValidateSet('readOnly','readWrite')]
        [String]$NFSAccessMode,
        [Parameter(ParameterSetName=’NFS’)]
        [ValidateSet('AUTH_SYS','SEC_KRB5')]
        [String]$NFSSecurity,
        [Parameter(ParameterSetName=’VMFS’)]
        [String]$DiskName,
        [Parameter(ParameterSetName=’VMFS’)]
        [Int]$Partition,
        [Parameter(ParameterSetName=’VVOL’)]
        [String]$ContainerId
    )

    function New-VmwDatastoreOnVMHost{
        param(
            [VMware.Vim.HostSystem]$Esx
        )

        $Esx.UpdateViewData('ConfigManager')
        $hdsSystem = Get-View -Id $Esx.ConfigManager.DatastoreSystem
        switch($DatastoreType){
            {[VmwDatastoreType]::Local}{
                $hdsSystem.CreateLocalDatastore($Name,$localPath)
            }
            {[VmwDatastoreType]::NFS}{
                $spec = New-Object VMware.Vim.HostNasVolumeSpec
                $spec.AccessMode = [VMware.Vim.HostMountMode]$NFSAccessMode
                $spec.localPath = $Name
                if($NFSVersion -eq [VMware.Vim.HostFileSystemVolumeFileSystemType]::NFS41){
                    $spec.RemoteHostNames = $NFSHost
                    $spec.SecurityType = $NFSSecurity
                }
                elseif($NFSVersion -eq [VMware.Vim.HostFileSystemVolumeFileSystemType]::NFS){
                    $spec.RemoteHost = $NFSHost
                }
                $spec.RemotePath = $NFSPath
                $spec.Type = $NFSVersion
    
                $hdsSystem.CreateNasDatastore($spec)
            }
            {[VmwDatastoreType]::VMFS}{
                $spec = New-Object VMware.Vim.VmfsDatastoreCreateSpec
                $spec.vmfs = New-Object VMware.VIm.HostVmfsSpec
                $spec.Vmfs.VolumeName = $Name
                $spec.vmfs.extent = New-Object VMware.Vim.HostScsiDiskPartition
                $spec.Vmfs.Extent.DiskName = $DiskName
                $spec.Vmfs.Extent.Partition = $Partition
    
                $hdsSystem.CreateVmfsDatastore($spec)
            }
            {[VmwDatastoreType]::VVOL}{
                $spec = New-Object VMware.Vim.HostDatastoreSystemVvolDatastoreSpec
                $spec.Name = $Name
                $spec.ScId = $ContainerId

                $hdsSystem.CreateVvolDatastore($spec)
            }
        }
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Add a Datastore, named $($Name), in $($Parent.Name) " 

    if($Parent -is [VMware.Vim.ClusterComputeResource]){
        $Parent.UpdateViewData('Host')
        $Parent.Host | %{
              New-VmwDatastoreOnVMHost -Esx $_
        }  
    }
    elseif($Parent -is [VMware.Vim.HostSystem]){
        New-VmwDatastoreOnVMHost -Esx $Parent
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwDatastore
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Datastore
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove Datastore, named $($Name), from $($Parent.Name)" 

    $result = $Datastore.DatastoreEnterMaintenanceMode() | Out-Null
    if($result.drsFault){
        Write-Host -Message "$(Get-Date) DRS fault, attempt reason $($result.reason)"
        $result.drsFault | %{
            $vm = Get-view -Id $_.VM
            Write-Host -Message "$(Get-Date) DRS fault, reason $($result.reason)"
        }
    }
    if($result.Recommendations){
    
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwDatastoreCluster
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [PSCredential]$Credential
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Add a DatastoreCluster, named $($Name), in $($Parent.Name) " 

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwDatastoreCluster
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$DatastoreCluster
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove DatastoreCluster, named $($DatastoreCluster.Name), from $($Parent.Name)" 

    $result = $Datastore.DatastoreEnterMaintenanceMode() | Out-Null
    if($result.drsFault){
        Write-Host -Message "$(Get-Date) DRS fault, attempt reason $($result.reason)"
        $result.drsFault | %{
            $vm = Get-view -Id $_.VM
            Write-Host -Message "$(Get-Date) DRS fault, reason $($result.reason)"
        }
    }
    if($result.Recommendations){
    
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwVSS
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [PSCredential]$Credential,
        [int]$MTU = 1500,
        [int]$NumberOfPorts = 128,
        [string[]]$ANic,
        [string[]]$SNic
    )

    function New-VmwVSSOnVMHost{
        param(
            [VMware.Vim.HostSystem]$Esx
        )

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) Adding VSS $($Name) on $($Esx.Name)" 

        $Esx.UpdateViewData('ConfigManager.NetworkSystem')
        $netSystem = Get-View -Id $Esx.ConfigManager.NetworkSystem
        
        $spec = New-Object VMware.Vim.HostVirtualSwitchSpec
        $spec.Mtu = $MTU
        $spec.numPorts = $NumberOfPorts
        $spec.Policy = New-Object VMware.Vim.HostNetworkPolicy
        $spec.Policy.NicTeaming = New-Object VMware.Vim.HostNicTeamingPolicy
        if($ANic -or $SNic){
            $spec.Policy.NicTeaming.NicOrder = New-Object VMware.Vim.HostNicOrderPolicy
            # When Nic Teaming is used, the Bridge needs to be defined as well
            $spec.Bridge = New-Object VMware.Vim.HostVirtualSwitchBondBridge

            if($ANic){
                  $spec.Policy.NicTeaming.NicOrder.activeNic = $ANic
                  $spec.Bridge.NicDevice += $ANic
            }
            if($SNic){
                  $spec.Policy.NicTeaming.NicOrder.standbyNic = $SNic
                  $spec.Bridge.NicDevice += $SNic
            }
        }

        # Contrary to what the API Ref indicates, the following needs to be present
        # We take the ESXi 6 defaults
        # ==> Start
        $spec.Policy.NicTeaming.Policy = 'loadbalance_srcid'
        $spec.Policy.NicTeaming.FailureCriteria = New-Object VMware.Vim.HostNicFailureCriteria
        $spec.Policy.NicTeaming.FailureCriteria.CheckSpeed = 'minimum'
        $spec.Policy.NicTeaming.FailureCriteria.Speed = 10
        $spec.Policy.NicTeaming.FailureCriteria.CheckDuplex = $false
        $spec.Policy.NicTeaming.FailureCriteria.FullDuplex = $false
        $spec.Policy.NicTeaming.FailureCriteria.CheckErrorPercent = $false
        $spec.Policy.NicTeaming.FailureCriteria.Percentage = 0
        $spec.Policy.NicTeaming.FailureCriteria.CheckBeacon = $false
        $spec.Policy.NicTeaming.NotifySwitches = $true
        $spec.Policy.NicTeaming.ReversePolicy = $true
        $spec.Policy.NicTeaming.RollingOrder = $false
        $spec.Policy.Security = New-Object VMware.Vim.HostNetworkSecurityPolicy
        $spec.Policy.Security.AllowPromiscuous = $false
        $spec.Policy.Security.ForgedTransmits = $true
        $spec.Policy.Security.MacChanges = $true
        $spec.Policy.ShapingPolicy = New-Object VMware.Vim.HostNetworkTrafficShapingPolicy
        $spec.Policy.ShapingPolicy.Enabled = $false
        # ==> End

        $netSystem.AddVirtualSwitch($Name,$spec)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Add a VSS, named $($Name), in $($Parent.Name)" 

    if($Parent -is [VMware.Vim.ClusterComputeResource]){
        $Parent.UpdateViewData('Host')
        Get-View -Id $Parent.Host | %{
              New-VmwVSSOnVMHost -Esx $_
        }  
    }
    elseif($Parent -is [VMware.Vim.HostSystem]){
        New-VmwVSSOnVMHost -Esx $Parent
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Remove-VmwVSS
{
    [CmdletBinding()]
    param(
        [PSObject[]]$Parent,
        [string]$VSSName
    )

    function Remove-VmwVSSOnVMHost{
        param(
            [VMware.Vim.HostSystem]$Esx
        )

        $esx.UpdateViewData('ConfigManager.NetworkSystem')
        $netSystem = Get-View -Id $Esx.ConfigManager.NetworkSystem
        
        $netSystem.RemoveVirtualSwitch($VSSName)
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Remove VSS, named $($VSSName), from $($Parent.Name)" 

    if($Parent.Node -is [VMware.Vim.ClusterComputeResource]){
        $Parent.Node.UpdateViewData('Host')
        Get-View -Id $Parent.Node.Host | %{
              Remove-VmwVSSOnVMHost -Esx $_
        }  
    }
    elseif($Parent.Node -is [VMware.Vim.HostSystem]){
        Remove-VmwVSSOnVMHost -Esx $Parent.Node
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
}

function Test-VmwVSSConfig
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [PSCredential]$Credential,
        [int]$MTU = 1500,
        [int]$NumberOfPorts = 128,
        [string[]]$ANic,
        [string[]]$SNic
    )

    function Test-VmwVSSConfigOnVMHost{
        [CmdletBinding()]
        [OutputType([System.Boolean])]
        param(
            [VMware.Vim.HostSystem]$Esx
        )

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) Test VSS Config $($Name) on $($Esx.Name)"

        $Esx.UpdateViewData('ConfigManager.NetworkSystem')
        $netSystem = Get-View -Id $Esx.ConfigManager.NetworkSystem
        $vss = $netSystem.NetworkInfo.Vswitch | where{$_.Name -eq $Name}

        $correctConfig = $true
        if($vss.Numports -ne $numberOfPorts){$correctConfig = $false}
        if($vss.Mtu -ne $MTU){$correctConfig = $false}
        $actualANic = $vss.Spec.Policy.NicTeaming.NicOrder.ActiveNic
        if(!$actualANic){$actualANic = @()}
        if($ANic -and 
           (Compare-Object -ReferenceObject $ANic -DifferenceObject $actualANic)){
            $correctConfig = $false
        }
        $actualSNic = $vss.Spec.Policy.NicTeaming.NicOrder.StandbyNic
        if(!$actualSNic){$actualSNic = @()}
        if($Snic -and 
           (Compare-Object -ReferenceObject $SNic -DifferenceObject $actualSNic)){
            $correctConfig = $false
        }
        $actualBondNic = $vss.Spec.Bridge.NicDevice
        if(!$actualBondNic){$actualBondNic = @()}
        if(($Anic -or $SNic) -and 
           (Compare-Object -ReferenceObject ($ANic + $Snic) -DifferenceObject $actualBondNic) -and
           $vss.Spec.Bridge -isnot [VMware.Vim.HostVirtualSwitchBondBridge]){
            $correctConfig = $false
        }

        Write-Verbose -Message "$(Get-Date) Correct Config? $($correctConfig)"

        return $correctConfig
        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Test config VSS, named $($Name), on $($Parent.Name)" 

    $testResult = @()
    if($Parent -is [VMware.Vim.ClusterComputeResource]){
        $Parent.UpdateViewData('Host')
        Get-View -Id $Parent.Host | %{
              $testResult += (Test-VmwVSSConfigOnVMHost -Esx $_)
        }  
    }
    elseif($Parent -is [VMware.Vim.HostSystem]){
        $testResult += (Test-VmwVSSConfigOnVMHost -Esx $Parent)
    }
    
    Write-Verbose -Message "$(Get-Date) VSS config correct? $($testResult -notcontains $false)" 
    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 

    return ($testResult -notcontains $false)
}

function Set-VmwVSSConfig
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$Name,
        [PSCredential]$Credential,
        [int]$MTU = 1500,
        [int]$NumberOfPorts = 128,
        [string[]]$ANic,
        [string[]]$SNic
    )

    function Set-VmwVSSConfigOnVMHost{
        [CmdletBinding()]
        param(
            [VMware.Vim.HostSystem]$Esx
        )

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;">>Entering {0}" -f $s[0].FunctionName)" 
        Write-Verbose -Message "$(Get-Date) Set VSS Config $($Name) on $($Esx.Name)"

        $Esx.UpdateViewData('ConfigManager.NetworkSystem')
        $netSystem = Get-View -Id $Esx.ConfigManager.NetworkSystem
        $vss = $netSystem.NetworkInfo.Vswitch | where{$_.Name -eq $Name}

        $spec = $vss.Spec
        if($spec.Numports -ne $numberOfPorts){$spec.Numports = $numberOfPorts}
        if($spec.Mtu -ne $MTU){$spec.Mtu = $MTU}
        
        # Compare-Object doesn't allow $null on Reference- and DifferenceObject
        # Solved by replacing $null by an empty array

        $actualANic = $vss.Spec.Policy.NicTeaming.NicOrder.ActiveNic
        if(!$actualANic){$actualANic = @()}
        $desiredANic = $ANic
        if(!$desiredANic){$desiredANic = @()}
        if(Compare-Object -ReferenceObject $desiredANic -DifferenceObject $actualANic){
            $spec.Policy.NicTeaming.NicOrder.ActiveNic = $ANic
        }
        $actualSNic = $vss.Spec.Policy.NicTeaming.NicOrder.StandbyNic
        if(!$actualSNic){$actualSNic = @()}
        $desiredSNic = $SNic
        if(!$desiredSNic){$desiredSNic = @()}
        if(Compare-Object -ReferenceObject $desiredSNic -DifferenceObject $actualSNic){
            $spec.Policy.NicTeaming.NicOrder.StandbyNic = $SNic   
        }
        if($spec.Bridge -isnot [VMware.Vim.HostVirtualSwitchBondBridge]){
            $spec.Bridge = New-Object VMware.Vim.HostVirtualSwitchBondBridge
        }
        $actualBondNic = $vss.Spec.Bridge.NicDevice
        if(!$actualBondNic){$actualBondNic = @()}
        $desiredBondNic = $ANic + $SNic
        if(!$desiredBondNic){$desiredBondNic = @()}
        if(Compare-Object -ReferenceObject $desiredBondNic -DifferenceObject $actualBondNic){
           $spec.Bridge.NicDevice = $ANic +$Snic
        }        
        $netSystem.UpdateVirtualSwitch($Name,$spec)

        Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"<<Leaving {0}" -f $s[0].FunctionName)" 
    }

    if($Parent -is [VMware.Vim.ClusterComputeResource]){
        $Parent.UpdateViewData('Host')
        Get-View -Id $Parent.Host | %{
              Set-VmwVSSConfigOnVMHost -Esx $_
        }  
    }
    elseif($Parent -is [VMware.Vim.HostSystem]){
        Set-VmwVSSConfigOnVMHost -Esx $Parent
    }
}
