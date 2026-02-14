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
/// Resolve a full `DiagramColors` value from `RenderOptions`.
/// Missing `bg`/`fg` values fall back to `DiagramColors::default()`.
fn build_colors(options : RenderOptions) -> DiagramColors {
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
/// Merge user `options` with an explicit color palette.
/// Explicit values in `options` win; missing color fields are filled from `colors`.
fn merge_options_with_colors(
  options : RenderOptions,
  colors : DiagramColors,
) -> RenderOptions {
  {
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
/// Parse Mermaid text and render an SVG string.
/// Supports flowchart, state, sequence, class, and ER headers.
///
/// # Example
/// ```mbt check
/// test {
///   let svg = try! render_mermaid(
///     (
///       #|graph TD
///       #|A --> B
///     ),
///   )
///   assert_true(svg.has_prefix("<svg "))
///   assert_true(svg.contains(">A</text>"))
/// }
/// ```
pub fn render_mermaid(
  text : String,
  options? : RenderOptions = RenderOptions::default(),
) -> String raise MermaidError {
  let graph = @parser_header_core.parse_mermaid(text)
  let positioned = @layout.layout_graph(graph, options)
  @renderer_svg.render_svg(
    positioned,
    build_colors(options),
    option_string_or(options.font, "Inter"),
    option_bool_or(options.transparent, false),
  )
}

///|
/// Render SVG using an explicit color palette, plus optional non-color options.
fn render_mermaid_with_colors(
  text : String,
  colors : DiagramColors,
  options? : RenderOptions = RenderOptions::default(),
) -> String raise MermaidError {
  let merged = merge_options_with_colors(options, colors)
  render_mermaid(text, options=merged)
}

///|
/// Render SVG with a theme name string.
/// Theme names are normalized (`TOKYO   NIGHT`, `tokyo_night`, etc. are accepted).
/// Raises `UnknownTheme` if the name cannot be resolved.
///
/// # Example
/// ```mbt check
/// test {
///   let svg = try! render_mermaid_with_theme_name(
///     (
///       #|graph TD
///       #|A --> B
///     ),
///     "TOKYO   NIGHT",
///   )
///   assert_true(svg.contains("--bg:#1a1b26"))
/// }
/// ```
pub fn render_mermaid_with_theme_name(
  text : String,
  theme_name : String,
  options? : RenderOptions = RenderOptions::default(),
) -> String raise MermaidError {
  match @themes.theme_by_name(theme_name) {
    Some(colors) => render_mermaid_with_colors(text, colors, options~)
    None => raise UnknownTheme(theme_name)
  }
}

///|
/// Parse Mermaid text and render ASCII/Unicode terminal output.
/// Use `AsciiRenderOptions.use_ascii = true` for pure ASCII glyphs.
///
/// # Example
/// ```mbt check
/// test {
///   let ascii = try! render_mermaid_ascii(
///     (
///       #|graph LR
///       #|A --> B
///     ),
///     options={
///       use_ascii: true,
///       padding_x: 5,
///       padding_y: 5,
///       box_border_padding: 1,
///     },
///   )
///   assert_true(ascii.contains("A"))
///   assert_true(ascii.contains("B"))
/// }
/// ```
pub fn render_mermaid_ascii(
  text : String,
  options? : AsciiRenderOptions = AsciiRenderOptions::default(),
) -> String raise MermaidError {
  let graph = @parser_header_core.parse_mermaid(text)
  @renderer_ascii.render_ascii(graph, options)
}
