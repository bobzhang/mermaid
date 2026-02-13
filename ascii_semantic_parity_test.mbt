///|
test "ASCII preserves sequence operators for sequence diagrams" {
  let diagram =
    #|sequenceDiagram
    #|A->B: Open
    #|B-->>A: Reply
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("+"))
  assert_true(ascii.contains("Open"))
  assert_true(ascii.contains("Reply"))
  assert_true(ascii.contains("........"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("┌───┐"))
  assert_true(unicode.contains("Open"))
  assert_true(unicode.contains("Reply"))
  assert_true(unicode.contains("▷"))
  assert_true(unicode.contains("◀"))
  assert_true(unicode.contains("╌"))
}

///|
test "ASCII sequence renders blocks, dividers, and notes" {
  let diagram =
    #|sequenceDiagram
    #|A->>B: Request
    #|alt Success
    #|B-->>A: 200
    #|else Failure
    #|B-->>A: 500
    #|end
    #|Note right of B: Inspect response
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("alt [Success]"))
  assert_true(ascii.contains("[Failure]"))
  assert_true(ascii.contains("Inspect response"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("alt [Success]"))
  assert_true(unicode.contains("[Failure]"))
  assert_true(unicode.contains("Inspect response"))
  assert_true(unicode.contains("┤"))
}

///|
test "ASCII sequence accepts activation operators without activation bars" {
  let diagram =
    #|sequenceDiagram
    #|A->>+B: Activate
    #|B-->>-A: Return
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("Activate"))
  assert_true(ascii.contains("Return"))
  assert_true(!ascii.contains("|||"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("Activate"))
  assert_true(unicode.contains("Return"))
  assert_true(!unicode.contains("│││"))
}

///|
test "ASCII sequence ignores standalone activation commands" {
  let diagram =
    #|sequenceDiagram
    #|participant A
    #|participant B
    #|activate A
    #|A->>B: Work
    #|deactivate A
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("Work"))
  assert_true(!ascii.contains("|||"))
  assert_true(!ascii.contains("+-+"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("Work"))
  assert_true(!unicode.contains("│││"))
  assert_true(!unicode.contains("└─┘"))
}

///|
test "ASCII sequence ignores standalone activation commands for self messages" {
  let diagram =
    #|sequenceDiagram
    #|participant A
    #|activate A
    #|A->>A: Think
    #|deactivate A
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("Think"))
  assert_true(!ascii.contains("|||"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("Think"))
  assert_true(!unicode.contains("│││"))
}

///|
test "ASCII flowchart renders subgraph containers" {
  let diagram =
    #|graph TD
    #|subgraph one
    #|A --> B
    #|end
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 2,
    padding_y: 2,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("one"))
  assert_true(ascii.contains("A"))
  assert_true(ascii.contains("B"))
  assert_true(ascii.contains("+"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 2,
    padding_y: 2,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("one"))
  assert_true(unicode.contains("A"))
  assert_true(unicode.contains("B"))
  assert_true(unicode.contains("┌"))
  assert_true(unicode.contains("┐"))
}

///|
test "ASCII flowchart renders nested subgraph labels" {
  let diagram =
    #|graph TD
    #|subgraph Outer
    #|subgraph Inner
    #|A --> B
    #|end
    #|C --> D
    #|end
  let output = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 2,
    padding_y: 2,
    box_border_padding: 1,
  })

  assert_true(output.contains("Outer"))
  assert_true(output.contains("Inner"))
}

///|
test "ASCII preserves class operators for class diagrams" {
  let diagram =
    #|classDiagram
    #|A <|-- B : inherits
    #|C *-- D : owns
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("+"))
  assert_true(ascii.contains("herit"))
  assert_true(ascii.contains("owns"))
  assert_true(ascii.contains("^"))
  assert_true(ascii.contains("*"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("┌───┐"))
  assert_true(unicode.contains("herit"))
  assert_true(unicode.contains("owns"))
  assert_true(unicode.contains("△"))
  assert_true(unicode.contains("◆"))
}

///|
test "ASCII preserves ER operator semantics" {
  let diagram =
    #|erDiagram
    #|CUSTOMER ||--o{ ORDER : places
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("||--o{"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("║───o╟"))
}

///|
test "ASCII state text renderer hides synthetic pseudostate ids in boxed mode" {
  let diagram =
    #|stateDiagram-v2
    #|[*] --> Idle
    #|Idle --> [*]
  let ascii = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(ascii.contains("Idle"))
  assert_true(!ascii.contains("state_start_"))
  assert_true(!ascii.contains("state_end_"))
  assert_true(ascii.contains("+"))

  let unicode = @beautiful_mermaid.render_mermaid_ascii(diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(unicode.contains("Idle"))
  assert_true(!unicode.contains("state_start_"))
  assert_true(!unicode.contains("state_end_"))
  assert_true(unicode.contains("┌"))
}
