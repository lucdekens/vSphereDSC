enum Ensure {
   Absent
   Present
}

$tgtName = 'vEng.local.lab'
$configName = 'vmw'
 
Configuration $configName
{
    param(
    [System.Management.Automation.PSCredential]$Credential
    )

    Import-DscResource -ModuleName vSphereDSC

    Node $AllNodes.NodeName
    {
        $number = 0
        foreach($datacenter in $Node.Datacenters)
        {
            $number++
            $dcName = "Datacenter$number"
            VmwDatacenter $dcName
            {
                Name = $datacenter.DatacenterName
                Path = $datacenter.Path
                Ensure = $datacenter.Ensure
                vServer = $Allnodes.Server
                vCredential = $Allnodes.Credential
            }
        }
    }
}

#region VCSA Account
$vcUser = '<your VCSA user>'
$vcPswd = '<your VCSA user password>'
$sVcCred = @{
    TypeName = 'System.Management.Automation.PSCredential'
    ArgumentList = $vcUser,(ConvertTo-SecureString -String $vcPswd -AsPlainText -Force)
}
$vcCred = New-Object @sVcCred
#endregion

$ConfigData = @{   
    AllNodes = @(
        @{
            NodeName = '*'
            Server = 'vcsa.local.lab'     
            Credential = $vcCred
            PSDscAllowPlainTextPassword=$true
            PSDscAllowDomainUser = $true
        },
        @{
            NodeName = $configName
            Datacenters = @(
                @{
                    DatacenterName = 'DC1'
                    Path = '/'
                    Ensure = [Ensure]::Present
                }
            )
        }
    )  
} 

. "$(Split-Path $MyInvocation.MyCommand.Path)\..\..\Tools\Get-TargetGuid.ps1"
$guid = Get-TargetGuid -TargetName $tgtName

Invoke-Expression  "$($configName) -ConfigurationData `$configData -OutputPath '.\DSC'"

$pullShare = '\\pull\DSCService\Configuration\'
$mof = ".\DSC\$($configName).mof"
$tgtMof = "$pullshare\$guid.mof"

Copy-Item -Path $mof -Destination $tgtMof
New-DSCChecksum $tgtMof -Force

# For testing with Start-DscCOnfiguration
Copy-Item -Path $mof -Destination ".\DSC\$($tgtName.Split('.')[0]).mof"
