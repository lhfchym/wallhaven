param(
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",
    [string] $QtRoot = "C:\Qt\6.8.3\msvc2022_64",
    [switch] $Package
)

$ErrorActionPreference = "Stop"

$windowsSource = $PSScriptRoot
$repositoryRoot = Split-Path -Parent $windowsSource

if ($repositoryRoot -match "[^\x00-\x7F]") {
    $junctionParent = Join-Path $env:LOCALAPPDATA "WallhavenBuild"
    $junctionRoot = Join-Path $junctionParent "source"
    New-Item -ItemType Directory -Path $junctionParent -Force | Out-Null

    if (Test-Path -LiteralPath $junctionRoot) {
        $junctionItem = Get-Item -LiteralPath $junctionRoot
        $existingTarget = [string] $junctionItem.Target
        if ($junctionItem.LinkType -ne "Junction" -or
            [IO.Path]::GetFullPath($existingTarget) -ne [IO.Path]::GetFullPath($repositoryRoot)) {
            throw "Build junction already exists and points elsewhere: $junctionRoot"
        }
    } else {
        New-Item -ItemType Junction -Path $junctionRoot -Target $repositoryRoot | Out-Null
    }

    $windowsSource = Join-Path $junctionRoot "Windows"
}

if (-not (Test-Path -LiteralPath (Join-Path $QtRoot "bin\qmake.exe"))) {
    throw "Qt was not found at $QtRoot"
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path -LiteralPath $vswhere)) {
    throw "vswhere was not found. Install Visual Studio 2022 Build Tools with the C++ workload."
}

$visualStudio = & $vswhere -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
if (-not $visualStudio) {
    throw "The MSVC x64 toolchain was not found."
}

$vsDevCmd = Join-Path $visualStudio "Common7\Tools\VsDevCmd.bat"
$developerEnvironment = & cmd.exe /d /s /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to initialize the MSVC developer environment."
}
foreach ($line in $developerEnvironment) {
    if ($line -match "^([^=]+)=(.*)$") {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

$cmakeCommand = Get-Command cmake.exe -ErrorAction SilentlyContinue
$cmake = if ($cmakeCommand) {
    $cmakeCommand.Source
} else {
    Join-Path $env:ProgramFiles "CMake\bin\cmake.exe"
}
if (-not (Test-Path -LiteralPath $cmake)) {
    throw "CMake was not found."
}

$ninjaCommand = Get-Command ninja.exe -ErrorAction SilentlyContinue
if ($ninjaCommand) {
    $ninja = $ninjaCommand.Source
} else {
    $ninja = Get-ChildItem -Path (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet") `
        -Recurse -Filter ninja.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $ninja -or -not (Test-Path -LiteralPath $ninja)) {
    throw "Ninja was not found."
}

$buildDirectory = Join-Path $windowsSource ("build-" + $Configuration.ToLowerInvariant())

& $cmake `
    -S $windowsSource `
    -B $buildDirectory `
    -G Ninja `
    "-DCMAKE_BUILD_TYPE=$Configuration" `
    "-DCMAKE_PREFIX_PATH=$QtRoot" `
    "-DCMAKE_MAKE_PROGRAM=$ninja"
if ($LASTEXITCODE -ne 0) {
    throw "CMake configuration failed."
}

& $cmake --build $buildDirectory --parallel
if ($LASTEXITCODE -ne 0) {
    throw "Build failed."
}

if ($Package) {
    $packageStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $packageDirectory = Join-Path $PSScriptRoot "dist\WallhavenWindows-$Configuration-$packageStamp"
    & $cmake --install $buildDirectory --prefix $packageDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Packaging failed."
    }
    Write-Host "Packaged application: $packageDirectory"
} else {
    Write-Host "Built executable: $(Join-Path $buildDirectory 'WallhavenWindows.exe')"
}
