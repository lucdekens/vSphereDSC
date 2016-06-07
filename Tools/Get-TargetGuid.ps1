function Get-TargetGuid
{
    param(
        [string]$TargetName
    )

    $guidMaster = '\\Pull\Repository\guidMaster.csv'

    if(Test-Path -Path $guidMaster){
        $guids = Import-Csv -Path $guidMaster
    }
    else{
        $guids = @()
    }
    $tgtGuid = $guids | where{$_.target -eq $TargetName} | Select -ExpandProperty guid
    if(!$tgtGuid){
        $tgtGuid = New-Guid
        $guids += New-Object PSObject -Property @{
            target = $TargetName
            guid = $tgtGuid
        }
        $guids | Export-Csv -Path $guidMaster -NoTypeInformation -UseCulture
    }
    $tgtGuid
}
