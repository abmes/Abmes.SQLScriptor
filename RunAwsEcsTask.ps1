Param(
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

function Main()
{
    $containerOverrides = Get-ContainerOverrides

    $tempContainerOverridesFileName = "tempcontaineroverrides.json"
    Set-Content -Path $tempContainerOverridesFileName -Value $containerOverrides

    $runJson = &aws ecs run-task --cluster $ClusterName --task-definition $ContainerName --overrides "file://$tempContainerOverridesFileName" --profile $AwsProfileName --region $AwsRegion
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