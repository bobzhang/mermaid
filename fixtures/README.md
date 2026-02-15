# Fixture Layout Suites

This directory contains graph fixtures used to evaluate layout quality against
the official Mermaid renderer.

## Stress Fixtures

Files named `layout_stress_*.mmd` are the default suite consumed by:

```bash
bun run scripts/compare_layout_stress.ts --max-logical-crossing-multiplier 1.0
```

These fixtures are intended to stay stable under a strict quality gate.

## Challenge Fixtures

Files named `layout_challenge_*.mmd` are intentionally difficult topologies used
for exploratory comparison. They are not part of the default strict gate.

Run them explicitly:

```bash
bun run scripts/compare_layout_stress.ts fixtures/layout_challenge_001_nested_portal_mesh.mmd
```

This separation keeps CI-quality signals stable while still tracking hard cases.
