///|
pub enum ThemeName {
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
pub fn theme_colors(theme : ThemeName) -> DiagramColors {
  match theme {
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
pub fn parse_theme_name(name : String) -> ThemeName? {
  match name.to_lower() {
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
pub fn built_in_themes() -> Array[ThemeName] {
  [
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
