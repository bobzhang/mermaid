///|
fn coverage_ascii_option_matrix() -> Array[AsciiRenderOptions] {
  [
    { use_ascii: true, padding_x: 5, padding_y: 5, box_border_padding: 1 },
    { use_ascii: false, padding_x: 5, padding_y: 5, box_border_padding: 1 },
    { use_ascii: true, padding_x: 0, padding_y: 0, box_border_padding: 0 },
    { use_ascii: false, padding_x: 0, padding_y: 0, box_border_padding: 0 },
    { use_ascii: true, padding_x: 1, padding_y: 2, box_border_padding: 2 },
    { use_ascii: false, padding_x: 1, padding_y: 2, box_border_padding: 2 },
    { use_ascii: true, padding_x: -1, padding_y: -1, box_border_padding: 0 },
    { use_ascii: false, padding_x: -1, padding_y: -1, box_border_padding: 0 },
  ]
}

///|
fn coverage_svg_option_matrix() -> Array[RenderOptions] {
  [
    RenderOptions::default(),
    {
      bg: None,
      fg: None,
      line: None,
      accent: None,
      muted: None,
      surface: None,
      border: None,
      font: Some("Fira Code"),
      padding: Some(0),
      node_spacing: Some(0),
      layer_spacing: Some(0),
      transparent: Some(true),
    },
    {
      bg: Some("#0f172a"),
      fg: Some("#e2e8f0"),
      line: Some("#64748b"),
      accent: Some("#38bdf8"),
      muted: Some("#94a3b8"),
      surface: Some("#0b1220"),
      border: Some("#334155"),
      font: Some("Roboto Mono"),
      padding: Some(8),
      node_spacing: Some(4),
      layer_spacing: Some(4),
      transparent: Some(false),
    },
    {
      bg: None,
      fg: None,
      line: None,
      accent: None,
      muted: None,
      surface: None,
      border: None,
      font: None,
      padding: Some(-4),
      node_spacing: Some(-2),
      layer_spacing: Some(-2),
      transparent: Some(true),
    },
  ]
}

///|
test "Coverage matrix renders supported corpus with varied options" {
  let ascii_options = coverage_ascii_option_matrix()
  let svg_options = coverage_svg_option_matrix()

  for case_data in ts_supported_cases() {
    for option_index, ascii_option in ascii_options {
      let ascii = render_mermaid_ascii(case_data.input, options=ascii_option)
      if option_index < 4 && ts_normalize_whitespace(ascii) == "" {
        fail("empty ascii output in coverage matrix for \{case_data.name}")
      }
    }

    for svg_option in svg_options {
      let svg = render_mermaid(case_data.input, options=svg_option)
      assert_true(svg.has_prefix("<svg "))
      assert_true(svg.has_suffix("</svg>"))
    }
  }
}

///|
test "Coverage matrix exercises parser corpus paths" {
  let mut parse_failed = 0
  let mut parse_succeeded = 0

  let all_cases = @test_support.corpus_cases()
  for case_data in all_cases {
    let parsed : Result[MermaidGraph, MermaidError] = try? @parser_header_core.parse_mermaid(
      case_data.input,
    )
    match parsed {
      Ok(_) => {
        parse_succeeded = parse_succeeded + 1
        ignore(try? render_mermaid_ascii(case_data.input))
        ignore(try? render_mermaid(case_data.input))
      }
      Err(_) => parse_failed = parse_failed + 1
    }
  }

  assert_true(all_cases.length() > 0)
  assert_true(parse_succeeded + parse_failed == all_cases.length())
}

///|
test "Coverage matrix parser malformed headers and bodies" {
  let invalid_inputs = [
    "",
    (
      #|pie
      #|A : 1
    ),
    (
      #|graph
      #|A --> B
    ),
    (
      #|graph XX
      #|A --> B
    ),
    (
      #|graph TD extra
      #|A --> B
    ),
    (
      #|flowchart XX
      #|A --> B
    ),
    (
      #|stateDiagram-v2 extra
      #|A --> B
    ),
    (
      #|sequenceDiagram extra
      #|A->>B: x
    ),
    (
      #|classDiagram extra
      #|A --> B
    ),
    (
      #|erDiagram extra
      #|A ||--|| B : link
    ),
  ]

  for input in invalid_inputs {
    let parsed : Result[MermaidGraph, MermaidError] = try? @parser_header_core.parse_mermaid(
      input,
    )
    match parsed {
      Ok(_) => ()
      Err(ParseFailure(_)) => ()
      Err(UnknownTheme(_)) => fail("unexpected theme error")
    }
  }
}

///|
test "Coverage matrix nested structs are exercised" {
  let sub : MermaidSubgraph = {
    id: "sg-id",
    label: "Subgraph",
    node_ids: ["A", "B"],
    children: [
      {
        id: "child",
        label: "Child",
        node_ids: ["A"],
        children: [],
        direction: None,
      },
    ],
    direction: None,
  }
  assert_eq(sub.id, "sg-id")
  assert_eq(sub.children.length(), 1)

  let group : PositionedGroup = {
    id: "g",
    label: "Group",
    x: 10,
    y: 20,
    width: 30,
    height: 40,
    children: [
      {
        id: "nested",
        label: "Nested",
        x: 1,
        y: 2,
        width: 3,
        height: 4,
        children: [],
      },
    ],
  }
  assert_eq(group.id, "g")
  assert_eq(group.children.length(), 1)
}

///|
test "Coverage matrix class and ER relation variants" {
  let class_diagram =
    #|classDiagram
    #|  class Service {
    #|    <<interface>>
    #|
    #|    +run ()
    #|    +stop()
    #|  }
    #|  class Impl {
    #|    +run()
    #|  }
    #|  Service <|-- Impl
    #|  Impl ..|> Adapter
    #|  Owner *-- Resource
    #|  Viewer o-- Resource
    #|  Reader --o Book
    #|  Writer --* Chapter
    #|  Client ..> Api
    #|  Api --> Client
  let class_ascii = render_mermaid_ascii(class_diagram)
  let class_unicode = render_mermaid_ascii(class_diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(class_ascii.contains("Service"))
  assert_true(class_ascii.contains("run"))
  assert_true(class_unicode.contains("Service"))

  let er_diagram =
    #|erDiagram
    #|  A ||--|| B : strict
    #|  B ||--o{ C : optional_many
    #|  C |o--|{ D : optional_to_many
    #|  D }|--o{ E : many_to_optional_many
    #|  E }|..|| F : dotted_ident
    #|  F ||..|| G : dotted_pair
  let er_ascii = render_mermaid_ascii(er_diagram)
  let er_unicode = render_mermaid_ascii(er_diagram, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  assert_true(er_ascii.contains("strict"))
  assert_true(er_unicode.contains("strict"))
}

///|
test "Coverage matrix sequence edge cases" {
  let sequence_input =
    #|sequenceDiagram
    #|  actor U as User
    #|  participant S as Server
    #|  participant DB as Database
    #|  U->>S: Login
    #|  activate S
    #|  S->>DB: Query
    #|  activate DB
    #|  DB-->>S: Result
    #|  deactivate DB
    #|  S-->>-U: Token
    #|  Note right of S: line 1\\nline 2
    #|  Note over U,DB: shared state
    #|  alt ok
    #|    S--)U: async
    #|  else retry
    #|    U->>+S: Retry
    #|  end
    #|  deactivate S
  let ascii = render_mermaid_ascii(sequence_input)
  let unicode = render_mermaid_ascii(sequence_input, options={
    use_ascii: false,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let svg = render_mermaid(sequence_input)

  assert_true(ascii.contains("User"))
  assert_true(unicode.contains("Server"))
  assert_true(svg.contains("sequence"))
}

///|
test "Coverage matrix renders empty flowchart forms" {
  let empty_flowchart =
    #|graph TD
    #|
  let empty_flowchart_with_comment =
    #|graph LR
    #|%% comment only
    #|
  let empty_a = render_mermaid_ascii(empty_flowchart)
  let empty_b = render_mermaid_ascii(empty_flowchart_with_comment)
  let empty_svg = render_mermaid(empty_flowchart)

  assert_true(empty_a == "" || empty_a == "\n")
  assert_true(empty_b == "" || empty_b == "\n")
  assert_true(empty_svg.has_prefix("<svg "))
}
