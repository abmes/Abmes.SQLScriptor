$logDir = "C:\Logs\SQLScriptor"


.\Abmes.SQLScriptor.exe /logdir $logDir /config "SQLSCRIPTOR_CONFIG_LOCATION" /script "SQLSCRIPTOR_SCRIPT_LOCATION" /databases "SQLSCRIPTOR_DATABASES"


$s3LogsBucketName = $env:AWS_S3_LOGS_BUCKET_NAME

if ($s3LogsBucketName)
{
    Write-Host " "
    Write-Host "Uploading logs to '$s3LogsBucketName' bucket..."
    Write-Host " "

    $awsRegion = $s3LogsBucketName.Split("@")[1]
    $s3LogsBucketName = $s3LogsBucketName.Split("@")[0]
    
    $logFiles = Get-ChildItem -Path $logDir -Recurse -File
    
    foreach ($logFile in $logFiles)
    {
        $key = $logFile.FullName.Substring($logDir.Length + 1).Replace("\", "/")

        Write-Host $key

        Write-S3Object -BucketName $s3LogsBucketName -Key $key -File $logFile.FullName -Region $awsRegion
    }

    Write-Host " "
    Write-Host "Done uploading logs."
}