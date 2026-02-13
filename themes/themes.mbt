///|
/// Identifier for a built-in color theme.
pub type ThemeName = @themes_core.ThemeName

///|
/// A Shiki-format token color rule for editor theme conversion.
pub type ShikiTokenColor = @themes_core.ShikiTokenColor

///|
/// A Shiki-format theme used to derive diagram colors.
pub type ShikiTheme = @themes_core.ShikiTheme

///|
/// Creates a `ShikiTokenColor` rule for a single scope.
pub fn shiki_token_color(
  scope : String,
  foreground : String?,
) -> ShikiTokenColor {
  @themes_core.shiki_token_color(scope, foreground)
}

///|
/// Creates a `ShikiTokenColor` rule applying to multiple scopes.
pub fn shiki_token_color_many(
  scopes : Array[String],
  foreground : String?,
) -> ShikiTokenColor {
  @themes_core.shiki_token_color_many(scopes, foreground)
}

///|
/// Creates a `ShikiTheme` from type, colors map, and token colors.
pub fn shiki_theme(
  theme_type : String?,
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes_core.shiki_theme(theme_type, colors, token_colors)
}

///|
/// Creates a dark `ShikiTheme` from colors map and token colors.
pub fn shiki_dark_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes_core.shiki_dark_theme(colors, token_colors)
}

///|
/// Creates a light `ShikiTheme` from colors map and token colors.
pub fn shiki_light_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes_core.shiki_light_theme(colors, token_colors)
}

///|
/// Converts a `ShikiTheme` into a `DiagramColors` palette.
pub fn from_shiki_theme(theme : ShikiTheme) -> @model.DiagramColors {
  @themes_core.from_shiki_theme(theme)
}

///|
/// Returns the `DiagramColors` for a built-in theme.
pub fn theme_colors(theme : ThemeName) -> @model.DiagramColors {
  @themes_core.theme_colors(theme)
}

///|
/// Returns all built-in theme names.
pub fn built_in_themes() -> Array[ThemeName] {
  @themes_core.built_in_themes()
}

///|
/// Returns the URL-safe slug string for a theme name.
pub fn theme_slug(theme : ThemeName) -> String {
  @themes_core.theme_slug(theme)
}

///|
/// Returns all built-in theme slugs as strings.
pub fn built_in_theme_slugs() -> Array[String] {
  @themes_core.built_in_theme_slugs()
}

///|
/// Returns all built-in theme slugs as a comma-separated string.
pub fn built_in_theme_slugs_csv() -> String {
  @themes_core.built_in_theme_slugs_csv()
}

///|
/// Returns a map from theme slug to `DiagramColors` for all built-in themes.
pub fn built_in_theme_colors() -> Map[String, @model.DiagramColors] {
  @themes_core.built_in_theme_colors()
}

///|
/// Normalizes a theme name by lowercasing and collapsing separators.
pub fn normalize_theme_name(name : String) -> String {
  @themes_core.normalize_theme_name(name)
}

///|
/// Parses a string into a `ThemeName` if it matches a built-in theme.
pub fn parse_theme_name(name : String) -> ThemeName? {
  @themes_core.parse_theme_name(name)
}

///|
/// Looks up `DiagramColors` by theme name string.
pub fn theme_by_name(name : String) -> @model.DiagramColors? {
  @themes_core.theme_by_name(name)
}

///|
/// Returns true if the given name matches a built-in theme.
pub fn theme_exists(name : String) -> Bool {
  @themes_core.theme_exists(name)
}

///|
/// Returns the canonical slug for a theme name, or `None` if unrecognized.
pub fn canonical_theme_slug(name : String) -> String? {
  @themes_core.canonical_theme_slug(name)
}
