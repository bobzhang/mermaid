# Layout Parity Baseline (2026-02-19)

This directory stores pinned stress-parity reports generated with:

```sh
bun run scripts/compare_layout_stress.ts --local-layout-engine dagre-parity --json /tmp/layout_stress_dagre_parity.json
bun run scripts/compare_layout_stress.ts --local-layout-engine elk --json /tmp/layout_stress_elk.json
```

Copied into:

- `dagre-parity.json`
- `elk.json`

Snapshot summary:

- `dagre-parity`: `fixtures=13`, `structuralOk=13`, `avgWeightedGapIndex=0.0672`, `avgMajorRankExactMatchRate=0.7554`, `totalMajorRankCompositionMismatches=0`, `avgLogicalCrossingMultiplier=0.8839`
- `elk`: `fixtures=13`, `structuralOk=13`, `avgWeightedGapIndex=0.1120`, `avgMajorRankExactMatchRate=0.5466`, `totalMajorRankCompositionMismatches=56`, `avgLogicalCrossingMultiplier=0.9061`

Use:

```sh
bun run scripts/check_layout_parity_gates.ts
bun run scripts/check_layout_parity_gates.ts --profile target
bun run scripts/check_phase_parity_gates.ts
```
