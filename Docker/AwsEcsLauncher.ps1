$logDir = Join-Path ([System.IO.Path]::GetTempPath()) "SQLScriptorLogs"

Import-Module AWSPowerShell.NetCore

if ($IsWindows) { Set-Alias sqlscriptor .\Abmes.SQLScriptor.exe }
if ($IsLinux)   { Set-Alias sqlscriptor .\sqlscriptor }

sqlscriptor -logdir $logDir -config "SQLSCRIPTOR_CONFIG_LOCATION" -script "SQLSCRIPTOR_SCRIPT_LOCATION" -databases "SQLSCRIPTOR_DATABASES" -versionsonly "SQLSCRIPTOR_VERSIONSONLY"


$s3LogsBucketName = $env:AWS_S3_LOGS_BUCKET_NAME

if ($s3LogsBucketName)
{
    $awsRegion = $s3LogsBucketName.Split("@")[1]
    $s3LogsBucketName = $s3LogsBucketName.Split("@")[0]
    
    Write-Host " "
    Write-Host "Uploading logs to '$s3LogsBucketName' bucket..."
    Write-Host " "

    $logFiles = Get-ChildItem -Path $logDir -Recurse -File
    
    foreach ($logFile in $logFiles)
    {
        $key = $logFile.FullName.Substring($logDir.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar).Replace([System.IO.Path]::DirectorySeparatorChar, "/")

        Write-Host $key

        Write-S3Object -BucketName $s3LogsBucketName -Key $key -File $logFile.FullName -Region $awsRegion
    }

    Write-Host " "
    Write-Host "Done uploading logs."
}