///|
fn parser_generated_ascii_option(seed : Int) -> AsciiRenderOptions {
  {
    use_ascii: seed % 2 == 0,
    padding_x: [0, 1, 2, 5][seed % 4],
    padding_y: [0, 1, 2, 5][seed / 2 % 4],
    box_border_padding: [0, 1, 2][seed % 3],
  }
}

///|
fn parser_generated_svg_option(seed : Int) -> RenderOptions {
  {
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: None,
    padding: [Some(0), Some(4), Some(12), None][seed % 4],
    node_spacing: [Some(2), Some(8), None][seed % 3],
    layer_spacing: [Some(2), Some(8), None][seed / 2 % 3],
    transparent: Some(seed % 2 == 1),
  }
}

///|
fn parser_generated_exercise(input : String, seed : Int) -> Bool {
  let parsed : Result[MermaidGraph, MermaidError] = try? parse_mermaid(input)
  match parsed {
    Ok(_) => {
      ignore(
        try? render_mermaid_ascii(
          input,
          options=parser_generated_ascii_option(seed),
        ),
      )
      ignore(
        try? render_mermaid(input, options=parser_generated_svg_option(seed)),
      )
      true
    }
    Err(_) => false
  }
}

///|
fn parser_generated_flowchart(
  direction : String,
  operator : String,
  seed : Int,
) -> String {
  let tag = "f\{seed % 11}"
  "graph \{direction}\n%% generated \{tag}\nA[Rect] \{operator} B((Circle))\nB \{operator} C{Diamond}\nC \{operator} D[/Trap/]\nD \{operator} E[\\\\Trap\\\\]\nE -->|lbl \{tag}| A\n"
}

///|
fn parser_generated_sequence(
  operator : String,
  block_type : String,
  seed : Int,
) -> String {
  let tag = "s\{seed % 17}"
  "sequenceDiagram\nactor U as User\nparticipant S as Server\nparticipant DB as Database\nU\{operator}S: \{tag}-1\nS->>DB: \{tag}-2\n\{block_type} branch\nDB-->>S: \{tag}-3\nend\nNote left of U: \{tag}\nNote over U,S: \{tag} over\n"
}

///|
fn parser_generated_class(
  relation1 : String,
  relation2 : String,
  seed : Int,
) -> String {
  let tag = "c\{seed % 13}"
  "classDiagram\nclass A {\n  +id int\n  +run ()\n}\nclass B {\n  +start()\n}\nclass C {\n  +stop()\n}\nA \{relation1} B : \{tag}-ab\nB \{relation2} C : \{tag}-bc\nB --> A\n"
}

///|
fn parser_generated_er(
  relation1 : String,
  relation2 : String,
  seed : Int,
) -> String {
  let tag = "e\{seed % 13}"
  "erDiagram\nA {\n  string id PK\n  string name\n}\nB {\n  string aid FK\n  string note \\\"text\\\"\n}\nC {\n  string bid FK\n}\nA \{relation1} B : \{tag}-ab\nB \{relation2} C : \{tag}-bc\n"
}

///|
test "Generated parser corpus exercises mixed syntax paths" {
  let directions = ["TD", "TB", "LR", "RL", "BT"]
  let flow_operators = ["-->", "-.->", "==>", "---", "<-->", "<-.->", "=="]
  let sequence_operators = ["->>", "-->>", "->", "--)", "-x", "->>+", "-->>-"]
  let sequence_blocks = [
    "alt", "opt", "loop", "par", "critical", "break", "rect",
  ]
  let class_relations = ["<|--", "..|>", "*--", "o--", "--o", "--*", "..>"]
  let er_relations = [
    "||--||", "||--o{", "|o--|{", "}|--o{", "||..o{", "}|..||",
  ]

  let mut seed = 0
  let mut attempts = 0
  let mut parsed_ok = 0

  for direction in directions {
    for operator in flow_operators {
      attempts = attempts + 1
      if parser_generated_exercise(
          parser_generated_flowchart(direction, operator, seed),
          seed,
        ) {
        parsed_ok = parsed_ok + 1
      }
      seed = seed + 1
    }
  }

  for operator in sequence_operators {
    for block_type in sequence_blocks {
      attempts = attempts + 1
      if parser_generated_exercise(
          parser_generated_sequence(operator, block_type, seed),
          seed,
        ) {
        parsed_ok = parsed_ok + 1
      }
      seed = seed + 1
    }
  }

  for relation1 in class_relations {
    for relation2 in class_relations {
      attempts = attempts + 1
      if parser_generated_exercise(
          parser_generated_class(relation1, relation2, seed),
          seed,
        ) {
        parsed_ok = parsed_ok + 1
      }
      seed = seed + 1
    }
  }

  for relation1 in er_relations {
    for relation2 in er_relations {
      attempts = attempts + 1
      if parser_generated_exercise(
          parser_generated_er(relation1, relation2, seed),
          seed,
        ) {
        parsed_ok = parsed_ok + 1
      }
      seed = seed + 1
    }
  }

  assert_true(attempts > 0)
  assert_true(parsed_ok > attempts / 3)
}

///|
test "Generated parser corpus exercises empty diagram variants" {
  let empty_variants = [
    "graph TD\n", "graph LR\n%% only comment\n", "classDiagram\n", "erDiagram\n",
    "sequenceDiagram\n", "stateDiagram-v2\n",
  ]

  let mut ok = 0
  for i, input in empty_variants {
    if parser_generated_exercise(input, i) {
      ok = ok + 1
    }
  }

  assert_true(ok >= 3)
}
