Param(
  [Parameter(Mandatory=$true)] [string] $OrganizationName,
  [Parameter(Mandatory=$true)] [string] $ContainerName,
  [Parameter(Mandatory=$true)] [ValidateSet("Linux", "Windows")] [string] $TargetOS
)

$ErrorActionPreference = "Stop"

$version = "latest"

$OrganizationName = $OrganizationName.ToLower()
$ContainerName = $ContainerName.ToLower()

$saveLocation = Get-Location


function Docker-GetEngineTargetOS()
{
    $osArch = docker version | Select-String "OS/Arch" | % { $_.ToString().Split(" ") } | ? { $_ } | select -last 1

    return $osArch.Split("/")[0]
}

function Docker-SetEngineTargetOS(
    [Parameter(Mandatory=$true)] [ValidateSet("Windows", "Linux")] [string] $TargetOS
)
{
    $currentEngineTargetOS = Docker-GetEngineTargetOS

    if ($currentEngineTargetOS -ine $TargetOS)
    {
        $capitalizedTargetOS = $TargetOS.ToUpper()[0] + $TargetOS.ToLower().Substring(1)

        Write-Host "Setting Docker engine target OS to '$capitalizedTargetOS' ..."

        $targetSwitch = "-Switch" + $capitalizedTargetOS + "Engine"

        & $Env:ProgramFiles\Docker\Docker\DockerCli.exe -SwitchDaemon -SwitchEngine $targetSwitch
        
        $newEngineTargetOS = Docker-GetEngineTargetOS

        if ($newEngineTargetOS -ine $TargetOS)
        {
            throw "Can't switch docker engine target OS to '$TargetOS'. Try 'Run as Administrator' or switch in advance."
        }
    }
}



#build docker image
Set-Location $PSScriptRoot/docker

New-Item -Path bin -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

Copy-Item .\AwsEcsLauncher.ps1 -Destination .\bin -Force
Copy-Item .\$TargetOS\Dockerfile -Destination .

if ($TargetOS -eq "Windows")
{
    Copy-Item ..\bin\Win32\Release\Abmes.SQLScriptor.exe -Destination .\bin -Force
}

if ($TargetOS -eq "Linux")
{
    Copy-Item ..\bin\Linux64\Release\sqlscriptor -Destination .\bin -Force
}

Docker-SetEngineTargetOS $TargetOS
docker build -t "$OrganizationName/${ContainerName}:${version}" .

Remove-Item .\Dockerfile -Force

Set-Location $saveLocation