///|
test "ASCII preserves sequence operators for sequence diagrams" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nA->B: Open\nB-->>A: Reply",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("+"))
  assert_true(ascii.contains("Open"))
  assert_true(ascii.contains("Reply"))
  assert_true(ascii.contains("........"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nA->B: Open\nB-->>A: Reply",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("┌───┐"))
  assert_true(unicode.contains("Open"))
  assert_true(unicode.contains("Reply"))
  assert_true(unicode.contains("▷"))
  assert_true(unicode.contains("◀"))
  assert_true(unicode.contains("╌"))
}

///|
test "ASCII sequence renders blocks, dividers, and notes" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nA->>B: Request\nalt Success\nB-->>A: 200\nelse Failure\nB-->>A: 500\nend\nNote right of B: Inspect response",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("alt [Success]"))
  assert_true(ascii.contains("[Failure]"))
  assert_true(ascii.contains("Inspect response"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nA->>B: Request\nalt Success\nB-->>A: 200\nelse Failure\nB-->>A: 500\nend\nNote right of B: Inspect response",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("alt [Success]"))
  assert_true(unicode.contains("[Failure]"))
  assert_true(unicode.contains("Inspect response"))
  assert_true(unicode.contains("┤"))
}

///|
test "ASCII sequence renders activation bars" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nA->>+B: Activate\nB-->>-A: Return",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("Activate"))
  assert_true(ascii.contains("Return"))
  assert_true(ascii.contains("|||"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nA->>+B: Activate\nB-->>-A: Return",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("Activate"))
  assert_true(unicode.contains("Return"))
  assert_true(unicode.contains("│││"))
}

///|
test "ASCII sequence ignores standalone activation commands" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nparticipant A\nparticipant B\nactivate A\nA->>B: Work\ndeactivate A",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("Work"))
  assert_true(!ascii.contains("|||"))
  assert_true(!ascii.contains("+-+"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nparticipant A\nparticipant B\nactivate A\nA->>B: Work\ndeactivate A",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("Work"))
  assert_true(!unicode.contains("│││"))
  assert_true(!unicode.contains("└─┘"))
}

///|
test "ASCII sequence ignores standalone activation commands for self messages" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nparticipant A\nactivate A\nA->>A: Think\ndeactivate A",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("Think"))
  assert_true(!ascii.contains("|||"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "sequenceDiagram\nparticipant A\nactivate A\nA->>A: Think\ndeactivate A",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("Think"))
  assert_true(!unicode.contains("│││"))
}

///|
test "ASCII flowchart renders subgraph containers" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph TD\nsubgraph one\nA --> B\nend",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 2,
      padding_y: 2,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("one"))
  assert_true(ascii.contains("A"))
  assert_true(ascii.contains("B"))
  assert_true(ascii.contains("+"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph TD\nsubgraph one\nA --> B\nend",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 2,
      padding_y: 2,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("one"))
  assert_true(unicode.contains("A"))
  assert_true(unicode.contains("B"))
  assert_true(unicode.contains("┌"))
  assert_true(unicode.contains("┐"))
}

///|
test "ASCII flowchart renders nested subgraph labels" {
  let output = try! @beautiful_mermaid.render_mermaid_ascii(
    "graph TD\nsubgraph Outer\nsubgraph Inner\nA --> B\nend\nC --> D\nend",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 2,
      padding_y: 2,
      box_border_padding: 1,
    },
  )

  assert_true(output.contains("Outer"))
  assert_true(output.contains("Inner"))
}

///|
test "ASCII preserves class operators for class diagrams" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "classDiagram\nA <|-- B : inherits\nC *-- D : owns",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("+"))
  assert_true(ascii.contains("herit"))
  assert_true(ascii.contains("owns"))
  assert_true(ascii.contains("^"))
  assert_true(ascii.contains("*"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "classDiagram\nA <|-- B : inherits\nC *-- D : owns",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("┌───┐"))
  assert_true(unicode.contains("herit"))
  assert_true(unicode.contains("owns"))
  assert_true(unicode.contains("△"))
  assert_true(unicode.contains("◆"))
}

///|
test "ASCII preserves ER operator semantics" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "erDiagram\nCUSTOMER ||--o{ ORDER : places",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("||--o{"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "erDiagram\nCUSTOMER ||--o{ ORDER : places",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("║───o╟"))
}

///|
test "ASCII state text renderer hides synthetic pseudostate ids in boxed mode" {
  let ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    "stateDiagram-v2\n[*] --> Idle\nIdle --> [*]",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(ascii.contains("Idle"))
  assert_true(!ascii.contains("state_start_"))
  assert_true(!ascii.contains("state_end_"))
  assert_true(ascii.contains("+"))

  let unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    "stateDiagram-v2\n[*] --> Idle\nIdle --> [*]",
    options=@beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    },
  )
  assert_true(unicode.contains("Idle"))
  assert_true(!unicode.contains("state_start_"))
  assert_true(!unicode.contains("state_end_"))
  assert_true(unicode.contains("┌"))
}
