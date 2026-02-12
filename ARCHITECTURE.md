# Architecture

This document describes how the MoonBit port of `beautiful-mermaid` is structured and how data flows through the system.

## High-Level Pipeline

```text
Mermaid source text
  -> parser package (`parser/parser.mbt`, exported as `@beautiful_mermaid/parser.parse_mermaid`)
  -> root bridge (`parser.mbt`, converts parser package types to root package types)
  -> MermaidGraph (AST-like model in types.mbt)
  -> layout bridge package (`layout/layout.mbt`)
  -> layout/core bridge package (`layout/core/layout.mbt`, `layout/core/types.mbt`) + layout/engine/core implementation (`layout/engine/core/layout.mbt`, `layout/engine/core/layout_state_ascii_grid.mbt`) + layout/engine/pathfinder/core implementation (`layout/engine/pathfinder/core/ascii_grid_pathfinder.mbt`) + layout/engine/sequence/core implementation (`layout/engine/sequence/core/layout_sequence.mbt`)
  -> PositionedGraph (geometry model in types.mbt)
  -> renderer
     - renderer/svg/core/svg_renderer.mbt + root renderer/svg bridge package (SVG output)
     - renderer/ascii/flow_state package + renderer/ascii/sequence package + renderer/ascii/class_er package + root renderer/ascii bridge package (text output)
  -> final SVG / ASCII / Unicode string
```

`beautiful_mermaid.mbt` is the public facade that wires parser, layout, themes, and renderers into stable API functions.

## Core Modules

## Data Model and Contracts

- `types.mbt`
  - Defines public domain types:
    - Parse layer: `MermaidGraph`, `MermaidNode`, `MermaidEdge`, `MermaidSubgraph`, sequence-specific types.
    - Layout layer: `PositionedGraph`, `PositionedNode`, `PositionedEdge`, `PositionedGroup`, sequence positioned types.
    - Config layer: `RenderOptions`, `AsciiRenderOptions`, `DiagramColors`.
  - Keeps parser/layout/renderer boundaries explicit through shared types.

## Parse Layer

- `parser/header/core` package
  - Core header-dispatch implementation: `parser/header/core/parser.mbt`.
  - Flowchart parsing implementation is in `parser/flowchart/core/parser_flowchart.mbt`, re-exported via `parser/header/core/parser_flowchart.mbt` bridge functions.
  - State parsing implementation is in `parser/state/core/parser_state.mbt`, re-exported via `parser/header/core/parser_state.mbt` bridge functions.
  - Sequence parsing implementation is in `parser/sequence/core/parser_sequence.mbt`, re-exported via `parser/header/core/parser_sequence.mbt` bridge functions.
  - Class/ER parsing implementation is in `parser/class_er/core/parser_class_er.mbt`, re-exported via `parser/header/core/parser_class_er.mbt` bridge functions.
- `parser/core` bridge package (`parser/core/parser.mbt`)
  - Re-exports `parse_mermaid` by delegating to `parser/header/core`.
- `parser` package bridge (`parser/parser.mbt`)
  - Exposes `/parser.parse_mermaid` while delegating to `parser/core`.
  - Entry: `@beautiful_mermaid/parser.parse_mermaid(text)`.
  - Dispatches by Mermaid header (`graph`, `flowchart`, `stateDiagram`, `sequenceDiagram`, `classDiagram`, `erDiagram`).
  - Produces a parser-package `MermaidGraph` independent of output format.
- Root bridge `parser.mbt`
  - Calls parser package entrypoint and converts parser-package graph/error values into root package public types (`types.mbt`).

## Layout Layer

- `layout/engine/core` package
  - Core flow/state/class/er layout implementation and routing orchestration (`layout/engine/core/layout.mbt`, `layout/engine/core/layout_state_ascii_grid.mbt`).
- `layout/engine/pathfinder/core` package
  - Core ASCII grid pathfinding implementation (`layout/engine/pathfinder/core/ascii_grid_pathfinder.mbt`).
  - Consumed by `layout/engine/core` for state edge routing.
- `layout/engine/sequence/core` package
  - Core sequence layout implementation (`layout/engine/sequence/core/layout_sequence.mbt`).
  - Consumed by `layout/engine/core` for sequence diagram positioning.
- `layout/core` package bridge (`layout/core/layout.mbt`, `layout/core/types.mbt`)
  - Re-exports layout/engine/core public APIs for downstream packages (`@beautiful_mermaid/layout/core`).
- `layout` package bridge (`layout/layout.mbt`, `layout/types.mbt`)
  - Re-exports layout/core public APIs for downstream packages (`@beautiful_mermaid/layout`).

## Render Layer

- `renderer/svg/core/svg_renderer.mbt`
  - Converts `PositionedGraph` to SVG.
  - Applies colors/font/spacing/transparent behavior from options.
  - Uses CSS variables to keep theming composable.
- `renderer/svg/svg_renderer.mbt`
  - Public bridge package entrypoint that re-exports SVG rendering for downstream callers.
- `renderer/ascii/flow_state/core/ascii_renderer.mbt`
  - Core ASCII/Unicode flowchart/state rendering path and dispatch glue.
  - Includes grid/pathfinding support through `renderer/ascii/flow_state/core/ascii_grid_pathfinder.mbt`.
- `renderer/ascii/flow_state/ascii_renderer.mbt`
  - Public bridge package entrypoint that re-exports flow/state ASCII rendering for downstream callers.
- `renderer/ascii/ascii_renderer.mbt`
  - Public bridge package entrypoint that re-exports ASCII rendering for downstream callers.
- `renderer/ascii/sequence/core/ascii_sequence_renderer.mbt`
  - Specialized sequence diagram text rendering implementation.
- `renderer/ascii/sequence/ascii_sequence_renderer.mbt`
  - Public bridge package entrypoint that re-exports sequence ASCII rendering for downstream callers.
- `renderer/ascii/class_er/core/ascii_class_renderer.mbt`
  - Class diagram text rendering and relationship markers implementation.
- `renderer/ascii/class_er/core/ascii_er_renderer.mbt`
  - ER diagram text rendering and cardinality/operator display implementation.
- `renderer/ascii/class_er/ascii_class_renderer.mbt`, `renderer/ascii/class_er/ascii_er_renderer.mbt`
  - Public bridge package entrypoints that re-export class/ER ASCII rendering for downstream callers.

## Theme and Styling

- `themes/core/themes.mbt`
  - Theme implementation: built-in palettes, slug normalization/parsing, and Shiki-to-diagram color conversion.
- `themes/themes.mbt`
  - Public bridge package entrypoint that re-exports theme APIs and types for downstream callers.
- `beautiful_mermaid.mbt`
  - Exposes:
    - `render_mermaid` (SVG)
    - `render_mermaid_ascii` (ASCII/Unicode)
    - theme/color convenience wrappers.

## CLI Layer

- `cmd/main/core/main.mbt`
  - CLI implementation: argument parsing, mode validation, and render invocation.
- `cmd/main/main.mbt`
  - Thin executable bridge (`is-main`) that delegates to `cmd/main/core`.

## Test Architecture

The suite is intentionally layered to catch regressions at different levels:

- Parser correctness:
  - `parser_*_test.mbt`, `parser_parity_test.mbt`, `parser_supported_corpus_test.mbt`.
- Layout/renderer invariants (white-box):
  - `*_wbtest.mbt` files (for internal geometry/routing behavior).
- Semantic parity tests:
  - `svg_semantic_parity_test.mbt`, `svg_state_semantic_parity_test.mbt`, `ascii_semantic_parity_test.mbt`, diagram-specific corpus tests.
- Snapshot/regression tests:
  - `supported_svg_snapshot_test.mbt`, `upstream_svg_snapshot_test.mbt`, `supported_render_smoke_test.mbt`.
  - Snapshots are stored in `__snapshot__/` with external SVG files for visual diffing.
- Upstream parity coverage:
  - `upstream_samples_smoke_test.mbt` generated from upstream corpus.
- Test fixtures and helpers:
  - `test_support/core/fixtures.mbt`, `test_support/core/normalize.mbt`, `test_support/core/gate_cases.mbt` hold fixture and normalization implementation.
  - `test_support/test_support.mbt` is the public bridge package entrypoint used by tests.

## Extension Points

When adding a new Mermaid feature/category, follow this order:

1. Extend parse model and parser branch in `parser/` package.
2. Extend layout contracts/positioning in `layout/engine/core` or `layout/engine/sequence/core` (and update `layout/core` + `layout` bridge exports as needed).
3. Implement renderer support in `svg_renderer.mbt` and/or text renderers.
4. Add semantic parity tests and snapshot coverage.
5. Update CLI/docs only after API behavior is validated.
