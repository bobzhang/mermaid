///|
fn print_usage() -> Unit {
  println("Usage:")
  println("  moon run cmd/main -- \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --ascii \"graph LR\\nA --> B\"")
  println("  moon run cmd/main -- --unicode \"graph LR\\nA --> B\"")
  println("  moon run cmd/main -- --ascii --ascii-padding-x=8 \"graph LR\\nA --> B\"")
  println("  moon run cmd/main -- --ascii --ascii-padding-y=2 \"graph LR\\nA --> B\"")
  println(
    "  moon run cmd/main -- --ascii --ascii-box-border-padding=2 \"graph LR\\nA --> B\"",
  )
  println("  moon run cmd/main -- --theme=tokyo-night \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --font='Roboto Mono' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --bg='#0f172a' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --fg='#e2e8f0' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --line='#64748b' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --accent='#38bdf8' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --muted='#94a3b8' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --surface='#0b1220' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --border='#334155' \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --padding=20 \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --node-spacing=80 \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --layer-spacing=90 \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --transparent \"graph TD\\nA --> B\"")
  println("  moon run cmd/main -- --list-themes")
  println("Flags:")
  println("  --ascii    Render ASCII output")
  println("  --unicode  Render Unicode text output")
  println("  --ascii-padding-x  ASCII horizontal padding, e.g. 8")
  println("  --ascii-padding-y  ASCII vertical padding, e.g. 2")
  println("  --ascii-box-border-padding  ASCII box border padding, e.g. 2")
  println("  --theme    SVG theme slug, e.g. tokyo-night, github-dark")
  println("  --font     SVG font family, e.g. Inter, Roboto Mono")
  println("  --bg       SVG background color, e.g. #0f172a")
  println("  --fg       SVG foreground color, e.g. #e2e8f0")
  println("  --line     SVG edge color, e.g. #64748b")
  println("  --accent   SVG accent color, e.g. #38bdf8")
  println("  --muted    SVG muted text color, e.g. #94a3b8")
  println("  --surface  SVG node fill color, e.g. #0b1220")
  println("  --border   SVG stroke color, e.g. #334155")
  println("  --padding  SVG/layout padding in px, e.g. 20")
  println("  --node-spacing  Horizontal node spacing in px, e.g. 80")
  println("  --layer-spacing  Vertical layer spacing in px, e.g. 90")
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
fn parse_non_negative_int(raw : String) -> Int? {
  let normalized = raw.trim().to_string()
  if normalized == "" {
    return None
  }
  let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
    normalized,
  )
  match parsed {
    Ok(value) => if value >= 0 { Some(value) } else { None }
    Err(_) => None
  }
}

///|
fn ascii_spacing_overridden(
  padding_x : Int,
  padding_y : Int,
  box_border_padding : Int,
) -> Bool {
  padding_x != 5 || padding_y != 5 || box_border_padding != 1
}

///|
fn ascii_spacing_requires_text_mode(
  render_text : Bool,
  padding_x : Int,
  padding_y : Int,
  box_border_padding : Int,
) -> Bool {
  !render_text && ascii_spacing_overridden(padding_x, padding_y, box_border_padding)
}

///|
fn text_mode_override(arg : String) -> Bool? {
  if arg == "--ascii" {
    Some(true)
  } else if arg == "--unicode" {
    Some(false)
  } else {
    None
  }
}

///|
fn svg_options_overridden(
  theme_slug : String?,
  font_name : String?,
  bg_color : String?,
  fg_color : String?,
  line_color : String?,
  accent_color : String?,
  muted_color : String?,
  surface_color : String?,
  border_color : String?,
  padding : Int?,
  node_spacing : Int?,
  layer_spacing : Int?,
  transparent : Bool,
) -> Bool {
  theme_slug is Some(_) ||
  font_name is Some(_) ||
  bg_color is Some(_) ||
  fg_color is Some(_) ||
  line_color is Some(_) ||
  accent_color is Some(_) ||
  muted_color is Some(_) ||
  surface_color is Some(_) ||
  border_color is Some(_) ||
  padding is Some(_) ||
  node_spacing is Some(_) ||
  layer_spacing is Some(_) ||
  transparent
}

///|
fn main {
  let args = cli_args_without_program()
  let mut render_text = false
  let mut use_ascii_chars = true
  let mut ascii_padding_x = 5
  let mut ascii_padding_y = 5
  let mut ascii_box_border_padding = 1
  let mut theme_slug : String? = None
  let mut font_name : String? = None
  let mut bg_color : String? = None
  let mut fg_color : String? = None
  let mut line_color : String? = None
  let mut accent_color : String? = None
  let mut muted_color : String? = None
  let mut surface_color : String? = None
  let mut border_color : String? = None
  let mut padding : Int? = None
  let mut node_spacing : Int? = None
  let mut layer_spacing : Int? = None
  let mut transparent = false
  let mut diagram : String? = None
  let mut expect_theme_value = false
  let mut expect_font_value = false
  let mut expect_bg_value = false
  let mut expect_fg_value = false
  let mut expect_line_value = false
  let mut expect_accent_value = false
  let mut expect_muted_value = false
  let mut expect_surface_value = false
  let mut expect_border_value = false
  let mut expect_padding_value = false
  let mut expect_node_spacing_value = false
  let mut expect_layer_spacing_value = false
  let mut expect_ascii_padding_x_value = false
  let mut expect_ascii_padding_y_value = false
  let mut expect_ascii_box_border_padding_value = false

  for arg in args {
    if expect_ascii_box_border_padding_value {
      if arg.has_prefix("--") {
        println("Error: --ascii-box-border-padding requires a value")
        print_usage()
        return
      }
      match parse_non_negative_int(arg) {
        Some(value) => ascii_box_border_padding = value
        None => {
          println(
            "Error: --ascii-box-border-padding requires a non-negative integer",
          )
          print_usage()
          return
        }
      }
      expect_ascii_box_border_padding_value = false
      continue
    }

    if expect_ascii_padding_y_value {
      if arg.has_prefix("--") {
        println("Error: --ascii-padding-y requires a value")
        print_usage()
        return
      }
      match parse_non_negative_int(arg) {
        Some(value) => ascii_padding_y = value
        None => {
          println("Error: --ascii-padding-y requires a non-negative integer")
          print_usage()
          return
        }
      }
      expect_ascii_padding_y_value = false
      continue
    }

    if expect_ascii_padding_x_value {
      if arg.has_prefix("--") {
        println("Error: --ascii-padding-x requires a value")
        print_usage()
        return
      }
      match parse_non_negative_int(arg) {
        Some(value) => ascii_padding_x = value
        None => {
          println("Error: --ascii-padding-x requires a non-negative integer")
          print_usage()
          return
        }
      }
      expect_ascii_padding_x_value = false
      continue
    }

    if expect_layer_spacing_value {
      if arg.has_prefix("--") {
        println("Error: --layer-spacing requires a value")
        print_usage()
        return
      }
      match parse_non_negative_int(arg) {
        Some(value) => layer_spacing = Some(value)
        None => {
          println("Error: --layer-spacing requires a non-negative integer")
          print_usage()
          return
        }
      }
      expect_layer_spacing_value = false
      continue
    }

    if expect_node_spacing_value {
      if arg.has_prefix("--") {
        println("Error: --node-spacing requires a value")
        print_usage()
        return
      }
      match parse_non_negative_int(arg) {
        Some(value) => node_spacing = Some(value)
        None => {
          println("Error: --node-spacing requires a non-negative integer")
          print_usage()
          return
        }
      }
      expect_node_spacing_value = false
      continue
    }

    if expect_padding_value {
      if arg.has_prefix("--") {
        println("Error: --padding requires a value")
        print_usage()
        return
      }
      match parse_non_negative_int(arg) {
        Some(value) => padding = Some(value)
        None => {
          println("Error: --padding requires a non-negative integer")
          print_usage()
          return
        }
      }
      expect_padding_value = false
      continue
    }

    if expect_border_value {
      if arg.has_prefix("--") {
        println("Error: --border requires a value")
        print_usage()
        return
      }
      border_color = Some(arg)
      expect_border_value = false
      continue
    }

    if expect_surface_value {
      if arg.has_prefix("--") {
        println("Error: --surface requires a value")
        print_usage()
        return
      }
      surface_color = Some(arg)
      expect_surface_value = false
      continue
    }

    if expect_muted_value {
      if arg.has_prefix("--") {
        println("Error: --muted requires a value")
        print_usage()
        return
      }
      muted_color = Some(arg)
      expect_muted_value = false
      continue
    }

    if expect_accent_value {
      if arg.has_prefix("--") {
        println("Error: --accent requires a value")
        print_usage()
        return
      }
      accent_color = Some(arg)
      expect_accent_value = false
      continue
    }

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
    match text_mode_override(arg) {
      Some(ascii_mode) => {
        render_text = true
        use_ascii_chars = ascii_mode
        continue
      }
      None => ()
    }
    if arg == "--ascii-padding-x" {
      expect_ascii_padding_x_value = true
      continue
    }
    if arg == "--ascii-padding-y" {
      expect_ascii_padding_y_value = true
      continue
    }
    if arg == "--ascii-box-border-padding" {
      expect_ascii_box_border_padding_value = true
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
    if arg == "--accent" {
      expect_accent_value = true
      continue
    }
    if arg == "--muted" {
      expect_muted_value = true
      continue
    }
    if arg == "--surface" {
      expect_surface_value = true
      continue
    }
    if arg == "--border" {
      expect_border_value = true
      continue
    }
    if arg == "--padding" {
      expect_padding_value = true
      continue
    }
    if arg == "--node-spacing" {
      expect_node_spacing_value = true
      continue
    }
    if arg == "--layer-spacing" {
      expect_layer_spacing_value = true
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
    if arg.has_prefix("--accent=") {
      let accent = (try! arg[9:]).to_string()
      if accent == "" {
        println("Error: --accent requires a non-empty value")
        print_usage()
        return
      }
      accent_color = Some(accent)
      continue
    }
    if arg.has_prefix("--muted=") {
      let muted = (try! arg[8:]).to_string()
      if muted == "" {
        println("Error: --muted requires a non-empty value")
        print_usage()
        return
      }
      muted_color = Some(muted)
      continue
    }
    if arg.has_prefix("--surface=") {
      let surface = (try! arg[10:]).to_string()
      if surface == "" {
        println("Error: --surface requires a non-empty value")
        print_usage()
        return
      }
      surface_color = Some(surface)
      continue
    }
    if arg.has_prefix("--border=") {
      let border = (try! arg[9:]).to_string()
      if border == "" {
        println("Error: --border requires a non-empty value")
        print_usage()
        return
      }
      border_color = Some(border)
      continue
    }
    if arg.has_prefix("--padding=") {
      let raw_padding = (try! arg[10:]).to_string()
      if raw_padding == "" {
        println("Error: --padding requires a non-empty value")
        print_usage()
        return
      }
      match parse_non_negative_int(raw_padding) {
        Some(value) => padding = Some(value)
        None => {
          println("Error: --padding requires a non-negative integer")
          print_usage()
          return
        }
      }
      continue
    }
    if arg.has_prefix("--node-spacing=") {
      let raw_node_spacing = (try! arg[15:]).to_string()
      if raw_node_spacing == "" {
        println("Error: --node-spacing requires a non-empty value")
        print_usage()
        return
      }
      match parse_non_negative_int(raw_node_spacing) {
        Some(value) => node_spacing = Some(value)
        None => {
          println("Error: --node-spacing requires a non-negative integer")
          print_usage()
          return
        }
      }
      continue
    }
    if arg.has_prefix("--layer-spacing=") {
      let raw_layer_spacing = (try! arg[16:]).to_string()
      if raw_layer_spacing == "" {
        println("Error: --layer-spacing requires a non-empty value")
        print_usage()
        return
      }
      match parse_non_negative_int(raw_layer_spacing) {
        Some(value) => layer_spacing = Some(value)
        None => {
          println("Error: --layer-spacing requires a non-negative integer")
          print_usage()
          return
        }
      }
      continue
    }
    if arg.has_prefix("--ascii-padding-x=") {
      let raw_ascii_padding_x = (try! arg[18:]).to_string()
      if raw_ascii_padding_x == "" {
        println("Error: --ascii-padding-x requires a non-empty value")
        print_usage()
        return
      }
      match parse_non_negative_int(raw_ascii_padding_x) {
        Some(value) => ascii_padding_x = value
        None => {
          println("Error: --ascii-padding-x requires a non-negative integer")
          print_usage()
          return
        }
      }
      continue
    }
    if arg.has_prefix("--ascii-padding-y=") {
      let raw_ascii_padding_y = (try! arg[18:]).to_string()
      if raw_ascii_padding_y == "" {
        println("Error: --ascii-padding-y requires a non-empty value")
        print_usage()
        return
      }
      match parse_non_negative_int(raw_ascii_padding_y) {
        Some(value) => ascii_padding_y = value
        None => {
          println("Error: --ascii-padding-y requires a non-negative integer")
          print_usage()
          return
        }
      }
      continue
    }
    if arg.has_prefix("--ascii-box-border-padding=") {
      let raw_ascii_box_border_padding = (try! arg[27:]).to_string()
      if raw_ascii_box_border_padding == "" {
        println("Error: --ascii-box-border-padding requires a non-empty value")
        print_usage()
        return
      }
      match parse_non_negative_int(raw_ascii_box_border_padding) {
        Some(value) => ascii_box_border_padding = value
        None => {
          println(
            "Error: --ascii-box-border-padding requires a non-negative integer",
          )
          print_usage()
          return
        }
      }
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
  if expect_accent_value {
    println("Error: --accent requires a value")
    print_usage()
    return
  }
  if expect_muted_value {
    println("Error: --muted requires a value")
    print_usage()
    return
  }
  if expect_surface_value {
    println("Error: --surface requires a value")
    print_usage()
    return
  }
  if expect_border_value {
    println("Error: --border requires a value")
    print_usage()
    return
  }
  if expect_padding_value {
    println("Error: --padding requires a value")
    print_usage()
    return
  }
  if expect_node_spacing_value {
    println("Error: --node-spacing requires a value")
    print_usage()
    return
  }
  if expect_layer_spacing_value {
    println("Error: --layer-spacing requires a value")
    print_usage()
    return
  }
  if expect_ascii_padding_x_value {
    println("Error: --ascii-padding-x requires a value")
    print_usage()
    return
  }
  if expect_ascii_padding_y_value {
    println("Error: --ascii-padding-y requires a value")
    print_usage()
    return
  }
  if expect_ascii_box_border_padding_value {
    println("Error: --ascii-box-border-padding requires a value")
    print_usage()
    return
  }
  if ascii_spacing_requires_text_mode(
    render_text,
    ascii_padding_x,
    ascii_padding_y,
    ascii_box_border_padding,
  ) {
    println(
      "Error: ASCII spacing flags require --ascii or --unicode text output mode",
    )
    print_usage()
    return
  }
  if render_text &&
    svg_options_overridden(
      theme_slug,
      font_name,
      bg_color,
      fg_color,
      line_color,
      accent_color,
      muted_color,
      surface_color,
      border_color,
      padding,
      node_spacing,
      layer_spacing,
      transparent,
    ) {
    println(
      "Error: SVG flags require SVG output mode (omit --ascii/--unicode)",
    )
    print_usage()
    return
  }

  let input = match diagram {
    Some(found) => found
    None =>
      "graph TD\nA[Start] --> B{Decision}\nB -->|Yes| C[Done]\nB -->|No| D[Retry]"
  }

  if render_text {
    let options = @beautiful_mermaid.AsciiRenderOptions::{
      use_ascii: use_ascii_chars,
      padding_x: ascii_padding_x,
      padding_y: ascii_padding_y,
      box_border_padding: ascii_box_border_padding,
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
    accent: accent_color,
    muted: muted_color,
    surface: surface_color,
    border: border_color,
    font: font_name,
    padding,
    node_spacing,
    layer_spacing,
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
