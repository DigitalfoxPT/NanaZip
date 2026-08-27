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

$CertificatePath = Join-Path $PSScriptRoot 'NanaZipCustom.cer'
$Bundle = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'NanaZipCustom_*.msixbundle' |
    Select-Object -First 1

if (-not (Test-Path -LiteralPath $CertificatePath))
{
    throw 'Não foi encontrado o certificado NanaZipCustom.cer.'
}

if (-not $Bundle)
{
    throw 'Não foi encontrado o pacote NanaZipCustom_*.msixbundle.'
}

Write-Host 'A instalar o certificado do NanaZip Custom...' -ForegroundColor Cyan
$Certificate = Import-Certificate `
    -FilePath $CertificatePath `
    -CertStoreLocation 'Cert:\LocalMachine\TrustedPeople'

Write-Host 'A instalar o NanaZip Custom...' -ForegroundColor Cyan
Add-AppxPackage -Path $Bundle.FullName -ForceApplicationShutdown

Write-Host ''
Write-Host 'NanaZip Custom instalado com sucesso.' -ForegroundColor Green
Write-Host "Certificado: $($Certificate.Thumbprint)"
Write-Host 'Se o menu de contexto não aparecer imediatamente, reinicie o Explorador de Ficheiros.'

