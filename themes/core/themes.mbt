///|
/// Built-in theme identifiers for `render_mermaid_with_theme_name`.
enum ThemeName {
  ZincLight
  ZincDark
  TokyoNight
  TokyoNightStorm
  TokyoNightLight
  CatppuccinMocha
  CatppuccinLatte
  Nord
  NordLight
  Dracula
  GithubLight
  GithubDark
  SolarizedLight
  SolarizedDark
  OneDark
}

///|
/// Minimal Shiki token color model used by `from_shiki_theme`.
struct ShikiTokenColor {
  scopes : Array[String]
  foreground : String?
}

///|
/// Helper to construct a token-color entry for one scope.
fn shiki_token_color(scope : String, foreground : String?) -> ShikiTokenColor {
  { scopes: [scope], foreground }
}

///|
/// Helper to construct a token-color entry for multiple scopes.
fn shiki_token_color_many(
  scopes : Array[String],
  foreground : String?,
) -> ShikiTokenColor {
  { scopes, foreground }
}

///|
/// Simplified Shiki-like theme model used to derive `DiagramColors`.
struct ShikiTheme {
  theme_type : String?
  colors : Map[String, String]?
  token_colors : Array[ShikiTokenColor]?
}

///|
/// Build a `ShikiTheme` value.
fn shiki_theme(
  theme_type : String?,
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  { theme_type, colors, token_colors }
}

///|
/// Build a dark `ShikiTheme`.
fn shiki_dark_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  shiki_theme(Some("dark"), colors, token_colors)
}

///|
/// Build a light `ShikiTheme`.
fn shiki_light_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  shiki_theme(Some("light"), colors, token_colors)
}

///|
fn shiki_theme_color(theme : ShikiTheme, key : String) -> String? {
  match theme.colors {
    Some(colors) => colors.get(key)
    None => None
  }
}

///|
fn shiki_token_scope_color(theme : ShikiTheme, scope : String) -> String? {
  match theme.token_colors {
    Some(token_colors) => {
      let mut found : String? = None
      for token in token_colors {
        if found is Some(_) {
          continue
        }
        if token.scopes.contains(scope) {
          match token.foreground {
            Some(color) => found = Some(color)
            None => ()
          }
        }
      }
      found
    }
    None => None
  }
}

///|
/// Convert editor-like theme data to diagram colors.
/// Falls back to sensible light/dark defaults when fields are missing.
fn from_shiki_theme(theme : ShikiTheme) -> DiagramColors {
  let theme_kind = match theme.theme_type {
    Some(kind) => kind.trim().to_string().to_lower()
    None => ""
  }
  let is_dark = theme_kind == "dark"

  let bg = match shiki_theme_color(theme, "editor.background") {
    Some(color) => color
    None => if is_dark { "#1e1e1e" } else { "#ffffff" }
  }
  let fg = match shiki_theme_color(theme, "editor.foreground") {
    Some(color) => color
    None => if is_dark { "#d4d4d4" } else { "#333333" }
  }

  let line = shiki_theme_color(theme, "editorLineNumber.foreground")
  let accent = match shiki_theme_color(theme, "focusBorder") {
    Some(color) => Some(color)
    None => shiki_token_scope_color(theme, "keyword")
  }
  let muted = match shiki_token_scope_color(theme, "comment") {
    Some(color) => Some(color)
    None => line
  }
  let surface = shiki_theme_color(theme, "editor.selectionBackground")
  let border = shiki_theme_color(theme, "editorWidget.border")

  { bg, fg, line, accent, muted, surface, border }
}

///|
/// Return the color palette for a built-in theme.
fn theme_colors(theme : ThemeName) -> DiagramColors {
  match theme {
    ZincLight =>
      {
        bg: "#FFFFFF",
        fg: "#27272A",
        line: None,
        accent: None,
        muted: None,
        surface: None,
        border: None,
      }
    ZincDark =>
      {
        bg: "#18181B",
        fg: "#FAFAFA",
        line: None,
        accent: None,
        muted: None,
        surface: None,
        border: None,
      }
    TokyoNight =>
      {
        bg: "#1a1b26",
        fg: "#a9b1d6",
        line: Some("#3d59a1"),
        accent: Some("#7aa2f7"),
        muted: Some("#565f89"),
        surface: None,
        border: None,
      }
    TokyoNightStorm =>
      {
        bg: "#24283b",
        fg: "#a9b1d6",
        line: Some("#3d59a1"),
        accent: Some("#7aa2f7"),
        muted: Some("#565f89"),
        surface: None,
        border: None,
      }
    TokyoNightLight =>
      {
        bg: "#d5d6db",
        fg: "#343b58",
        line: Some("#34548a"),
        accent: Some("#34548a"),
        muted: Some("#9699a3"),
        surface: None,
        border: None,
      }
    CatppuccinMocha =>
      {
        bg: "#1e1e2e",
        fg: "#cdd6f4",
        line: Some("#585b70"),
        accent: Some("#cba6f7"),
        muted: Some("#6c7086"),
        surface: None,
        border: None,
      }
    CatppuccinLatte =>
      {
        bg: "#eff1f5",
        fg: "#4c4f69",
        line: Some("#9ca0b0"),
        accent: Some("#8839ef"),
        muted: Some("#9ca0b0"),
        surface: None,
        border: None,
      }
    Nord =>
      {
        bg: "#2e3440",
        fg: "#d8dee9",
        line: Some("#4c566a"),
        accent: Some("#88c0d0"),
        muted: Some("#616e88"),
        surface: None,
        border: None,
      }
    NordLight =>
      {
        bg: "#eceff4",
        fg: "#2e3440",
        line: Some("#aab1c0"),
        accent: Some("#5e81ac"),
        muted: Some("#7b88a1"),
        surface: None,
        border: None,
      }
    Dracula =>
      {
        bg: "#282a36",
        fg: "#f8f8f2",
        line: Some("#6272a4"),
        accent: Some("#bd93f9"),
        muted: Some("#6272a4"),
        surface: None,
        border: None,
      }
    GithubLight =>
      {
        bg: "#ffffff",
        fg: "#1f2328",
        line: Some("#d1d9e0"),
        accent: Some("#0969da"),
        muted: Some("#59636e"),
        surface: None,
        border: None,
      }
    GithubDark =>
      {
        bg: "#0d1117",
        fg: "#e6edf3",
        line: Some("#3d444d"),
        accent: Some("#4493f8"),
        muted: Some("#9198a1"),
        surface: None,
        border: None,
      }
    SolarizedLight =>
      {
        bg: "#fdf6e3",
        fg: "#657b83",
        line: Some("#93a1a1"),
        accent: Some("#268bd2"),
        muted: Some("#93a1a1"),
        surface: None,
        border: None,
      }
    SolarizedDark =>
      {
        bg: "#002b36",
        fg: "#839496",
        line: Some("#586e75"),
        accent: Some("#268bd2"),
        muted: Some("#586e75"),
        surface: None,
        border: None,
      }
    OneDark =>
      {
        bg: "#282c34",
        fg: "#abb2bf",
        line: Some("#4b5263"),
        accent: Some("#c678dd"),
        muted: Some("#5c6370"),
        surface: None,
        border: None,
      }
  }
}

///|
/// Return the canonical slug for a built-in theme.
fn theme_slug(theme : ThemeName) -> String {
  match theme {
    ZincLight => "zinc-light"
    ZincDark => "zinc-dark"
    TokyoNight => "tokyo-night"
    TokyoNightStorm => "tokyo-night-storm"
    TokyoNightLight => "tokyo-night-light"
    CatppuccinMocha => "catppuccin-mocha"
    CatppuccinLatte => "catppuccin-latte"
    Nord => "nord"
    NordLight => "nord-light"
    Dracula => "dracula"
    GithubLight => "github-light"
    GithubDark => "github-dark"
    SolarizedLight => "solarized-light"
    SolarizedDark => "solarized-dark"
    OneDark => "one-dark"
  }
}

///|
/// Normalize user theme input:
/// lowercase, spaces/underscores to `-`, collapse repeated separators.
fn normalize_theme_name(name : String) -> String {
  let normalized = name
    .trim()
    .to_string()
    .to_lower()
    .replace_all(old="_", new="-")
    .replace_all(old=" ", new="-")
    .replace_all(old="\t", new="-")
    .replace_all(old="\n", new="-")
    .replace_all(old="\r", new="-")
  let mut collapsed = normalized
  while collapsed.contains("--") {
    collapsed = collapsed.replace_all(old="--", new="-")
  }

  let mut trimmed = collapsed
  while trimmed.has_prefix("-") && trimmed.length() > 0 {
    trimmed = (try! trimmed[1:]).to_string()
  }
  while trimmed.has_suffix("-") && trimmed.length() > 0 {
    trimmed = (try! trimmed[:trimmed.length() - 1]).to_string()
  }

  trimmed
}

///|
/// Parse a user-supplied theme name to a `ThemeName`.
/// Accepts `default` as an alias for `zinc-light`.
///
fn parse_theme_name(name : String) -> ThemeName? {
  match normalize_theme_name(name) {
    "default" => Some(ZincLight)
    "zinc-light" => Some(ZincLight)
    "zinc-dark" => Some(ZincDark)
    "tokyo-night" => Some(TokyoNight)
    "tokyo-night-storm" => Some(TokyoNightStorm)
    "tokyo-night-light" => Some(TokyoNightLight)
    "catppuccin-mocha" => Some(CatppuccinMocha)
    "catppuccin-latte" => Some(CatppuccinLatte)
    "nord" => Some(Nord)
    "nord-light" => Some(NordLight)
    "dracula" => Some(Dracula)
    "github-light" => Some(GithubLight)
    "github-dark" => Some(GithubDark)
    "solarized-light" => Some(SolarizedLight)
    "solarized-dark" => Some(SolarizedDark)
    "one-dark" => Some(OneDark)
    _ => None
  }
}

///|
/// Resolve a user theme name directly to colors.
///
/// # Example
/// ```mbt check
/// test {
///   match theme_by_name("github-dark") {
///     Some(colors) => assert_eq(colors.bg, "#0d1117")
///     None => fail("theme should resolve")
///   }
/// }
/// ```
pub fn theme_by_name(name : String) -> DiagramColors? {
  match parse_theme_name(name) {
    Some(theme) => Some(theme_colors(theme))
    None => None
  }
}

///|
/// Return whether a user theme name resolves to a known built-in theme.
fn theme_exists(name : String) -> Bool {
  parse_theme_name(name) is Some(_)
}

///|
/// Return the canonical slug for a user theme name, if it resolves.
pub fn canonical_theme_slug(name : String) -> String? {
  match parse_theme_name(name) {
    Some(theme) => Some(theme_slug(theme))
    None => None
  }
}

///|
/// Return all built-in themes in stable display order.
fn built_in_themes() -> Array[ThemeName] {
  [
    ZincLight,
    ZincDark,
    TokyoNight,
    TokyoNightStorm,
    TokyoNightLight,
    CatppuccinMocha,
    CatppuccinLatte,
    Nord,
    NordLight,
    Dracula,
    GithubLight,
    GithubDark,
    SolarizedLight,
    SolarizedDark,
    OneDark,
  ]
}

///|
/// Return canonical slugs for all built-in themes.
fn built_in_theme_slugs() -> Array[String] {
  built_in_themes().map(theme_slug)
}

///|
/// Return built-in theme slugs as a comma-separated string.
pub fn built_in_theme_slugs_csv() -> String {
  built_in_theme_slugs().join(", ")
}

///|
/// Return a slug-to-colors map for all built-in themes.
fn built_in_theme_colors() -> Map[String, DiagramColors] {
  let themes : Map[String, DiagramColors] = {}
  for theme in built_in_themes() {
    themes[theme_slug(theme)] = theme_colors(theme)
  }
  themes
}
