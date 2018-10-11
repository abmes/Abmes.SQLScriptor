FROM microsoft/windowsservercore

RUN [ "powershell.exe", "-Command", "Install-PackageProvider -Name Nuget -Force" ]
RUN [ "powershell.exe", "-Command", "Install-Module -Name AWSPowerShell -Force" ]
RUN [ "powershell.exe", "-Command", "Set-ExecutionPolicy RemoteSigned" ]

COPY bin/ /

ENTRYPOINT [ "powershell.exe", "-File", "AwsEcsLauncher.ps1" ]