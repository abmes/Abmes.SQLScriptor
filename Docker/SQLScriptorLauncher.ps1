$ProgressPreference = "SilentlyContinue"

$logDir = Join-Path (Join-Path ([System.IO.Path]::GetTempPath()) "SQLScriptorLogs") ([System.Guid]::NewGuid().ToString())

Import-Module AWSPowerShell.NetCore

if ($IsWindows) { Set-Alias sqlscriptor (Join-Path (Get-Location) Abmes.SQLScriptor.exe) }
if ($IsLinux)   { Set-Alias sqlscriptor (Join-Path (Get-Location) sqlscriptor) }

sqlscriptor -logdir $logDir -config "SQLSCRIPTOR_CONFIG_LOCATION" -script "SQLSCRIPTOR_SCRIPT_LOCATION" -databases "SQLSCRIPTOR_DATABASES" -versionsonly "SQLSCRIPTOR_VERSIONSONLY" | % { Write-Output $_ }

$s3LogsBucketName = $env:AWS_S3_LOGS_BUCKET_NAME

if ($s3LogsBucketName)
{
    $awsRegion = $s3LogsBucketName.Split("@")[1]
    $s3LogsBucketName = $s3LogsBucketName.Split("@")[0]
    
    Write-Output " "
    Write-Output "Uploading logs to '$s3LogsBucketName' bucket..."
    Write-Output " "

    $logFiles = Get-ChildItem -Path $logDir -Recurse -File
    
    foreach ($logFile in $logFiles)
    {
        $key = $logFile.FullName.Substring($logDir.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar).Replace([System.IO.Path]::DirectorySeparatorChar, "/")

        Write-Output $key

        Write-S3Object -BucketName $s3LogsBucketName -Key $key -File $logFile.FullName -ContentType "text/plain" -Region $awsRegion | Out-Null
        
        Start-Sleep -Seconds 1
    }

    Write-Output " "
    Write-Output "Done uploading logs."
}