// Compiled only by integration tests, never bundled with the product.
use std::io::{self, BufRead, Write};
fn main() {
    if let Ok(path) = std::env::var("ROUTER_TEST_PID") {
        std::fs::write(path, std::process::id().to_string()).unwrap();
    }
    let mode = std::env::var("ROUTER_TEST_MODE").unwrap_or_default();
    let mut lines = io::stdin().lock().lines();
    let initialize = lines.next().unwrap().unwrap();
    assert!(initialize.contains("initialize") && initialize.contains("clientInfo"));
    if mode == "timeout" { std::thread::sleep(std::time::Duration::from_secs(30)); return; }
    if mode == "malformed" { println!("not JSON: secret must not leak"); return; }
    if mode == "oversized" { println!("{}", "x".repeat(4 * 1024 * 1024 + 1)); return; }
    if mode == "error" { println!(r#"{{"id":1,"error":{{"message":"secret must not leak"}}}}"#); return; }
    println!(r#"{{"id":1,"result":{{}}}}"#); io::stdout().flush().unwrap();
    let initialized = lines.next().unwrap().unwrap();
    assert!(initialized.contains("initialized"));
    let query = lines.next().unwrap().unwrap();
    assert!(query.contains("account/rateLimits/read"));
    if mode == "missing" { println!(r#"{{"id":2,"result":{{"unexpected":true}}}}"#); return; }
    println!(r#"{{"method":"account/updated","params":{{}}}}"#);
    println!(r#"{{"id":2,"result":{{"rateLimitsByLimitId":{{"codex":{{"primary":{{"usedPercent":95,"windowDurationMins":300}}}}}}}}}}"#);
    io::stdout().flush().unwrap();
    std::thread::sleep(std::time::Duration::from_secs(30));
}
