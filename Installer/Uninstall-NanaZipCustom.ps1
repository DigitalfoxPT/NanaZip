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

$Package = Get-AppxPackage -Name 'DigitalfoxPT.NanaZipCustom'
if ($Package)
{
    Write-Host 'A desinstalar o NanaZip Custom...' -ForegroundColor Cyan
    $Package | Remove-AppxPackage
}
else
{
    Write-Host 'O NanaZip Custom não está instalado.' -ForegroundColor Yellow
}

$CertificatePath = Join-Path $PSScriptRoot 'NanaZipCustom.cer'
if (Test-Path -LiteralPath $CertificatePath)
{
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath)
    $InstalledCertificate = Get-Item `
        -LiteralPath "Cert:\LocalMachine\TrustedPeople\$($Certificate.Thumbprint)" `
        -ErrorAction SilentlyContinue
    if ($InstalledCertificate)
    {
        Remove-Item -LiteralPath $InstalledCertificate.PSPath -Force
        Write-Host 'Certificado do NanaZip Custom removido.' -ForegroundColor Green
    }
}

Write-Host 'Desinstalação concluída.' -ForegroundColor Green

