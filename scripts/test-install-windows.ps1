# Isolated integration checks. Run: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-install-windows.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ai-skills-test-' + [guid]::NewGuid())
$previousHome = $env:HOME
$project = Join-Path $sandbox 'project with spaces'
$launcher = Join-Path $repo 'install.ps1'
function Run-Installer([string[]] $Flags, [int] $Expected = 0) {
    # Windows PowerShell wraps native stderr as ErrorRecord even for expected failures.
    $ErrorActionPreference = 'Continue'
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher @Flags 2>&1
    if ($LASTEXITCODE -ne $Expected) { throw "Installer exit $LASTEXITCODE (expected $Expected): $output" }
    return $output
}
try {
    New-Item -ItemType Directory -Path $project -Force | Out-Null
    $env:HOME = Join-Path $sandbox 'home'
    New-Item -ItemType Directory -Path (Join-Path $env:HOME '.codex'), (Join-Path $env:HOME '.claude') -Force | Out-Null
    Run-Installer @('--help') | Out-Null
    Run-Installer @('--unknown') 1 | Out-Null
    foreach ($vendor in @('claude', 'openai')) {
        $flags = @('--all', '--skills', '--vendor', $vendor, '--project', $project, '--no-external', '--agents')
        Run-Installer $flags | Out-Null
        $skillsDir = if ($vendor -eq 'claude') { '.claude/skills' } else { '.agents/skills' }
        $agentDir = if ($vendor -eq 'claude') { '.claude/agents' } else { '.codex/agents' }
        foreach ($skill in Get-ChildItem (Join-Path $repo $vendor) -Directory) {
            if (Test-Path (Join-Path $skill.FullName 'SKILL.md')) {
                if (-not (Test-Path (Join-Path $project "$skillsDir/$($skill.Name)/SKILL.md"))) { throw "Missing $vendor/$($skill.Name)" }
            }
        }
        $target = Join-Path $project "$skillsDir/agent-router/SKILL.md"
        Set-Content -LiteralPath $target -Value 'local change'
        $agent = Get-ChildItem (Join-Path $project $agentDir) -File | Select-Object -First 1
        if (-not $agent) { throw "Missing agent templates for $vendor" }
        Set-Content -LiteralPath $agent.FullName -Value 'custom agent'
        Run-Installer $flags | Out-Null
        if ((Get-Content $target -Raw).Trim() -ne 'local change') { throw 'Install overwrote an existing skill' }
        Run-Installer ($flags + '--update') | Out-Null
        if ((Get-FileHash $target).Hash -ne (Get-FileHash (Join-Path $repo "$vendor/agent-router/SKILL.md")).Hash) { throw 'Update did not restore skill' }
        if ((Get-Content $agent.FullName -Raw).Trim() -ne 'custom agent') { throw 'Update overwrote an agent' }
        Run-Installer @('--list', '--vendor', $vendor, '--project', $project, '--no-external') | Out-Null
    }
    Write-Output 'PASS: help, invalid flags, both vendors, project paths with spaces, install, update, agent preservation and list.'
} finally {
    $env:HOME = $previousHome
    # Delete only the unique test directory created above.
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
