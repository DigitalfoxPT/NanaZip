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

$Packages = @(
    Get-AppxPackage -Name 'BrunoFaria.NanaZip'
    Get-AppxPackage -Name 'DigitalfoxPT.NanaZipCustom'
) | Where-Object { $_ }

if ($Packages)
{
    Write-Host 'A desinstalar o NanaZip...' -ForegroundColor Cyan
    $Packages | Remove-AppxPackage
}
else
{
    Write-Host 'O NanaZip não está instalado.' -ForegroundColor Yellow
}

$CertificatePath = Join-Path $PSScriptRoot 'NanaZip.cer'
if (Test-Path -LiteralPath $CertificatePath)
{
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
    $InstalledCertificate = Get-Item `
        -LiteralPath "Cert:\LocalMachine\TrustedPeople\$($Certificate.Thumbprint)" `
        -ErrorAction SilentlyContinue
    if ($InstalledCertificate)
    {
        Remove-Item -LiteralPath $InstalledCertificate.PSPath -Force
        Write-Host 'Certificado do NanaZip removido.' -ForegroundColor Green
    }
}

Get-ChildItem -LiteralPath 'Cert:\LocalMachine\TrustedPeople' |
    Where-Object { $_.Subject -eq 'CN=DigitalfoxPT' } |
    Remove-Item -Force

Write-Host 'Desinstalação concluída.' -ForegroundColor Green
