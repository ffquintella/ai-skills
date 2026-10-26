use crate::{Error, Result};
use serde::Deserialize;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Config {
    pub schema_version: u32,
    pub effort_order: Vec<String>,
    pub reference_workload: Workload,
    pub quota_policy: QuotaPolicy,
    pub modes: BTreeMap<String, Mode>,
    pub tasks: BTreeMap<String, Task>,
    pub providers: BTreeMap<String, Provider>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Workload {
    pub input_tokens: u64,
    pub output_tokens: u64,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct QuotaPolicy {
    pub snapshot_ttl_seconds: u64,
    pub economy_remaining_percent: f64,
    pub extreme_remaining_percent: f64,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Mode {
    pub max_output_tokens: u64,
    pub context_budget_tokens: u64,
    pub concurrency: u32,
    pub optional_delegation: bool,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Task {
    pub min_tier: u32,
    pub required_capabilities: Vec<String>,
    pub min_effort: String,
    pub preferred_effort: BTreeMap<String, String>,
    pub security: Floor,
    /// Lower requirements used when a complete specification already settles the design.
    #[serde(default)]
    pub specified: Option<Specified>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Specified {
    pub min_tier: u32,
    pub min_effort: String,
    pub preferred_effort: BTreeMap<String, String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Floor {
    pub min_tier: u32,
    pub min_effort: String,
    pub required_capabilities: Vec<String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Provider {
    pub models: Vec<Model>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Model {
    pub id: String,
    pub enabled: bool,
    pub tier: u32,
    pub capabilities: Vec<String>,
    pub supported_efforts: Vec<String>,
    pub quota_buckets: Vec<String>,
    pub context_tokens: u64,
    pub max_output_tokens: u64,
    pub prices: Prices,
    pub price_bands: Vec<Band>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Prices {
    pub input: f64,
    pub cached_input: f64,
    pub output: f64,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Band {
    pub above_input_tokens: u64,
    pub prices: Prices,
}

fn require(condition: bool, message: &str) -> Result<()> {
    if condition {
        Ok(())
    } else {
        Err(Error::invalid(message))
    }
}

fn unique(values: &[String]) -> bool {
    values.iter().all(|v| !v.trim().is_empty())
        && values.iter().collect::<BTreeSet<_>>().len() == values.len()
}

impl Prices {
    fn valid(&self) -> bool {
        [self.input, self.cached_input, self.output]
            .iter()
            .all(|v| v.is_finite() && *v >= 0.0)
            && self.cached_input <= self.input
    }
}

impl Model {
    pub fn cost(&self, input: u64, output: u64) -> f64 {
        let price = self
            .price_bands
            .iter()
            .rev()
            .find(|b| input > b.above_input_tokens)
            .map_or(&self.prices, |b| &b.prices);
        (input as f64 * price.input + output as f64 * price.output) / 1_000_000.0
    }
}

impl Config {
    pub fn parse(raw: &str) -> Result<Self> {
        let config: Self = serde_saphyr::from_str(raw).map_err(|_| {
            Error::invalid("invalid YAML policy: check schema, required fields and value types")
        })?;
        config.validate()?;
        Ok(config)
    }

    pub fn effort_rank(&self, name: &str) -> Option<usize> {
        self.effort_order.iter().position(|e| e == name)
    }

    fn validate(&self) -> Result<()> {
        require(
            self.schema_version == 1,
            "unsupported schema_version; expected 1",
        )?;
        require(
            !self.effort_order.is_empty() && unique(&self.effort_order),
            "effort_order must contain unique nonempty levels",
        )?;
        require(
            self.reference_workload.input_tokens > 0 && self.reference_workload.output_tokens > 0,
            "reference workload must be positive",
        )?;
        let q = &self.quota_policy;
        require(
            q.snapshot_ttl_seconds > 0
                && q.extreme_remaining_percent.is_finite()
                && q.economy_remaining_percent.is_finite()
                && q.extreme_remaining_percent > 0.0
                && q.extreme_remaining_percent < q.economy_remaining_percent
                && q.economy_remaining_percent < 100.0,
            "invalid quota thresholds or TTL",
        )?;
        require(
            self.modes.len() == 3,
            "modes must contain normal, economy and extreme",
        )?;
        for name in ["normal", "economy", "extreme"] {
            let mode = self
                .modes
                .get(name)
                .ok_or_else(|| Error::invalid("missing economy mode"))?;
            require(
                mode.max_output_tokens > 0
                    && mode.context_budget_tokens > mode.max_output_tokens
                    && mode.concurrency > 0,
                "invalid mode token budgets or concurrency",
            )?;
        }
        for names in [["normal", "economy"], ["economy", "extreme"]] {
            let upper = &self.modes[names[0]];
            let lower = &self.modes[names[1]];
            require(
                lower.max_output_tokens <= upper.max_output_tokens
                    && lower.context_budget_tokens <= upper.context_budget_tokens
                    && lower.concurrency <= upper.concurrency
                    && (!lower.optional_delegation || upper.optional_delegation),
                "economy modes must not increase resource budgets",
            )?;
        }
        require(
            self.modes["extreme"].concurrency == 1 && !self.modes["extreme"].optional_delegation,
            "extreme mode requires concurrency 1 and no optional delegation",
        )?;
        require(
            !self.tasks.is_empty() && !self.providers.is_empty(),
            "tasks and providers cannot be empty",
        )?;
        for task in self.tasks.values() {
            let base = self
                .effort_rank(&task.min_effort)
                .ok_or_else(|| Error::invalid("unknown task minimum effort"))?;
            let security = self
                .effort_rank(&task.security.min_effort)
                .ok_or_else(|| Error::invalid("unknown security minimum effort"))?;
            require(
                task.min_tier > 0 && task.security.min_tier >= task.min_tier && security >= base,
                "security minimums must preserve task minimums",
            )?;
            require(
                unique(&task.required_capabilities) && unique(&task.security.required_capabilities),
                "capabilities must be unique nonempty names",
            )?;
            require(
                task.preferred_effort.len() == 3,
                "task requires three mode effort values",
            )?;
            let mut previous = usize::MAX;
            for name in ["normal", "economy", "extreme"] {
                let effort = task
                    .preferred_effort
                    .get(name)
                    .and_then(|e| self.effort_rank(e))
                    .ok_or_else(|| Error::invalid("missing or unknown mode effort"))?;
                require(
                    effort >= base && effort <= previous,
                    "mode efforts must preserve minimum and not increase in economy",
                )?;
                previous = effort;
            }
            if let Some(spec) = &task.specified {
                let spec_base = self
                    .effort_rank(&spec.min_effort)
                    .ok_or_else(|| Error::invalid("unknown specified minimum effort"))?;
                require(
                    spec.min_tier > 0 && spec.min_tier <= task.min_tier && spec_base <= base,
                    "specified minimums cannot exceed task minimums",
                )?;
                require(
                    spec.preferred_effort.len() == 3,
                    "specified requires three mode effort values",
                )?;
                let mut previous = usize::MAX;
                for name in ["normal", "economy", "extreme"] {
                    let effort = spec
                        .preferred_effort
                        .get(name)
                        .and_then(|e| self.effort_rank(e))
                        .ok_or_else(|| {
                            Error::invalid("missing or unknown specified mode effort")
                        })?;
                    let task_effort = self.effort_rank(&task.preferred_effort[name]).unwrap_or(0);
                    require(
                        effort >= spec_base && effort <= previous && effort <= task_effort,
                        "specified mode efforts must preserve their minimum, not increase in economy and not exceed the task's",
                    )?;
                    previous = effort;
                }
            }
        }
        for (name, provider) in &self.providers {
            require(
                !name.trim().is_empty() && !provider.models.is_empty(),
                "providers require a name and model catalog",
            )?;
            let mut ids = BTreeSet::new();
            for model in &provider.models {
                require(
                    !model.id.trim().is_empty() && ids.insert(&model.id),
                    "model IDs must be nonempty and unique per provider",
                )?;
                require(
                    model.tier > 0
                        && model.context_tokens > model.max_output_tokens
                        && model.max_output_tokens > 0,
                    "invalid model tier or token ceilings",
                )?;
                require(
                    unique(&model.capabilities)
                        && unique(&model.quota_buckets)
                        && unique(&model.supported_efforts)
                        && !model.supported_efforts.is_empty()
                        && model
                            .supported_efforts
                            .iter()
                            .all(|e| self.effort_rank(e).is_some()),
                    "invalid model capabilities, buckets or efforts",
                )?;
                require(
                    model.prices.valid(),
                    "prices must be finite nonnegative, cached input no greater than input",
                )?;
                let mut previous = None;
                for band in &model.price_bands {
                    require(
                        band.prices.valid() && previous.is_none_or(|v| band.above_input_tokens > v),
                        "price bands must have valid prices and strictly ascending thresholds",
                    )?;
                    previous = Some(band.above_input_tokens);
                }
            }
        }
        Ok(())
    }
}
