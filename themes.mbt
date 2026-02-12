///|
pub type ThemeName = @themes.ThemeName

///|
pub type ShikiTokenColor = @themes.ShikiTokenColor

///|
pub type ShikiTheme = @themes.ShikiTheme

///|
pub fn shiki_token_color(
  scope : String,
  foreground : String?,
) -> ShikiTokenColor {
  @themes.shiki_token_color(scope, foreground)
}

///|
pub fn shiki_token_color_many(
  scopes : Array[String],
  foreground : String?,
) -> ShikiTokenColor {
  @themes.shiki_token_color_many(scopes, foreground)
}

///|
pub fn shiki_theme(
  theme_type : String?,
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes.shiki_theme(theme_type, colors, token_colors)
}

///|
pub fn shiki_dark_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes.shiki_dark_theme(colors, token_colors)
}

///|
pub fn shiki_light_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes.shiki_light_theme(colors, token_colors)
}

///|
pub fn from_shiki_theme(theme : ShikiTheme) -> DiagramColors {
  @themes.from_shiki_theme(theme)
}

///|
pub fn theme_colors(theme : ThemeName) -> DiagramColors {
  @themes.theme_colors(theme)
}

///|
pub fn theme_slug(theme : ThemeName) -> String {
  @themes.theme_slug(theme)
}

///|
pub fn normalize_theme_name(name : String) -> String {
  @themes.normalize_theme_name(name)
}

///|
pub fn parse_theme_name(name : String) -> ThemeName? {
  @themes.parse_theme_name(name)
}

///|
pub fn theme_by_name(name : String) -> DiagramColors? {
  @themes.theme_by_name(name)
}

///|
pub fn theme_exists(name : String) -> Bool {
  @themes.theme_exists(name)
}

///|
pub fn canonical_theme_slug(name : String) -> String? {
  @themes.canonical_theme_slug(name)
}

///|
pub fn built_in_themes() -> Array[ThemeName] {
  @themes.built_in_themes()
}

///|
pub fn built_in_theme_slugs() -> Array[String] {
  @themes.built_in_theme_slugs()
}

///|
pub fn built_in_theme_slugs_csv() -> String {
  @themes.built_in_theme_slugs_csv()
}

///|
pub fn built_in_theme_colors() -> Map[String, DiagramColors] {
  @themes.built_in_theme_colors()
}
