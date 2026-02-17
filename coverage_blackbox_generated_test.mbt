///|
fn generated_ascii_option(seed : Int) -> @model.AsciiRenderOptions {
  let use_ascii = seed % 2 == 0
  let padding_x = [0, 1, 2, 5][seed % 4]
  let padding_y = [0, 1, 2, 5][seed / 2 % 4]
  let box_border_padding = [0, 1, 2][seed % 3]
  { use_ascii, padding_x, padding_y, box_border_padding }
}

///|
fn generated_svg_option(seed : Int) -> @model.RenderOptions {
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
    layout_engine: None,
  }
}

///|
fn generated_render_attempt(input : String, seed : Int) -> (Bool, Bool) {
  let ascii_result : Result[String, @model.MermaidError] = try? render_mermaid_ascii(
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
  let svg_result : Result[String, @model.MermaidError] = try? render_mermaid(
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
  (
    $|graph \{direction}
    $|A[Alpha] \{operator} B[Beta]
    $|B \{operator} C[Gamma]
    $|A \{operator} C
    $|C \{operator} D[Delta]
    $|D -->|back \{label}| A
    $|A -->|label \{label}| E[Echo]
    $|
  )
}

///|
fn generated_state(direction : String, seed : Int) -> String {
  let tag = "t\{seed % 7}"
  (
    $|stateDiagram-v2
    $|  direction \{direction}
    $|  [*] --> Idle
    $|  Idle --> Working: \{tag}
    $|  Working --> Waiting
    $|  Waiting --> Working
    $|  Working --> Done
    $|  Done --> [*]
    $|
  )
}

///|
fn generated_sequence(
  operator1 : String,
  operator2 : String,
  seed : Int,
) -> String {
  let tag = "m\{seed % 9}"
  (
    $|sequenceDiagram
    $|participant A
    $|participant B
    $|participant C
    $|A\{operator1}B: \{tag}-1
    $|B\{operator2}C: \{tag}-2
    $|C->>A: \{tag}-3
    $|Note over A,C: \{tag}
    $|
  )
}

///|
fn generated_class(
  operator : String,
  reverse_operator : String,
  seed : Int,
) -> String {
  let tag = "R\{seed % 5}"
  (
    $|classDiagram
    $|class Base {
    $|  +id Int
    $|  +run()
    $|}
    $|class Impl {
    $|  +run()
    $|}
    $|class Helper {
    $|  +assist()
    $|}
    $|Base \{operator} Impl : \{tag}
    $|Impl \{reverse_operator} Helper : \{tag}
    $|Impl --> Base
    $|
  )
}

///|
fn generated_er(operator1 : String, operator2 : String, seed : Int) -> String {
  let tag = "E\{seed % 6}"
  (
    $|erDiagram
    $|A {
    $|  string id PK
    $|}
    $|B {
    $|  string aid FK
    $|}
    $|C {
    $|  string bid FK
    $|}
    $|A \{operator1} B : \{tag}-ab
    $|B \{operator2} C : \{tag}-bc
    $|
  )
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
