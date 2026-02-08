///|
pub enum ThemeName {
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
} derive(Eq, Show, ToJson)

///|
pub(all) struct ShikiTokenColor {
  scopes : Array[String]
  foreground : String?
} derive(Eq, Show, ToJson)

///|
pub fn shiki_token_color(
  scope : String,
  foreground : String?,
) -> ShikiTokenColor {
  { scopes: [scope], foreground }
}

///|
pub fn shiki_token_color_many(
  scopes : Array[String],
  foreground : String?,
) -> ShikiTokenColor {
  { scopes, foreground }
}

///|
pub(all) struct ShikiTheme {
  theme_type : String?
  colors : Map[String, String]?
  token_colors : Array[ShikiTokenColor]?
} derive(Eq, Show, ToJson)

///|
pub fn shiki_theme(
  theme_type : String?,
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  { theme_type, colors, token_colors }
}

///|
pub fn shiki_dark_theme(
  colors : Map[String, String]?,
  token_colors : Array[ShikiTokenColor]?,
) -> ShikiTheme {
  shiki_theme(Some("dark"), colors, token_colors)
}

///|
pub fn shiki_light_theme(
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
pub fn from_shiki_theme(theme : ShikiTheme) -> DiagramColors {
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

  {
    bg,
    fg,
    line,
    accent,
    muted,
    surface,
    border,
  }
}

///|
pub fn theme_colors(theme : ThemeName) -> DiagramColors {
  match theme {
    ThemeName::ZincLight =>
      {
        bg: "#FFFFFF",
        fg: "#27272A",
        line: None,
        accent: None,
        muted: None,
        surface: None,
        border: None,
      }
    ThemeName::ZincDark =>
      {
        bg: "#18181B",
        fg: "#FAFAFA",
        line: None,
        accent: None,
        muted: None,
        surface: None,
        border: None,
      }
    ThemeName::TokyoNight =>
      {
        bg: "#1a1b26",
        fg: "#a9b1d6",
        line: Some("#3d59a1"),
        accent: Some("#7aa2f7"),
        muted: Some("#565f89"),
        surface: None,
        border: None,
      }
    ThemeName::TokyoNightStorm =>
      {
        bg: "#24283b",
        fg: "#a9b1d6",
        line: Some("#3d59a1"),
        accent: Some("#7aa2f7"),
        muted: Some("#565f89"),
        surface: None,
        border: None,
      }
    ThemeName::TokyoNightLight =>
      {
        bg: "#d5d6db",
        fg: "#343b58",
        line: Some("#34548a"),
        accent: Some("#34548a"),
        muted: Some("#9699a3"),
        surface: None,
        border: None,
      }
    ThemeName::CatppuccinMocha =>
      {
        bg: "#1e1e2e",
        fg: "#cdd6f4",
        line: Some("#585b70"),
        accent: Some("#cba6f7"),
        muted: Some("#6c7086"),
        surface: None,
        border: None,
      }
    ThemeName::CatppuccinLatte =>
      {
        bg: "#eff1f5",
        fg: "#4c4f69",
        line: Some("#9ca0b0"),
        accent: Some("#8839ef"),
        muted: Some("#9ca0b0"),
        surface: None,
        border: None,
      }
    ThemeName::Nord =>
      {
        bg: "#2e3440",
        fg: "#d8dee9",
        line: Some("#4c566a"),
        accent: Some("#88c0d0"),
        muted: Some("#616e88"),
        surface: None,
        border: None,
      }
    ThemeName::NordLight =>
      {
        bg: "#eceff4",
        fg: "#2e3440",
        line: Some("#aab1c0"),
        accent: Some("#5e81ac"),
        muted: Some("#7b88a1"),
        surface: None,
        border: None,
      }
    ThemeName::Dracula =>
      {
        bg: "#282a36",
        fg: "#f8f8f2",
        line: Some("#6272a4"),
        accent: Some("#bd93f9"),
        muted: Some("#6272a4"),
        surface: None,
        border: None,
      }
    ThemeName::GithubLight =>
      {
        bg: "#ffffff",
        fg: "#1f2328",
        line: Some("#d1d9e0"),
        accent: Some("#0969da"),
        muted: Some("#59636e"),
        surface: None,
        border: None,
      }
    ThemeName::GithubDark =>
      {
        bg: "#0d1117",
        fg: "#e6edf3",
        line: Some("#3d444d"),
        accent: Some("#4493f8"),
        muted: Some("#9198a1"),
        surface: None,
        border: None,
      }
    ThemeName::SolarizedLight =>
      {
        bg: "#fdf6e3",
        fg: "#657b83",
        line: Some("#93a1a1"),
        accent: Some("#268bd2"),
        muted: Some("#93a1a1"),
        surface: None,
        border: None,
      }
    ThemeName::SolarizedDark =>
      {
        bg: "#002b36",
        fg: "#839496",
        line: Some("#586e75"),
        accent: Some("#268bd2"),
        muted: Some("#586e75"),
        surface: None,
        border: None,
      }
    ThemeName::OneDark =>
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
pub fn theme_slug(theme : ThemeName) -> String {
  match theme {
    ThemeName::ZincLight => "zinc-light"
    ThemeName::ZincDark => "zinc-dark"
    ThemeName::TokyoNight => "tokyo-night"
    ThemeName::TokyoNightStorm => "tokyo-night-storm"
    ThemeName::TokyoNightLight => "tokyo-night-light"
    ThemeName::CatppuccinMocha => "catppuccin-mocha"
    ThemeName::CatppuccinLatte => "catppuccin-latte"
    ThemeName::Nord => "nord"
    ThemeName::NordLight => "nord-light"
    ThemeName::Dracula => "dracula"
    ThemeName::GithubLight => "github-light"
    ThemeName::GithubDark => "github-dark"
    ThemeName::SolarizedLight => "solarized-light"
    ThemeName::SolarizedDark => "solarized-dark"
    ThemeName::OneDark => "one-dark"
  }
}

///|
fn normalize_theme_name_input(name : String) -> String {
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
  collapsed
}

///|
pub fn normalize_theme_name(name : String) -> String {
  normalize_theme_name_input(name)
}

///|
pub fn parse_theme_name(name : String) -> ThemeName? {
  match normalize_theme_name_input(name) {
    "zinc-light" => Some(ThemeName::ZincLight)
    "zinc-dark" => Some(ThemeName::ZincDark)
    "tokyo-night" => Some(ThemeName::TokyoNight)
    "tokyo-night-storm" => Some(ThemeName::TokyoNightStorm)
    "tokyo-night-light" => Some(ThemeName::TokyoNightLight)
    "catppuccin-mocha" => Some(ThemeName::CatppuccinMocha)
    "catppuccin-latte" => Some(ThemeName::CatppuccinLatte)
    "nord" => Some(ThemeName::Nord)
    "nord-light" => Some(ThemeName::NordLight)
    "dracula" => Some(ThemeName::Dracula)
    "github-light" => Some(ThemeName::GithubLight)
    "github-dark" => Some(ThemeName::GithubDark)
    "solarized-light" => Some(ThemeName::SolarizedLight)
    "solarized-dark" => Some(ThemeName::SolarizedDark)
    "one-dark" => Some(ThemeName::OneDark)
    _ => None
  }
}

///|
pub fn theme_by_name(name : String) -> DiagramColors? {
  match parse_theme_name(name) {
    Some(theme) => Some(theme_colors(theme))
    None => None
  }
}

///|
pub fn theme_exists(name : String) -> Bool {
  parse_theme_name(name) is Some(_)
}

///|
pub fn canonical_theme_slug(name : String) -> String? {
  match parse_theme_name(name) {
    Some(theme) => Some(theme_slug(theme))
    None => None
  }
}

///|
pub fn built_in_themes() -> Array[ThemeName] {
  [
    ThemeName::ZincLight,
    ThemeName::ZincDark,
    ThemeName::TokyoNight,
    ThemeName::TokyoNightStorm,
    ThemeName::TokyoNightLight,
    ThemeName::CatppuccinMocha,
    ThemeName::CatppuccinLatte,
    ThemeName::Nord,
    ThemeName::NordLight,
    ThemeName::Dracula,
    ThemeName::GithubLight,
    ThemeName::GithubDark,
    ThemeName::SolarizedLight,
    ThemeName::SolarizedDark,
    ThemeName::OneDark,
  ]
}

///|
pub fn built_in_theme_slugs() -> Array[String] {
  built_in_themes().map(theme_slug)
}

///|
pub fn built_in_theme_slugs_csv() -> String {
  built_in_theme_slugs().join(", ")
}

///|
pub fn built_in_theme_colors() -> Map[String, DiagramColors] {
  let themes : Map[String, DiagramColors] = {}
  for theme in built_in_themes() {
    themes[theme_slug(theme)] = theme_colors(theme)
  }
  themes
}
