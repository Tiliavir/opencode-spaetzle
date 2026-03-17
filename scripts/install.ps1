# install.ps1 — Install spaetzle wrapper script for opencode-spaetzle
#
# Usage:
#   irm https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.ps1 | iex
#
# Or to install to a custom location:
#   irm https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install.ps1 | iex -InstallDir "C:\bin"

param(
    [string]$InstallDir = "$env:USERPROFILE\.local\bin",
    [string]$Image = "ghcr.io/tiliavir/opencode-spaetzle:latest"
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[install.ps1] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[install.ps1] WARNING: $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[install.ps1] ERROR: $Message" -ForegroundColor Red
    exit 1
}

Write-Info "Installing spaetzle wrapper script..."

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
}

$dockerVersion = docker --version
Write-Info "Docker found: $dockerVersion"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

if (-not (Test-Path $InstallDir -PathType Container)) {
    Write-Error "Cannot access or create install directory: $InstallDir"
}

$spaetzleScript = Join-Path $InstallDir "spaetzle.ps1"

Write-Info "Writing spaetzle wrapper to $spaetzleScript..."

$scriptContent = @'
# spaetzle — Docker wrapper for opencode-spaetzle
#
# Automatically detects and mounts host paths (Git config, SSH keys,
# npmrc, Maven settings) and forwards API tokens when present.
#
# Usage:
#   spaetzle.ps1 [docker run extra flags...] [-- command]
#
# Examples:
#   spaetzle.ps1
#   spaetzle.ps1 -e OPENAI_API_KEY=sk-...
#   spaetzle.ps1 -- opencode

param(
    [string]$Image = $env:OPENCODE_IMAGE,
    [string]$Workspace = $PWD,
    [string[]]$ExtraArgs = @(),
    [string[]]$Command = @()
)

if (-not $Image) {
    $Image = "ghcr.io/tiliavir/opencode-spaetzle:latest"
}

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[spaetzle] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[spaetzle] WARNING: $Message" -ForegroundColor Yellow
}

if ($args -contains "-v" -or $args -contains "--version") {
    Write-Info "spaetzle wrapper for opencode-spaetzle"
    Write-Info "Image: $Image"
    Write-Info "Workspace: $Workspace"
    exit 0
}

$dockerArgs = @("run", "-it")

$labelName = Split-Path -Leaf $Workspace
$label = "spaetzle-$labelName"
$dockerArgs += @("--name", $label)

$dockerArgs += @("-v", "${Workspace}:/workspace:rw")
$dockerArgs += @("-w", "/workspace")

$homeDir = $env:USERPROFILE
$containerHome = "/root"

function Add-Mount {
    param(
        [string]$HostPath,
        [string]$ContainerPath,
        [string]$Mode = "ro"
    )

    if (Test-Path $HostPath) {
        $dockerArgs += @("-v", "${HostPath}:${ContainerPath}:${Mode}")
        Write-Info "Mounting ${HostPath} → ${ContainerPath} (${Mode})"
    }
}

$gitconfig = Join-Path $homeDir ".gitconfig"
Add-Mount -HostPath $gitconfig -ContainerPath "$containerHome/.gitconfig"

$gitConfigDir = Join-Path $homeDir ".config\git"
if (Test-Path $gitConfigDir) {
    Add-Mount -HostPath $gitConfigDir -ContainerPath "$containerHome/.config/git"
}

$sshDir = Join-Path $homeDir ".ssh"
if (Test-Path $sshDir) {
    Add-Mount -HostPath $sshDir -ContainerPath "$containerHome/.ssh"
} else {
    Write-Warn "No ~/.ssh directory found — SSH-based git remotes will not work"
}

$githubCopilotDir = Join-Path $homeDir ".config\github-copilot"
if (Test-Path $githubCopilotDir) {
    Add-Mount -HostPath $githubCopilotDir -ContainerPath "$containerHome/.config/github-copilot"
}

$npmConfigDir = Join-Path $homeDir ".config\npm"
if (Test-Path $npmConfigDir) {
    Add-Mount -HostPath $npmConfigDir -ContainerPath "$containerHome/.config/npm"
}

$npmrc = Join-Path $homeDir ".npmrc"
if (Test-Path $npmrc) {
    Add-Mount -HostPath $npmrc -ContainerPath "$containerHome/.npmrc"
}

$m2Dir = Join-Path $homeDir ".m2"
if (Test-Path $m2Dir) {
    Add-Mount -HostPath $m2Dir -ContainerPath "$containerHome/.m2"
}

$opencodeDir = Join-Path $homeDir ".local\share\opencode"
if (Test-Path $opencodeDir) {
    Add-Mount -HostPath $opencodeDir -ContainerPath "$containerHome/.local/share/opencode"
}

if ($env:GITHUB_TOKEN) {
    $dockerArgs += @("-e", "GITHUB_TOKEN=${env:GITHUB_TOKEN}")
    Write-Info "Forwarding GITHUB_TOKEN"
} elseif ($env:GH_TOKEN) {
    $dockerArgs += @("-e", "GITHUB_TOKEN=${env:GH_TOKEN}")
    Write-Info "Forwarding GH_TOKEN as GITHUB_TOKEN"
} else {
    Write-Warn "No GITHUB_TOKEN / GH_TOKEN set — GitHub Copilot provider will not work without auth"
}

@("OPENAI_API_KEY", "ANTHROPIC_API_KEY") | ForEach-Object {
    $val = Get-Content "env:$_" -ErrorAction SilentlyContinue
    if ($val) {
        $dockerArgs += @("-e", "${_}=${val}")
        Write-Info "Forwarding ${_}"
    }
}

if ($ExtraArgs) {
    $dockerArgs += $ExtraArgs
}

$dockerArgs += $Image

if ($Command) {
    $dockerArgs += $Command
}

Write-Info "Starting opencode-spaetzle container (image: $Image)"
Write-Info "Workspace: $Workspace"
Write-Info "Container label: $label"

& docker @dockerArgs
'@

Set-Content -Path $spaetzleScript -Value $scriptContent -Encoding UTF8

$cmdScript = Join-Path $InstallDir "spaetzle.cmd"
$cmdContent = @"@echo off
REM spaetzle.cmd — Windows command wrapper for spaetzle.ps1

set "SCRIPT_DIR=$InstallDir"
set "SCRIPT_NAME=spaetzle.ps1"

if not exist "%SCRIPT_DIR%\%SCRIPT_NAME%" (
    echo [spaetzle] ERROR: spaetzle.ps1 not found in %SCRIPT_DIR%
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\%SCRIPT_NAME%" %*
"@

Set-Content -Path $cmdScript -Value $cmdContent -Encoding ASCII

Write-Info "Successfully installed spaetzle to $spaetzleScript"
Write-Info "Also installed spaetzle.cmd for Windows command prompt"

$pathParts = $env:PATH -split [IO.Path]::PathSeparator
$isInPath = $pathParts -contains $InstallDir

if (-not $isInPath) {
    Write-Warn "$InstallDir is not in your PATH"
    Write-Info "Add this to your PowerShell profile to use 'spaetzle.ps1' from anywhere:"
    Write-Info "  `$env:PATH = `"$InstallDir;`$env:PATH`""
}

Write-Info "Done! Run 'spaetzle.ps1' to start the container."
