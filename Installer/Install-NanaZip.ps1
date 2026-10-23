[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Test-Administrator
{
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


# Close only processes from this fork's installed packages.
# UpdateWhileInUse=defer in the manifest overrides ForceApplicationShutdown.
function Get-NanaZipProcesses
{
    param([string[]]$InstallRoots)

    Get-Process -Name 'NanaZip*' -ErrorAction SilentlyContinue |
        Where-Object {
            $ExecutablePath = $_.Path
            if ($ExecutablePath)
            {
                foreach ($Root in $InstallRoots)
                {
                    if ($ExecutablePath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase))
                    {
                        return $true
                    }
                }
            }
            return $false
        }
}

function Stop-NanaZipInstances
{
    $InstallRoots = @(
        foreach ($PackageName in @('BrunoFaria.NanaZip', 'DigitalfoxPT.NanaZipCustom'))
        {
            Get-AppxPackage -Name $PackageName -ErrorAction Stop |
                Where-Object { $_.InstallLocation } |
                ForEach-Object { $_.InstallLocation.TrimEnd('\') + '\' }
        }
    )
    if ($InstallRoots.Count -eq 0) { return }

    $Running = @(Get-NanaZipProcesses -InstallRoots $InstallRoots)
    if ($Running.Count -eq 0) { return }

    Write-Warning 'O NanaZip vai fechar automaticamente. As operações de compressão ou extração em curso podem ser interrompidas.'
    foreach ($Instance in $Running)
    {
        try { $null = $Instance.CloseMainWindow() }
        catch { if (-not $Instance.HasExited) { throw } }
    }

    $Deadline = [DateTime]::UtcNow.AddSeconds(5)
    do
    {
        $Running = @(Get-NanaZipProcesses -InstallRoots $InstallRoots)
        if ($Running.Count -eq 0) { return }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $Deadline)

    foreach ($Instance in $Running)
    {
        try
        {
            if (-not $Instance.HasExited)
            {
                Stop-Process -InputObject $Instance -Force -ErrorAction Stop
                if (-not $Instance.WaitForExit(10000))
                {
                    throw "Não foi possível fechar o processo $($Instance.Id) do NanaZip."
                }
            }
        }
        catch { if (-not $Instance.HasExited) { throw } }
    }

    if (@(Get-NanaZipProcesses -InstallRoots $InstallRoots).Count -gt 0)
    {
        throw 'O NanaZip voltou a abrir. Feche-o e execute novamente Install.cmd.'
    }
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

Stop-NanaZipInstances
Write-Host 'A instalar o NanaZip...' -ForegroundColor Cyan
try
{
    Add-AppxPackage -Path $Bundle.FullName -ForceApplicationShutdown -ErrorAction Stop
}
catch
{
    if ($_ | Out-String | Select-String -SimpleMatch '0x80073D02')
    {
        Write-Host 'O pacote ainda está em utilização. A tentar novamente...' -ForegroundColor Yellow
        Stop-NanaZipInstances
        Start-Sleep -Seconds 2
        try
        {
            Add-AppxPackage -Path $Bundle.FullName -ForceApplicationShutdown -ErrorAction Stop
        }
        catch
        {
            Write-Warning 'Se o erro 0x80073D02 persistir, reinicie o Windows e execute Install.cmd antes de abrir o NanaZip.'
            throw
        }
    }
    else { throw }
}

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
