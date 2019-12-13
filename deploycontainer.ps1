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


$awsIdentityJson = &aws sts get-caller-identity --profile $AwsProfileName --region $AwsRegion
$awsIdentity = ConvertFrom-Json ([string]::Join("", $awsIdentityJson))
$awsAccountId = $awsIdentity.Account

$awsEcrRepositoryUri = $awsAccountId + ".dkr.ecr." + $AwsRegion + ".amazonaws.com/$OrganizationName/${ContainerName}"

$command = &aws ecr get-login --profile $AwsProfileName --region $AwsRegion --no-include-email

Invoke-Expression -Command $command

docker tag ($OrganizationName + "/${ContainerName}:${version}") ($awsEcrRepositoryUri + ":${version}")

docker push ($awsEcrRepositoryUri + ":${version}")


Set-Location $saveLocation