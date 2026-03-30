# install-helvetia.ps1 — Build a local wrapper image with company certs
#
# Usage:
#   irm https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.ps1 | iex
#
# Or to install to a custom location:
#   irm https://raw.githubusercontent.com/tiliavir/opencode-spaetzle/main/scripts/install-helvetia.ps1 | iex -InstallDir "C:\bin"

param(
    [string]$InstallDir = "$env:USERPROFILE\.local\bin",
    [string]$BaseImage = "ghcr.io/tiliavir/opencode-spaetzle:latest",
    [string]$Image = "opencode-spaetzle-helvetia:latest"
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[install-helvetia.ps1] $Message"
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[install-helvetia.ps1] WARNING: $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[install-helvetia.ps1] ERROR: $Message" -ForegroundColor Red
    exit 1
}

Write-Info "Building local wrapper image with company certificates..."
Write-Info "Base image: $BaseImage"
Write-Info "Wrapper image: $Image"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
}

$dockerVersion = docker --version
Write-Info "Docker found: $dockerVersion"

$tempDockerfile = [System.IO.Path]::GetTempFileName() + ".dockerfile"
Write-Info "Creating temporary Dockerfile..."

$dockerfileContent = @"
FROM jfrog.balgroupit.com/git-platform-docker/certbundler:latest AS certbundler
FROM ghcr.io/tiliavir/opencode-spaetzle:latest

COPY --from=certbundler /app/certbundler /app/certbundler
USER root
RUN /app/certbundler && rm -f /app/certbundler

WORKDIR /workspace

CMD ["bash"]
"@

Set-Content -Path $tempDockerfile -Value $dockerfileContent -Encoding UTF8

Write-Info "Building wrapper image..."
docker build --build-arg BASE_IMAGE=$BaseImage -t $Image -f $tempDockerfile .

Remove-Item $tempDockerfile -Force

Write-Info "Successfully built $Image"

$containerHome = "/root"
$homeDir = $env:USERPROFILE
$configHome = Join-Path $homeDir ".config"
$dataHome = Join-Path $homeDir ".local\share"

$staticMountDefinitions = [System.Collections.Generic.List[string]]::new()
$staticMountInfoLines = [System.Collections.Generic.List[string]]::new()

function Add-StaticMountDefinition {
    param(
        [string]$HostPath,
        [string]$ContainerPath,
        [string]$Mode = "ro"
    )

    if (Test-Path $HostPath) {
        $escapedHostPath = $HostPath.Replace("'", "''")
        $escapedContainerPath = $ContainerPath.Replace("'", "''")
        $staticMountDefinitions.Add("    @{ HostPath = '$escapedHostPath'; ContainerPath = '$escapedContainerPath'; Mode = '$Mode' }")
        $staticMountInfoLines.Add("Write-Info `"Mounting $HostPath to $ContainerPath ($Mode)`"")
    }
}

Add-StaticMountDefinition -HostPath (Join-Path $homeDir ".gitconfig") -ContainerPath "$containerHome/.gitconfig"
Add-StaticMountDefinition -HostPath (Join-Path $homeDir ".config\git") -ContainerPath "$containerHome/.config/git"

$sshDir = Join-Path $homeDir ".ssh"
if (Test-Path $sshDir) {
    Add-StaticMountDefinition -HostPath $sshDir -ContainerPath "$containerHome/.ssh"
} else {
    Write-Warn "No ~/.ssh directory found - SSH-based git remotes will not work"
}

Add-StaticMountDefinition -HostPath (Join-Path $configHome "github-copilot") -ContainerPath "$containerHome/.config/github-copilot"
Add-StaticMountDefinition -HostPath (Join-Path $configHome "npm") -ContainerPath "$containerHome/.config/npm"
Add-StaticMountDefinition -HostPath (Join-Path $homeDir ".npmrc") -ContainerPath "$containerHome/.npmrc"
Add-StaticMountDefinition -HostPath (Join-Path $homeDir ".m2") -ContainerPath "$containerHome/.m2" -Mode "rw"
Add-StaticMountDefinition -HostPath (Join-Path $dataHome "opencode") -ContainerPath "$containerHome/.local/share/opencode" -Mode "rw"

$staticMountsBlock = "    # No optional mounts detected during installation"
if ($staticMountDefinitions.Count -gt 0) {
    $staticMountsBlock = $staticMountDefinitions -join "`n"
}

$staticMountInfoBlock = "Write-Info `"No optional mounts configured`""
if ($staticMountInfoLines.Count -gt 0) {
    $staticMountInfoBlock = $staticMountInfoLines -join "`n"
}

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

if (-not (Test-Path $InstallDir -PathType Container)) {
    Write-Error "Cannot access or create install directory: $InstallDir"
}

$spaetzleScript = Join-Path $InstallDir "spaetzle.ps1"

Write-Info "Writing spaetzle wrapper to $spaetzleScript..."

$scriptContent = @'
# spaetzle — Docker wrapper for opencode-spaetzle (helvetia version)
#
# Uses host paths detected during installation (Git config, SSH keys,
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
    $Image = "opencode-spaetzle-helvetia:latest"
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
    Write-Info "spaetzle wrapper for opencode-spaetzle (helvetia)"
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

$StaticMounts = @(
__STATIC_MOUNTS__
)

foreach ($mount in $StaticMounts) {
    $dockerArgs += @("-v", "$($mount.HostPath):$($mount.ContainerPath):$($mount.Mode)")
}

__STATIC_MOUNT_INFO__

if ($env:GITHUB_TOKEN) {
    $dockerArgs += @("-e", "GITHUB_TOKEN=${env:GITHUB_TOKEN}")
    Write-Info "Forwarding GITHUB_TOKEN"
} elseif ($env:GH_TOKEN) {
    $dockerArgs += @("-e", "GITHUB_TOKEN=${env:GH_TOKEN}")
    Write-Info "Forwarding GH_TOKEN as GITHUB_TOKEN"
} else {
    Write-Warn "No GITHUB_TOKEN / GH_TOKEN set - GitHub Copilot provider will not work without auth"
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

$null = docker container inspect $label 2>&1
if ($LASTEXITCODE -eq 0) {
    $containerStatus = (docker container inspect --format '{{.State.Status}}' $label 2>$null)
    if ($containerStatus -eq "running") {
        Write-Info "Container '$label' is already running - reconnecting..."
        Write-Warn "Environment variables (tokens/keys) are from the original run and cannot be updated on reconnect."
        & docker exec -it $label bash
    } else {
        Write-Info "Container '$label' exists but is stopped - restarting..."
        Write-Warn "Environment variables (tokens/keys) are from the original run and cannot be updated on reconnect."
        & docker start -ai $label
    }
    exit
}

& docker @dockerArgs
'@

$scriptContent = $scriptContent.Replace("__STATIC_MOUNTS__", $staticMountsBlock)
$scriptContent = $scriptContent.Replace("__STATIC_MOUNT_INFO__", $staticMountInfoBlock)

Set-Content -Path $spaetzleScript -Value $scriptContent -Encoding UTF8

$cmdScript = Join-Path $InstallDir "spaetzle.cmd"
$cmdContent = @"
@echo off
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

Write-Info "Done!"
Write-Info ""
Write-Info "To customize the certificates, edit the Dockerfile that was used to build"
Write-Info "the wrapper image, or rebuild with:"
Write-Info "  docker build -t $Image -f /path/to/your/Dockerfile ."
