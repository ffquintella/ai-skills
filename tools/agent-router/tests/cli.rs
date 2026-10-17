use serde_json::{Value, json};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Output, Stdio};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};

static NEXT: AtomicUsize = AtomicUsize::new(0);
struct Temp(PathBuf);
impl Temp {
    fn new() -> Self {
        let p = std::env::temp_dir().join(format!(
            "agent-router-test-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ));
        fs::create_dir_all(&p).unwrap();
        Self(p)
    }
    fn write(&self, name: &str, content: &str) -> PathBuf {
        let p = self.0.join(name);
        fs::write(&p, content).unwrap();
        p
    }
}
impl Drop for Temp {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
fn matrix() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("models.yaml")
}
fn run(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_agent-router"))
        .arg("--matrix")
        .arg(matrix())
        .args(args)
        .output()
        .unwrap()
}
fn value(out: &Output, code: i32) -> Value {
    assert_eq!(
        out.status.code(),
        Some(code),
        "stdout={} stderr={}",
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    serde_json::from_slice(&out.stdout).expect("single JSON object on stdout")
}
fn decision(extra: &[&str]) -> Value {
    let mut args = vec!["--provider", "openai", "--task", "lookup"];
    args.extend(extra);
    value(&run(&args), 0)
}
fn snapshot(provider: &str, remaining: f64, duration: u64, bucket: Option<&str>) -> Value {
    json!({"provider":provider,"observed_at":now(),"windows":[{"name":"test","remaining_percent":remaining,"duration_minutes":duration,"bucket":bucket}]})
}
fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}
fn with_quota(payload: Value, extra: &[&str]) -> (Temp, Value) {
    let temp = Temp::new();
    let p = temp.write("quota.json", &payload.to_string());
    let mut args = vec!["--quota-file", p.to_str().unwrap()];
    args.extend(extra);
    let result = decision(&args);
    (temp, result)
}

#[test]
fn cheapest_capable_and_security_floor() {
    assert_eq!(
        decision(&["--daily-remaining", "80"])["model"],
        "gpt-6-luna"
    );
    let d = decision(&["--security-sensitive", "--daily-remaining", "5"]);
    assert_eq!(d["model"], "gpt-6.1-sol");
    assert_eq!(d["effort"], "xhigh");
    assert_eq!(d["concurrency"], 1);
    assert_eq!(d["optional_delegation"], false);
}
#[test]
fn exact_quota_thresholds_and_unknown() {
    for (remaining, mode) in [("25.01", "normal"), ("25", "economy"), ("10", "extreme")] {
        assert_eq!(decision(&["--daily-remaining", remaining])["mode"], mode);
    }
    assert_eq!(decision(&[])["mode"], "economy");
    let d = value(
        &run(&[
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--weekly-remaining",
            "0",
        ]),
        3,
    );
    assert!(d["model"].is_null());
    assert_eq!(d["mode"], "blocked");
}
#[test]
fn estimates_and_mode_workload_conflicts() {
    assert!(decision(&[])["estimated_api_cost_usd"].is_null());
    let d = decision(&["--output-tokens", "500"]);
    assert_eq!(d["estimated_api_cost_usd"], 0.00065);
    assert!(!d["cost_assumptions"].as_array().unwrap().is_empty());
    let d = value(
        &run(&[
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--daily-remaining",
            "5",
            "--output-tokens",
            "3000",
        ]),
        4,
    );
    assert_eq!(d["error"]["code"], "no_eligible_model");
}
#[test]
fn availability_and_provider_do_not_fallback() {
    assert_eq!(
        decision(&["--available-models", "gpt-6-astra,gpt-6.1-sol"])["model"],
        "gpt-6.1-sol"
    );
    let d = value(
        &run(&[
            "--provider",
            "openai",
            "--task",
            "complex",
            "--available-models",
            "claude-opus-5-5",
        ]),
        4,
    );
    assert_eq!(d["error"]["code"], "no_eligible_model");
}
#[test]
fn normalized_freshness_partial_and_override() {
    for observed in [Some(now() - 1000), Some(now() + 60), None] {
        let mut q = snapshot("openai", 0.0, 300, None);
        match observed {
            Some(t) => q["observed_at"] = json!(t),
            None => {
                q.as_object_mut().unwrap().remove("observed_at");
            }
        }
        let (_t, d) = with_quota(q, &[]);
        assert_eq!(d["mode"], "economy");
        assert!(!d["quota"]["warnings"].as_array().unwrap().is_empty());
    }
    let mut q = snapshot("openai", 0.0, 300, None);
    q["windows"][0]["resets_at"] = json!(now() - 1);
    assert_eq!(with_quota(q, &[]).1["mode"], "economy");
    let q = json!({"provider":"openai","observed_at":now(),"windows":[{"name":"missing"},{"name":"daily","duration_minutes":1440,"remaining_percent":0},{"name":"5h","duration_minutes":300,"remaining_percent":9}]});
    let (_t, d) = with_quota(q, &["--daily-remaining", "90"]);
    assert_eq!(d["mode"], "extreme");
    assert_eq!(d["quota"]["remaining_percent"], 9.0);
}
#[test]
fn quotas_are_bucket_and_provider_isolated() {
    let q = snapshot("anthropic", 0.0, 10080, None);
    assert_eq!(with_quota(q, &[]).1["mode"], "economy");
    let q = snapshot("openai", 0.0, 300, Some("unrelated"));
    let (_t, d) = with_quota(q, &["--daily-remaining", "80"]);
    assert_eq!(d["mode"], "normal");
    assert!(
        d["quota"]["warnings"]
            .as_array()
            .unwrap()
            .iter()
            .any(|v| v.as_str().unwrap().contains("unrecognized bucket"))
    );
}
#[test]
fn native_codex_and_claude_keep_window_lengths() {
    let q = json!({"observed_at":now(),"payload":{"result":{"rateLimits":{"primary":{"usedPercent":100,"windowDurationMins":1440}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":91,"windowDurationMins":300,"resetsAt":now()+1000}}}}}});
    let (_t, d) = with_quota(q, &[]);
    assert_eq!(d["mode"], "extreme");
    assert_eq!(d["quota"]["windows"][0]["duration_minutes"], 300);
    let t = Temp::new();
    let p=t.write("claude.json",&json!({"observed_at":now(),"payload":{"rate_limits":{"five_hour":{"used_percentage":80,"resets_at":now()+1000},"seven_day":{"used_percentage":5}}}}).to_string());
    let d = value(
        &run(&[
            "--provider",
            "anthropic",
            "--task",
            "lookup",
            "--quota-file",
            p.to_str().unwrap(),
        ]),
        0,
    );
    assert_eq!(d["mode"], "economy");
    assert_eq!(d["quota"]["remaining_percent"], 20.0);
}
#[test]
fn malformed_inputs_conflicts_and_safe_json_errors() {
    for args in [
        vec![
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--daily-remaining",
            "101",
        ],
        vec![
            "--provider",
            "openai",
            "--task",
            "lookup",
            "--quota-stdin",
            "--quota-source",
            "codex",
        ],
        vec!["--provider", "unknown", "--task", "lookup"],
    ] {
        value(&run(&args), 2);
    }
    let t = Temp::new();
    for raw in [
        "{",
        r#"{"provider":"openai","windows":[],"typo":3}"#,
        r#"{"rate_limits":{"five_hour":{"used_percentage":"bad"}}}"#,
        r#"{"rateLimits":{"primary":{"usedPercent":-1,"windowDurationMins":300}}}"#,
    ] {
        let p = t.write("bad.json", raw);
        value(
            &run(&[
                "--provider",
                "openai",
                "--task",
                "lookup",
                "--quota-file",
                p.to_str().unwrap(),
            ]),
            2,
        );
    }
}
#[test]
fn dynamic_yaml_replacement_tie_break_and_price_bands() {
    let t = Temp::new();
    let yaml = fs::read_to_string(matrix())
        .unwrap()
        .replace("gpt-6-luna", "custom-cheap");
    let p = t.write("models.yaml", &yaml);
    let d = value(
        &Command::new(env!("CARGO_BIN_EXE_agent-router"))
            .args([
                "--matrix",
                p.to_str().unwrap(),
                "--provider",
                "openai",
                "--task",
                "lookup",
            ])
            .output()
            .unwrap(),
        0,
    );
    assert_eq!(d["model"], "custom-cheap");
    let d = value(
        &run(&[
            "--provider",
            "anthropic",
            "--task",
            "lookup",
            "--input-tokens",
            "100001",
            "--daily-remaining",
            "80",
        ]),
        0,
    );
    assert_eq!(d["estimated_api_cost_usd"], 0.0525005);
}
#[test]
fn rejects_missing_empty_unsupported_and_malformed_matrix() {
    let t = Temp::new();
    for raw in [
        "",
        "schema_version: 99",
        "schema_version: 1\nunknown: yes",
        "{",
    ] {
        let p = t.write("bad.yaml", raw);
        value(
            &Command::new(env!("CARGO_BIN_EXE_agent-router"))
                .args([
                    "--matrix",
                    p.to_str().unwrap(),
                    "--provider",
                    "openai",
                    "--task",
                    "lookup",
                ])
                .output()
                .unwrap(),
            2,
        );
    }
    value(
        &Command::new(env!("CARGO_BIN_EXE_agent-router"))
            .args([
                "--matrix",
                t.0.join("missing").to_str().unwrap(),
                "--provider",
                "openai",
                "--task",
                "lookup",
            ])
            .output()
            .unwrap(),
        2,
    );
}
#[test]
fn compact_json_text_help_and_stdin() {
    let out = run(&["--provider", "openai", "--task", "lookup"]);
    value(&out, 0);
    assert_eq!(String::from_utf8_lossy(&out.stdout).lines().count(), 1);
    let out = run(&[
        "--provider",
        "openai",
        "--task",
        "lookup",
        "--format",
        "text",
    ]);
    assert!(String::from_utf8_lossy(&out.stdout).contains("gpt-6-luna"));
    let out = run(&["--help"]);
    assert!(out.status.success());
    assert!(String::from_utf8_lossy(&out.stdout).contains("--quota-source"));
    let mut child = Command::new(env!("CARGO_BIN_EXE_agent-router"))
        .arg("--matrix")
        .arg(matrix())
        .args(["--provider", "openai", "--task", "lookup", "--quota-stdin"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .unwrap();
    child
        .stdin
        .take()
        .unwrap()
        .write_all(snapshot("openai", 80.0, 300, None).to_string().as_bytes())
        .unwrap();
    assert_eq!(
        value(&child.wait_with_output().unwrap(), 0)["mode"],
        "normal"
    );
}
