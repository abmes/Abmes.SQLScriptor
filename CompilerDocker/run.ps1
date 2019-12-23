$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

Get-ChildItem "C:\Program Files (x86)\Embarcadero\Studio" -Include LinuxPAServer20.0.tar.gz -Recurse | sort -Property FullName | select -Last 1 | % { Copy-Item $_ -Force }

$containerFullName = "abmes/sqlscriptorcompiler:latest"

docker build -t $containerFullName .

Remove-Item LinuxPAServer20.0.tar.gz

docker run -it -p 127.0.0.1:64211:64211 $containerFullName
