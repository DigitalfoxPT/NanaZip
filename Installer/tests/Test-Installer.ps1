$ErrorActionPreference = 'Stop'
$Source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\Install-NanaZip.ps1'))
$Tokens = $null
$Errors = $null
$Ast = [Management.Automation.Language.Parser]::ParseInput($Source, [ref]$Tokens, [ref]$Errors)
if ($Errors.Count) { throw ($Errors | Out-String) }
$Functions = $Ast.FindAll({ param($Node) $Node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)
foreach ($Function in $Functions) { Invoke-Expression $Function.Extent.Text }

function New-TestProcess($ProcessPath, $Graceful)
{
    $Item = [pscustomobject]@{ Path = $ProcessPath; HasExited = $false; Id = 123; Graceful = $Graceful }
    $Item | Add-Member ScriptMethod CloseMainWindow { if ($this.Graceful) { $this.HasExited = $true }; return $this.Graceful }
    $Item | Add-Member ScriptMethod WaitForExit { param($Timeout) return $this.HasExited }
    return $Item
}
function Get-AppxPackage { param($Name, $ErrorAction) if ($Name -eq 'BrunoFaria.NanaZip') { [pscustomobject]@{ InstallLocation = 'C:\Apps\Custom' } } }
function Get-Process { param($Name, $ErrorAction) $script:Processes | Where-Object { -not $_.HasExited } }
function Stop-Process { param($InputObject, [switch]$Force, $ErrorAction) $script:Forced++; $InputObject.HasExited = $true }

foreach ($Graceful in @($true, $false))
{
    $script:Forced = 0
    $Custom = New-TestProcess 'C:\Apps\Custom\NanaZip.Modern.FileManager.exe' $Graceful
    $Official = New-TestProcess 'C:\Apps\Official\NanaZip.Modern.FileManager.exe' $false
    $Similar = New-TestProcess 'C:\Apps\CustomOther\NanaZip.exe' $false
    $script:Processes = @($Custom, $Official, $Similar)
    Stop-NanaZipInstances
    if (-not $Custom.HasExited -or $Official.HasExited -or $Similar.HasExited) { throw 'Process scope failed' }
    if (($Graceful -and $script:Forced -ne 0) -or (-not $Graceful -and $script:Forced -ne 1)) { throw 'Close strategy failed' }
}
$script:Processes = @()
Stop-NanaZipInstances
'PASS: graceful close, forced close, official package isolation, path boundary, no running instances'

# Exercise the complete installer with all OS mutations mocked.
$AdminFunction = $Functions | Where-Object Name -eq 'Test-Administrator'
$SafeSource = $Source.Remove($AdminFunction.Extent.StartOffset, $AdminFunction.Extent.EndOffset - $AdminFunction.Extent.StartOffset).Insert($AdminFunction.Extent.StartOffset, 'function Test-Administrator { return $true }')
$SafeSource = $SafeSource.Replace('$PSScriptRoot', "'C:\Test'")
function Get-ChildItem { param($LiteralPath, $Filter) [pscustomobject]@{ FullName = 'C:\Test\NanaZip.msixbundle' } }
function Test-Path { param($LiteralPath) return $true }
function Import-Certificate { param($FilePath, $CertStoreLocation) [pscustomobject]@{ Thumbprint = 'MOCK' } }
function Start-Sleep { param($Seconds, $Milliseconds) }
function Add-AppxPackage
{
    param($Path, [switch]$ForceApplicationShutdown, $ErrorAction)
    $script:InstallAttempts++
    if ($script:InstallAttempts -eq 1 -and $script:FirstError) { throw $script:FirstError }
}
foreach ($Scenario in @('', '0x80073D02 package in use', '0x800B0109 certificate error'))
{
    $script:FirstError = $Scenario
    $script:InstallAttempts = 0
    $Failed = $false
    try { & ([scriptblock]::Create($SafeSource)) | Out-Null } catch { $Failed = $true }
    $ExpectedAttempts = if ($Scenario -like '0x80073D02*') { 2 } else { 1 }
    $ExpectedFailure = $Scenario -like '0x800B0109*'
    if ($script:InstallAttempts -ne $ExpectedAttempts -or $Failed -ne $ExpectedFailure) { throw "Retry policy failed: $Scenario" }
}
'PASS: successful install, one retry for 0x80073D02, no retry for unrelated failure'
