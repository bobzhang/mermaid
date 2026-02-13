# Architecture

This document describes the current MoonBit architecture of `bobzhang/beautiful_mermaid`, including package boundaries, data flow, and test strategy.

## High-Level Pipeline

```text
Mermaid source text
  -> parser facade (`parser.mbt`)
  -> parser package stack (`parser/*`)
  -> MermaidGraph (normalized semantic graph)
  -> layout package stack (`layout/*`)
  -> PositionedGraph (geometry + routed edges)
  -> ASCII layout-plan stage (`renderer/ascii/layout_plan/*`) for text-mode routing/packing
  -> renderer package stack (`renderer/svg/*`, `renderer/ascii/*`)
  -> SVG or ASCII/Unicode output
```

`beautiful_mermaid.mbt` is the public facade that wires parser, layout, themes, and renderers into stable API functions.

## Design Pattern Used Across Packages

The project uses a consistent 3-layer package pattern in most subsystems:

1. `engine/core` packages: implementation.
2. `core` packages: stable bridge/re-export surface.
3. top-level package bridge: public subsystem entrypoint.

This keeps implementation internals movable while preserving clean public import paths.

## Data Model and Contracts

- `model/types.mbt`
  - Source-of-truth domain types: parser graph, layout graph, options, themes.
- `types.mbt`
  - Public re-export layer for root consumers.

Key models:

- Parse model: `MermaidGraph`, `MermaidNode`, `MermaidEdge`, `MermaidSubgraph`, sequence metadata types.
- Layout model: `PositionedGraph`, `PositionedNode`, `PositionedEdge`, grouped and sequence positioned types.
- Render config: `RenderOptions`, `AsciiRenderOptions`, `DiagramColors`.

## Parse Layer

### Entry and Dispatch

- Root facade: `parser.mbt`
  - `parse_mermaid(text)` delegates to parser package.
- Parser package bridge: `parser/parser.mbt`
  - Public API is intentionally parse-only: `parse_mermaid(String) -> @model.MermaidGraph raise @model.MermaidError`.
  - Model types are owned by `model/types.mbt` and are not re-exported from the parser package.
- Parser core bridge: `parser/core/parser.mbt`
- Header dispatcher implementation: `parser/header/core/parser.mbt`
  - Handles normalization, preprocessing, header detection, and dispatch.

Supported headers:

- `graph` / `flowchart`
- `stateDiagram` / `stateDiagram-v2`
- `sequenceDiagram`
- `classDiagram`
- `erDiagram`

### Diagram Parser Packages

Each diagram parser follows `core -> engine/core`:

- Flowchart:
  - Bridge: `parser/flowchart/core/parser_flowchart.mbt`
  - Implementation: `parser/flowchart/engine/core/parser_flowchart.mbt`
- State:
  - Bridge: `parser/state/core/parser_state.mbt`
  - Implementation: `parser/state/engine/core/parser_state.mbt`
- Sequence:
  - Bridge: `parser/sequence/core/parser_sequence.mbt`
  - Implementation: `parser/sequence/engine/core/parser_sequence.mbt`
- Class/ER:
  - Bridge: `parser/class_er/core/parser_class_er.mbt`
  - Implementation: `parser/class_er/engine/core/parser_class_er.mbt`

### Shared Parser Engine (`parser/common/engine/core`)

- Implementation file: `parser/common/engine/core/parser_common_helpers.mbt`
- Shared responsibilities now include:
  - token trimming and direction parsing,
  - common node token parsing,
  - edge-operator scanning algorithms:
    - `find_earliest_operator_indices`
    - `find_first_operator_indices`
  - canonical flow/state edge operator specs:
    - `flow_edge_operator_specs`
  - subgraph stack mutation helpers:
    - append nodes,
    - append child subgraphs,
    - set local subgraph direction.

Important design detail:

- Flowchart/state/sequence parser engines keep local `EdgeOp` structs and map shared operator specs/index results into local types.
- This avoids cross-package record-construction coupling while still centralizing parsing semantics.

## Layout Layer

### Package Topology

- Public bridge: `layout/layout.mbt`, `layout/types.mbt`
- Bridge layer: `layout/core/layout.mbt`, `layout/core/types.mbt`
- Engine bridge: `layout/engine/core/layout.mbt`, `layout/engine/core/ascii_grid_pathfinder.mbt`

Implementations:

- Graph/state/class/ER layout:
  - `layout/engine/graph/core/layout.mbt`
  - `layout/engine/graph/core/layout_state_ascii_grid.mbt`
- Pathfinder:
  - `layout/engine/pathfinder/core/ascii_grid_pathfinder.mbt`
- Sequence layout:
  - `layout/engine/sequence/core/layout_sequence.mbt`

Output: `PositionedGraph`.

## Render Layer

### SVG

- Public bridge: `renderer/svg/svg_renderer.mbt`
- Bridge layer: `renderer/svg/core/svg_renderer.mbt`
- Implementation: `renderer/svg/engine/core/svg_renderer.mbt`

### ASCII / Unicode

- Public umbrella: `renderer/ascii/ascii_renderer.mbt`
- Internal layout-plan stage:
  - Package: `renderer/ascii/layout_plan/layout_plan.mbt`
  - Produces `AsciiLayoutPlan` with family dispatch and precomputed layout payloads for:
    - sequence lifeline/message/block/note coordinates,
    - class box sections/levels/placements,
    - ER entity sections/grid placements,
    - state flat-grid routing, and
    - flow subgraph positioned geometry.
- Flow/state renderer:
  - Bridge: `renderer/ascii/flow_state/core/ascii_renderer.mbt`
  - Implementation: `renderer/ascii/flow_state/engine/core/ascii_renderer.mbt`
  - Dispatches by plan kind and delegates rendering to family renderers with precomputed plan data.
- Sequence renderer:
  - Bridge: `renderer/ascii/sequence/core/ascii_sequence_renderer.mbt`
  - Implementation: `renderer/ascii/sequence/engine/core/ascii_sequence_renderer.mbt`
  - Consumes `AsciiSequenceLayout` from the plan stage.
- Class/ER renderer:
  - Bridge: `renderer/ascii/class_er/core/ascii_class_renderer.mbt`, `renderer/ascii/class_er/core/ascii_er_renderer.mbt`
  - Implementations: `renderer/ascii/class_er/engine/core/ascii_class_renderer.mbt`, `renderer/ascii/class_er/engine/core/ascii_er_renderer.mbt`
  - Consume `AsciiClassLayout` and `AsciiErLayout` from the plan stage.

## Theme and Styling

- Theme implementation: `themes/core/themes.mbt`
- Theme bridge: `themes/themes.mbt`

The renderers consume resolved diagram colors/options and do not own theme canonicalization logic.

## CLI Layer

- Executable bridge: `cmd/main/main.mbt`
- Core bridge: `cmd/main/core/main.mbt`
- Implementation: `cmd/main/app/core/main.mbt`

CLI focuses on argument parsing, mode validation, and calling the facade APIs.

## Test Architecture

The test suite is intentionally layered.

### Black-box parser and integration tests

- Parser behavior:
  - `parser_parity_test.mbt`
  - `parser_sequence_test.mbt`
  - `parser_state_test.mbt`
  - `parser_class_er_test.mbt`
  - `parser_subgraph_test.mbt`
  - `parser_supported_corpus_test.mbt`
- Full pipeline:
  - `integration_pipeline_test.mbt`

Recent parser black-box additions specifically validate shared edge-operator behavior across flowchart and state parsing.

### White-box/internal behavior tests

- `*_wbtest.mbt` packages (layout and renderer internals, routing, invariants).

### Snapshot and corpus parity tests

- SVG/ASCII snapshots and upstream corpus parity tests under root test files and `__snapshot__/`.
- Added ASCII pipeline lock snapshots: `ascii_pipeline_lock_snapshot_test.mbt` (ASCII + Unicode golden baselines for flow/state/sequence/class/ER).

## Extension Guidelines

When adding a new diagram feature, follow this order:

1. Extend parser model/behavior in `parser/*` (prefer shared logic in `parser/common/engine/core` when reusable).
2. Extend layout contracts and placement logic in `layout/*`.
3. Extend SVG and/or ASCII renderers.
4. Add black-box parser tests plus integration/snapshot coverage.
5. Update docs and CLI surface after behavior is validated.
