# Integrate agent-router into plugins and installers

User authorized implementation as an extension of the CLI. Continue on
codex/agent-router-cli, preserving prior edits. No live plugin registration or push.
Ship source and launchers in the plugin; keep builds/custom YAML outside its cache.

## Runtime contract

scripts/router-runtime.sh implements --root PATH --runtime-dir PATH, --ensure,
--status, and -- followed by CLI arguments. Default runtime: AI_SKILLS_ROUTER_HOME,
else XDG_DATA_HOME/ai-skills/agent-router, else HOME/.local/share/ai-skills/agent-router.
Project installer uses PROJECT/.ai-skills/agent-router. Ensure prints only the
binary path to stdout; logs/build output go to stderr. Status never builds.

Detect six native Rust targets. Reuse a matching installed binary/source fingerprint;
otherwise prefer a verified current local native build or AI_SKILLS_ROUTER_BINARY,
then cargo build --locked --release --target TARGET --target-dir RUNTIME/build.
Missing Cargo/compiler or failed build fails clearly, preserving installed data.
Do not auto-install Rust. Serialize preparation and atomically replace the binary.
Fingerprint Cargo.toml, Cargo.lock and src, excluding YAML. Never build in plugin cache.

Create models.yaml when absent. Refresh unmodified managed policies; preserve custom
policies and write the new default to models.yaml.dist. Refresh README/SCHEMA.
Do not change PATH or shell profiles.

## Task 1: shared runtime and launchers (coordinator)

Test first build, reuse, stale source, failures, native prebuilt, policy preservation,
stdout purity and paths with spaces using isolated fixtures. RED before code.
Add root scripts/agent-router and identical skill-local launchers in both vendors.
Plugin launchers resolve their root and prepare runtime on use. Copied skills use
project runtime then user runtime without needing the source checkout.

## Task 2: installer integration (implementer)

Own install.sh and scripts/test-install-windows.ps1 only. Auto-ensure router once
when agent-router selected and once before plugin installation, even --no-external.
Add --no-router. Help/list never build; list reports status/path. Scope user/project,
AI_SKILLS_ROUTER_HOME wins. PowerShell keeps delegating to Bash.
Tests assert runtime, both vendor launchers, custom policy survival, opt-out, and
plugin mode with fixture CLIs. Preserve existing skill and agent-template behavior.

## Task 3: docs, CI, verification (coordinator)

Skills invoke bundled launcher, not an assumed PATH command. Document automatic
bootstrap, paths, overrides, prerequisites and preserved policy. Version 0.3.1.
CI runs runtime/installer fixtures on native jobs, retaining standalone archives.
Run Rust tests/fmt/clippy/audit, package smoke, runtime tests and Windows installer
tests. Independent final review. Other OS runtime evidence remains CI pending.
