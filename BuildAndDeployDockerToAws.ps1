Param(
  [Parameter(Mandatory=$true)] [string] $OrganizationName,
  [Parameter(Mandatory=$true)] [string] $ContainerName,
  [Parameter(Mandatory=$true)] [ValidateSet("Linux", "Windows")] [string] $Platform,
  [Parameter(Mandatory=$true)] [string] $AwsProfileName,
  [Parameter(Mandatory=$true)] [ValidateSet("eu-central-1")] [string] $AwsRegion
)

$ErrorActionPreference = "Stop"

$version = "latest"

$OrganizationName = $OrganizationName.ToLower()
$ContainerName = $ContainerName.ToLower()

$saveLocation = Get-Location


function Get-MSBuildPath()
{
    $msbuildFiles = gci -Path "C:\Program Files (x86)\Microsoft Visual Studio" -Recurse -Filter msbuild.exe | where { $_.FullName.ToLower().EndsWith("\bin\msbuild.exe") }
    $orderedMsbuildFiles = $msbuildFiles | sort @{expression = {[System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).ProductVersionRaw}; Descending = $true}
    return $orderedMsbuildFiles[0].FullName
}

#build project
Set-Location $PSScriptRoot

$Env:BDS = (Get-ChildItem "C:\Program Files (x86)\Embarcadero\Studio" | sort Name | select -Last 1).FullName
Set-Alias msbuild (Get-MSBuildPath)

msbuild .\Abmes.SQLScriptor.dproj /t:Build /p:Configuration=Release


#build docker image
Set-Location $PSScriptRoot/docker

Copy-Item .\AwsEcsLauncher.ps1 -Destination .\bin -Force

if ($Platform -eq "Windows")
{
    Copy-Item ..\bin\Win32\Release\Abmes.SQLScriptor.exe -Destination .\bin -Force
    Copy-Item .\Windows\Dockerfile -Destination .
}

if ($Platform -eq "Windows")
{
    Copy-Item ..\bin\Linux64\Release\sqlscriptor -Destination .\bin -Force
    Copy-Item .\Linux\Dockerfile -Destination .
}

docker build -t "$OrganizationName/${ContainerName}:${version}" .


#deploy

$awsIdentityJson = &aws sts get-caller-identity --profile $AwsProfileName --region $AwsRegion
$awsIdentity = ConvertFrom-Json ([string]::Join("", $awsIdentityJson))
$awsAccountId = $awsIdentity.Account

$awsEcrRepositoryUri = $awsAccountId + ".dkr.ecr." + $AwsRegion + ".amazonaws.com/$OrganizationName/${ContainerName}"

$command = &aws ecr get-login --profile $AwsProfileName --region $AwsRegion --no-include-email

Invoke-Expression -Command $command

docker tag ($OrganizationName + "/${ContainerName}:${version}") ($awsEcrRepositoryUri + ":${version}")

docker push ($awsEcrRepositoryUri + ":${version}")


Set-Location $saveLocation