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
fn option_color_or(value : String?, fallback : String?) -> String? {
  match value {
    Some(found) => Some(found)
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
pub fn merge_options_with_colors(
  options : RenderOptions,
  colors : DiagramColors,
) -> RenderOptions {
  RenderOptions::{
    bg: Some(option_string_or(options.bg, colors.bg)),
    fg: Some(option_string_or(options.fg, colors.fg)),
    line: option_color_or(options.line, colors.line),
    accent: option_color_or(options.accent, colors.accent),
    muted: option_color_or(options.muted, colors.muted),
    surface: option_color_or(options.surface, colors.surface),
    border: option_color_or(options.border, colors.border),
    font: options.font,
    padding: options.padding,
    node_spacing: options.node_spacing,
    layer_spacing: options.layer_spacing,
    transparent: options.transparent,
  }
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
pub fn render_mermaid_with_colors(
  text : String,
  colors : DiagramColors,
  options? : RenderOptions = RenderOptions::default(),
) -> String raise MermaidError {
  let merged = merge_options_with_colors(options, colors)
  render_mermaid(text, options=merged)
}

///|
pub fn render_mermaid_with_theme_name(
  text : String,
  theme_name : String,
  options? : RenderOptions = RenderOptions::default(),
) -> String raise MermaidError {
  match theme_by_name(theme_name) {
    Some(colors) => render_mermaid_with_colors(text, colors, options~)
    None => raise MermaidError::ParseFailure("Unknown theme: \{theme_name}")
  }
}

///|
pub fn render_mermaid_ascii(
  text : String,
  options? : AsciiRenderOptions = AsciiRenderOptions::default(),
) -> String raise MermaidError {
  let graph = parse_mermaid(text)
  render_ascii(graph, options)
}
