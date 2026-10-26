use agent_router::{
    config::Config,
    quota::Quota,
    router::{Request, choose},
};
use serde_json::json;

const YAML: &str = include_str!("../models.yaml");

fn request(task: &str) -> Request<'_> {
    Request {
        provider: "openai",
        task,
        security_sensitive: false,
        spec_complete: false,
        available_models: None,
        input_tokens: None,
        output_tokens: None,
    }
}

#[test]
fn context_budget_reserves_room_for_recommended_output() {
    let config = Config::parse(YAML).unwrap();
    let mut r = request("lookup");
    r.input_tokens = Some(32768);
    assert!(
        choose(&config, &r, &Quota::default()).is_err(),
        "economy context cannot fit a reply"
    );
    r.input_tokens = Some(32000);
    let d = choose(&config, &r, &Quota::default()).unwrap();
    assert_eq!(d.max_output_tokens, 768);
}

#[test]
fn price_bands_apply_strictly_above_threshold() {
    let config = Config::parse(YAML).unwrap();
    let haiku = &config.providers["anthropic"].models[0];
    assert_eq!(haiku.cost(100000, 1000), 0.0105);
    assert_eq!(haiku.cost(100001, 1000), 0.0525005);
    let luna = &config.providers["openai"].models[0];
    assert_eq!(luna.cost(272000, 1000), 0.0277);
    assert_eq!(luna.cost(272001, 1000), 0.0551502);
}

#[test]
fn stable_model_id_breaks_equal_cost_ties() {
    let mut yaml: serde_json::Value = serde_saphyr::from_str(YAML).unwrap();
    let models = yaml["providers"]["openai"]["models"]
        .as_array_mut()
        .unwrap();
    let mut copy = models[0].clone();
    copy["id"] = "a-first".into();
    models.push(copy);
    let config = Config::parse(&serde_json::to_string(&yaml).unwrap()).unwrap();
    assert_eq!(
        choose(&config, &request("lookup"), &Quota::default())
            .unwrap()
            .model
            .as_deref(),
        Some("a-first")
    );
}

#[test]
fn duplicate_models_bad_prices_unknown_fields_and_inverted_thresholds_are_rejected() {
    for bad in [
        YAML.replace("gpt-6.1-sol", "gpt-6-luna"),
        YAML.replace("input: 0.10", "input: -1"),
        YAML.replace("enabled: true", "enabeld: true"),
        YAML.replace(
            "extreme_remaining_percent: 10",
            "extreme_remaining_percent: 50",
        ),
        YAML.replace("min_effort: xhigh", "min_effort: unsupported"),
        YAML.replace("concurrency: 1", "concurrency: 0"),
    ] {
        assert!(Config::parse(&bad).is_err());
    }
}

#[test]
fn buckets_are_evaluated_per_model_and_exhausted_model_is_not_selected() {
    let yaml = YAML.replacen("quota_buckets: [codex]", "quota_buckets: [cheap]", 1);
    let config = Config::parse(&yaml).unwrap();
    let q = Quota::parse(
        &json!({"provider":"openai","observed_at":1000,"windows":[
            {"name":"cheap","remaining_percent":0,"duration_minutes":300,"bucket":"cheap"},
            {"name":"other","remaining_percent":90,"duration_minutes":300,"bucket":"codex"}
        ]})
        .to_string(),
        1000,
        300,
        false,
    )
    .unwrap();
    let d = choose(&config, &request("lookup"), &q).unwrap();
    assert_eq!(d.model.as_deref(), Some("gpt-6.1-sol"));
    assert_eq!(d.mode, "normal");
}

#[test]
fn ttl_boundary_is_known_and_past_reset_does_not_imply_full_quota() {
    let raw = json!({"provider":"openai","observed_at":700,"windows":[
        {"name":"5h","remaining_percent":0,"duration_minutes":300,"resets_at":1100}
    ]});
    let config = Config::parse(YAML).unwrap();
    let q = Quota::parse(&raw.to_string(), 1000, 300, false).unwrap();
    assert_eq!(
        choose(&config, &request("lookup"), &q).unwrap().mode,
        "blocked"
    );
    let q = Quota::parse(&raw.to_string(), 1001, 300, false).unwrap();
    assert_eq!(
        choose(&config, &request("lookup"), &q).unwrap().mode,
        "economy"
    );
    let q = Quota::parse(&raw.to_string(), 1100, 500, false).unwrap();
    assert!(!choose(&config, &request("lookup"), &q).unwrap().quota.known);
}

#[test]
fn security_floor_survives_all_modes_and_disabled_models_are_ignored() {
    let config = Config::parse(YAML).unwrap();
    for remaining in [90.0, 25.0, 10.0] {
        let mut q = Quota::default();
        q.override_percent("openai", 1440, Some(remaining), 1000)
            .unwrap();
        let mut r = request("routine");
        r.security_sensitive = true;
        let d = choose(&config, &r, &q).unwrap();
        assert_eq!(d.model.as_deref(), Some("gpt-6.1-sol"));
        assert_eq!(d.effort.as_deref(), Some("xhigh"));
    }
    let yaml = YAML.replacen("enabled: true", "enabled: false", 1);
    let config = Config::parse(&yaml).unwrap();
    assert_eq!(
        choose(&config, &request("lookup"), &Quota::default())
            .unwrap()
            .model
            .as_deref(),
        Some("gpt-6.1-sol")
    );
}

#[test]
fn quota_overrides_only_matching_provider_and_duration() {
    let mut q = Quota::parse(
        &json!({"provider":"anthropic","observed_at":1000,"windows":[
            {"name":"daily","remaining_percent":3,"duration_minutes":1440}
        ]})
        .to_string(),
        1000,
        300,
        false,
    )
    .unwrap();
    q.override_percent("openai", 1440, Some(80.0), 1000)
        .unwrap();
    assert_eq!(q.windows.len(), 2);
    assert_eq!(q.windows[0].remaining_percent, 3.0);
    q.override_percent("openai", 10080, Some(5.0), 1000)
        .unwrap();
    let config = Config::parse(YAML).unwrap();
    assert_eq!(
        choose(&config, &request("lookup"), &q).unwrap().mode,
        "extreme"
    );
}

fn routed(provider: &str, task: &str, spec: bool, security: bool) -> (String, String) {
    let config = Config::parse(YAML).unwrap();
    let mut q = Quota::default();
    q.override_percent(provider, 1440, Some(90.0), 1000)
        .unwrap();
    let mut r = request(task);
    r.provider = provider;
    r.spec_complete = spec;
    r.security_sensitive = security;
    let d = choose(&config, &r, &q).unwrap();
    (d.model.unwrap(), d.effort.unwrap())
}

#[test]
fn complete_spec_lowers_change_tasks_one_rung() {
    let pair = |m: &str, e: &str| (m.to_string(), e.to_string());
    assert_eq!(
        routed("anthropic", "complex", false, false),
        pair("claude-opus-5-5", "xhigh")
    );
    assert_eq!(
        routed("anthropic", "complex", true, false),
        pair("claude-sonnet-5-5", "high")
    );
    assert_eq!(
        routed("anthropic", "routine", false, false),
        pair("claude-sonnet-5-5", "high")
    );
    assert_eq!(
        routed("anthropic", "routine", true, false),
        pair("claude-haiku-5-5", "high")
    );
    assert_eq!(
        routed("openai", "complex", true, false),
        pair("gpt-6.1-sol", "high")
    );
    assert_eq!(
        routed("openai", "routine", true, false),
        pair("gpt-6-luna", "high")
    );
}

#[test]
fn complete_spec_never_lowers_security_or_tasks_without_a_spec_policy() {
    let pair = |m: &str, e: &str| (m.to_string(), e.to_string());
    assert_eq!(
        routed("anthropic", "complex", true, true),
        pair("claude-opus-5-5", "xhigh")
    );
    assert_eq!(
        routed("anthropic", "routine", true, true),
        pair("claude-opus-5-5", "xhigh")
    );
    assert_eq!(
        routed("anthropic", "review", true, false),
        routed("anthropic", "review", false, false)
    );
    assert_eq!(
        routed("openai", "lookup", true, false),
        routed("openai", "lookup", false, false)
    );
}

#[test]
fn spec_policy_cannot_raise_task_minimums() {
    for bad in [
        YAML.replace("specified: {min_tier: 2,", "specified: {min_tier: 4,"),
        YAML.replace(
            "specified: {min_tier: 2, min_effort: medium",
            "specified: {min_tier: 2, min_effort: max",
        ),
        YAML.replace(
            "specified: {min_tier: 1, min_effort: medium, preferred_effort: {normal: high",
            "specified: {min_tier: 1, min_effort: medium, preferred_effort: {normal: low",
        ),
    ] {
        assert_ne!(bad, YAML);
        assert!(Config::parse(&bad).is_err());
    }
}
