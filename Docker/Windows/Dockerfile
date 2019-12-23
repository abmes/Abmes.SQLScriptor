FROM mcr.microsoft.com/powershell

COPY bin/ /

RUN [ "pwsh", "-Command", "Install-Module", "-Name", "AWSPowerShell.NetCore", "-Force" ]

ENTRYPOINT [ "pwsh", "-File", "./SQLScriptorLauncher.ps1" ]