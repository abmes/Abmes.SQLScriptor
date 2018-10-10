Param(
  [Parameter(Mandatory=$true)] [string] $OrganizationName,
  [Parameter(Mandatory=$true)] [string] $ContainerName,
  [Parameter(Mandatory=$true)] [string] $AwsProfileName,
  [Parameter(Mandatory=$true)] [ValidateSet("eu-central-1")] [string] $AwsRegion
)

$version = "latest"

$OrganizationNameLower = $OrganizationName.ToLower()
$ContainerNameLower = $ContainerName.ToLower()

function Get-ContainerImageUri()
{
    $awsIdentityJson = &aws sts get-caller-identity --profile $AwsProfileName --region $AwsRegion
    $awsIdentity = ConvertFrom-Json ([string]::Join("", $awsIdentityJson))
    $awsAccountId = $awsIdentity.Account

    $awsEcrRepositoryUri = $awsAccountId + ".dkr.ecr." + $AwsRegion + ".amazonaws.com/$OrganizationNameLower/${ContainerNameLower}"

    return $awsEcrRepositoryUri + ":" + $version
}

function Get-ContainerDefinitions()
{
    $containerImageUri = Get-ContainerImageUri

    $containerDefinitions = Get-Content $PSScriptRoot\Docker\AwsEcsTaskContainerDefinitions.json

    $containerDefinitions = $containerDefinitions.Replace("[ContainerName]", $ContainerName)
    $containerDefinitions = $containerDefinitions.Replace("[AwsRegion]", $AwsRegion)
    $containerDefinitions = $containerDefinitions.Replace("[ContainerImageUri]", $containerImageUri)

    return $containerDefinitions
}

function Create-LogGroupIfMissing([string] $logGroupName)
{
    $logGroupsJson = &aws logs describe-log-groups --log-group-name-prefix $logGroupName --profile $AwsProfileName --region $AwsRegion
    $logGroups = ConvertFrom-Json ([string]::Join("", $logGroupsJson))

    if ($logGroups.logGroups.Count -eq 0)
    {
        &aws logs create-log-group --log-group-name $logGroupName --profile $AwsProfileName --region $AwsRegion
    }
}

function Main()
{
    $containerDefinitions = Get-ContainerDefinitions

    $cd = ConvertFrom-Json ([string]::Join("", $containerDefinitions))
    Create-LogGroupIfMissing ($cd[0].logConfiguration.options."awslogs-group")

    $tempContainerDefinitionsFileName = "tempcontainerdefinitions.json"
    Set-Content -Path $tempContainerDefinitionsFileName -Value $containerDefinitions

    &aws ecs register-task-definition --family $ContainerName --cpu 1024 --memory 500 --container-definitions "file://$tempContainerDefinitionsFileName" --profile $AwsProfileName --region $AwsRegion

    Remove-Item $tempContainerDefinitionsFileName
}

Main