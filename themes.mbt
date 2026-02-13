/// Identifier for a built-in color theme.
pub type ThemeName = @themes.ThemeName

/// A Shiki-format token color rule for editor theme conversion.
pub type ShikiTokenColor = @themes.ShikiTokenColor

/// A Shiki-format theme used to derive diagram colors.
pub type ShikiTheme = @themes.ShikiTheme

/// Creates a `ShikiTokenColor` rule for a single scope.
pub fn shiki_token_color(
  scope : String,
  foreground : String?,
) -> ShikiTokenColor {
  @themes.shiki_token_color(scope, foreground)
}

/// Creates a `ShikiTokenColor` rule applying to multiple scopes.
pub fn shiki_token_color_many(
  scopes : Array[String],
  foreground : String?,
) -> ShikiTokenColor {
  @themes.shiki_token_color_many(scopes, foreground)
}

/// Creates a `ShikiTheme` from type, colors map, and token colors.
pub fn shiki_theme(
  theme_type : String?,
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes.shiki_theme(theme_type, colors, token_colors)
}

/// Creates a dark `ShikiTheme` from colors map and token colors.
pub fn shiki_dark_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes.shiki_dark_theme(colors, token_colors)
}

/// Creates a light `ShikiTheme` from colors map and token colors.
pub fn shiki_light_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes.shiki_light_theme(colors, token_colors)
}

/// Converts a `ShikiTheme` into a `DiagramColors` palette.
pub fn from_shiki_theme(theme : ShikiTheme) -> DiagramColors {
  @themes.from_shiki_theme(theme)
}

/// Returns the `DiagramColors` for a built-in theme.
pub fn theme_colors(theme : ThemeName) -> DiagramColors {
  @themes.theme_colors(theme)
}

/// Returns the URL-safe slug string for a theme name.
pub fn theme_slug(theme : ThemeName) -> String {
  @themes.theme_slug(theme)
}

/// Normalizes a theme name by lowercasing and collapsing separators.
pub fn normalize_theme_name(name : String) -> String {
  @themes.normalize_theme_name(name)
}

/// Parses a string into a `ThemeName` if it matches a built-in theme.
pub fn parse_theme_name(name : String) -> ThemeName? {
  @themes.parse_theme_name(name)
}

/// Looks up `DiagramColors` by theme name string.
pub fn theme_by_name(name : String) -> DiagramColors? {
  @themes.theme_by_name(name)
}

/// Returns true if the given name matches a built-in theme.
pub fn theme_exists(name : String) -> Bool {
  @themes.theme_exists(name)
}

/// Returns the canonical slug for a theme name, or `None` if unrecognized.
pub fn canonical_theme_slug(name : String) -> String? {
  @themes.canonical_theme_slug(name)
}

/// Returns all built-in theme names.
pub fn built_in_themes() -> Array[ThemeName] {
  @themes.built_in_themes()
}

/// Returns all built-in theme slugs as strings.
pub fn built_in_theme_slugs() -> Array[String] {
  @themes.built_in_theme_slugs()
}

/// Returns all built-in theme slugs as a comma-separated string.
pub fn built_in_theme_slugs_csv() -> String {
  @themes.built_in_theme_slugs_csv()
}

/// Returns a map from theme slug to `DiagramColors` for all built-in themes.
pub fn built_in_theme_colors() -> Map[String, DiagramColors] {
  @themes.built_in_theme_colors()
}
