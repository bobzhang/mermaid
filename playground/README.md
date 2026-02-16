# Mermaid Playground (MoonBit JS target)

This playground is isolated in the `playground-mermaid` worktree and renders Mermaid text live in the browser.

## What it does

- Serves a local web UI at `http://127.0.0.1:4173`
- Sends text to `POST /api/render` on each edit (debounced)
- Includes built-in examples for flowchart, state, sequence, class, and ER diagrams
- Renders by running:

```bash
moon run cmd/main --target js -- "<mermaid text>"
```

So the SVG output path is the MoonBit JS target, not the native target.

## Build

From module root (`../playground.mermaid`):

```bash
moon build --target js
```

This compiles the project for JS and warms the build cache used by playground renders.

## Run

From module root (`../playground.mermaid`):

```bash
node playground/server.mjs
```

Then open `http://127.0.0.1:4173`.

## Build + Run (one flow)

```bash
moon build --target js
node playground/server.mjs
```

## Requirements

- Node.js 18+
- `moon` available on your `PATH`
