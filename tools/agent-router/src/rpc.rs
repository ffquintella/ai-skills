//! Small read-only JSON-RPC client. Does not start inference or access token files.
use crate::{Error, Result};
use serde_json::{Value, json};
use std::io::{BufRead, BufReader, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{Receiver, sync_channel};
use std::time::{Duration, Instant};

const MAX_BYTES: u64 = 4 * 1024 * 1024;

struct Server(Child);
impl Drop for Server {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}

fn executable(explicit: Option<&Path>) -> Result<PathBuf> {
    if let Some(path) = explicit {
        if path.extension().is_some_and(|e| {
            e.eq_ignore_ascii_case("cmd")
                || e.eq_ignore_ascii_case("ps1")
                || e.eq_ignore_ascii_case("bat")
        }) {
            return Err(Error::adapter(
                "--codex-path must name the native executable, not a shell shim",
            ));
        }
        return Ok(path.into());
    }
    let search = std::env::var_os("PATH").unwrap_or_default();
    for directory in std::env::split_paths(&search).filter(|p| p.is_absolute()) {
        let candidate = directory.join(if cfg!(windows) { "codex.exe" } else { "codex" });
        if candidate.is_file() {
            return Ok(candidate);
        }
        // npm's Windows shim launches Node. Find its native leaf instead, so the
        // process we kill/reap on timeout is the actual server, not a wrapper.
        if cfg!(windows) {
            let target = if cfg!(target_arch = "aarch64") {
                "aarch64-pc-windows-msvc"
            } else {
                "x86_64-pc-windows-msvc"
            };
            let package = if cfg!(target_arch = "aarch64") {
                "codex-win32-arm64"
            } else {
                "codex-win32-x64"
            };
            for vendor in [
                directory.join("node_modules/@openai/codex/vendor"),
                directory.join(format!("node_modules/@openai/{package}/vendor")),
                directory.join(format!(
                    "node_modules/@openai/codex/node_modules/@openai/{package}/vendor"
                )),
            ] {
                let candidate = vendor.join(target).join("codex/codex.exe");
                if candidate.is_file() {
                    return Ok(candidate);
                }
            }
        }
    }
    Err(Error::adapter(
        "native Codex executable not found; install Codex or supply --codex-path",
    ))
}

fn send(stdin: &mut ChildStdin, message: &Value) -> Result<()> {
    writeln!(stdin, "{message}")
        .and_then(|()| stdin.flush())
        .map_err(|_| Error::adapter("could not write Codex protocol request"))
}

fn response(
    receiver: &Receiver<std::result::Result<Value, ()>>,
    id: u64,
    deadline: Instant,
) -> Result<Value> {
    loop {
        let duration = deadline.saturating_duration_since(Instant::now());
        if duration.is_zero() {
            return Err(Error::adapter("Codex quota query timed out"));
        }
        let value = receiver
            .recv_timeout(duration)
            .map_err(|_| Error::adapter("Codex quota query timed out or connection closed"))?
            .map_err(|()| Error::adapter("invalid or oversized Codex protocol response"))?;
        if value.get("id").and_then(Value::as_u64) == Some(id) {
            if value.get("error").is_some() {
                return Err(Error::adapter(
                    "Codex quota RPC failed; check login and account support",
                ));
            }
            return value
                .get("result")
                .filter(|v| v.is_object())
                .cloned()
                .ok_or_else(|| Error::adapter("Codex RPC response missing result"));
        }
        // Notifications have no ID. Server requests are not supported by this
        // quota-only client and are rejected rather than left waiting forever.
        if value.get("method").is_some() && value.get("id").is_some() {
            return Err(Error::adapter(
                "Codex server requested unsupported interactive authentication",
            ));
        }
    }
}

pub fn fetch(path: Option<&Path>, timeout: Duration) -> Result<String> {
    if timeout.is_zero() || timeout > Duration::from_secs(120) {
        return Err(Error::invalid(
            "quota timeout must be between 1 and 120 seconds",
        ));
    }
    let deadline = Instant::now() + timeout;
    let mut command = Command::new(executable(path)?);
    command
        .arg("app-server")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null());
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x0800_0000); // CREATE_NO_WINDOW
    }
    let mut server = Server(
        command
            .spawn()
            .map_err(|_| Error::adapter("could not start native Codex app-server"))?,
    );
    let mut stdin = server
        .0
        .stdin
        .take()
        .ok_or_else(|| Error::adapter("Codex stdin unavailable"))?;
    let stdout = server
        .0
        .stdout
        .take()
        .ok_or_else(|| Error::adapter("Codex stdout unavailable"))?;
    let (sender, receiver) = sync_channel(16);
    std::thread::spawn(move || {
        let mut reader = BufReader::new(stdout.take(MAX_BYTES + 1));
        let mut bytes = 0;
        loop {
            let mut line = Vec::new();
            match reader.read_until(b'\n', &mut line) {
                Ok(0) | Err(_) => break,
                Ok(size) => {
                    bytes += size as u64;
                }
            }
            if bytes > MAX_BYTES {
                let _ = sender.send(Err(()));
                break;
            }
            let value = serde_json::from_slice(&line).map_err(|_| ());
            if sender.send(value).is_err() {
                break;
            }
        }
    });
    send(
        &mut stdin,
        &json!({"id":1,"method":"initialize","params":{"clientInfo":{
        "name":"agent_router","title":"Agent Router","version":env!("CARGO_PKG_VERSION")}}}),
    )?;
    response(&receiver, 1, deadline)?;
    send(&mut stdin, &json!({"method":"initialized","params":{}}))?;
    send(
        &mut stdin,
        &json!({"id":2,"method":"account/rateLimits/read"}),
    )?;
    let result = response(&receiver, 2, deadline)?;
    // Server is killed and reaped by Drop on success and every failure path.
    Ok(result.to_string())
}
