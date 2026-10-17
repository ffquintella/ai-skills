use crate::{Error, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize)]
pub struct Window {
    pub provider: String,
    pub name: String,
    pub remaining_percent: f64,
    pub duration_minutes: u64,
    pub bucket: Option<String>,
    pub resets_at: Option<u64>,
    pub observed_at: Option<u64>,
    pub usable: bool,
    pub source: String,
}

#[derive(Debug, Default, Clone)]
pub struct Quota {
    pub windows: Vec<Window>,
    pub warnings: Vec<String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Snapshot {
    provider: String,
    #[serde(default)]
    observed_at: Option<u64>,
    windows: Vec<PartialWindow>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct PartialWindow {
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    remaining_percent: Option<f64>,
    #[serde(default)]
    duration_minutes: Option<u64>,
    #[serde(default)]
    resets_at: Option<u64>,
    #[serde(default)]
    bucket: Option<String>,
}

pub fn percent(number: f64) -> Result<f64> {
    if number.is_finite() && (0.0..=100.0).contains(&number) {
        Ok(number)
    } else {
        Err(Error::invalid(
            "quota percentages must be finite numbers between 0 and 100",
        ))
    }
}

fn number(value: Option<&Value>, field: &str) -> Result<Option<f64>> {
    value
        .filter(|v| !v.is_null())
        .map(|v| {
            v.as_f64()
                .ok_or_else(|| Error::invalid(format!("invalid numeric quota field: {field}")))
        })
        .transpose()
}

fn integer(value: Option<&Value>, field: &str) -> Result<Option<u64>> {
    value
        .filter(|v| !v.is_null())
        .map(|v| {
            v.as_u64()
                .ok_or_else(|| Error::invalid(format!("invalid integer quota field: {field}")))
        })
        .transpose()
}

impl Quota {
    pub fn parse(raw: &str, now: u64, ttl: u64, live: bool) -> Result<Self> {
        let document: Value =
            serde_json::from_str(raw).map_err(|_| Error::invalid("invalid quota JSON"))?;
        let (payload, observed) = if let Some(payload) = document.get("payload") {
            let object = document
                .as_object()
                .ok_or_else(|| Error::invalid("quota wrapper must be an object"))?;
            if object.keys().any(|k| k != "payload" && k != "observed_at") {
                return Err(Error::invalid("unknown quota wrapper field"));
            }
            (
                payload,
                integer(document.get("observed_at"), "observed_at")?,
            )
        } else {
            (
                &document,
                integer(document.get("observed_at"), "observed_at")?,
            )
        };
        let observed = if live { Some(now) } else { observed };
        let mut quota = Self::default();
        if payload.get("windows").is_some() {
            let snapshot: Snapshot = serde_json::from_value(payload.clone())
                .map_err(|_| Error::invalid("invalid normalized quota fields or types"))?;
            if snapshot.provider.trim().is_empty() {
                return Err(Error::invalid("quota provider cannot be empty"));
            }
            let time = if live {
                Some(now)
            } else {
                observed.or(snapshot.observed_at)
            };
            for partial in snapshot.windows {
                quota.add(&snapshot.provider, partial, time, now, ttl, "snapshot")?;
            }
        } else {
            let native = payload.get("result").unwrap_or(payload);
            if native.get("error").is_some() || payload.get("error").is_some() {
                return Err(Error::invalid("quota payload reports an RPC error"));
            }
            if let Some(buckets) = native.get("rateLimitsByLimitId").filter(|v| !v.is_null()) {
                let buckets = buckets
                    .as_object()
                    .ok_or_else(|| Error::invalid("rateLimitsByLimitId must be an object"))?;
                for (bucket, entry) in buckets {
                    quota.codex_entry(entry, Some(bucket.clone()), observed, now, ttl)?;
                }
            } else if let Some(entry) = native.get("rateLimits") {
                let bucket = match entry.get("limitId").filter(|v| !v.is_null()) {
                    Some(v) => Some(
                        v.as_str()
                            .ok_or_else(|| Error::invalid("limitId must be a string"))?
                            .to_owned(),
                    ),
                    None => Some("codex".into()),
                };
                quota.codex_entry(entry, bucket, observed, now, ttl)?;
            } else if let Some(limits) = native.get("rate_limits") {
                if !limits.is_object() && !limits.is_null() {
                    return Err(Error::invalid("rate_limits must be an object"));
                }
                for (name, minutes) in [("five_hour", 300), ("seven_day", 10080)] {
                    if let Some(v) = limits.get(name).filter(|v| !v.is_null()) {
                        if !v.is_object() {
                            return Err(Error::invalid("Claude quota window must be an object"));
                        }
                        let used = number(v.get("used_percentage"), "used_percentage")?;
                        let remaining = used.map(percent).transpose()?.map(|p| 100.0 - p);
                        quota.add(
                            "anthropic",
                            PartialWindow {
                                name: Some(name.into()),
                                remaining_percent: remaining,
                                duration_minutes: Some(minutes),
                                resets_at: integer(v.get("resets_at"), "resets_at")?,
                                bucket: None,
                            },
                            observed,
                            now,
                            ttl,
                            "claude_statusline",
                        )?;
                    }
                }
                if limits.is_null() || limits.as_object().is_some_and(|v| v.is_empty()) {
                    quota.warnings.push("Claude rate limits unavailable".into());
                }
            } else if native.get("model").is_some() || native.get("session_id").is_some() {
                quota
                    .warnings
                    .push("Claude statusline has no rate_limits yet".into());
            } else {
                return Err(Error::invalid(
                    "unrecognized quota payload; expected normalized, Codex or Claude JSON",
                ));
            }
        }
        if quota.windows.is_empty() {
            quota
                .warnings
                .push("no complete quota windows available".into());
        }
        Ok(quota)
    }

    fn codex_entry(
        &mut self,
        entry: &Value,
        bucket: Option<String>,
        observed: Option<u64>,
        now: u64,
        ttl: u64,
    ) -> Result<()> {
        if entry.is_null() {
            self.warnings.push("Codex quota bucket unavailable".into());
            return Ok(());
        }
        if !entry.is_object() {
            return Err(Error::invalid("Codex quota bucket must be an object"));
        }
        for name in ["primary", "secondary"] {
            if let Some(v) = entry.get(name).filter(|v| !v.is_null()) {
                if !v.is_object() {
                    return Err(Error::invalid("Codex quota window must be an object"));
                }
                let used = number(v.get("usedPercent"), "usedPercent")?;
                let remaining = used.map(percent).transpose()?.map(|p| 100.0 - p);
                self.add(
                    "openai",
                    PartialWindow {
                        name: Some(name.into()),
                        remaining_percent: remaining,
                        duration_minutes: integer(
                            v.get("windowDurationMins"),
                            "windowDurationMins",
                        )?,
                        resets_at: integer(v.get("resetsAt"), "resetsAt")?,
                        bucket: bucket.clone(),
                    },
                    observed,
                    now,
                    ttl,
                    "codex",
                )?;
            }
        }
        Ok(())
    }

    fn add(
        &mut self,
        provider: &str,
        partial: PartialWindow,
        observed: Option<u64>,
        now: u64,
        ttl: u64,
        source: &str,
    ) -> Result<()> {
        if let Some(value) = partial.remaining_percent {
            percent(value)?;
        }
        if partial.duration_minutes == Some(0)
            || partial.bucket.as_ref().is_some_and(|b| b.trim().is_empty())
        {
            return Err(Error::invalid("quota duration and bucket must be nonempty"));
        }
        let (Some(remaining), Some(duration)) =
            (partial.remaining_percent, partial.duration_minutes)
        else {
            self.warnings.push("incomplete quota window ignored".into());
            return Ok(());
        };
        let name = partial.name.unwrap_or_else(|| format!("{duration}m"));
        if name.trim().is_empty() {
            return Err(Error::invalid("quota window name cannot be empty"));
        }
        let fresh = observed.is_some_and(|time| time <= now && now - time <= ttl);
        let reset = partial.resets_at.is_some_and(|time| time <= now);
        if !fresh {
            self.warnings.push(format!(
                "{provider}/{name}: missing, stale or future observation timestamp"
            ));
        }
        if reset {
            self.warnings.push(format!(
                "{provider}/{name}: reset has passed; remaining quota unknown"
            ));
        }
        self.windows.push(Window {
            provider: provider.into(),
            name,
            remaining_percent: remaining,
            duration_minutes: duration,
            bucket: partial.bucket,
            resets_at: partial.resets_at,
            observed_at: observed,
            usable: fresh && !reset,
            source: source.into(),
        });
        Ok(())
    }

    pub fn override_percent(
        &mut self,
        provider: &str,
        minutes: u64,
        remaining: Option<f64>,
        now: u64,
    ) -> Result<()> {
        if let Some(remaining) = remaining {
            percent(remaining)?;
            self.windows
                .retain(|w| w.provider != provider || w.duration_minutes != minutes);
            self.windows.push(Window {
                provider: provider.into(),
                name: if minutes == 1440 { "daily" } else { "weekly" }.into(),
                remaining_percent: remaining,
                duration_minutes: minutes,
                bucket: None,
                resets_at: None,
                observed_at: Some(now),
                usable: true,
                source: "parameter".into(),
            });
        }
        Ok(())
    }
}
