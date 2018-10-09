Param(
  [Parameter(Mandatory=$true)] [string] $UserName,
  [Parameter(Mandatory=$true)] [string] $AwsProfileName,
  [Parameter(Mandatory=$true)] [string] $AwsRegion
)

$containerName = "sqlscriptor"
$version = "latest"

Set-Location $PSScriptRoot/docker

#build
Copy-Item ..\Win32\Release\Abmes.${containerName}.exe -Destination .\bin -Force

docker build -t "$UserName/${containerName}:${version}" .


#deploy

$awsIdentityJson = &aws sts get-caller-identity --profile $AwsProfileName --region $AwsRegion
$awsIdentity = ConvertFrom-Json ([string]::Join("", $awsIdentityJson))
$awsAccountId = $awsIdentity.Account

$awsEcrRepositoryUri = $awsAccountId + ".dkr.ecr." + $AwsRegion + ".amazonaws.com/$UserName/${containerName}"

$command = &aws ecr get-login --profile $AwsProfileName --region $AwsRegion --no-include-email

Invoke-Expression -Command $command

docker tag ($UserName + "/${containerName}:${version}") ($awsEcrRepositoryUri + ":${version}")

docker push ($awsEcrRepositoryUri + ":${version}")