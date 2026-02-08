///|
fn option_string_or(value : String?, fallback : String) -> String {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn option_bool_or(value : Bool?, fallback : Bool) -> Bool {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
pub fn build_colors(options : RenderOptions) -> DiagramColors {
  let defaults = DiagramColors::default()
  {
    bg: option_string_or(options.bg, defaults.bg),
    fg: option_string_or(options.fg, defaults.fg),
    line: options.line,
    accent: options.accent,
    muted: options.muted,
    surface: options.surface,
    border: options.border,
  }
}

///|
fn resolve_font(options : RenderOptions) -> String {
  option_string_or(options.font, "Inter")
}

///|
fn resolve_transparent(options : RenderOptions) -> Bool {
  option_bool_or(options.transparent, false)
}

///|
pub fn render_mermaid(
  text : String,
  options? : RenderOptions = RenderOptions::default(),
) -> String raise MermaidError {
  let graph = parse_mermaid(text)
  let positioned = layout_graph(graph, options)
  render_svg(
    positioned,
    build_colors(options),
    resolve_font(options),
    resolve_transparent(options),
  )
}

///|
pub fn render_mermaid_ascii(
  text : String,
  options? : AsciiRenderOptions = AsciiRenderOptions::default(),
) -> String raise MermaidError {
  let graph = parse_mermaid(text)
  render_ascii(graph, options)
}
