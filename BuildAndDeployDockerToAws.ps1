Param(
  [Parameter(Mandatory=$true)] [string] $UserName,
  [Parameter(Mandatory=$true)] [string] $AwsProfileName,
  [Parameter(Mandatory=$true)] [string] $AwsRegion,
  [Parameter(Mandatory=$true)] [string] $AwsEcrRepository
)

Set-Location $PSScriptRoot/docker

#build
Copy-Item ..\Win32\Release\Abmes.SQLScriptor.exe -Destination .\bin -Force

docker build -t $UserName/sqlscriptor:latest .


#deploy

if (!$AwsEcrRepository.Contains(".")) 
{
  $AwsEcrRepository = $AwsEcrRepository + ".dkr.ecr." + $AwsRegion + ".amazonaws.com"
}

if (!$AwsEcrRepository.Contains("/")) 
{
  $AwsEcrRepository = $AwsEcrRepository + "/$UserName/sqlscriptor"
}

$command = &aws ecr get-login --profile $AwsProfileName --region $AwsRegion --no-include-email

Invoke-Expression -Command $command

docker tag ($UserName + "/sqlscriptor:latest") ($AwsEcrRepository + ":latest")

docker push ($AwsEcrRepository + ":latest")