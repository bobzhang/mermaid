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
test "SVG renders flowchart subgraph containers" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Backend\nA --> B\nend",
  )

  assert_true(svg.contains("class=\"group-outer\""))
  assert_true(svg.contains("class=\"group-header\""))
  assert_true(svg.contains("class=\"group-label\""))
  assert_true(svg.contains(">Backend</text>"))
}

///|
test "SVG renders nested flowchart subgraph containers" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Outer\nsubgraph Inner\nA --> B\nend\nC --> D\nend",
  )

  let group_count = @test_support.count_occurrences(
    svg, "class=\"group-outer\"",
  )
  assert_true(group_count >= 2)
  assert_true(svg.contains(">Outer</text>"))
  assert_true(svg.contains(">Inner</text>"))
}

///|
test "SVG renders nested empty subgraph labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Outer\nsubgraph Inner\nend\nA --> B\nend",
  )

  assert_true(svg.contains(">Outer</text>"))
  assert_true(svg.contains(">Inner</text>"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
}

///|
test "SVG renders empty subgraph without crashing" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph Empty\nend\nA --> B",
  )

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Empty</text>"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
}

///|
test "SVG renders edges targeting an empty subgraph without id-dup node label" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nsubgraph S [Empty Group]\nend\nA --> S\nS --> B",
  )

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Empty Group</text>"))
  assert_true(svg.contains(">A</text>"))
  assert_true(svg.contains(">B</text>"))
  assert_eq(@test_support.count_occurrences(svg, ">S</text>"), 0)
}

///|
test "SVG applies classDef and style overrides" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[Start]:::entry --> B[End]\nclassDef entry fill:#f9f,stroke:#333,color:#111\nstyle A stroke:#000,color:#fff",
  )

  assert_true(svg.contains("fill=\"#f9f\""))
  assert_true(svg.contains("stroke=\"#000\""))
  assert_true(!svg.contains("stroke=\"#333\""))
  assert_true(svg.contains("fill=\"#fff\""))
}

///|
test "SVG flowchart no-arrow edges render without arrowhead markers" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA --- B")

  assert_true(svg.contains("<polyline"))
  assert_true(!svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(!svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "SVG flowchart bidirectional arrows render both markers" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA <--> B")

  assert_true(svg.contains("marker-end=\"url(#arrowhead)\""))
  assert_true(svg.contains("marker-start=\"url(#arrowhead-start)\""))
}

///|
test "SVG flowchart renders self-loop edge" {
  let svg = try! @beautiful_mermaid.render_mermaid("graph TD\nA[Node] --> A")

  assert_true(svg.contains("<svg"))
  assert_true(svg.contains(">Node</text>"))
  assert_true(svg.contains("<polyline"))
}

///|
test "SVG flowchart renders self-loop edge with label" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "graph TD\nA[Retry] -->|again| A",
  )

  assert_true(svg.contains(">Retry</text>"))
  assert_true(svg.contains(">again</text>"))
}

///|
test "SVG renders multiline class labels from parser details" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Animal {\n  +String name\n  +eat() void\n}",
  )

  assert_true(svg.contains("class=\"node-header\""))
  assert_true(svg.contains("class=\"class-row\""))
  assert_true(svg.contains(">Animal</text>"))
  assert_true(svg.contains(">+name: String</text>"))
  assert_true(svg.contains(">+eat: void</text>"))
}

///|
test "SVG class renders annotations and members" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Flyable {\n  <<interface>>\n  +fly() void\n}",
  )

  assert_true(svg.contains("&lt;&lt;interface&gt;&gt;"))
  assert_true(svg.contains(">Flyable</text>"))
  assert_true(svg.contains(">+fly: void</text>"))
}

///|
test "SVG class dependency uses dashed line and arrow marker" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nService ..> Repository",
  )

  assert_true(svg.contains("stroke-dasharray=\"6 4\""))
  assert_true(svg.contains("marker-end=\"url(#class-arrow)\""))
}

///|
test "SVG class realization uses dashed line and inherit marker" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nService ..|> Contract : realizes",
  )

  assert_true(svg.contains("stroke-dasharray=\"6 4\""))
  assert_true(svg.contains("marker-end=\"url(#class-inherit)\""))
  assert_true(svg.contains(">realizes</text>"))
}

///|
test "SVG class marker defs match upstream geometry" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nA <|-- B\nC *-- D\nE o-- F\nG --> H\nI ..> J\n",
  )

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
test "SVG class entities include compartment divider lines" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Animal {\n  +String name\n  +eat() void\n}",
  )

  let divider_count = @test_support.count_occurrences(
    svg, "class=\"node-divider\"",
  )
  assert_true(divider_count >= 1)
}

///|
test "SVG class renders complete hierarchy with abstract annotation" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nclass Animal {\n  <<abstract>>\n  +String name\n  +eat() void\n}\nclass Dog {\n  +String breed\n  +bark() void\n}\nclass Cat {\n  +bool isIndoor\n  +meow() void\n}\nAnimal <|-- Dog\nAnimal <|-- Cat",
  )

  assert_true(svg.contains(">Animal</text>"))
  assert_true(svg.contains(">Dog</text>"))
  assert_true(svg.contains(">Cat</text>"))
  assert_true(svg.contains("&lt;&lt;abstract&gt;&gt;"))
}

///|
test "SVG class supports explicit dark colors" {
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

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}

///|
test "SVG sequence renders lifelines and message labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nAlice->>Bob: Hello Bob\nBob-->>Alice: Hi Alice",
  )

  assert_true(svg.contains("class=\"lifeline\""))
  assert_true(svg.contains(">Hello Bob</text>"))
  assert_true(svg.contains(">Hi Alice</text>"))
}

///|
test "SVG sequence renders participant declarations and aliases" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A as Alice\nparticipant B as Bob\nA->>B: Message",
  )

  assert_true(svg.contains(">Alice</text>"))
  assert_true(svg.contains(">Bob</text>"))
  assert_true(svg.contains(">Message</text>"))
}

///|
test "SVG sequence maps open and filled arrow markers" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->B: Open\nB--)A: Dotted Open\nA-->>B: Filled",
  )

  assert_true(svg.contains("id=\"seq-arrow\""))
  assert_true(svg.contains("id=\"seq-arrow-open\""))
  assert_true(svg.contains("marker-end=\"url(#seq-arrow-open)\""))
  assert_true(svg.contains("marker-end=\"url(#seq-arrow)\""))
}

///|
test "SVG sequence dashed returns include dashed stroke segments" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Request\nB-->>A: Response",
  )

  assert_true(svg.contains(">Request</text>"))
  assert_true(svg.contains(">Response</text>"))
  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
}

///|
test "SVG sequence renders blocks, dividers, and notes" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Request\nalt Success\nB-->>A: 200\nelse Failure\nB-->>A: 500\nend\nNote right of B: Inspect response",
  )

  assert_true(svg.contains("class=\"sequence-block\""))
  assert_true(svg.contains(">alt [Success]</text>"))
  assert_true(svg.contains(">[Failure]</text>"))
  assert_true(svg.contains("class=\"sequence-note\""))
  assert_true(svg.contains(">Inspect response</text>"))
}

///|
test "SVG sequence renders loop block labels" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nA->>B: Start\nloop Every 5s\nA->>B: Ping\nend",
  )

  assert_true(svg.contains("class=\"sequence-block\""))
  assert_true(svg.contains(">loop [Every 5s]</text>"))
}

///|
test "SVG sequence renders activation bars and actor icons" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nactor U as User\nparticipant S as Server\nU->>+S: Request\nS-->>-U: Response",
  )

  assert_true(svg.contains("class=\"sequence-activation\""))
  assert_true(svg.contains("class=\"sequence-actor\""))
}

///|
test "SVG sequence ignores standalone activation commands" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A\nparticipant B\nactivate A\nA->>B: Work\ndeactivate A",
  )

  assert_true(!svg.contains("class=\"sequence-activation\""))
  assert_true(svg.contains(">Work</text>"))
}

///|
test "SVG sequence ignores standalone activation commands for self messages" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A\nactivate A\nA->>A: Think\ndeactivate A",
  )

  assert_true(!svg.contains("class=\"sequence-activation\""))
  assert_true(svg.contains(">Think</text>"))
}

///|
test "SVG sequence lifeline count follows participant count" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant A\nparticipant B\nA->>B: Hello",
  )

  let lifeline_count = @test_support.count_occurrences(
    svg, "class=\"lifeline\"",
  )
  assert_true(lifeline_count >= 2)
}

///|
test "SVG sequence renders complex authentication flow content" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "sequenceDiagram\nparticipant C as Client\nparticipant S as Server\nparticipant DB as Database\nC->>S: POST /login\nS->>DB: SELECT user\nalt User found\nDB-->>S: User record\nS-->>C: 200 OK + token\nelse Not found\nDB-->>S: null\nS-->>C: 401 Unauthorized\nend",
  )

  assert_true(svg.contains(">Client</text>"))
  assert_true(svg.contains(">Server</text>"))
  assert_true(svg.contains(">Database</text>"))
  assert_true(svg.contains(">POST /login</text>"))
  assert_true(svg.contains(">200 OK + token</text>"))
}

///|
test "SVG sequence supports explicit dark colors" {
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

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}

///|
test "SVG class relations render semantic markers" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "classDiagram\nA <|-- B : inherits\nC *-- D : owns\nE o-- F : has\nG ..> H : depends",
  )

  assert_true(svg.contains("marker-start=\"url(#class-inherit)\""))
  assert_true(svg.contains("marker-start=\"url(#class-composition)\""))
  assert_true(svg.contains("marker-start=\"url(#class-aggregation)\""))
  assert_true(svg.contains("marker-end=\"url(#class-arrow)\""))
}

///|
test "SVG ER relations render endpoint cardinality tokens" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nCUSTOMER ||--o{ ORDER : places",
  )

  assert_true(svg.contains("class=\"edge-endpoint\""))
  assert_true(svg.contains(">||</text>"))
  assert_true(svg.contains(">o{</text>"))
}

///|
test "SVG ER renders entity attributes with key tokens" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nCUSTOMER {\n  int id PK\n  string name\n  string email UK\n}",
  )

  assert_true(svg.contains(">CUSTOMER</text>"))
  assert_true(svg.contains("id"))
  assert_true(svg.contains("name"))
  assert_true(svg.contains("email"))
  assert_true(svg.contains("PK"))
  assert_true(svg.contains("UK"))
}

///|
test "SVG ER renders relationship polyline and label" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nA ||--o{ B : has",
  )

  assert_true(svg.contains("<polyline"))
  assert_true(svg.contains(">has</text>"))
}

///|
test "SVG ER non-identifying relations are dashed" {
  let svg = try! @beautiful_mermaid.render_mermaid(
    "erDiagram\nUSER ||..o{ LOG : generates",
  )

  assert_true(svg.contains("stroke-dasharray=\"4 4\""))
  assert_true(svg.contains(">generates</text>"))
}

///|
test "SVG ER supports explicit dark colors" {
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

  assert_true(svg.contains("--bg:#18181B"))
  assert_true(svg.contains("--fg:#FAFAFA"))
}
