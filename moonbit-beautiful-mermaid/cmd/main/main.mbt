///|
fn print_usage() -> Unit {
  println("Usage:")
  println("  moon run cmd/main -- \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --ascii \"graph LR\\nA --> B\"")
  println("  moon run cmd/main -- --theme=tokyo-night \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --font='Roboto Mono' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --bg='#0f172a' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --fg='#e2e8f0' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --line='#64748b' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --transparent \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --list-themes")
  println("Flags:")
  println("  --ascii    Render ASCII output")
  println("  --theme    SVG theme slug, e.g. tokyo-night, github-dark")
  println("  --font     SVG font family, e.g. Inter, Roboto Mono")
  println("  --bg       SVG background color, e.g. #0f172a")
  println("  --fg       SVG foreground color, e.g. #e2e8f0")
  println("  --line     SVG edge color, e.g. #64748b")
  println("  --transparent  Omit SVG background fill")
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
  let mut font_name : String? = None
  let mut bg_color : String? = None
  let mut fg_color : String? = None
  let mut line_color : String? = None
  let mut transparent = false
  let mut diagram : String? = None
  let mut expect_theme_value = false
  let mut expect_font_value = false
  let mut expect_bg_value = false
  let mut expect_fg_value = false
  let mut expect_line_value = false

  for arg in args {
    if expect_line_value {
      if arg.has_prefix("--") {
        println("Error: --line requires a value")
        print_usage()
        return
      }
      line_color = Some(arg)
      expect_line_value = false
      continue
    }

    if expect_fg_value {
      if arg.has_prefix("--") {
        println("Error: --fg requires a value")
        print_usage()
        return
      }
      fg_color = Some(arg)
      expect_fg_value = false
      continue
    }

    if expect_bg_value {
      if arg.has_prefix("--") {
        println("Error: --bg requires a value")
        print_usage()
        return
      }
      bg_color = Some(arg)
      expect_bg_value = false
      continue
    }

    if expect_font_value {
      if arg.has_prefix("--") {
        println("Error: --font requires a value")
        print_usage()
        return
      }
      font_name = Some(arg)
      expect_font_value = false
      continue
    }

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
    if arg == "--transparent" {
      transparent = true
      continue
    }
    if arg == "--font" {
      expect_font_value = true
      continue
    }
    if arg == "--bg" {
      expect_bg_value = true
      continue
    }
    if arg == "--fg" {
      expect_fg_value = true
      continue
    }
    if arg == "--line" {
      expect_line_value = true
      continue
    }
    if arg.has_prefix("--font=") {
      let font = (try! arg[7:]).to_string()
      if font == "" {
        println("Error: --font requires a non-empty value")
        print_usage()
        return
      }
      font_name = Some(font)
      continue
    }
    if arg.has_prefix("--bg=") {
      let bg = (try! arg[5:]).to_string()
      if bg == "" {
        println("Error: --bg requires a non-empty value")
        print_usage()
        return
      }
      bg_color = Some(bg)
      continue
    }
    if arg.has_prefix("--fg=") {
      let fg = (try! arg[5:]).to_string()
      if fg == "" {
        println("Error: --fg requires a non-empty value")
        print_usage()
        return
      }
      fg_color = Some(fg)
      continue
    }
    if arg.has_prefix("--line=") {
      let line = (try! arg[7:]).to_string()
      if line == "" {
        println("Error: --line requires a non-empty value")
        print_usage()
        return
      }
      line_color = Some(line)
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
  if expect_font_value {
    println("Error: --font requires a value")
    print_usage()
    return
  }
  if expect_bg_value {
    println("Error: --bg requires a value")
    print_usage()
    return
  }
  if expect_fg_value {
    println("Error: --fg requires a value")
    print_usage()
    return
  }
  if expect_line_value {
    println("Error: --line requires a value")
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

  let svg_options = @beautiful_mermaid.RenderOptions::{
    bg: bg_color,
    fg: fg_color,
    line: line_color,
    accent: None,
    muted: None,
    surface: None,
    border: None,
    font: font_name,
    padding: None,
    node_spacing: None,
    layer_spacing: None,
    transparent: Some(transparent),
  }

  let rendered_svg = match theme_slug {
    Some(slug) => {
      let themed = try? @beautiful_mermaid.render_mermaid_with_theme_name(
        input,
        slug,
        options=svg_options,
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
    None => try? @beautiful_mermaid.render_mermaid(input, options=svg_options)
  }

  match rendered_svg {
    Ok(output) => println(output)
    Err(err) => println("Error: \{err}")
  }
}
