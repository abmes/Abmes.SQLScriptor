Param(
  [Parameter(Mandatory=$true)] [string] $OrganizationName,
  [Parameter(Mandatory=$true)] [string] $ContainerName,
  [Parameter(Mandatory=$true)] [string] $AwsProfileName,
  [Parameter(Mandatory=$true)] [ValidateSet("eu-central-1")] [string] $AwsRegion
)

$ErrorActionPreference = "Stop"

$version = "latest"

$OrganizationName = $OrganizationName.ToLower()
$ContainerName = $ContainerName.ToLower()

$saveLocation = Get-Location


#build project
Set-Location $PSScriptRoot

$Env:BDS = (Get-ChildItem "C:\Program Files (x86)\Embarcadero\Studio" | sort Name | select -Last 1).FullName

. "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\MSBuild\15.0\Bin\MSBuild.exe" .\Abmes.SQLScriptor.dproj /t:Build /p:Configuration=Release


#build docker image
Set-Location $PSScriptRoot/docker

Copy-Item ..\Win32\Release\Abmes.${ContainerName}.exe -Destination .\bin -Force

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