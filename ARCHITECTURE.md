# Architecture

This document describes how the MoonBit port of `beautiful-mermaid` is structured and how data flows through the system.

## High-Level Pipeline

```text
Mermaid source text
  -> parser package (`parser/parser.mbt`, exported as `@beautiful_mermaid/parser.parse_mermaid`)
  -> root bridge (`parser.mbt`, converts parser package types to root package types)
  -> MermaidGraph (AST-like model in types.mbt)
  -> layout.mbt / layout_state_ascii_grid.mbt
  -> PositionedGraph (geometry model in types.mbt)
  -> renderer
     - svg_renderer.mbt (SVG output)
     - ascii_renderer package + renderer/ascii/sequence package + renderer/ascii/class_er package (text output)
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

- `parser/` package
  - Core implementation files: `parser/parser.mbt`, `parser/parser_flowchart.mbt`, `parser/parser_state.mbt`, `parser/parser_sequence.mbt`, `parser/parser_class_er.mbt`.
  - Entry: `@beautiful_mermaid/parser.parse_mermaid(text)`.
  - Dispatches by Mermaid header (`graph`, `flowchart`, `stateDiagram`, `sequenceDiagram`, `classDiagram`, `erDiagram`).
  - Produces a parser-package `MermaidGraph` independent of output format.
- Root bridge `parser.mbt`
  - Calls parser package entrypoint and converts parser-package graph/error values into root package public types (`types.mbt`).

## Layout Layer

- `layout.mbt`
  - General graph layout and geometry for SVG and text renderers.
  - Computes node positions, edge routes, subgraph/group bounds, and sequence placement primitives.
- `layout_state_ascii_grid.mbt`
  - State-diagram-specific grid logic used by ASCII routing/placement.

## Render Layer

- `svg_renderer.mbt`
  - Converts `PositionedGraph` to SVG.
  - Applies colors/font/spacing/transparent behavior from options.
  - Uses CSS variables to keep theming composable.
- `ascii_renderer.mbt`
  - Core ASCII/Unicode flowchart/state rendering path.
  - Includes grid/pathfinding support through `ascii_grid_pathfinder.mbt`.
- `renderer/ascii/sequence/ascii_sequence_renderer.mbt`
  - Specialized sequence diagram text rendering extracted as a dedicated renderer package.
- `renderer/ascii/class_er/ascii_class_renderer.mbt`
  - Class diagram text rendering and relationship markers.
- `renderer/ascii/class_er/ascii_er_renderer.mbt`
  - ER diagram text rendering and cardinality/operator display.

## Theme and Styling

- `themes.mbt`
  - Built-in themes (`ThemeName`) and slug normalization/parsing.
  - Theme lookup helpers and canonicalization.
  - Conversion from Shiki-like token themes into `DiagramColors`.
- `beautiful_mermaid.mbt`
  - Exposes:
    - `render_mermaid` (SVG)
    - `render_mermaid_ascii` (ASCII/Unicode)
    - theme/color convenience wrappers.

## CLI Layer

- `cmd/main/main.mbt`
  - Thin wrapper over public APIs.
  - Parses flags for output mode and styling.
  - Keeps behavior close to library APIs to avoid drift.

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
  - `test_support/fixtures.mbt`, `test_support/normalize.mbt`, `test_support/gate_cases.mbt`.

## Extension Points

When adding a new Mermaid feature/category, follow this order:

1. Extend parse model and parser branch in `parser/` package.
2. Extend layout contracts/positioning in `layout.mbt` (and state grid helpers if needed).
3. Implement renderer support in `svg_renderer.mbt` and/or text renderers.
4. Add semantic parity tests and snapshot coverage.
5. Update CLI/docs only after API behavior is validated.
