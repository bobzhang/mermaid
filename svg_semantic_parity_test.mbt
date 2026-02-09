///|
test "SVG semantic parity gate cases" {
  for case_data in @test_support.gate_cases() {
    let svg = try! @beautiful_mermaid.render_mermaid(case_data.input)
    assert_true(
      @test_support.contains_all(svg, case_data.expected_svg_fragments),
    )
    assert_true(svg.has_prefix("<svg "))
    assert_true(svg.has_suffix("</svg>"))
  }
}

///|
fn snapshot_semantic_svg(
  it : @test.Test,
  filename : String,
  svg : String,
) -> Unit raise {
  it.write(svg)
  it.snapshot(filename~)
}

///|
test "SVG renders flowchart subgraph containers" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Backend\nA --> B\nend",
  )
  snapshot_semantic_svg(it, "semantic_flowchart_subgraph_containers.svg", svg)

  assert_true(svg.contains("class=\"group-outer\""))
  assert_true(svg.contains("class=\"group-header\""))
  assert_true(svg.contains("class=\"group-label\""))
  assert_true(svg.contains(">Backend</text>"))
}

///|
test "SVG renders nested flowchart subgraph containers" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Outer\nsubgraph Inner\nA --> B\nend\nC --> D\nend",
  )
  snapshot_semantic_svg(
    it, "semantic_flowchart_nested_subgraph_containers.svg", svg,
  )

  let group_count = @test_support.count_occurrences(
    svg, "class=\"group-outer\"",
  )
  assert_true(group_count >= 2)
  assert_true(svg.contains(">Outer</text>"))
  assert_true(svg.contains(">Inner</text>"))
}

///|
test "SVG renders nested empty subgraph labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Outer\nsubgraph Inner\nend\nA --> B\nend",
  )
  snapshot_semantic_svg(
    it, "semantic_flowchart_nested_empty_subgraph_labels.svg", svg,
  )

  assert_true(svg.contains(">Outer</text>"))
  assert_true(svg.contains(">Inner</text>"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
}

///|
test "SVG renders empty subgraph without crashing" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Empty\nend\nA --> B",
  )
  snapshot_semantic_svg(it, "semantic_flowchart_empty_subgraph.svg", svg)

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Empty</text>"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
}

///|
test "SVG renders edges targeting an empty subgraph without id-dup node label" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph S [Empty Group]\nend\nA --> S\nS --> B",
  )
  snapshot_semantic_svg(
    it, "semantic_flowchart_empty_subgraph_edge_target.svg", svg,
  )

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Empty Group</text>"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
  assert_eq(@test_support.count_occurrences(svg, ">S</text>"), 0)
}

///|
test "SVG applies classDef and style overrides" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[Start]:::entry --> B[End]\nclassDef entry fill:#f9f,stroke:#333,color:#111\nstyle A stroke:#000,color:#fff",
  )
  snapshot_semantic_svg(it, "semantic_flowchart_classdef_style.svg", svg)

  assert_true(svg.contains("fill=\"#f9f\""))
  assert_true(svg.contains("stroke=\"#000\""))
  assert_true(!svg.contains("stroke=\"#333\""))
  assert_true(svg.contains("fill=\"#fff\""))
}

///|
test "SVG flowchart no-arrow edges render without arrowhead markers" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --- B")
  snapshot_semantic_svg(it, "semantic_flowchart_no_arrow.svg", svg)

  assert_true(svg.contains("<polyline"))
  assert_true(!svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(!svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "SVG flowchart bidirectional arrows render both markers" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA <--> B")
  snapshot_semantic_svg(it, "semantic_flowchart_bidirectional.svg", svg)

  assert_true(svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "SVG flowchart renders self-loop edge" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA[Node] --> A")
  snapshot_semantic_svg(it, "semantic_flowchart_self_loop.svg", svg)

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Node</text>"))
  assert_true(svg.contains("<polyline"))
}

///|
test "SVG flowchart renders self-loop edge with label" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[Retry] -->|again| A",
  )
  snapshot_semantic_svg(it, "semantic_flowchart_self_loop_label.svg", svg)

  assert_true(svg.contains(">Retry</text>"))
  assert_true(svg.contains(">again</text>"))
}

///|
test "SVG renders multiline class labels from parser details" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Animal {\n  +String name\n  +eat() void\n}",
  )
  snapshot_semantic_svg(it, "semantic_class_multiline_labels.svg", svg)

  assert_true(svg.contains("class=\"node-header\""))
  assert_true(svg.contains("class=\"class-row\""))
  assert_true(svg.contains(">Animal</text>"))
  assert_true(svg.contains(">+name: String</text>"))
  assert_true(svg.contains(">+eat: void ()</text>"))
}

///|
test "SVG class renders annotations and members" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Flyable {\n  <<interface>>\n  +fly() void\n}",
  )
  snapshot_semantic_svg(it, "semantic_class_annotations_members.svg", svg)

  assert_true(svg.contains("&lt;&lt;interface&gt;&gt;"))
  assert_true(svg.contains(">Flyable</text>"))
  assert_true(svg.contains(">+fly: void ()</text>"))
}

///|
test "SVG class dependency uses dashed line and arrow marker" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nService ..> Repository",
  )
  snapshot_semantic_svg(it, "semantic_class_dependency.svg", svg)

  assert_true(svg.contains("stroke-dasharray=\"6 4\""))
  assert_true(svg.contains("marker-end=\"url(#class-arrow)\""))
}

///|
test "SVG class realization uses dashed line and inherit marker" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nService ..|> Contract : realizes",
  )
  snapshot_semantic_svg(it, "semantic_class_realization.svg", svg)

  assert_true(svg.contains("stroke-dasharray=\"6 4\""))
  assert_true(svg.contains("marker-end=\"url(#class-inherit)\""))
  assert_true(svg.contains(">realizes</text>"))
}

///|
test "SVG class marker defs match upstream geometry" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nA <|-- B\nC *-- D\nE o-- F\nG --> H\nI ..> J\n",
  )
  snapshot_semantic_svg(it, "semantic_class_marker_defs.svg", svg)

  assert_true(
    svg.contains(
      "id=\"class-inherit\" markerWidth=\"12\" markerHeight=\"10\" refX=\"12\" refY=\"5\"",
    ),
  )
  assert_true(
    svg.contains(
      "id=\"class-composition\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\"",
    ),
  )
  assert_true(
    svg.contains(
      "id=\"class-aggregation\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\"",
    ),
  )
  assert_true(
    svg.contains(
      "id=\"class-arrow\" markerWidth=\"8\" markerHeight=\"6\" refX=\"8\" refY=\"3\"",
    ),
  )
  assert_true(svg.contains("stroke-width=\"1.5\""))
}

///|
test "SVG class entities include compartment divider lines" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Animal {\n  +String name\n  +eat() void\n}",
  )
  snapshot_semantic_svg(it, "semantic_class_compartment_dividers.svg", svg)

  let divider_count = @test_support.count_occurrences(
    svg, "class=\"node-divider\"",
  )
  assert_true(divider_count >= 1)
}

///|
test "SVG class renders complete hierarchy with abstract annotation" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Animal {\n  <<abstract>>\n  +String name\n  +eat() void\n}\nclass Dog {\n  +String breed\n  +bark() void\n}\nclass Cat {\n  +bool isIndoor\n  +meow() void\n}\nAnimal <|-- Dog\nAnimal <|-- Cat",
  )
  snapshot_semantic_svg(it, "semantic_class_complete_hierarchy.svg", svg)

  assert_true(svg.contains(">Animal</text>"))
  assert_true(svg.contains(">Dog</text>"))
  assert_true(svg.contains(">Cat</text>"))
  assert_true(svg.contains("&lt;&lt;abstract&gt;&gt;"))
}

///|
test "SVG class supports explicit dark colors" (it : @test.Test) {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass A {\n  +x int\n}",
    options~,
  )
  snapshot_semantic_svg(it, "semantic_class_dark_colors.svg", svg)

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}

///|
test "SVG render options include provided enrichment CSS vars" (it : @test.Test) {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#111111"),
    fg: Some("#eeeeee"),
    line: Some("#123456"),
    accent: Some("#234567"),
    muted: Some("#345678"),
    surface: Some("#456789"),
    border: Some("#56789a"),
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options~,
  )
  snapshot_semantic_svg(it, "semantic_render_options_enriched.svg", svg)

  assert_true(svg.contains("--bg:#111111"))
  assert_true(svg.contains("--fg:#eeeeee"))
  assert_true(svg.contains("--line:#123456"))
  assert_true(svg.contains("--accent:#234567"))
  assert_true(svg.contains("--muted:#345678"))
  assert_true(svg.contains("--surface:#456789"))
  assert_true(svg.contains("--border:#56789a"))
}

///|
test "SVG render options omit enrichment CSS vars when unset" (it : @test.Test) {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options~,
  )
  snapshot_semantic_svg(it, "semantic_render_options_unset.svg", svg)

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
  assert_true(!svg.contains("--line:"))
  assert_true(!svg.contains("--accent:"))
  assert_true(!svg.contains("--muted:"))
  assert_true(!svg.contains("--surface:"))
  assert_true(!svg.contains("--border:"))
}

///|
test "SVG transparent render option omits root background style and rect" (
  it : @test.Test,
) {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: Some(true),
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA --> B",
    options~,
  )
  snapshot_semantic_svg(it, "semantic_render_options_transparent.svg", svg)

  assert_true(!svg.contains("background:var(--bg)"))
  assert_true(!svg.contains("<rect width=\""))
}

///|
test "SVG sequence renders lifelines and message labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nAlice->>Bob: Hello Bob\nBob-->>Alice: Hi Alice",
  )
  snapshot_semantic_svg(it, "semantic_sequence_lifelines_messages.svg", svg)

  assert_true(svg.contains("class=\"lifeline\""))
  assert_true(svg.contains(">Hello Bob</text>"))
  assert_true(svg.contains(">Hi Alice</text>"))
}

///|
test "SVG sequence renders participant declarations and aliases" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A as Alice\nparticipant B as Bob\nA->>B: Message",
  )
  snapshot_semantic_svg(it, "semantic_sequence_participants_aliases.svg", svg)

  assert_true(svg.contains(">Alice</text>"))
  assert_true(svg.contains(">Bob</text>"))
  assert_true(svg.contains(">Message</text>"))
}

///|
test "SVG sequence maps open and filled arrow markers" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->B: Open\nB--)A: Dotted Open\nA-->>B: Filled",
  )
  snapshot_semantic_svg(it, "semantic_sequence_open_filled_markers.svg", svg)

  assert_true(svg.contains("id=\"seq-arrow\""))
  assert_true(svg.contains("id=\"seq-arrow-open\""))
  assert_true(svg.contains("marker-end=\"url(#seq-arrow-open)\""))
  assert_true(svg.contains("marker-end=\"url(#seq-arrow)\""))
}

///|
test "SVG sequence dashed returns include dashed stroke segments" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Request\nB-->>A: Response",
  )
  snapshot_semantic_svg(it, "semantic_sequence_dashed_returns.svg", svg)

  assert_true(svg.contains(">Request</text>"))
  assert_true(svg.contains(">Response</text>"))
  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
}

///|
test "SVG sequence renders blocks, dividers, and notes" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Request\nalt Success\nB-->>A: 200\nelse Failure\nB-->>A: 500\nend\nNote right of B: Inspect response",
  )
  snapshot_semantic_svg(it, "semantic_sequence_blocks_dividers_notes.svg", svg)

  assert_true(svg.contains("class=\"sequence-block\""))
  assert_true(svg.contains(">alt [Success]</text>"))
  assert_true(svg.contains(">[Failure]</text>"))
  assert_true(svg.contains("class=\"sequence-note\""))
  assert_true(svg.contains(">Inspect response</text>"))
}

///|
test "SVG sequence renders loop block labels" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Start\nloop Every 5s\nA->>B: Ping\nend",
  )
  snapshot_semantic_svg(it, "semantic_sequence_loop_block_labels.svg", svg)

  assert_true(svg.contains("class=\"sequence-block\""))
  assert_true(svg.contains(">loop [Every 5s]</text>"))
}

///|
test "SVG sequence renders activation bars and actor icons" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nactor U as User\nparticipant S as Server\nU->>+S: Request\nS-->>-U: Response",
  )
  snapshot_semantic_svg(it, "semantic_sequence_activation_actor_icons.svg", svg)

  assert_true(svg.contains("class=\"sequence-activation\""))
  assert_true(svg.contains("class=\"sequence-actor\""))
}

///|
test "SVG sequence ignores standalone activation commands" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A\nparticipant B\nactivate A\nA->>B: Work\ndeactivate A",
  )
  snapshot_semantic_svg(
    it, "semantic_sequence_ignore_standalone_activation.svg", svg,
  )

  assert_true(!svg.contains("class=\"sequence-activation\""))
  assert_true(svg.contains(">Work</text>"))
}

///|
test "SVG sequence ignores standalone activation commands for self messages" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A\nactivate A\nA->>A: Think\ndeactivate A",
  )
  snapshot_semantic_svg(
    it, "semantic_sequence_ignore_standalone_activation_self.svg", svg,
  )

  assert_true(!svg.contains("class=\"sequence-activation\""))
  assert_true(svg.contains(">Think</text>"))
}

///|
test "SVG sequence lifeline count follows participant count" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A\nparticipant B\nA->>B: Hello",
  )
  snapshot_semantic_svg(it, "semantic_sequence_lifeline_count.svg", svg)

  let lifeline_count = @test_support.count_occurrences(
    svg, "class=\"lifeline\"",
  )
  assert_true(lifeline_count >= 2)
}

///|
test "SVG sequence renders complex authentication flow content" (
  it : @test.Test,
) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant C as Client\nparticipant S as Server\nparticipant DB as Database\nC->>S: POST /login\nS->>DB: SELECT user\nalt User found\nDB-->>S: User record\nS-->>C: 200 OK + token\nelse Not found\nDB-->>S: null\nS-->>C: 401 Unauthorized\nend",
  )
  snapshot_semantic_svg(it, "semantic_sequence_complex_auth_flow.svg", svg)

  assert_true(svg.contains(">Client</text>"))
  assert_true(svg.contains(">Server</text>"))
  assert_true(svg.contains(">Database</text>"))
  assert_true(svg.contains(">POST /login</text>"))
  assert_true(svg.contains(">200 OK + token</text>"))
}

///|
test "SVG sequence supports explicit dark colors" (it : @test.Test) {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Hello",
    options~,
  )
  snapshot_semantic_svg(it, "semantic_sequence_dark_colors.svg", svg)

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}

///|
test "SVG class relations render semantic markers" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nA <|-- B : inherits\nC *-- D : owns\nE o-- F : has\nG ..> H : depends",
  )
  snapshot_semantic_svg(it, "semantic_class_relations_markers.svg", svg)

  assert_true(svg.contains("marker-start=\"url(#class-inherit)\""))
  assert_true(svg.contains("marker-start=\"url(#class-composition)\""))
  assert_true(svg.contains("marker-start=\"url(#class-aggregation)\""))
  assert_true(svg.contains("marker-end=\"url(#class-arrow)\""))
}

///|
test "SVG ER relations render endpoint cardinality tokens" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nCUSTOMER ||--o{ ORDER : places",
  )
  snapshot_semantic_svg(it, "semantic_er_relations_cardinality_tokens.svg", svg)

  assert_true(svg.contains("class=\"edge-endpoint\""))
  assert_true(svg.contains(">||</text>"))
  assert_true(svg.contains(">o{</text>"))
}

///|
test "SVG ER renders entity attributes with key tokens" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nCUSTOMER {\n  int id PK\n  string name\n  string email UK\n}",
  )
  snapshot_semantic_svg(it, "semantic_er_entity_attributes_keys.svg", svg)

  assert_true(svg.contains(">CUSTOMER</text>"))
  assert_true(svg.contains("id"))
  assert_true(svg.contains("name"))
  assert_true(svg.contains("email"))
  assert_true(svg.contains("PK"))
  assert_true(svg.contains("UK"))
}

///|
test "SVG ER renders relationship polyline and label" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nA ||--o{ B : has",
  )
  snapshot_semantic_svg(it, "semantic_er_relationship_polyline_label.svg", svg)

  assert_true(svg.contains("<polyline"))
  assert_true(svg.contains(">has</text>"))
}

///|
test "SVG ER non-identifying relations are dashed" (it : @test.Test) {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nUSER ||..o{ LOG : generates",
  )
  snapshot_semantic_svg(it, "semantic_er_nonidentifying_dashed.svg", svg)

  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
  assert_true(svg.contains(">generates</text>"))
}

///|
test "SVG ER supports explicit dark colors" (it : @test.Test) {
  let options = @beautiful_mermaid.RenderOptions::{
    bg: Some("#18181B"),
    fg: Some("#FAFAFA"),
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: None,
  }
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nA ||--|| B : links",
    options~,
  )
  snapshot_semantic_svg(it, "semantic_er_dark_colors.svg", svg)

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}
