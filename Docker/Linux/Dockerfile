FROM mcr.microsoft.com/powershell

COPY bin/ /

RUN [ "apt-get", "update", "-y" ]
RUN [ "apt-get", "upgrade", "-y" ]
RUN [ "apt-get", "install", "software-properties-common", "-y" ]
RUN [ "add-apt-repository", "ppa:mfikes/planck", "-y" ]
RUN [ "apt-get", "update", "-y" ]
RUN [ "apt-get", "install", "planck", "-y" ]

RUN [ "pwsh", "-Command", "Install-Module", "-Name", "AWSPowerShell.NetCore", "-Force" ]

ENTRYPOINT [ "pwsh", "-File", "./AwsEcsLauncher.ps1" ]