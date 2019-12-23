Param(
  [Parameter(Mandatory=$false)] [ValidateSet("EC2", "FARGATE")] [string] $LaunchType = "FARGATE",
  [Parameter(Mandatory=$false)] [string[]] $Subnets,
  [Parameter(Mandatory=$false)] [string[]] $SecurityGroupIds,
  [Parameter(Mandatory=$false)] [string[]] $SecurityGroupNames,
  [Parameter(Mandatory=$true)]  [string] $ContainerName,
  [Parameter(Mandatory=$true)]  [string] $ClusterName,
  [Parameter(Mandatory=$true)]  [string] $ConfigLocation,
  [Parameter(Mandatory=$true)]  [string] $ScriptLocation,
  [Parameter(Mandatory=$false)] [string] $Databases,
  [switch] $VersionsOnly,
  [Parameter(Mandatory=$true)]  [string] $S3LogsBucketName,
  [switch] $Wait,
  [Parameter(Mandatory=$true)]  [string] $AwsProfileName,
  [Parameter(Mandatory=$true)]  [ValidateSet("eu-central-1")] [string] $AwsRegion
)

function Get-EnvVarJson([string] $envVarName, [string] $envVarValue)
{
    return "{`"name`":`"$envVarName`",`"value`":`"$envVarValue`"}"
}

function Get-ContainerOverrides()
{
    $dbs = if ($Databases) { $Databases } else { "*" }
    $versionsOnlyValue = if ($VersionsOnly.IsPresent) { "1" } else { "0" }

    $configLocationEnvVarJson   = Get-EnvVarJson "SQLSCRIPTOR_CONFIG_LOCATION" $ConfigLocation
    $scriptLocationEnvVarJson   = Get-EnvVarJson "SQLSCRIPTOR_SCRIPT_LOCATION" $ScriptLocation
    $databasesEnvVarJson        = Get-EnvVarJson "SQLSCRIPTOR_DATABASES" $dbs
    $versionsOnlyEnvVarJson     = Get-EnvVarJson "SQLSCRIPTOR_VERSIONSONLY" $versionsOnlyValue
    $s3LogsBucketNameEnvVarJson = Get-EnvVarJson "AWS_S3_LOGS_BUCKET_NAME" ($S3LogsBucketName + "@" + $AwsRegion)

    return "{`"containerOverrides`":[{`"name`":`"$ContainerName`",`"environment`":[$configLocationEnvVarJson,$scriptLocationEnvVarJson,$databasesEnvVarJson,$versionsOnlyEnvVarJson,$s3LogsBucketNameEnvVarJson]}]}"
}

function Aws-EC2-GetSecurityGroupIds(
    [Parameter(Mandatory=$false)] [string[]] $SecurityGroupNames,
    [Parameter(Mandatory=$false)] [string]   $AwsProfileName,
    [Parameter(Mandatory=$false)] [string]   $AwsRegion
)
{
    $groupNames = [string]::Join(",", $SecurityGroupNames)

    $result = &aws ec2 describe-security-groups --group-names "$groupNames" --profile "AwsProfileName" --region "$AwsRegion"

    $json = ConvertFrom-Json ([string]::Concat($result))

    return $json.SecurityGroups.GroupId
}

function Internal-Ecs-GetNetworkConfiguration(
    [Parameter(Mandatory=$false)] [string[]] $subnets,
    [Parameter(Mandatory=$false)] [string[]] $securityGroupIds,
    [Parameter(Mandatory=$false)] [string[]] $securityGroupNames,
    [Parameter(Mandatory=$false)] [bool] $assignPublicIp
)
{
    if ((!$securityGroupIds) -and ($securityGroupNames))
    {
        $securityGroupIds = Aws-EC2-GetSecurityGroupIds -SecurityGroupNames $securityGroupNames
    }

    $subnetsString = [string]::Join(",", $subnets)
    $securityGroupIdsString = [string]::Join(",", $securityGroupIds)
    $assignPublicIpString = if ($assignPublicIp) { "ENABLED" } else { "DISABLED" }

    return "awsvpcConfiguration={subnets=[$subnetsString],securityGroups=[$securityGroupIdsString],assignPublicIp=$assignPublicIpString}"
}

function Main()
{
    $containerOverrides = Get-ContainerOverrides

    $tempContainerOverridesFileName = "tempcontaineroverrides.json"
    Set-Content -Path $tempContainerOverridesFileName -Value $containerOverrides

    if ($LaunchType -eq "EC2")
    {
        $networkConfiguration = Internal-Ecs-GetNetworkConfiguration -subnets $Subnets -securityGroupIds $SecurityGroupIds -securityGroupNames $SecurityGroupNames -assignPublicIp $true
        $runJson = &aws ecs run-task --cluster $ClusterName --launch-type "$LaunchType" --network-configuration "$networkConfiguration" --task-definition $ContainerName --overrides "file://$tempContainerOverridesFileName" --profile $AwsProfileName --region $AwsRegion
    }
    else
    {
        $runJson = &aws ecs run-task --cluster $ClusterName --launch-type "$LaunchType" --task-definition $ContainerName --overrides "file://$tempContainerOverridesFileName" --profile $AwsProfileName --region $AwsRegion
    }

    $runJson

    Remove-Item $tempContainerOverridesFileName

    $run = ConvertFrom-Json ([string]::Join("", $runJson))

    $taskArn = $run.tasks[0].taskArn

    if ($Wait.IsPresent)
    {
        Write-Host ""
        Write-Host "Waiting task $taskArn to stop..."

        &aws ecs wait tasks-stopped --cluster $ClusterName --tasks $taskArn --profile $AwsProfileName --region $AwsRegion
    }
}

Main