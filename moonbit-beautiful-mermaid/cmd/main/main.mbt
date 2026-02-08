///|
fn print_usage() -> Unit {
  println("Usage:")
  println("  moon run cmd/main -- \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --ascii \"graph LR\\nA --> B\"")
  println("Flags:")
  println("  --ascii    Render ASCII output")
  println("  --help     Show this help")
}

///|
fn cli_args_without_program() -> Array[String] {
  let all_args = @env.args()
  if all_args.length() <= 1 {
    []
  } else {
    let args : Array[String] = []
    for i in 1..<all_args.length() {
      args.push(all_args[i])
    }
    args
  }
}

///|
fn main {
  let args = cli_args_without_program()
  let mut use_ascii = false
  let mut diagram : String? = None

  for arg in args {
    if arg == "--help" {
      print_usage()
      return
    }
    if arg == "--ascii" {
      use_ascii = true
      continue
    }
    if !arg.has_prefix("--") {
      diagram = Some(arg)
    }
  }

  let input = match diagram {
    Some(found) => found
    None =>
      "graph TD\nA[Start] --> B{Decision}\nB -->|Yes| C[Done]\nB -->|No| D[Retry]"
  }

  if use_ascii {
    let options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    }
    let rendered_ascii = try? @beautiful_mermaid.render_mermaid_ascii(
      input,
      options~,
    )
    match rendered_ascii {
      Ok(output) => println(output)
      Err(err) => println("Error: \{err}")
    }
    return
  }

  let rendered_svg = try? @beautiful_mermaid.render_mermaid(input)
  match rendered_svg {
    Ok(output) => println(output)
    Err(err) => println("Error: \{err}")
  }
}
