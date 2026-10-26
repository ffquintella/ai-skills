use crate::{
    Error, Result,
    config::{Config, Model},
    quota::{Quota, Window},
};
use serde::Serialize;

pub struct Request<'a> {
    pub provider: &'a str,
    pub task: &'a str,
    pub security_sensitive: bool,
    pub spec_complete: bool,
    pub available_models: Option<&'a [String]>,
    pub input_tokens: Option<u64>,
    pub output_tokens: Option<u64>,
}

#[derive(Serialize)]
pub struct QuotaStatus {
    pub remaining_percent: Option<f64>,
    pub known: bool,
    pub windows: Vec<Window>,
    pub warnings: Vec<String>,
}

#[derive(Serialize)]
pub struct Decision {
    pub provider: String,
    pub task: String,
    pub spec_complete: bool,
    pub model: Option<String>,
    pub effort: Option<String>,
    pub mode: String,
    pub reason: String,
    pub quota: QuotaStatus,
    pub estimated_api_cost_usd: Option<f64>,
    pub cost_assumptions: Vec<String>,
    pub max_output_tokens: u64,
    pub context_budget_tokens: u64,
    pub concurrency: u32,
    pub optional_delegation: bool,
}

fn quota_for(config: &Config, quota: &Quota, provider: &str, model: &Model) -> QuotaStatus {
    let known_buckets: std::collections::BTreeSet<_> = config.providers[provider]
        .models
        .iter()
        .flat_map(|m| &m.quota_buckets)
        .collect();
    let mut warnings = quota.warnings.clone();
    for window in &quota.windows {
        if window.provider == provider
            && window
                .bucket
                .as_ref()
                .is_some_and(|b| !known_buckets.contains(b))
        {
            warnings.push(format!(
                "unrecognized bucket ignored: {}",
                window.bucket.as_deref().unwrap_or_default()
            ));
        }
    }
    let windows: Vec<_> = quota
        .windows
        .iter()
        .filter(|w| {
            w.provider == provider
                && w.bucket
                    .as_ref()
                    .is_none_or(|b| model.quota_buckets.contains(b))
        })
        .cloned()
        .collect();
    let remaining = windows
        .iter()
        .filter(|w| w.usable)
        .map(|w| w.remaining_percent)
        .min_by(f64::total_cmp);
    if remaining.is_none() {
        warnings.push("applicable quota unknown; conservative economy mode".into());
    }
    warnings.sort();
    warnings.dedup();
    QuotaStatus {
        remaining_percent: remaining,
        known: remaining.is_some(),
        windows,
        warnings,
    }
}

pub fn choose(config: &Config, request: &Request<'_>, quota: &Quota) -> Result<Decision> {
    let provider = config
        .providers
        .get(request.provider)
        .ok_or_else(|| Error::invalid("provider not in YAML matrix"))?;
    let task = config
        .tasks
        .get(request.task)
        .ok_or_else(|| Error::invalid("task not in YAML matrix"))?;
    // A complete specification lowers the base requirements; security floors still apply.
    let spec = task.specified.as_ref().filter(|_| request.spec_complete);
    let (task_min_tier, task_min_effort, task_preferred) = match spec {
        Some(s) => (s.min_tier, &s.min_effort, &s.preferred_effort),
        None => (task.min_tier, &task.min_effort, &task.preferred_effort),
    };
    let base = config
        .effort_rank(task_min_effort)
        .ok_or_else(|| Error::invalid("invalid task effort"))?;
    let floor = if request.security_sensitive {
        base.max(
            config
                .effort_rank(&task.security.min_effort)
                .ok_or_else(|| Error::invalid("invalid security effort"))?,
        )
    } else {
        base
    };
    let min_tier = if request.security_sensitive {
        task_min_tier.max(task.security.min_tier)
    } else {
        task_min_tier
    };
    let input = request
        .input_tokens
        .unwrap_or(config.reference_workload.input_tokens);
    let output = request
        .output_tokens
        .unwrap_or(config.reference_workload.output_tokens);
    let mut candidates = Vec::new();
    let mut blocked = None;
    for model in &provider.models {
        if !model.enabled
            || model.tier < min_tier
            || request
                .available_models
                .is_some_and(|ids| !ids.contains(&model.id))
            || !task
                .required_capabilities
                .iter()
                .all(|cap| model.capabilities.contains(cap))
            || (request.security_sensitive
                && !task
                    .security
                    .required_capabilities
                    .iter()
                    .all(|cap| model.capabilities.contains(cap)))
        {
            continue;
        }
        if !model
            .supported_efforts
            .iter()
            .any(|e| config.effort_rank(e).is_some_and(|rank| rank >= floor))
        {
            continue;
        }
        let status = quota_for(config, quota, request.provider, model);
        if status.remaining_percent == Some(0.0) {
            blocked = Some(status);
            continue;
        }
        let mode_name = match status.remaining_percent {
            Some(value) if value <= config.quota_policy.extreme_remaining_percent => "extreme",
            Some(value) if value <= config.quota_policy.economy_remaining_percent => "economy",
            None => "economy",
            _ => "normal",
        };
        let mode = &config.modes[mode_name];
        let context = mode.context_budget_tokens.min(model.context_tokens);
        let required_input = request.input_tokens.unwrap_or(0);
        let required_output = request.output_tokens.unwrap_or(0);
        let max_output = mode
            .max_output_tokens
            .min(model.max_output_tokens)
            .min(context.saturating_sub(required_input));
        if max_output == 0
            || required_output > max_output
            || required_input
                .checked_add(required_output)
                .is_none_or(|n| n > context)
            || input
                .checked_add(output)
                .is_none_or(|n| n > model.context_tokens)
            || output > model.max_output_tokens
        {
            continue;
        }
        let preferred = config
            .effort_rank(&task_preferred[mode_name])
            .ok_or_else(|| Error::invalid("invalid mode effort"))?
            .max(floor);
        // Choose nearest supported effort at/below preferred, always respecting the floor.
        let effort = model
            .supported_efforts
            .iter()
            .filter_map(|e| config.effort_rank(e).map(|rank| (e, rank)))
            .filter(|(_, rank)| *rank >= floor)
            .min_by_key(|(_, rank)| {
                if *rank <= preferred {
                    preferred - rank
                } else {
                    config.effort_order.len() + rank - preferred
                }
            });
        let Some((effort, _)) = effort else {
            continue;
        };
        candidates.push((
            model.cost(input, output),
            &model.id,
            effort.clone(),
            mode_name,
            status,
            max_output,
            context,
        ));
    }
    candidates.sort_by(|a, b| a.0.total_cmp(&b.0).then_with(|| a.1.cmp(b.1)));
    if let Some((cost, id, effort, mode_name, status, max_output, context)) =
        candidates.into_iter().next()
    {
        let mode = &config.modes[mode_name];
        let explicit = request.input_tokens.is_some() || request.output_tokens.is_some();
        let mut assumptions = Vec::new();
        if explicit {
            if request.input_tokens.is_none() {
                assumptions.push(format!("input_tokens assumed from YAML reference: {input}"));
            }
            if request.output_tokens.is_none() {
                assumptions.push(format!(
                    "output_tokens assumed from YAML reference: {output}"
                ));
            }
            assumptions.push("standard uncached API text estimate; excludes effort overhead, tools and subscription quota".into());
        }
        return Ok(Decision {
            provider: request.provider.into(),
            task: request.task.into(),
            spec_complete: spec.is_some(),
            model: Some(id.clone()),
            effort: Some(effort),
            mode: mode_name.into(),
            reason: if request.security_sensitive {
                "cheapest eligible model preserving security tier and effort floors"
            } else if spec.is_some() {
                "cheapest available model meeting the task's complete-specification floors"
            } else {
                "cheapest available model satisfying task capabilities and resource budgets"
            }
            .into(),
            quota: status,
            estimated_api_cost_usd: explicit.then_some(cost),
            cost_assumptions: assumptions,
            max_output_tokens: max_output,
            context_budget_tokens: context,
            concurrency: mode.concurrency,
            optional_delegation: mode.optional_delegation,
        });
    }
    if let Some(status) = blocked {
        return Ok(Decision {
            provider: request.provider.into(),
            task: request.task.into(),
            spec_complete: spec.is_some(),
            model: None,
            effort: None,
            mode: "blocked".into(),
            reason: "applicable quota exhausted; no usable eligible model".into(),
            quota: status,
            estimated_api_cost_usd: None,
            cost_assumptions: vec![],
            max_output_tokens: 0,
            context_budget_tokens: 0,
            concurrency: 0,
            optional_delegation: false,
        });
    }
    Err(Error { exit: 4, code: "no_eligible_model", message: "no available model satisfies capabilities, effort floors and mode token budgets; update YAML/availability or reduce workload".into() })
}
