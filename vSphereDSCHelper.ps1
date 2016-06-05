enum VmwFolderType {
    Yellow
    Blue
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

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 

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

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)"    
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

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Connect with credential $($Credential.UserName)"
    Write-Verbose -Message "$(Get-Date) SessionId $($Id)"

    Enable-PowerCLI
    
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -DisplayDeprecationWarnings $false -Confirm:$false | Out-Null
    $srv = Connect-VIServer -Server $Server -Credential $Credential

    Write-Verbose -Message "$(Get-Date) Connected with credential $($Credential.UserName)"
    Write-Verbose -Message "$(Get-Date) $('Got session ID {0}' -f $srv.SessionId)"

    return $srv.SessionId

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
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
    
        $hidden = 'vm','host','network','datastore','Resources'
        switch($Node){
            {$_ -is [VMware.Vim.Folder]}{
                if($Node.ChildEntity){
                    Get-View -Id $Node.ChildEntity
                }
            }
            {$_ -is [VMware.Vim.Datacenter]}{
                $all = @()
                $all += Get-View -Id $Node.VmFolder
                $all += Get-View -Id $Node.HostFolder
                $all += Get-View -Id $Node.DatastoreFolder
                $all += Get-View -Id $Node.NetworkFolder
                $all | %{
                    if($hidden -contains $_.Name){
                        Get-NodeChild -Node $_
                    }
                    else{
                        $_
                    }
                }
            }
            {$_ -is [VMware.Vim.ClusterComputeResource]}{
                $all = @()
                $all += Get-View -Id $Node.Host
                $all += Get-View -Id $Node.ResourcePool 
                $all = $all | %{
                    if($hidden -contains $_.Name){
                        Get-NodeChild -Node $_
                    }
                    else{
                        $_
                    }
                }
                $all
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
            }
            {$_ -is [VMware.Vim.DistributedVirtualSwitch]}{
                Get-View -Id $Node.Portgroup
            }
        }
    }

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Start: $($StartNode.Name)" 
    Write-Verbose -Message "$(Get-Date) Path: $($Path)" 

    $found = $true
 
    # Loop through Path
    $node = @($StartNode)
    foreach($qualifier in $Path.TrimStart('/').Split('/',[StringSplitOptions]::RemoveEmptyEntries)){
        $nodeMatch = @($node) | %{
            Get-NodeChild -Node $_ | where{$_.Name -eq $qualifier}
        }
        if(!$nodeMatch){
            $found = $false
            $node = $null
            break
        }
        $node = $nodeMatch
    }
 
    Write-Verbose -Message "$(Get-Date) Nodes found $($node.Count)"
    Write-Verbose -Message "$(Get-Date) Nodes: $(($node | %{$_.Name}) -join '|')"

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

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
} 

function Test-VmwNodePath
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [PSObject]$StartNode = (Get-View -Id (Get-View -Id ServiceInstance).Content.RootFolder),
        [String]$Path
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
    Write-Verbose -Message "$(Get-Date) Start: $($StartNode.Name)" 
    Write-Verbose -Message "$(Get-Date) Path: $($Path)" 

    $nodeObj = Get-VmwNodeFromPath -StartNode $StartNode -Path $Path
    
    return $nodeObj.Found

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
}

function New-VmwFolder
{
    [CmdletBinding()]
    param(
        [VMware.Vim.ManagedEntity]$Parent,
        [String]$FolderName,
        [VmwFolderType]$FolderType
    )

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
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

    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 
}

function Test-VmwFolderType
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [VMware.Vim.ManagedEntity]$Node,
        [VmwFolderType]$FolderType
    )
    
    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Entering {0}" -f $s[0].FunctionName)" 
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
    Write-Verbose -Message "$(Get-Date) $($s = Get-PSCallStack;"Leaving {0}" -f $s[0].FunctionName)" 

    return $foundType
}
