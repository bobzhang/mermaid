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
      true,
    ),
    true,
  )
}
