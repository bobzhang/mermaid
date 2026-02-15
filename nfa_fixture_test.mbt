///|
fn nfa_lock_options(use_ascii : Bool) -> @beautiful_mermaid.AsciiRenderOptions {
  { use_ascii, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
fn inspect_nfa_ascii_and_unicode(input : String) -> String raise {
  let ascii = @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=nfa_lock_options(true),
  )
  let unicode = @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=nfa_lock_options(false),
  )
  (
    #|# ASCII
    #|
  ) +
  ascii +
  (
    #|
    #|
    #|# UNICODE
    #|
  ) +
  unicode
}

///|
fn nfa_fixture_001_source() -> String {
  let source =
    #|graph LR
    #|0@{shape: circ}
    #|1@{shape: circ}
    #|2@{shape: circ}
    #|3@{shape: circ}
    #|4@{shape: circ}
    #|5@{shape: circ}
    #|start@{shape: f-circ} --- 0
    #|0 -- [a-b] --> 3
    #|1 -- c --> 2
    #|2 -- d --> 4
    #|3 -.-> 1
    #|3 -.-> 4
    #|4 -.-> 0
    #|4 -.-> 5
    #|5 --- #0@{shape: dbl-circ}
  source
}

///|
fn nfa_fixture_003_source() -> String {
  let source =
    #|graph LR
    #|0@{shape: circ}
    #|1@{shape: circ}
    #|2@{shape: circ}
    #|3@{shape: circ}
    #|4@{shape: circ}
    #|5@{shape: circ}
    #|6@{shape: circ}
    #|7@{shape: circ}
    #|8@{shape: circ}
    #|start@{shape: f-circ} --- 8
    #|0 -- A --> 1
    #|1 -- B --> 2
    #|2 -- C --> 3
    #|3 --- #0@{shape: dbl-circ}
    #|4 -- A --> 5
    #|5 -- B --> 6
    #|6 -- C --> 7
    #|7 --- #1@{shape: dbl-circ}
    #|8 -.-> 0
    #|8 -.-> 4
  source
}

///|
fn nfa_find_positioned_node(
  nodes : Array[@model.PositionedNode],
  node_id : String,
) -> @model.PositionedNode raise {
  for node in nodes {
    if node.id == node_id {
      return node
    }
  }
  fail("missing positioned node \{node_id}")
}

///|
test "NFA fixture 001: basic automaton with epsilon transitions" (
  it : @test.Test,
) {
  let output = inspect_nfa_ascii_and_unicode(nfa_fixture_001_source())
  it.write(output)
  it.snapshot(filename="nfa_001_ascii_unicode.txt")
}

///|
test "NFA fixture 003: parallel paths with shared alphabet" (it : @test.Test) {
  let output = inspect_nfa_ascii_and_unicode(nfa_fixture_003_source())
  it.write(output)
  it.snapshot(filename="nfa_003_ascii_unicode.txt")
}

///|
test "NFA fixture 001: SVG renders all nodes and edges" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(nfa_fixture_001_source())
  it.write(svg)
  it.snapshot(filename="nfa_001_svg.svg")
}

///|
test "NFA fixture 003: SVG renders all nodes and edges" (it : @test.Test) {
  let svg = @beautiful_mermaid.render_mermaid(nfa_fixture_003_source())
  it.write(svg)
  it.snapshot(filename="nfa_003_svg.svg")
}

///|
test "NFA fixture 001: layout places start before first state" {
  let graph = @parser_header_core.parse_mermaid(nfa_fixture_001_source())
  let positioned = @layout.layout_graph(graph, @model.RenderOptions::default())
  let start = nfa_find_positioned_node(positioned.nodes, "start")
  let q0 = nfa_find_positioned_node(positioned.nodes, "0")
  assert_true(start.x < q0.x)
}
