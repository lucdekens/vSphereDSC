# Configure PowerCLi on vEng
#
# Tested platform:
# Windows 2012 R2
# PowerShell v5 Production Preview
#

$tgtName = 'vEng.local.lab'
$pcliName = 'VMware-PowerCLI-6.3.0-3737840.exe'

$configName = $tgtName.Split('.')[0]

Configuration $configName
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $AllNodes.NodeName
    {
        File DirectoryCopy
        {
            Ensure = "Present"
            Type = "File"
            Recurse = $true
            SourcePath = "\\Pull\Repository\PowerCLI\$($pcliName)"
            DestinationPath = "%windir%\Temp\$($pcliName)"    
        }

        Log AfterDirectoryCopy
        {
            Message = "PowerCLI installation file copied"
            DependsOn = "[File]DirectoryCopy"
        }
        
        Package Install-PowerCli
        {
            Name = "VMware vSphere PowerCLI"
            Path = "C:\Windows\Temp\$($pcliName)"
            Arguments = '/b"C:\Windows\Temp" /VADDLOCAL=ALL /S /V"/qn REBOOT=ReallySuppress"'
            ProductId = ''
            Ensure= "Present"
            DependsOn = "[File]DirectoryCopy"
        }

        Log AfterInstall
        {
            Message = "PowerCLI installed"
            DependsOn = "[Package]Install-PowerCLI"
        }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName = $configName
        }
    )
}

Invoke-Expression  "$($configName) -ConfigurationData `$configData -OutputPath '.\DSC'"

Start-DscConfiguration -ComputerName $configName -Wait -Verbose -Force -Path .\DSC
