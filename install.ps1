# Windows entry point; shares all installer behavior with install.sh.
# Usage: .\install.ps1 --all --vendor openai --no-external
# Requires Git for Windows (including Git Bash), not WSL.
$ErrorActionPreference = 'Stop'

$candidates = @()
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
if ($gitCommand) {
    $gitRoot = Split-Path (Split-Path $gitCommand.Source -Parent) -Parent
    $candidates += Join-Path $gitRoot 'bin\bash.exe'
}
foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA)) {
    if ($base) {
        $candidates += Join-Path $base 'Git\bin\bash.exe'
        $candidates += Join-Path $base 'Programs\Git\bin\bash.exe'
    }
}
$bash = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $bash) {
    Write-Error 'Git Bash was not found. Install Git for Windows (https://gitforwindows.org), then rerun install.ps1. WSL bash is not supported by this launcher.'
    exit 1
}

# Do not use a login shell: it can change HOME, PATH and the working directory.
# Pass arguments individually, so project paths containing spaces stay intact.
$installer = (Join-Path $PSScriptRoot 'install.sh').Replace('\', '/')
& $bash --noprofile --norc $installer @args
exit $LASTEXITCODE
