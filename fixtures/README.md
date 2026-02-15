# Fixture Layout Suites

This directory contains graph fixtures used to evaluate layout quality against
the official Mermaid renderer.

## Stress Fixtures

Files named `layout_stress_*.mmd` are the default suite consumed by:

```bash
bun run scripts/compare_layout_stress.ts --max-logical-crossing-multiplier 1.0
```

These fixtures are intended to stay stable under a strict quality gate.

For a broader quality watchdog (still based on current pre-alpha baseline), run:

```bash
bun run scripts/compare_layout_stress.ts \
  --max-logical-crossing-multiplier 1.0 \
  --max-polyline-crossing-multiplier 4.6 \
  --min-span-x-ratio 0.12 \
  --min-span-y-ratio 0.05 \
  --min-span-area-ratio 0.04 \
  --max-major-inversion-rate 0.55 \
  --max-avg-rmse 0.70 \
  --max-avg-inversion-rate 0.35 \
  --max-avg-major-inversion-rate 0.20 \
  --max-avg-polyline-crossing-multiplier 3.6 \
  --max-avg-logical-crossing-multiplier 0.8 \
  --min-avg-span-area-ratio 0.18
```

When local rendering is under load (e.g. concurrent Moon jobs), you can make
the watchdog more resilient to transient lock contention:

```bash
bun run scripts/compare_layout_stress.ts \
  --local-timeout-ms 120000 \
  --local-render-retries 2 \
  --retry-backoff-ms 500
```

## Challenge Fixtures

Files named `layout_challenge_*.mmd` are intentionally difficult topologies used
for exploratory comparison. They are not part of the default strict gate.

Run them explicitly:

```bash
bun run scripts/compare_layout_stress.ts fixtures/layout_challenge_001_nested_portal_mesh.mmd
```

This separation keeps CI-quality signals stable while still tracking hard cases.

## Topology Coverage

These fixtures are intentionally designed to cover different layout failure
modes instead of random graph noise.

- `layout_stress_008_hyper_weave_pipeline.mmd`: dense multi-stage weave with
  heavy cross-layer fan-in/fan-out.
- `layout_stress_009_nested_ring_bridges.mmd`: nested cyclic rings bridged
  across subgraphs.
- `layout_stress_010_bipartite_crossfire.mmd`: layered bipartite crossfire with
  many lateral and feedback links.
- `layout_stress_011_feedback_lattice.mmd`: lattice-style four-layer feedback
  network with diagonal and reverse links.
- `layout_stress_012_interleaved_subgraph_feedback.mmd`: nested subgraphs with
  interleaved bidirectional cross-cluster feedback and sink back-links.
- `layout_stress_013_rl_dual_scc_weave.mmd`: right-to-left dual-SCC weave used
  to validate `graph RL` directional behavior and long-range cross-cluster flow.
- `layout_challenge_002_multicluster_hyperloop.mmd`: high-density
  multi-cluster portal mesh for exploratory comparison.
- `layout_challenge_003_quad_cluster_pinwheel.mmd`: four-cluster pinwheel with
  nested cores and long-range reciprocal bridges.
- `layout_challenge_004_bt_multistage_crosswind.mmd`: bottom-to-top staged mesh
  with nested cores to stress `graph BT` rank assignment and backflow routing.
