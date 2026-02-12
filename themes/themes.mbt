///|
pub type ThemeName = @themes_core.ThemeName

///|
pub type ShikiTokenColor = @themes_core.ShikiTokenColor

///|
pub type ShikiTheme = @themes_core.ShikiTheme

///|
pub fn shiki_token_color(
  scope : String,
  foreground : String?,
) -> ShikiTokenColor {
  @themes_core.shiki_token_color(scope, foreground)
}

///|
pub fn shiki_token_color_many(
  scopes : Array[String],
  foreground : String?,
) -> ShikiTokenColor {
  @themes_core.shiki_token_color_many(scopes, foreground)
}

///|
pub fn shiki_theme(
  theme_type : String?,
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes_core.shiki_theme(theme_type, colors, token_colors)
}

///|
pub fn shiki_dark_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes_core.shiki_dark_theme(colors, token_colors)
}

///|
pub fn shiki_light_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  @themes_core.shiki_light_theme(colors, token_colors)
}

///|
pub fn from_shiki_theme(theme : ShikiTheme) -> @model.DiagramColors {
  @themes_core.from_shiki_theme(theme)
}

///|
pub fn theme_colors(theme : ThemeName) -> @model.DiagramColors {
  @themes_core.theme_colors(theme)
}

///|
pub fn built_in_themes() -> Array[ThemeName] {
  @themes_core.built_in_themes()
}

///|
pub fn theme_slug(theme : ThemeName) -> String {
  @themes_core.theme_slug(theme)
}

///|
pub fn built_in_theme_slugs() -> Array[String] {
  @themes_core.built_in_theme_slugs()
}

///|
pub fn built_in_theme_slugs_csv() -> String {
  @themes_core.built_in_theme_slugs_csv()
}

///|
pub fn built_in_theme_colors() -> Map[String, @model.DiagramColors] {
  @themes_core.built_in_theme_colors()
}

///|
pub fn normalize_theme_name(name : String) -> String {
  @themes_core.normalize_theme_name(name)
}

///|
pub fn parse_theme_name(name : String) -> ThemeName? {
  @themes_core.parse_theme_name(name)
}

///|
pub fn theme_by_name(name : String) -> @model.DiagramColors? {
  @themes_core.theme_by_name(name)
}

///|
pub fn theme_exists(name : String) -> Bool {
  @themes_core.theme_exists(name)
}

///|
pub fn canonical_theme_slug(name : String) -> String? {
  @themes_core.canonical_theme_slug(name)
}
