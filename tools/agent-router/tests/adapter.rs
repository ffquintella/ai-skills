use serde_json::Value;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::sync::OnceLock;
use std::time::{Duration, Instant};

static FIXTURE: OnceLock<PathBuf> = OnceLock::new();

fn fixture() -> &'static Path {
    FIXTURE
        .get_or_init(|| {
            let folder = Path::new(env!("CARGO_MANIFEST_DIR")).join("target/test-fixtures");
            std::fs::create_dir_all(&folder).unwrap();
            let binary = folder.join(if cfg!(windows) {
                "fake-codex.exe"
            } else {
                "fake-codex"
            });
            let result = Command::new("rustc")
                .args(["--edition=2024", "tests/fixtures/fake_codex.rs", "-o"])
                .arg(&binary)
                .current_dir(env!("CARGO_MANIFEST_DIR"))
                .output()
                .unwrap();
            assert!(
                result.status.success(),
                "{}",
                String::from_utf8_lossy(&result.stderr)
            );
            binary
        })
        .as_path()
}

fn run(mode: &str) -> Output {
    Command::new(env!("CARGO_BIN_EXE_agent-router"))
        .args([
            "--matrix",
            "models.yaml",
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--quota-source",
            "codex",
            "--quota-timeout-seconds",
            "1",
            "--codex-path",
        ])
        .arg(fixture())
        .env("ROUTER_TEST_MODE", mode)
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .unwrap()
}

#[test]
fn codex_handshake_and_live_quota_are_read_without_inference() {
    let out = run("success");
    assert!(
        out.status.success(),
        "{}",
        String::from_utf8_lossy(&out.stdout)
    );
    let d: Value = serde_json::from_slice(&out.stdout).unwrap();
    assert_eq!(d["mode"], "extreme");
    assert_eq!(d["quota"]["remaining_percent"], 5.0);
    assert_eq!(d["quota"]["windows"][0]["duration_minutes"], 300);
}

#[test]
fn timeout_kills_and_reaps_server_instead_of_waiting_for_its_completion() {
    let pid_file = std::env::temp_dir().join(format!("router-reap-{}.txt", std::process::id()));
    let binary = fixture();
    let start = Instant::now();
    let out = Command::new(env!("CARGO_BIN_EXE_agent-router"))
        .args([
            "--matrix",
            "models.yaml",
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--quota-source",
            "codex",
            "--quota-timeout-seconds",
            "1",
            "--codex-path",
        ])
        .arg(binary)
        .env("ROUTER_TEST_MODE", "timeout")
        .env("ROUTER_TEST_PID", &pid_file)
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .unwrap();
    assert_eq!(out.status.code(), Some(5));
    assert!(start.elapsed() < Duration::from_secs(5));
    let pid = std::fs::read_to_string(&pid_file).unwrap();
    let _ = std::fs::remove_file(pid_file);
    if cfg!(windows) {
        let result = Command::new("tasklist.exe")
            .args(["/FI", &format!("PID eq {pid}"), "/NH"])
            .output()
            .unwrap();
        assert!(
            !String::from_utf8_lossy(&result.stdout)
                .split_whitespace()
                .any(|s| s == pid)
        );
    } else {
        let result = Command::new("kill").args(["-0", &pid]).output().unwrap();
        assert!(!result.status.success());
    }
}

#[test]
fn protocol_errors_are_bounded_and_never_echo_server_secrets() {
    for mode in ["error", "malformed", "missing", "oversized"] {
        let out = run(mode);
        assert_eq!(out.status.code(), Some(5), "mode={mode}");
        let text = String::from_utf8_lossy(&out.stdout);
        assert!(!text.contains("secret"));
        assert_eq!(
            serde_json::from_slice::<Value>(&out.stdout).unwrap()["error"]["code"],
            "adapter_failure"
        );
    }
}

#[test]
fn invalid_manual_percentages_fail_before_starting_quota_query() {
    let out = Command::new(env!("CARGO_BIN_EXE_agent-router"))
        .args([
            "--matrix",
            "models.yaml",
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--daily-remaining",
            "101",
            "--quota-source",
            "codex",
            "--quota-timeout-seconds",
            "1",
            "--codex-path",
        ])
        .arg(fixture())
        .env("ROUTER_TEST_MODE", "timeout")
        .current_dir(env!("CARGO_MANIFEST_DIR"))
        .output()
        .unwrap();
    assert_eq!(
        out.status.code(),
        Some(2),
        "invalid input must not initiate external quota reads"
    );
}
