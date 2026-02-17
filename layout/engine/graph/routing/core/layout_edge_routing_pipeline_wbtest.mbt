///|
test "routing resolves redirect endpoints only when enabled" {
  let redirects : Map[String, String] = { "SG": "A" }
  assert_eq(resolve_edge_endpoint_id("SG", true, redirects), "A")
  assert_eq(resolve_edge_endpoint_id("SG", false, redirects), "SG")
  assert_eq(resolve_edge_endpoint_id("X", true, redirects), "X")
}
