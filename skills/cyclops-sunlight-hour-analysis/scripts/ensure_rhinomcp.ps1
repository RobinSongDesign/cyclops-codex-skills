[CmdletBinding()]
param(
    [ValidateSet("8")]
    [string]$RhinoVersion = "8",

    [switch]$InstallIfMissing,

    [string]$CodexConfigPath = (Join-Path (Join-Path $env:USERPROFILE ".codex") "config.toml"),

    [string]$PackageRoot,

    [string]$YakPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-ResultAndExit {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Result,

        [int]$ExitCode = 0
    )

    [pscustomobject]$Result | ConvertTo-Json -Compress -Depth 5
    exit $ExitCode
}

function Get-RouterCandidate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Architecture
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $null
    }

    $candidates = @(
        Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $router = Join-Path $_.FullName ("router\{0}\rhino-mcp-router.exe" -f $Architecture)
            if (Test-Path -LiteralPath $router -PathType Leaf) {
                $numericVersion = $_.Name -replace '-.*$', ''
                try {
                    $parsedVersion = [version]$numericVersion
                }
                catch {
                    $parsedVersion = [version]"0.0"
                }

                [pscustomobject]@{
                    VersionName = $_.Name
                    ParsedVersion = $parsedVersion
                    Stable = ($_.Name -notmatch '-')
                    RouterPath = $router
                }
            }
        }
    )

    if ($candidates.Count -eq 0) {
        return $null
    }

    return $candidates |
        Sort-Object -Property @{ Expression = "Stable"; Descending = $true }, @{ Expression = "ParsedVersion"; Descending = $true } |
        Select-Object -First 1
}

function Get-ConfiguredRhinoCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigText
    )

    $sectionPattern = '(?ms)^\[mcp_servers\.rhino\]\s*\r?\n.*?(?=^\[|\z)'
    $sectionMatch = [regex]::Match($ConfigText, $sectionPattern)
    if (-not $sectionMatch.Success) {
        return $null
    }

    $commandPattern = '(?m)^\s*command\s*=\s*(?<quote>[''"])(?<command>.*?)\k<quote>\s*$'
    $commandMatch = [regex]::Match($sectionMatch.Value, $commandPattern)
    if (-not $commandMatch.Success) {
        return $null
    }

    return $commandMatch.Groups['command'].Value -replace '\\\\', '\'
}

function Test-CommandAvailable {
    param(
        [AllowNull()]
        [string]$Command
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }

    if (Test-Path -LiteralPath $Command -PathType Leaf) {
        return $true
    }

    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Set-RhinoMcpConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true)]
        [string]$RouterPath,

        [Parameter(Mandatory = $true)]
        [string]$DefaultRhinoVersion
    )

    $configDirectory = Split-Path -Parent $ConfigPath
    if ([string]::IsNullOrWhiteSpace($configDirectory)) {
        throw "CodexConfigPath must include a parent directory."
    }

    if (-not (Test-Path -LiteralPath $configDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $configDirectory -Force | Out-Null
    }

    $existingText = ""
    $configExists = Test-Path -LiteralPath $ConfigPath -PathType Leaf
    if ($configExists) {
        $existingText = [IO.File]::ReadAllText($ConfigPath)
    }

    $escapedRouter = $RouterPath.Replace('\', '\\').Replace('"', '\"')
    $newSection = @"
[mcp_servers.rhino]
command = "$escapedRouter"
args = ["--default-version", "$DefaultRhinoVersion"]
"@

    $sectionPattern = '(?ms)^\[mcp_servers\.rhino\]\s*\r?\n.*?(?=^\[|\z)'
    $sectionMatch = [regex]::Match($existingText, $sectionPattern)
    if ($sectionMatch.Success) {
        $newText = $existingText.Substring(0, $sectionMatch.Index) + $newSection.TrimEnd() + "`r`n`r`n" + $existingText.Substring($sectionMatch.Index + $sectionMatch.Length).TrimStart("`r", "`n")
    }
    else {
        $separator = if ([string]::IsNullOrWhiteSpace($existingText)) { "" } else { "`r`n`r`n" }
        $newText = $existingText.TrimEnd("`r", "`n") + $separator + $newSection.TrimEnd() + "`r`n"
    }

    if ($newText -eq $existingText) {
        return [pscustomobject]@{
            Changed = $false
            BackupPath = $null
        }
    }

    $backupPath = $null
    if ($configExists) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "{0}.bak-{1}" -f $ConfigPath, $timestamp
        Copy-Item -LiteralPath $ConfigPath -Destination $backupPath
    }

    $temporaryPath = "{0}.tmp-{1}" -f $ConfigPath, ([guid]::NewGuid().ToString("N"))
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)

    try {
        [IO.File]::WriteAllText($temporaryPath, $newText, $utf8WithoutBom)
        Move-Item -LiteralPath $temporaryPath -Destination $ConfigPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }

    return [pscustomobject]@{
        Changed = $true
        BackupPath = $backupPath
    }
}

if ($env:OS -ne "Windows_NT") {
    Write-ResultAndExit -ExitCode 10 -Result @{
        status = "unsupported_platform"
        message = "Automatic RhinoMCP installation currently supports Windows only. Use the official McNeel setup guide."
        restartRequired = $false
    }
}

try {
    $CodexConfigPath = [IO.Path]::GetFullPath($CodexConfigPath)

    if ([string]::IsNullOrWhiteSpace($YakPath)) {
        $YakPath = Join-Path ${env:ProgramFiles} ("Rhino {0}\System\Yak.exe" -f $RhinoVersion)
    }

    if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
        $PackageRoot = Join-Path ([Environment]::GetFolderPath("ApplicationData")) ("McNeel\Rhinoceros\packages\{0}.0\Rhino-MCP-Platform" -f $RhinoVersion)
    }

    if (-not (Test-Path -LiteralPath $YakPath -PathType Leaf)) {
        Write-ResultAndExit -ExitCode 11 -Result @{
            status = "missing_rhino"
            message = "Rhino $RhinoVersion or its Yak package manager was not found at $YakPath."
            rhinoVersion = $RhinoVersion
            restartRequired = $false
        }
    }

    $architecture = if ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [Runtime.InteropServices.Architecture]::Arm64) { "win-arm64" } else { "win-x64" }
    $configText = if (Test-Path -LiteralPath $CodexConfigPath -PathType Leaf) { [IO.File]::ReadAllText($CodexConfigPath) } else { "" }
    $configuredCommand = Get-ConfiguredRhinoCommand -ConfigText $configText

    if (Test-CommandAvailable -Command $configuredCommand) {
        Write-ResultAndExit -Result @{
            status = "ready"
            message = "RhinoMCP is installed and the Codex configuration points to an available router."
            rhinoVersion = $RhinoVersion
            routerPath = $configuredCommand
            packageInstalled = $true
            configChanged = $false
            backupPath = $null
            restartRequired = $false
        }
    }

    $routerCandidate = Get-RouterCandidate -Root $PackageRoot -Architecture $architecture
    $installedNow = $false

    if ($null -eq $routerCandidate) {
        if (-not $InstallIfMissing) {
            Write-ResultAndExit -ExitCode 20 -Result @{
                status = "missing_dependency"
                message = "Rhino-MCP-Platform is not installed. Rerun with -InstallIfMissing to install the official McNeel package."
                rhinoVersion = $RhinoVersion
                restartRequired = $false
            }
        }

        $yakOutput = & $YakPath install Rhino-MCP-Platform 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-ResultAndExit -ExitCode 21 -Result @{
                status = "install_failed"
                message = ("Yak could not install Rhino-MCP-Platform. " + $yakOutput.Trim())
                rhinoVersion = $RhinoVersion
                restartRequired = $false
            }
        }

        $installedNow = $true
        $routerCandidate = Get-RouterCandidate -Root $PackageRoot -Architecture $architecture
        if ($null -eq $routerCandidate) {
            Write-ResultAndExit -ExitCode 22 -Result @{
                status = "install_failed"
                message = "Yak reported success, but no RhinoMCP router was found in $PackageRoot."
                rhinoVersion = $RhinoVersion
                restartRequired = $true
            }
        }
    }

    $configResult = Set-RhinoMcpConfig -ConfigPath $CodexConfigPath -RouterPath $routerCandidate.RouterPath -DefaultRhinoVersion $RhinoVersion
    $needsRestart = $installedNow -or $configResult.Changed

    Write-ResultAndExit -Result @{
        status = if ($needsRestart) { "installed" } else { "ready" }
        message = if ($needsRestart) { "RhinoMCP is installed and configured. Restart Rhino and Codex before continuing." } else { "RhinoMCP is installed and configured." }
        rhinoVersion = $RhinoVersion
        packageVersion = $routerCandidate.VersionName
        routerPath = $routerCandidate.RouterPath
        packageInstalled = $true
        configChanged = $configResult.Changed
        backupPath = $configResult.BackupPath
        restartRequired = $needsRestart
    }
}
catch {
    Write-ResultAndExit -ExitCode 99 -Result @{
        status = "error"
        message = $_.Exception.Message
        rhinoVersion = $RhinoVersion
        restartRequired = $false
    }
}
