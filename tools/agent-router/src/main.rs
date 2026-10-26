use agent_router::{
    Error, Result,
    config::Config,
    quota::Quota,
    router::{Request, choose},
    rpc,
};
use clap::{ArgGroup, Parser};
use serde_json::json;
use std::io::Read;
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

#[derive(Parser)]
#[command(
    version,
    about = "Choose the cheapest capable model using YAML policy and usage quotas"
)]
#[command(group(ArgGroup::new("quota_input").args(["quota_file", "quota_stdin", "quota_source"]).multiple(false)))]
struct Cli {
    #[arg(long)]
    provider: String,
    #[arg(long)]
    task: String,
    #[arg(long)]
    matrix: Option<PathBuf>,
    #[arg(long)]
    security_sensitive: bool,
    /// An approved spec or plan already fixes files, interfaces, behavior and the verify command.
    #[arg(long)]
    spec_complete: bool,
    #[arg(long, value_delimiter = ',')]
    available_models: Option<Vec<String>>,
    #[arg(long)]
    input_tokens: Option<u64>,
    #[arg(long)]
    output_tokens: Option<u64>,
    #[arg(long, allow_hyphen_values = true)]
    daily_remaining: Option<f64>,
    #[arg(long, allow_hyphen_values = true)]
    weekly_remaining: Option<f64>,
    #[arg(long)]
    quota_file: Option<PathBuf>,
    #[arg(long)]
    quota_stdin: bool,
    #[arg(long, value_parser = ["codex"])]
    quota_source: Option<String>,
    /// Native Codex executable; Windows .cmd/.ps1 shell shims are not accepted.
    #[arg(long, requires = "quota_source")]
    codex_path: Option<PathBuf>,
    #[arg(long, default_value_t = 10, value_parser = clap::value_parser!(u64).range(1..=120))]
    quota_timeout_seconds: u64,
    #[arg(long, default_value = "json", value_parser = ["json", "text"])]
    format: String,
}

fn read_limited(reader: impl Read, description: &str) -> Result<String> {
    let mut raw = String::new();
    reader
        .take(4 * 1024 * 1024 + 1)
        .read_to_string(&mut raw)
        .map_err(|_| Error::invalid(format!("could not read UTF-8 {description}")))?;
    if raw.len() > 4 * 1024 * 1024 {
        return Err(Error::invalid(format!("{description} exceeds 4 MiB")));
    }
    Ok(raw)
}

fn run(cli: Cli) -> Result<i32> {
    let path = match cli.matrix {
        Some(path) => path,
        None => std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|p| p.join("models.yaml")))
            .ok_or_else(|| Error::invalid("could not locate executable; supply --matrix"))?,
    };
    let file = std::fs::File::open(&path).map_err(|_| Error::invalid("matrix file missing or unreadable; place models.yaml beside executable or supply --matrix"))?;
    let config = Config::parse(&read_limited(file, "YAML matrix")?)?;
    if !config.providers.contains_key(&cli.provider) || !config.tasks.contains_key(&cli.task) {
        return Err(Error::invalid("provider or task not in YAML matrix"));
    }
    if cli
        .available_models
        .as_ref()
        .is_some_and(|ids| ids.is_empty() || ids.iter().any(|s| s.trim().is_empty()))
    {
        return Err(Error::invalid(
            "--available-models must contain nonempty IDs",
        ));
    }
    if cli.input_tokens == Some(0) || cli.output_tokens == Some(0) {
        return Err(Error::invalid("token estimates must be positive"));
    }
    // Validate manual assertions before any external source is contacted.
    for remaining in [cli.daily_remaining, cli.weekly_remaining]
        .into_iter()
        .flatten()
    {
        agent_router::quota::percent(remaining)?;
    }
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| Error::invalid("system clock before Unix epoch"))?
        .as_secs();
    let mut quota = if cli.quota_source.is_some() {
        if cli.provider != "openai" {
            return Err(Error::invalid(
                "Codex quota source applies only to provider openai",
            ));
        }
        let raw = rpc::fetch(
            cli.codex_path.as_deref(),
            Duration::from_secs(cli.quota_timeout_seconds),
        )?;
        Quota::parse(&raw, now, config.quota_policy.snapshot_ttl_seconds, true)
            .map_err(|_| Error::adapter("Codex returned an invalid quota payload"))?
    } else if let Some(path) = cli.quota_file {
        let file =
            std::fs::File::open(path).map_err(|_| Error::invalid("could not open quota file"))?;
        Quota::parse(
            &read_limited(file, "quota snapshot")?,
            now,
            config.quota_policy.snapshot_ttl_seconds,
            false,
        )?
    } else if cli.quota_stdin {
        Quota::parse(
            &read_limited(std::io::stdin().lock(), "quota stdin")?,
            now,
            config.quota_policy.snapshot_ttl_seconds,
            false,
        )?
    } else {
        Quota::default()
    };
    quota.override_percent(&cli.provider, 1440, cli.daily_remaining, now)?;
    quota.override_percent(&cli.provider, 10080, cli.weekly_remaining, now)?;
    let decision = choose(
        &config,
        &Request {
            provider: &cli.provider,
            task: &cli.task,
            security_sensitive: cli.security_sensitive,
            spec_complete: cli.spec_complete,
            available_models: cli.available_models.as_deref(),
            input_tokens: cli.input_tokens,
            output_tokens: cli.output_tokens,
        },
        &quota,
    )?;
    let blocked = decision.mode == "blocked";
    if cli.format == "text" {
        println!(
            "model={} effort={} mode={} output={} context={} concurrency={}\n{}",
            decision.model.as_deref().unwrap_or("none"),
            decision.effort.as_deref().unwrap_or("none"),
            decision.mode,
            decision.max_output_tokens,
            decision.context_budget_tokens,
            decision.concurrency,
            decision.reason
        );
        for warning in &decision.quota.warnings {
            eprintln!("warning: {warning}");
        }
    } else {
        println!(
            "{}",
            serde_json::to_string(&decision)
                .map_err(|_| Error::invalid("could not serialize decision"))?
        );
    }
    Ok(if blocked { 3 } else { 0 })
}

fn main() {
    let cli = match Cli::try_parse() {
        Ok(cli) => cli,
        Err(error)
            if matches!(
                error.kind(),
                clap::error::ErrorKind::DisplayHelp | clap::error::ErrorKind::DisplayVersion
            ) =>
        {
            let _ = error.print();
            return;
        }
        Err(_) => {
            println!(
                "{}",
                json!({"error":{"code":"invalid_input","message":"invalid CLI arguments; run --help"}})
            );
            std::process::exit(2);
        }
    };
    match run(cli) {
        Ok(code) => std::process::exit(code),
        Err(error) => {
            println!(
                "{}",
                json!({"error":{"code":error.code,"message":error.message}})
            );
            std::process::exit(error.exit);
        }
    }
}
