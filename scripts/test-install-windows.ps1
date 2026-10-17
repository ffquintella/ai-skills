# Isolated integration checks. Run: powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-install-windows.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('ai-skills-test-' + [guid]::NewGuid())
$previousHome = $env:HOME
$previousPath = $env:PATH
$previousRouterHome = $env:AI_SKILLS_ROUTER_HOME
$previousCodexHome = $env:CODEX_HOME
$previousClaudeConfig = $env:CLAUDE_CONFIG_DIR
$previousCliLog = $env:AI_SKILLS_TEST_CLI_LOG
$project = Join-Path $sandbox 'project with spaces'
$optOutProject = Join-Path $sandbox 'router opt out'
$launcher = Join-Path $repo 'install.ps1'
$gitRoot = Split-Path (Split-Path (Get-Command git.exe -ErrorAction Stop).Source -Parent) -Parent
$bash = Join-Path $gitRoot 'bin/bash.exe'
function Run-Installer([string[]] $Flags, [int] $Expected = 0) {
    # Windows PowerShell wraps native stderr as ErrorRecord even for expected failures.
    $ErrorActionPreference = 'Continue'
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher @Flags 2>&1
    if ($LASTEXITCODE -ne $Expected) { throw "Installer exit $LASTEXITCODE (expected $Expected): $output" }
    return $output
}
try {
    New-Item -ItemType Directory -Path $project, $optOutProject -Force | Out-Null
    $env:HOME = Join-Path $sandbox 'home'
    $env:CODEX_HOME = Join-Path $env:HOME '.codex'
    $env:CLAUDE_CONFIG_DIR = Join-Path $env:HOME '.claude'
    $env:AI_SKILLS_ROUTER_HOME = $null
    New-Item -ItemType Directory -Path (Join-Path $env:HOME '.codex'), (Join-Path $env:HOME '.claude') -Force | Out-Null
    # Fixture CLIs keep plugin commands away from the actual user registrations.
    $fixtureBin = Join-Path $sandbox 'fixture bin'
    New-Item -ItemType Directory -Path $fixtureBin | Out-Null
    $env:AI_SKILLS_TEST_CLI_LOG = (Join-Path $sandbox 'cli.log').Replace('\', '/')
    $fixtureCli = @'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$AI_SKILLS_TEST_CLI_LOG"
if [ "$*" = 'plugin list --json' ] || [ "$*" = 'plugin marketplace list --json' ]; then printf '[]\n'; fi
exit 0
'@
    foreach ($cli in @('claude', 'codex')) {
        [IO.File]::WriteAllText((Join-Path $fixtureBin $cli), $fixtureCli.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
    }
    $env:PATH = $fixtureBin + [IO.Path]::PathSeparator + $previousPath
    $help = Run-Installer @('--help')
    if (($help -join "`n") -notmatch '--no-router') { throw 'Help omits router opt-out' }
    Run-Installer @('--unknown') 1 | Out-Null
    $list = Run-Installer @('--list', '--project', $project, '--no-external')
    if (($list -join "`n") -notmatch 'agent-router runtime: missing') { throw 'List must report missing router runtime' }
    if (($list -join "`n") -notlike '*project with spaces/.ai-skills/agent-router*') { throw 'List must report scoped router path' }
    if (Test-Path (Join-Path $project '.ai-skills')) { throw 'Help/list created router files' }
    Run-Installer @('--all', '--skills', '--project', $optOutProject, '--no-external', '--no-router') | Out-Null
    Run-Installer @('--all', '--plugin', '--project', $optOutProject, '--no-external', '--no-router') | Out-Null
    if (Test-Path (Join-Path $optOutProject '.ai-skills/agent-router')) { throw '--no-router prepared a runtime' }
    foreach ($vendor in @('claude', 'openai')) {
        $flags = @('--all', '--skills', '--vendor', $vendor, '--project', $project, '--no-external', '--agents')
        Run-Installer $flags | Out-Null
        $runtime = Join-Path $project '.ai-skills/agent-router'
        $policy = Join-Path $runtime 'models.yaml'
        if (-not (Test-Path -LiteralPath $policy)) { throw 'Missing router runtime policy' }
        if (-not (Test-Path -LiteralPath (Join-Path $runtime 'agent-router.exe'))) { throw 'Missing router runtime binary' }
        $skillsDir = if ($vendor -eq 'claude') { '.claude/skills' } else { '.agents/skills' }
        $agentDir = if ($vendor -eq 'claude') { '.claude/agents' } else { '.codex/agents' }
        foreach ($skill in Get-ChildItem (Join-Path $repo $vendor) -Directory) {
            if (Test-Path (Join-Path $skill.FullName 'SKILL.md')) {
                if (-not (Test-Path (Join-Path $project "$skillsDir/$($skill.Name)/SKILL.md"))) { throw "Missing $vendor/$($skill.Name)" }
            }
        }
        $target = Join-Path $project "$skillsDir/agent-router/SKILL.md"
        $skillLauncher = Join-Path $project "$skillsDir/agent-router/scripts/agent-router"
        if (-not (Test-Path -LiteralPath $skillLauncher)) { throw "Missing $vendor router launcher" }
        $routerVersion = & $bash --noprofile --norc $skillLauncher --version
        if ($LASTEXITCODE -ne 0 -or ($routerVersion -join "`n") -notmatch '^agent-router \d') { throw "$vendor router launcher failed: $routerVersion" }
        Add-Content -LiteralPath $policy -Value "`n# local policy customization for $vendor"
        $customPolicy = (Get-FileHash -LiteralPath $policy).Hash
        Set-Content -LiteralPath $target -Value 'local change'
        $agent = Get-ChildItem (Join-Path $project $agentDir) -File | Select-Object -First 1
        if (-not $agent) { throw "Missing agent templates for $vendor" }
        Set-Content -LiteralPath $agent.FullName -Value 'custom agent'
        Run-Installer $flags | Out-Null
        if ((Get-Content $target -Raw).Trim() -ne 'local change') { throw 'Install overwrote an existing skill' }
        Run-Installer ($flags + '--update') | Out-Null
        if ((Get-FileHash -LiteralPath $policy).Hash -ne $customPolicy) { throw 'Install/update overwrote custom router policy' }
        if ((Get-FileHash $target).Hash -ne (Get-FileHash (Join-Path $repo "$vendor/agent-router/SKILL.md")).Hash) { throw 'Update did not restore skill' }
        if ((Get-Content $agent.FullName -Raw).Trim() -ne 'custom agent') { throw 'Update overwrote an agent' }
        $list = Run-Installer @('--list', '--vendor', $vendor, '--project', $project, '--no-external')
        if (($list -join "`n") -notmatch 'agent-router runtime: installed') { throw 'List must report installed router runtime' }
    }
    # An explicit override wins over project/user defaults in both install modes.
    $env:AI_SKILLS_ROUTER_HOME = Join-Path $sandbox 'override runtime'
    Clear-Content -LiteralPath $env:AI_SKILLS_TEST_CLI_LOG
    $pluginOutput = Run-Installer @('--all', '--plugin', '--project', $project, '--no-external')
    if ([regex]::Matches(($pluginOutput -join "`n"), 'Preparing agent-router runtime at').Count -ne 1) { throw 'Plugin mode must prepare router exactly once for both vendors' }
    if (-not (Test-Path (Join-Path $env:AI_SKILLS_ROUTER_HOME 'models.yaml'))) { throw 'Plugin mode did not prepare override runtime' }
    $calls = Get-Content -LiteralPath $env:AI_SKILLS_TEST_CLI_LOG -Raw
    if ($calls -notmatch 'claude plugin install ai-skills@ai-skills' -or $calls -notmatch 'codex plugin add ai-skills@ai-skills') { throw 'Plugin fixture commands were not called for both vendors' }
    if (Test-Path (Join-Path $env:HOME '.local/share/ai-skills/agent-router')) { throw 'Override leaked into user runtime' }
    Write-Output 'PASS: help/list read-only, flags, vendors, spaced paths, install/update, launchers, runtime, policy/agents preserved, opt-out and fixture plugins.'
} finally {
    $env:HOME = $previousHome
    $env:PATH = $previousPath
    $env:AI_SKILLS_ROUTER_HOME = $previousRouterHome
    $env:CODEX_HOME = $previousCodexHome
    $env:CLAUDE_CONFIG_DIR = $previousClaudeConfig
    $env:AI_SKILLS_TEST_CLI_LOG = $previousCliLog
    # Delete only the unique test directory created above.
    if (Test-Path -LiteralPath $sandbox) {
        $resolvedSandbox = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $sandbox).Path)
        $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $resolvedSandbox.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -or
            (Split-Path $resolvedSandbox -Leaf) -notmatch '^ai-skills-test-[0-9a-f-]{36}$') {
            throw "Refusing to remove unexpected test directory: $resolvedSandbox"
        }
        Remove-Item -LiteralPath $resolvedSandbox -Recurse -Force
    }
}
