///|
fn layout_engine_equal(
  left : @model.LayoutEngine,
  right : @model.LayoutEngine,
) -> Bool {
  match (left, right) {
    (Legacy, Legacy) => true
    (DagreParity, DagreParity) => true
    (Elk, Elk) => true
    (ElkLayered, ElkLayered) => true
    _ => false
  }
}

///|
fn assert_layout_engine_option_eq(
  actual : @model.LayoutEngine?,
  expected : @model.LayoutEngine?,
) -> Unit raise {
  match (actual, expected) {
    (None, None) => ()
    (Some(actual_engine), Some(expected_engine)) =>
      assert_true(layout_engine_equal(actual_engine, expected_engine))
    _ => fail("layout engine mismatch")
  }
}

///|
test "parse_non_negative_int accepts zero and positive integers" {
  assert_eq(parse_non_negative_int("0"), Some(0))
  assert_eq(parse_non_negative_int("1"), Some(1))
  assert_eq(parse_non_negative_int("42"), Some(42))
  assert_eq(parse_non_negative_int(" 7 "), Some(7))
  assert_eq(parse_non_negative_int("+9"), Some(9))
}

///|
test "parse_non_negative_int rejects negatives and invalid values" {
  assert_eq(parse_non_negative_int("-1"), None)
  assert_eq(parse_non_negative_int("abc"), None)
  assert_eq(parse_non_negative_int(""), None)
  assert_eq(parse_non_negative_int("   "), None)
}

///|
test "parse_layout_engine accepts supported variants" {
  assert_layout_engine_option_eq(parse_layout_engine("legacy"), Some(Legacy))
  assert_layout_engine_option_eq(
    parse_layout_engine("dagre-parity"),
    Some(DagreParity),
  )
  assert_layout_engine_option_eq(
    parse_layout_engine("DAGRE_PARITY"),
    Some(DagreParity),
  )
  assert_layout_engine_option_eq(
    parse_layout_engine("parity"),
    Some(DagreParity),
  )
  assert_layout_engine_option_eq(parse_layout_engine("elk"), Some(Elk))
  assert_layout_engine_option_eq(parse_layout_engine("ELK"), Some(Elk))
  assert_layout_engine_option_eq(
    parse_layout_engine("elk-layered"),
    Some(ElkLayered),
  )
  assert_layout_engine_option_eq(
    parse_layout_engine("ELK_LAYERED"),
    Some(ElkLayered),
  )
  assert_layout_engine_option_eq(parse_layout_engine(""), None)
  assert_layout_engine_option_eq(parse_layout_engine("experimental"), None)
}

///|
test "ascii_spacing_overridden is false for default spacing values" {
  assert_eq(ascii_spacing_overridden(5, 5, 1), false)
}

///|
test "ascii_spacing_overridden is true when any spacing differs" {
  assert_eq(ascii_spacing_overridden(8, 5, 1), true)
  assert_eq(ascii_spacing_overridden(5, 2, 1), true)
  assert_eq(ascii_spacing_overridden(5, 5, 2), true)
}

///|
test "ascii_spacing_requires_text_mode only errors in svg mode with overrides" {
  assert_eq(ascii_spacing_requires_text_mode(false, 5, 5, 1), false)
  assert_eq(ascii_spacing_requires_text_mode(false, 8, 5, 1), true)
  assert_eq(ascii_spacing_requires_text_mode(true, 8, 5, 1), false)
}

///|
test "text_mode_override maps ascii and unicode flags" {
  assert_eq(text_mode_override("--ascii"), Some(true))
  assert_eq(text_mode_override("--unicode"), Some(false))
  assert_eq(text_mode_override("--theme"), None)
}

///|
test "available_theme_list includes representative built-in slugs" {
  let available = available_theme_list()
  assert_true(available.contains("tokyo-night"))
  assert_true(available.contains("github-dark"))
  assert_true(available.contains("default"))
}

///|
test "theme_by_name handles aliases and normalization" {
  assert_true(@themes.theme_by_name("default") is Some(_))
  assert_true(@themes.theme_by_name("__github_dark__") is Some(_))
  assert_true(@themes.theme_by_name("moonbit-neon") is None)
}

///|
test "available_theme_list remains deduplicated" {
  let items = available_theme_list()
    .split(",")
    .map(item => item.trim().to_string())
    .to_array()
  let seen : Map[String, Bool] = {}
  for item in items {
    assert_true(item != "")
    assert_true(!seen.contains(item))
    seen[item] = true
  }
  assert_true(seen.contains("default"))
  assert_true(seen.contains("zinc-light"))
}

///|
test "svg_options_overridden tracks svg-only flags and spacing options" {
  assert_eq(
    svg_options_overridden(
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      false,
    ),
    false,
  )
  assert_eq(
    svg_options_overridden(
      Some("tokyo-night"),
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      false,
    ),
    true,
  )
  assert_eq(
    svg_options_overridden(
      None,
      Some("Inter"),
      None,
      None,
      Some("#64748b"),
      Some("#38bdf8"),
      None,
      None,
      Some("#334155"),
      None,
      None,
      None,
      None,
      false,
    ),
    true,
  )
  assert_eq(
    svg_options_overridden(
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      Some(20),
      None,
      None,
      None,
      false,
    ),
    true,
  )
  assert_eq(
    svg_options_overridden(
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      true,
    ),
    true,
  )
  assert_eq(
    svg_options_overridden(
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      None,
      Some(DagreParity),
      false,
    ),
    true,
  )
}
