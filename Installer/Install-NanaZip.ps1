[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-Administrator
{
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator))
{
    $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $Process = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $Arguments -Wait -PassThru
    exit $Process.ExitCode
}

$CertificatePath = Join-Path $PSScriptRoot 'NanaZip.cer'
$Bundle = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'NanaZip_*.msixbundle' |
    Select-Object -First 1

if (-not (Test-Path -LiteralPath $CertificatePath))
{
    throw 'Não foi encontrado o certificado NanaZip.cer.'
}

if (-not $Bundle)
{
    throw 'Não foi encontrado o pacote NanaZip_*.msixbundle.'
}

Write-Host 'A instalar o certificado do NanaZip...' -ForegroundColor Cyan
$Certificate = Import-Certificate `
    -FilePath $CertificatePath `
    -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople'

Write-Host 'A instalar o NanaZip...' -ForegroundColor Cyan
Add-AppxPackage -Path $Bundle.FullName -ForceApplicationShutdown

$LegacyPackage = Get-AppxPackage -Name 'DigitalfoxPT.NanaZipCustom'
if ($LegacyPackage)
{
    Write-Host 'A remover a instalação anterior...' -ForegroundColor Cyan
    $LegacyPackage | Remove-AppxPackage

    Get-ChildItem -LiteralPath 'Cert:\LocalMachine\TrustedPeople' |
        Where-Object { $_.Subject -eq 'CN=DigitalfoxPT' } |
        Remove-Item -Force
}

Write-Host ''
Write-Host 'NanaZip instalado com sucesso.' -ForegroundColor Green
Write-Host "Certificado: $($Certificate.Thumbprint)"
Write-Host 'Se o menu de contexto não aparecer imediatamente, reinicie o Explorador de Ficheiros.'
