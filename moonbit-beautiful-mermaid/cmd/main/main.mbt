///|
fn print_usage() -> Unit {
  println("Usage:")
  println("  moon run cmd/main -- \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --ascii \"graph LR\\nA --> B\"")
  println("  moon run cmd/main -- --theme=tokyo-night \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --list-themes")
  println("Flags:")
  println("  --ascii    Render ASCII output")
  println("  --theme    SVG theme slug, e.g. tokyo-night, github-dark")
  println("  --list-themes  Print built-in theme names")
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
  let mut theme_slug : String? = None
  let mut diagram : String? = None
  let mut expect_theme_value = false

  for arg in args {
    if expect_theme_value {
      if arg.has_prefix("--") {
        println("Error: --theme requires a value")
        print_usage()
        return
      }
      theme_slug = Some(arg)
      expect_theme_value = false
      continue
    }

    if arg == "--help" {
      print_usage()
      return
    }
    if arg == "--list-themes" {
      let available = @beautiful_mermaid.built_in_theme_slugs().join(", ")
      println(available)
      return
    }
    if arg == "--ascii" {
      use_ascii = true
      continue
    }
    if arg == "--theme" {
      expect_theme_value = true
      continue
    }
    if arg.has_prefix("--theme=") {
      let theme = (try! arg[8:]).to_string()
      if theme == "" {
        println("Error: --theme requires a non-empty value")
        print_usage()
        return
      }
      theme_slug = Some(theme)
      continue
    }
    if arg.has_prefix("--") {
      println("Error: unknown flag \{arg}")
      print_usage()
      return
    }
    diagram = Some(arg)
  }

  if expect_theme_value {
    println("Error: --theme requires a value")
    print_usage()
    return
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

  let rendered_svg = match theme_slug {
    Some(slug) => {
      let themed = try? @beautiful_mermaid.render_mermaid_with_theme_name(
        input,
        slug,
      )
      match themed {
        Err(@beautiful_mermaid.MermaidError::UnknownTheme(_)) => {
          println("Unknown theme: \{slug}")
          let available = @beautiful_mermaid.built_in_theme_slugs().join(", ")
          println("Available themes: \{available}")
          return
        }
        _ => themed
      }
    }
    None => try? @beautiful_mermaid.render_mermaid(input)
  }

  match rendered_svg {
    Ok(output) => println(output)
    Err(err) => println("Error: \{err}")
  }
}
