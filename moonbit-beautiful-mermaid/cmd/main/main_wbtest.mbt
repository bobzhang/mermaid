///|
test "parse_non_negative_int accepts zero and positive integers" {
  assert_eq(parse_non_negative_int("0"), Some(0))
  assert_eq(parse_non_negative_int("1"), Some(1))
  assert_eq(parse_non_negative_int("42"), Some(42))
  assert_eq(parse_non_negative_int(" 7 "), Some(7))
}

///|
test "parse_non_negative_int rejects negatives and invalid values" {
  assert_eq(parse_non_negative_int("-1"), None)
  assert_eq(parse_non_negative_int("abc"), None)
  assert_eq(parse_non_negative_int(""), None)
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
