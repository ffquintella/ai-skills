# Graph Report - ai-skills  (2026-10-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 343 nodes · 660 edges · 8 communities
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 111 edges (avg confidence: 0.89)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7cee42c4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Agent Routing and Repo Index
- Rust Review Pipeline
- Cortex Memory Tools
- Systematic Debugging Method
- Excalidraw and Helper Scripts
- Installer and Graphify Setup
- TDD and Parallel Dispatch
- Rust Bug-Class Clusters

## God Nodes (most connected - your core abstractions)
1. `Cortex tool catalogue (Claude)` - 26 edges
2. `agent-router skill (Claude Code)` - 24 edges
3. `dispatching-parallel-agents SKILL.md (claude)` - 21 edges
4. `rust-review SKILL.md (claude)` - 20 edges
5. `rust-review SKILL.md (openai)` - 19 edges
6. `ai-skills README` - 18 edges
7. `cortex-memory skill (Claude Code)` - 18 edges
8. `excalidraw-diagram SKILL.md (claude)` - 18 edges
9. `15 bug-class clusters (claude)` - 18 edges
10. `Sources behind the routing matrix (Claude)` - 17 edges

## Surprising Connections (you probably didn't know these)
- `codebase_analyze tool (tree-sitter AST)` --semantically_similar_to--> `graphify (external skill)`  [INFERRED] [semantically similar]
  claude/cortex-memory/references/tools.md → README.md
- `Codex escalation ladder (luna -> terra -> sol -> gpt-6-astra)` --semantically_similar_to--> `Escalation ladder (scout -> builder -> architect -> fable)`  [INFERRED] [semantically similar]
  openai/agent-router/SKILL.md → claude/agent-router/SKILL.md
- `Reasoning effort (none..max; Codex minimal..xhigh)` --semantically_similar_to--> `Effort level (low..max)`  [INFERRED] [semantically similar]
  openai/agent-router/SKILL.md → claude/agent-router/SKILL.md
- `Tiers at a glance (Claude vs Codex)` --semantically_similar_to--> `Agent/model/effort routing table (Step 2)`  [INFERRED] [semantically similar]
  docs/USAGE.md → claude/agent-router/SKILL.md
- `Tiers at a glance (Claude vs Codex)` --semantically_similar_to--> `Codex agent/model/effort/sandbox routing table`  [INFERRED] [semantically similar]
  docs/USAGE.md → openai/agent-router/SKILL.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Claude agent-router tier agents** — claude_agent_router_assets_agents_scout, claude_agent_router_assets_agents_builder, claude_agent_router_assets_agents_architect, claude_agent_router_assets_agents_reviewer, claude_agent_router_assets_agents_test_runner [EXTRACTED 1.00]
- **rust-review audit pipeline (claude): probe, workers, dedup, FP judge, SARIF** — claude_rust_review_scripts_probe, claude_rust_review_references_worker_brief, claude_rust_review_references_judges_dedup_judge, claude_rust_review_references_judges_fp_severity_judge, claude_rust_review_scripts_generate_sarif [EXTRACTED 1.00]
- **Four-phase root-cause debugging (claude)** — claude_systematic_debugging_skill_phase1_investigate, claude_systematic_debugging_skill_phase2_compare, claude_systematic_debugging_skill_phase3_hypothesis, claude_systematic_debugging_skill_phase4_fix [EXTRACTED 1.00]
- **Cortex memory remediation toolkit** — claude_cortex_memory_references_tools_rate_memory, claude_cortex_memory_references_tools_remember, claude_cortex_memory_references_tools_validate_memory, claude_cortex_memory_references_tools_forget, claude_cortex_memory_references_tools_anchor, claude_cortex_memory_references_tools_checkpoint [EXTRACTED 1.00]
- **rust-review audit pipeline (openai): probe, workers, dedup, FP judge, SARIF** — openai_rust_review_scripts_probe, openai_rust_review_references_worker_brief, openai_rust_review_references_judges_dedup_judge, openai_rust_review_references_judges_fp_severity_judge, openai_rust_review_scripts_generate_sarif [EXTRACTED 1.00]
- **Four-phase root-cause debugging (openai)** — openai_systematic_debugging_skill_phase1_investigate, openai_systematic_debugging_skill_phase2_compare, openai_systematic_debugging_skill_phase3_hypothesis, openai_systematic_debugging_skill_phase4_fix [EXTRACTED 1.00]
- **Parallel dispatch five-step workflow** — claude_dispatching_parallel_agents_skill_parallelism_criteria, claude_dispatching_parallel_agents_skill_independent_domains, claude_dispatching_parallel_agents_skill_self_contained_brief, claude_dispatching_parallel_agents_skill_single_message_dispatch, claude_dispatching_parallel_agents_skill_integrate_and_verify [EXTRACTED 1.00]
- **TDD red-green-refactor loop** — claude_test_driven_development_skill_red_green_refactor, claude_test_driven_development_skill_verify_red, claude_test_driven_development_skill_minimum_code, claude_test_driven_development_skill_verify_green_full_suite, claude_test_driven_development_skill_delegating_test_runs [EXTRACTED 1.00]
- **Code graph lookup options (graphify vs Cortex)** — readme_graphify, claude_agent_router_skill_graph_first_lookup, claude_agent_router_skill_one_graph_per_project, claude_cortex_memory_references_tools_unified_search, claude_cortex_memory_references_tools_codebase_analyze [INFERRED 0.85]
- **Excalidraw validate-and-render pipeline** — claude_excalidraw_diagram_skill_render_inspect_loop, claude_excalidraw_diagram_scripts_render_template, claude_excalidraw_diagram_scripts_render_template_renderdiagram, claude_excalidraw_diagram_references_sources_exporttosvg, claude_excalidraw_diagram_references_sources_playwright [INFERRED 0.85]

## Communities (8 total, 0 thin omitted)

### Community 0 - "Agent Routing and Repo Index"
Cohesion: 0.05
Nodes (53): AGENTS.md / CLAUDE.md project-rule contract, architect agent (Opus, xhigh), builder agent (Sonnet, high), reviewer agent (Sonnet, high, read-only), scout agent (Haiku, read-only), test-runner agent (Haiku), Sources behind the routing matrix (Claude), Agent skills (Claude Code docs) (+45 more)

### Community 1 - "Rust Review Pipeline"
Cohesion: 0.06
Nodes (41): Clusters and bug classes (claude), Judge briefs (claude), Dedup judge (claude), False-positive and severity judge (claude), fp_verdict taxonomy (TRUE_POSITIVE..OUT_OF_SCOPE) (claude), Severity matrix Remote vs Local (claude), rust-review sources (claude), RustSec advisories (+33 more)

### Community 2 - "Cortex Memory Tools"
Cohesion: 0.10
Nodes (33): Cortex tool catalogue (Claude), anchor tool, check_setup tool, checkpoint tool, consolidate maintenance pipeline, Cortex per-project wiki, cortex-wiki-groomer agent, detect_gaps tool (+25 more)

### Community 3 - "Systematic Debugging Method"
Cohesion: 0.07
Nodes (22): architect agent, systematic-debugging sources (claude), obra/superpowers systematic-debugging (claude citation), Debugging techniques (claude), Tracing a bad value backward (claude), Condition-based waiting (claude), Defense in depth after fix (claude), find-polluter.sh script (+14 more)

### Community 4 - "Excalidraw and Helper Scripts"
Cohesion: 0.07
Nodes (35): Excalidraw Color Palette (claude), Excalidraw Element Templates (claude), Excalidraw .excalidraw Format (claude), Excalidraw Binding Rules Table, Excalidraw Sources (claude), coleam00/excalidraw-diagram-skill (upstream), Excalidraw exportToSvg (via esm.sh), Playwright (headless browser render) (+27 more)

### Community 6 - "Installer and Graphify Setup"
Cohesion: 0.16
Nodes (25): agents_root(), ask(), copy_tree(), die(), ensure_graphify_cli(), err(), graphify_bin(), graphify_cli_version() (+17 more)

### Community 7 - "TDD and Parallel Dispatch"
Cohesion: 0.10
Nodes (19): Dispatching worked example (claude), Post-refactor Six-test Failure Example (abort/batch/approval), Dispatching sources (claude), obra/superpowers (upstream skills repo), dispatching-parallel-agents SKILL.md (claude), Parallel Dispatch Common Mistakes, Worktree Isolation for File Overlap, TDD Sources (claude) (+11 more)

### Community 8 - "Rust Bug-Class Clusters"
Cohesion: 0.12
Nodes (18): Cluster: async-runtime, 15 bug-class clusters (claude), Cluster: concurrency-data-race, Cluster: concurrency-locking, Cluster: error-handling, Cluster: ffi-cross-language, Cluster: info-disclosure, Cluster: input-os-safety (+10 more)

## Ambiguous Edges - Review These
- `agent-router skill (OpenAI Codex)` → `dispatching-parallel-subagents SKILL.md (openai)`  [AMBIGUOUS]
  openai/agent-router/SKILL.md · relation: references

## Knowledge Gaps
- **43 isolated node(s):** `Hard-to-test Design Smells Table`, `Excuses That Mean Restart From the Test`, `Router decision line (router: tier=... agent=...)`, `Best practices for Claude Code`, `7 practical ways to reduce Claude Code token usage (KDnuggets)` (+38 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 74 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ai-skills README` connect `Agent Routing and Repo Index` to `Rust Review Pipeline`, `Cortex Memory Tools`, `Systematic Debugging Method`, `Excalidraw and Helper Scripts`, `Installer and Graphify Setup`, `TDD and Parallel Dispatch`?**
  _High betweenness centrality (0.619) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `dispatching-parallel-agents SKILL.md (claude)` (e.g. with `obra/superpowers (upstream skills repo)` and `dispatching-parallel-subagents SKILL.md (openai)`) actually correct?**
  _`dispatching-parallel-agents SKILL.md (claude)` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Hard-to-test Design Smells Table`, `Excuses That Mean Restart From the Test`, `Router decision line (router: tier=... agent=...)` to the rest of the system?**
  _43 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Agent Routing and Repo Index` be split into smaller, more focused modules?**
  _Cohesion score 0.05341614906832298 - nodes in this community are weakly interconnected._
- **Why does `rust-review SKILL.md (claude)` connect `Rust Review Pipeline` to `Rust Bug-Class Clusters`, `Agent Routing and Repo Index`, `Systematic Debugging Method`?**
  _High betweenness centrality (0.234) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `rust-review SKILL.md (openai)` (e.g. with `openai.yaml (rust-review agent policy)` and `rust-review SKILL.md (claude)`) actually correct?**
  _`rust-review SKILL.md (openai)` has 2 INFERRED edges - model-reasoned connections that need verification._

### Low-confidence Hints
_AMBIGUOUS edges — the extractor was unsure. Verify before acting on these._

- **What is the exact relationship between `agent-router skill (OpenAI Codex)` and `dispatching-parallel-subagents SKILL.md (openai)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._