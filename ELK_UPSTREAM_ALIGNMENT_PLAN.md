# ELK Upstream Alignment Plan

## Current Baseline

Measured on stress fixtures (`fixtures/layout_stress_*.mmd`):

- Crossing phase parity (`scripts/compare_elk_crossing_phase_trace.ts`)
  - `post_sweep_total_order_mismatch=38/151`
  - `final_total_order_mismatch=35/151`
  - `composition_mismatch=0/151` (both post-sweep and final)
- Rank-order parity (`scripts/compare_elk_crossing_rank_order.ts`)
  - `total_order_mismatch=35/151`
  - `total_composition_mismatch=0/151`

Interpretation:
- Layer composition is already aligned.
- Main remaining gap is intra-layer ordering.

## Deep Gap Analysis (vs upstream ELK)

Reference classes:
- `LayerSweepCrossingMinimizer`
- `BarycenterHeuristic`
- `GraphInfoHolder`
- `ForsterConstraintResolver`
- `ISweepPortDistributor`

Major gaps:

- We still use a simplified neighbor-order sweep kernel instead of a full upstream-equivalent barycenter pass.
- Constraint resolution (Forster) is not modeled as an explicit phase in the local crossing kernel.
- Hierarchical graph sweep data model (`GraphInfoHolder` + child-graph recursion strategy) is not represented one-to-one.
- Trial execution and best-sweep persistence are close but still not mapped to upstream classes and responsibilities.

## Refactor Goal

Make crossing minimization phase-modular and upstream-faithful, so Dagre/ELK engines can be replaced independently and each phase can be verified in isolation.

## Phase Plan

- [x] Extract deterministic neighbor-order kernel into its own phase file:
  - `layout/engine/graph/engine/elk/core/elk_layered_pipeline_crossing_neighbor_order_phase.mbt`
- [ ] Introduce explicit crossing-phase contracts mirroring upstream roles:
  - `CrossingHeuristic`
  - `PortDistributor`
  - `ConstraintResolver`
  - `CrossingCounter`
- [ ] Implement faithful `BarycenterHeuristic` state machine (layer-level + node-level init and per-sweep preordered logic) behind the new contract.
- [ ] Implement `ForsterConstraintResolver` as a standalone phase with phase-level tests.
- [ ] Implement upstream-like graph-holder orchestration (`GraphInfoHolder` equivalent) to isolate hierarchical traversal/sweep decisions.
- [ ] Add a strict upstream parity mode that disables non-upstream local candidate selectors for A/B validation.
- [ ] Gate with intermediate parity checks at each stage:
  - rank seed layers
  - crossing post-sweep layers
  - crossing final layers
  - end-to-end weighted metrics

## Test Strategy (Non-Ad-Hoc)

- Keep existing end-to-end stress parity scripts.
- Add intermediate snapshot tests per phase boundary (input -> output, no rendering dependency).
- For each phase refactor:
  - lock expected intermediate trace lines before change,
  - port one upstream behavior chunk,
  - update/extend phase snapshots,
  - verify no composition regression and monotonic order-gap improvement target.

## Success Criteria

- No regression in existing composition parity (`0/151` stays).
- Order mismatch reduced from `35/151` toward upstream target over staged commits.
- Every major algorithm step testable without SVG rendering.
