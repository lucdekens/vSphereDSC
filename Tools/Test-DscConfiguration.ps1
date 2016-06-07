$tgtName = 'vEng.local.lab'

$configName = $tgtName.Split('.')[0]

Start-DscConfiguration -ComputerName $configName -Wait -Verbose -Force -Path .\DSC
