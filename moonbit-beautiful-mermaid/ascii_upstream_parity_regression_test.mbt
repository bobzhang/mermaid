///|
fn default_ascii_options(
  use_ascii : Bool,
) -> @beautiful_mermaid.AsciiRenderOptions {
  @beautiful_mermaid.AsciiRenderOptions::{
    use_ascii,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  }
}

///|
fn assert_text_parity(
  input : String,
  expected_ascii : String,
  expected_unicode : String,
) -> Unit raise {
  let actual_ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=default_ascii_options(true),
  )
  let actual_unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=default_ascii_options(false),
  )

  assert_eq(
    @test_support.normalize_whitespace(actual_ascii),
    @test_support.normalize_whitespace(expected_ascii),
  )
  assert_eq(
    @test_support.normalize_whitespace(actual_unicode),
    @test_support.normalize_whitespace(expected_unicode),
  )
}

///|
fn beautiful_mermaid_source() -> String {
  "stateDiagram-v2\n    direction LR\n    [*] --> Input\n    Input --> Parse: DSL\n    Parse --> Layout: AST\n    Layout --> SVG: Vector\n    Layout --> ASCII: Text\n    SVG --> Theme\n    ASCII --> Theme\n    Theme --> Output\n    Output --> [*]"
}

///|
fn beautiful_mermaid_expected_ascii() -> String {
  [
    "+--+     +-------+     +-------+     +--------+        +-------+     +-------+     +--------+     +--+",
    "|  |     |       |     |       |     |        |        |       |     |       |     |        |     |  |",
    "|  |---->| Input |-DSL>| Parse |-AST>| Layout |Vector->|  SVG  |---->| Theme |---->| Output |---->|  |",
    "|  |     |       |     |       |     |        |        |       |     |       |     |        |     |  |",
    "+--+     +-------+     +-------+     +--------+        +-------+     +-------+     +--------+     +--+",
    "                                          |                              ^",
    "                                          |                              |",
    "                                          |                              |",
    "                                        Text                             |",
    "                                          |                              |",
    "                                          |            +-------+         |",
    "                                          |            |       |         |",
    "                                          +----------->| ASCII |---------+",
    "                                                       |       |", "                                                       +-------+",
  ]
  .iter()
  .join("\n")
}

///|
fn beautiful_mermaid_expected_unicode() -> String {
  [
    "┌──┐     ┌───────┐     ┌───────┐     ┌────────┐        ┌───────┐     ┌───────┐     ┌────────┐     ┌──┐",
    "│  │     │       │     │       │     │        │        │       │     │       │     │        │     │  │",
    "│  ├────►│ Input ├─DSL►│ Parse ├─AST►│ Layout ├Vector─►│  SVG  ├────►│ Theme ├────►│ Output ├────►│  │",
    "│  │     │       │     │       │     │        │        │       │     │       │     │        │     │  │",
    "└──┘     └───────┘     └───────┘     └────┬───┘        └───────┘     └───────┘     └────────┘     └──┘",
    "                                          │                              ▲",
    "                                          │                              │",
    "                                          │                              │",
    "                                        Text                             │",
    "                                          │                              │",
    "                                          │            ┌───────┐         │",
    "                                          │            │       │         │",
    "                                          └───────────►│ ASCII ├─────────┘",
    "                                                       │       │", "                                                       └───────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn git_branching_workflow_source() -> String {
  "graph LR\n  A[main] --> B[develop]\n  B --> C[feature/auth]\n  B --> D[feature/ui]\n  C --> E{PR Review}\n  D --> E\n  E -->|approved| B\n  B --> F[release/1.0]\n  F --> G{Tests?}\n  G -->|pass| A\n  G -->|fail| F"
}

///|
fn git_branching_workflow_expected_ascii() -> String {
  [
    "+------+     +---------+     +--------------+      +-----------+", "|      |     |         |     |              |      |           |",
    "| main |---->| develop |---->| feature/auth |---+->| PR Review |", "|      |     |         |     |              |   |  |           |",
    "+------+     +---------+     +--------------+   |  +-----------+", "    ^             ^                             |    approved",
    "    |             |                             |        |", "    +-------------+------------------+----------+--------+",
    "                  |                  |          |", "                  |                  |          |",
    "                  |          +--------------+   |  +-----------+", "                  |          |              |   |  |           |",
    "                  +--------->|  feature/ui  |  fail|   Tests?  |", "                  |          |              |   |  |           |",
    "                  |          +--------------+   |  +-----------+", "                  |                             |        ^",
    "                  |                             |        |", "                  |                  +----------+        |",
    "                  |                  |                   |", "                  |                  v                   |",
    "                  |          +--------------+            |", "                  |          |              |            |",
    "                  +--------->| release/1.0  |------------+", "                             |              |",
    "                             +--------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn git_branching_workflow_expected_unicode() -> String {
  [
    "┌──────┐     ┌─────────┐     ┌──────────────┐      ┌───────────┐",
    "│      │     │         │     │              │      │           │",
    "│ main ├────►│ develop ├────►│ feature/auth ├───┬─►│ PR Review │",
    "│      │     │         │     │              │   │  │           │",
    "└──────┘     └────┬────┘     └──────────────┘   │  └─────┬─────┘",
    "    ▲             ▲                             │    approved", "    │             │                             │        │",
    "    └─────────────┼──────────────────┬──────────┼────────┘",
    "                  │                  │          │", "                  │                  │          │",
    "                  │          ┌───────┴──────┐   │  ┌───────────┐",
    "                  │          │              │   │  │           │",
    "                  ├─────────►│  feature/ui  │  fail┤   Tests?  │",
    "                  │          │              │   │  │           │",
    "                  │          └──────────────┘   │  └───────────┘",
    "                  │                             │        ▲", "                  │                             │        │",
    "                  │                  ┌──────────┘        │",
    "                  │                  │                   │", "                  │                  ▼                   │",
    "                  │          ┌──────────────┐            │",
    "                  │          │              │            │", "                  └─────────►│ release/1.0  ├────────────┘",
    "                             │              │", "                             └──────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Beautiful Mermaid sample" {
  assert_text_parity(
    beautiful_mermaid_source(),
    beautiful_mermaid_expected_ascii(),
    beautiful_mermaid_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Git Branching Workflow sample" {
  assert_text_parity(
    git_branching_workflow_source(),
    git_branching_workflow_expected_ascii(),
    git_branching_workflow_expected_unicode(),
  )
}
