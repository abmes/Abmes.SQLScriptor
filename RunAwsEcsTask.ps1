Param(
  [Parameter(Mandatory=$true)]  [string] $ContainerName,
  [Parameter(Mandatory=$true)]  [string] $ClusterName,
  [Parameter(Mandatory=$true)]  [string] $ConfigLocation,
  [Parameter(Mandatory=$true)]  [string] $ScriptLocation,
  [Parameter(Mandatory=$false)] [string] $Databases,
  [Parameter(Mandatory=$true)]  [string] $S3LogsBucketName,
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

    $configLocationEnvVarJson   = Get-EnvVarJson "SQLSCRIPTOR_CONFIG_LOCATION" $ConfigLocation
    $scriptLocationEnvVarJson   = Get-EnvVarJson "SQLSCRIPTOR_SCRIPT_LOCATION" $ScriptLocation
    $databasesEnvVarJson        = Get-EnvVarJson "SQLSCRIPTOR_DATABASES" $dbs
    $s3LogsBucketNameEnvVarJson = Get-EnvVarJson "AWS_S3_LOGS_BUCKET_NAME" ($S3LogsBucketName + "@" + $AwsRegion)

    return "{`"containerOverrides`":[{`"name`":`"$ContainerName`",`"environment`":[$configLocationEnvVarJson,$scriptLocationEnvVarJson,$databasesEnvVarJson,$s3LogsBucketNameEnvVarJson]}]}"
}

function Main()
{
    $containerOverrides = Get-ContainerOverrides

    $tempContainerOverridesFileName = "tempcontaineroverrides.json"
    Set-Content -Path $tempContainerOverridesFileName -Value $containerOverrides

    &aws ecs run-task --cluster $ClusterName --task-definition $ContainerName --overrides "file://$tempContainerOverridesFileName" --profile $AwsProfileName --region $AwsRegion

    Remove-Item $tempContainerOverridesFileName
}

Main