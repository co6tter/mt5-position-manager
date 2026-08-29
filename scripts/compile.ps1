param(
    [Parameter(Mandatory = $true)]
    [string]$MetaEditorPath,

    [string]$SourcePath = (Join-Path $PSScriptRoot "..\src\PositionManager.mq5"),

    [string]$LogPath = (Join-Path $PSScriptRoot "..\build\metaeditor.log")
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolvedMetaEditor = (Resolve-Path $MetaEditorPath).Path
$resolvedSource = (Resolve-Path $SourcePath).Path
$resolvedLog = [System.IO.Path]::GetFullPath($LogPath)
$logDirectory = Split-Path $resolvedLog -Parent
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
if (Test-Path $resolvedLog) {
    Remove-Item -Force $resolvedLog
}

& $resolvedMetaEditor "/compile:$resolvedSource" "/log:$resolvedLog"
$metaEditorExitCode = $LASTEXITCODE

if (-not (Test-Path $resolvedLog)) {
    throw "MetaEditor did not create a compile log: $resolvedLog"
}

$compileLog = Get-Content -Raw $resolvedLog
Write-Output $compileLog

if ($metaEditorExitCode -ne 0 -or $compileLog -notmatch "(?im)\b0 errors?\b") {
    throw "MQL5 compilation failed. See: $resolvedLog"
}
