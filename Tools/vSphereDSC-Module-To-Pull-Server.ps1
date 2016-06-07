$moduleName = 'vSphereDSC'
$sourceFolder = "$($env:userprofile)\OneDrive\BitBucket"
$pullSrvName = 'pull.local.lab'

$srcPath = "$($sourceFolder)\$($moduleName)"
$pullSrv = "\\$($pullSrvName)\DscService\Modules"

$localPath = $env:PSModulePath.split(';') | where{$_ -like "$($env:userprofile)*"}

# Increment Version Build
$modVersion = Test-ModuleManifest -Path "$($srcPath)\$($moduleName).psd1" | Select -ExpandProperty Version
$newVersion = [Version]::new($modVersion.Major,$modVersion.Minor,$modVersion.Build + 1,$modVersion.Revision)
Update-ModuleManifest -Path "$($srcPath)\$($moduleName).psd1" -ModuleVersion $newVersion

# Copy new build to Pull server
$compressedModuleName = "$($srcPath)\..\$($moduleName)_$($newVersion.Major).$($newVersion.Minor).$($newVersion.Build).$($newVersion.Revision).zip"
Compress-Archive -Path "$($srcPath)\*" -DestinationPath $compressedModuleName
Copy-item -Path "$($srcPath)\..\$($moduleName)_$($newVersion.ToString()).zip" -Destination $pullSrv
New-DscChecksum -Path "$($pullSrv)\$($moduleName)*.zip"

# Copy new build to local Modules folder
if(Test-Path -Path "$localPath\$moduleName")
{
    Get-ChildItem -Path "$localPath\$moduleName" -Recurse | Remove-Item -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -Path "$localPath\$moduleName" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
}
Copy-Item -Path $srcPath -Destination $localPath -Recurse
