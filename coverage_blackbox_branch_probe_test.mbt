///|
fn branch_probe_ascii_options(seed : Int) -> @model.AsciiRenderOptions {
  {
    use_ascii: seed % 2 == 0,
    padding_x: [0, 1, 3, 5, -1][seed % 5],
    padding_y: [0, 1, 3, 5, -1][seed / 2 % 5],
    box_border_padding: [0, 1, 2][seed % 3],
  }
}

///|
fn branch_probe_svg_options(seed : Int) -> @model.RenderOptions {
  {
    bg: if seed % 3 == 0 {
      Some("#0f172a")
    } else {
      None
    },
    fg: if seed % 3 == 0 {
      Some("#e2e8f0")
    } else {
      None
    },
    line: if seed % 4 == 0 {
      Some("#64748b")
    } else {
      None
    },
    accent: if seed % 5 == 0 {
      Some("#38bdf8")
    } else {
      None
    },
    muted: None,
    surface: None,
    border: None,
    font: [
      Some("Inter"),
      Some("Cafeé Mono"),
      Some("漢字 Font"),
      Some("Emoji 😀 Font"),
      None,
    ][seed % 5],
    padding: [Some(0), Some(4), Some(8), Some(16), None][seed % 5],
    node_spacing: [Some(2), Some(8), Some(16), None][seed / 2 % 4],
    layer_spacing: [Some(2), Some(8), Some(16), None][seed / 3 % 4],
    transparent: if seed % 2 == 0 {
      Some(false)
    } else {
      Some(true)
    },
    layout_engine: None,
  }
}

///|
fn branch_probe_exercise_case(input : String, seed : Int) -> (Bool, Bool, Bool) {
  let parsed : Result[@model.MermaidGraph, @model.MermaidError] = try? @parser_header_core.parse_mermaid(
    input,
  )
  match parsed {
    Ok(_) => {
      let ascii_result : Result[String, @model.MermaidError] = try? @beautiful_mermaid.render_mermaid_ascii(
        input,
        options=branch_probe_ascii_options(seed),
      )
      let ascii_ok = match ascii_result {
        Ok(ascii) => {
          ignore(ascii.length())
          true
        }
        Err(_) => false
      }
      let svg_result : Result[String, @model.MermaidError] = try? @beautiful_mermaid.render_mermaid(
        input,
        options=branch_probe_svg_options(seed),
      )
      let svg_ok = match svg_result {
        Ok(svg) => svg.has_prefix("<svg ") && svg.has_suffix("</svg>")
        Err(_) => false
      }
      (true, ascii_ok, svg_ok)
    }
    Err(_) => (false, false, false)
  }
}

///|
fn branch_probe_inputs() -> Array[String] {
  [
    (
      #|graph TD
      #|  A[] --> B[Beta]
      #|  B -.->|dotted| C{Choose}
      #|  C ==> D[[Worker]]
      #|  D -->|ok| E((Done))
      #|  E --> A
      #|graph LR
      #|  A -->|left| B
      #|  B -->|right| A
      #|  A <-->|both| C
      #|  C <-.->|dot| B
      #|graph TD
      #|  end
      #|  subgraph !!!
      #|    A --> B
      #|  end
      #|  subgraph bad$id[Bad Id]
      #|    direction LR
      #|    B --> C
      #|  end
      #|  A -->|broken C
      #|graph TD
      #|  A["x&y"] & B['u&v'] & --> C
      #|  classDef warn fill:#fff,,stroke:#333,noColon
      #|  classDef onlyName
      #|  style A fill:#eee,,stroke:#111,noColon
      #|  A::: --> C
      #|  class A
      #|  class ,warn warn
      #|graph BT
      #|  S([Start]) --> T{{Hex}}
      #|  T --> U[/Trap\]
      #|  U --> V[\Trap/]
      #|  V --> W>Asym]
      #|graph RL
      #|  L1 --- L2
      #|  L2 -.- L3
      #|  L3 === L4
      #|graph TD
      #|  subgraph Outer
      #|    direction LR
      #|    A --> B
      #|    subgraph Inner
      #|      C --> D
      #|    end
      #|  end
      #|  B --> C
      #|stateDiagram-v2
      #|  [*] --> Idle
      #|  Idle --> Active
      #|  Active --> Waiting
      #|  Waiting --> Active
      #|  Active --> [*]
      #|stateDiagram-v2
      #|  }
      #|  {
      #|  state Idle
      #|  Idle --> Working
      #|  Working --> [*]
      #|stateDiagram-v2
      #|  [*] --> Idle
      #|  state Processing {
      #|    direction LR
      #|    Parse --> Validate
      #|    Validate --> Execute
      #|  }
      #|  Idle --> Processing : start
      #|  Processing --> Idle : back
      #|  Processing --> [*]
      #|stateDiagram-v2
      #|  A -->
      #|  A : description
      #|  : invalid-description
      #|  A --> [*]
      #|sequenceDiagram
      #|  participant Client as
      #|  participant
      #|  actor Ops as Operator
      #|  Client->>Server
      #|  ->>Client: no source
      #|  Server->>: no target
      #|  Note middle of Client: unknown placement
      #|  Note over Client
      #|  autonumber
      #|  Client--)Server: dotted open
      #|  Server-xClient: stop
      #|  Client->>+Server: activate
      #|  Server-->>-Client: deactivate
      #|  alt branch
      #|  else other
      #|  end
      #|sequenceDiagram
      #|  participant A
      #|  participant B
      #|  alt only
      #|  end
      #|  par left
      #|  and right
      #|  end
      #|  loop
      #|  end
      #|  A->>A
      #|  A->>B: done
      #|sequenceDiagram
      #|  A->>B: first
      #|  B-->>A: second
      #|  Note left of A: left
      #|  Note right of B: right
      #|  Note over A,B: over
      #|classDiagram
      #|  class  {
      #|  class {}
      #|  class Empty {}
      #|  class Foo }
      #|  class A {
      #|    +
      #|    ()
      #|    +run()
      #|    +run() void
      #|    String name
      #|  }
      #|  class B {
      #|    <<interface>>
      #|  }
      #|  A <|-- B : inherit
      #|  B --|> C : reverse_inherit
      #|  C ..|> D : realize
      #|  D --> E : assoc
      #|  E <-- F : assoc_left
      #|  F ..> G : dep
      #|  G --* H : comp
      #|  H --o I : aggr
      #|  I =-- J : thickish
      #|  J -.- K : dottedish
      #|classDiagram
      #|  class Plain
      #|  Plain :
      #|  Plain : +String title
      #|  Plain : +run()
      #|  Service "0..1" ..> "1..*" Repository : depends
      #|erDiagram
      #|  {
      #|  USER {
      #|    id
      #|    string email UK "contact & primary"
      #|  }
      #|  PROFILE {
      #|    int user_id FK
      #|  }
      #|  USER ||--o{ PROFILE : owns
      #|  PROFILE |o..|| AVATAR : maybe
      #|  AVATAR }|--o{ TAG : tags
      #|erDiagram
      #|  A {
      #|    int id PK
      #|  }
      #|  B {
      #|    int aid FK
      #|  }
      #|  A -- B
      #|  A ||--|| B : ok
      #|  A ||.. B : dotted
      #|graph TD
      #|sequenceDiagram
      #|classDiagram
      #|erDiagram
      #|stateDiagram-v2
    ),
  ]
}

///|
test "Blackbox branch probe corpus exercises rare parser and renderer paths" {
  let inputs = branch_probe_inputs()
  let mut parsed_ok = 0
  let mut parsed_fail = 0
  let mut ascii_ok = 0
  let mut svg_ok = 0

  for i, input in inputs {
    let (ok_parse, ok_ascii, ok_svg) = branch_probe_exercise_case(input, i)
    if ok_parse {
      parsed_ok = parsed_ok + 1
      if ok_ascii {
        ascii_ok = ascii_ok + 1
      }
      if ok_svg {
        svg_ok = svg_ok + 1
      }
    } else {
      parsed_fail = parsed_fail + 1
    }
  }

  assert_true(inputs.length() >= 1)
  assert_true(parsed_ok >= 1)
  assert_true(parsed_ok + parsed_fail == inputs.length())
  assert_true(ascii_ok >= parsed_ok / 2)
  assert_true(svg_ok >= parsed_ok / 2)
}

///|
test "Blackbox branch probe SVG font URL encoding includes multibyte paths" {
  let input =
    #|graph TD
    #|  A --> B
  let fonts = ["Inter", "Cafeé", "漢字", "Emoji 😀"]
  let mut saw_two_byte = false
  let mut saw_three_byte = false
  let mut saw_four_byte = false

  for i, font in fonts {
    let options : @model.RenderOptions = {
      bg: None,
      fg: None,
      line: None,
      accent: None,
      muted: None,
      surface: None,
      border: None,
      font: Some(font),
      padding: Some(4),
      node_spacing: Some(8),
      layer_spacing: Some(8),
      transparent: Some(i % 2 == 0),
      layout_engine: None,
    }
    let svg = @beautiful_mermaid.render_mermaid(input, options~)
    assert_true(
      svg.contains("@import url('https://fonts.googleapis.com/css2?family="),
    )
    if font == "Cafeé" && svg.contains("%C3%A9") {
      saw_two_byte = true
    }
    if font == "漢字" && svg.contains("%E6%BC%A2") {
      saw_three_byte = true
    }
    if font == "Emoji 😀" && svg.contains("%F0%9F%98%80") {
      saw_four_byte = true
    }
  }

  assert_true(saw_two_byte)
  assert_true(saw_three_byte)
  assert_true(saw_four_byte)
}
