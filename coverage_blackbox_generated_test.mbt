///|
fn generated_ascii_option(seed : Int) -> AsciiRenderOptions {
  let use_ascii = seed % 2 == 0
  let padding_x = [0, 1, 2, 5][seed % 4]
  let padding_y = [0, 1, 2, 5][seed / 2 % 4]
  let box_border_padding = [0, 1, 2][seed % 3]
  { use_ascii, padding_x, padding_y, box_border_padding }
}

///|
fn generated_svg_option(seed : Int) -> RenderOptions {
  let padding = [Some(0), Some(2), Some(8), Some(16)][seed % 4]
  let node_spacing = [Some(2), Some(8), Some(16), None][seed / 2 % 4]
  let layer_spacing = [Some(2), Some(8), Some(16), None][seed / 3 % 4]
  let transparent = if seed % 2 == 0 { Some(false) } else { Some(true) }
  let font = if seed % 3 == 0 { Some("Inter") } else { Some("Roboto Mono") }
  {
    bg: None,
    fg: None,
    line: None,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font,
    padding,
    node_spacing,
    layer_spacing,
    transparent,
  }
}

///|
fn generated_render_attempt(input : String, seed : Int) -> (Bool, Bool) {
  let ascii_result : Result[String, MermaidError] = try? render_mermaid_ascii(
    input,
    options=generated_ascii_option(seed),
  )
  let ascii_ok = match ascii_result {
    Ok(ascii) => {
      ignore(ascii.length())
      true
    }
    Err(_) => false
  }
  let svg_result : Result[String, MermaidError] = try? render_mermaid(
    input,
    options=generated_svg_option(seed),
  )
  let svg_ok = match svg_result {
    Ok(svg) => svg.has_prefix("<svg ") && svg.has_suffix("</svg>")
    Err(_) => false
  }
  (ascii_ok, svg_ok)
}

///|
fn generated_flowchart(
  direction : String,
  operator : String,
  seed : Int,
) -> String {
  let label = "L\{seed % 5}"
  "graph \{direction}\nA[Alpha] \{operator} B[Beta]\nB \{operator} C[Gamma]\nA \{operator} C\nC \{operator} D[Delta]\nD -->|back \{label}| A\nA -->|label \{label}| E[Echo]\n"
}

///|
fn generated_state(direction : String, seed : Int) -> String {
  let tag = "t\{seed % 7}"
  "stateDiagram-v2\n  direction \{direction}\n  [*] --> Idle\n  Idle --> Working: \{tag}\n  Working --> Waiting\n  Waiting --> Working\n  Working --> Done\n  Done --> [*]\n"
}

///|
fn generated_sequence(
  operator1 : String,
  operator2 : String,
  seed : Int,
) -> String {
  let tag = "m\{seed % 9}"
  "sequenceDiagram\nparticipant A\nparticipant B\nparticipant C\nA\{operator1}B: \{tag}-1\nB\{operator2}C: \{tag}-2\nC->>A: \{tag}-3\nNote over A,C: \{tag}\n"
}

///|
fn generated_class(
  operator : String,
  reverse_operator : String,
  seed : Int,
) -> String {
  let tag = "R\{seed % 5}"
  "classDiagram\nclass Base {\n  +id Int\n  +run()\n}\nclass Impl {\n  +run()\n}\nclass Helper {\n  +assist()\n}\nBase \{operator} Impl : \{tag}\nImpl \{reverse_operator} Helper : \{tag}\nImpl --> Base\n"
}

///|
fn generated_er(operator1 : String, operator2 : String, seed : Int) -> String {
  let tag = "E\{seed % 6}"
  "erDiagram\nA {\n  string id PK\n}\nB {\n  string aid FK\n}\nC {\n  string bid FK\n}\nA \{operator1} B : \{tag}-ab\nB \{operator2} C : \{tag}-bc\n"
}

///|
test "Generated coverage corpus for blackbox rendering" {
  let directions = ["TD", "TB", "LR", "RL", "BT"]
  let flow_operators = ["-->", "-.->", "==>", "---", "<-->", "<-.->"]
  let seq_operators = ["->>", "-->>", "->", "--)", "-x", "->>+", "-->>-"]
  let class_operators = ["<|--", "..|>", "*--", "o--", "--o", "--*"]
  let er_operators = [
    "||--||", "||--o{", "|o--|{", "}|--o{", "||..o{", "}|..||",
  ]

  let mut attempts = 0
  let mut ascii_ok = 0
  let mut svg_ok = 0
  let mut seed = 0

  for direction in directions {
    for operator in flow_operators {
      let input = generated_flowchart(direction, operator, seed)
      let (ok_ascii, ok_svg) = generated_render_attempt(input, seed)
      attempts = attempts + 1
      if ok_ascii {
        ascii_ok = ascii_ok + 1
      }
      if ok_svg {
        svg_ok = svg_ok + 1
      }
      seed = seed + 1
    }
  }

  for direction in directions {
    let input = generated_state(direction, seed)
    let (ok_ascii, ok_svg) = generated_render_attempt(input, seed)
    attempts = attempts + 1
    if ok_ascii {
      ascii_ok = ascii_ok + 1
    }
    if ok_svg {
      svg_ok = svg_ok + 1
    }
    seed = seed + 1
  }

  for operator1 in seq_operators {
    for operator2 in seq_operators {
      if operator1 == operator2 {
        continue
      }
      let input = generated_sequence(operator1, operator2, seed)
      let (ok_ascii, ok_svg) = generated_render_attempt(input, seed)
      attempts = attempts + 1
      if ok_ascii {
        ascii_ok = ascii_ok + 1
      }
      if ok_svg {
        svg_ok = svg_ok + 1
      }
      seed = seed + 1
    }
  }

  for operator in class_operators {
    for reverse_operator in class_operators {
      let input = generated_class(operator, reverse_operator, seed)
      let (ok_ascii, ok_svg) = generated_render_attempt(input, seed)
      attempts = attempts + 1
      if ok_ascii {
        ascii_ok = ascii_ok + 1
      }
      if ok_svg {
        svg_ok = svg_ok + 1
      }
      seed = seed + 1
    }
  }

  for operator1 in er_operators {
    for operator2 in er_operators {
      let input = generated_er(operator1, operator2, seed)
      let (ok_ascii, ok_svg) = generated_render_attempt(input, seed)
      attempts = attempts + 1
      if ok_ascii {
        ascii_ok = ascii_ok + 1
      }
      if ok_svg {
        svg_ok = svg_ok + 1
      }
      seed = seed + 1
    }
  }

  assert_true(attempts > 0)
  assert_true(ascii_ok > attempts / 2)
  assert_true(svg_ok > attempts / 2)
}
