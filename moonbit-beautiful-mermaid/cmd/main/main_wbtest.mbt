///|
test "parse_non_negative_int accepts zero and positive integers" {
  assert_eq(parse_non_negative_int("0"), Some(0))
  assert_eq(parse_non_negative_int("1"), Some(1))
  assert_eq(parse_non_negative_int("42"), Some(42))
}

///|
test "parse_non_negative_int rejects negatives and invalid values" {
  assert_eq(parse_non_negative_int("-1"), None)
  assert_eq(parse_non_negative_int("abc"), None)
  assert_eq(parse_non_negative_int(""), None)
}
