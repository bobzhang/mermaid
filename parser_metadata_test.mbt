///|
test "Parser captures classDef/class/style metadata" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph TD
      #|A[Start]:::entry --> B[End]
      #|classDef entry fill:#f9f,stroke:#333
      #|class B finish
      #|style A fill:#fff,stroke:#000
    ),
  )

  assert_eq(graph.class_defs.length(), 1)
  assert_eq(graph.class_assignments.length(), 2)
  assert_eq(graph.class_assignments.get("A"), Some("entry"))
  assert_eq(graph.class_assignments.get("B"), Some("finish"))

  match graph.class_defs.get("entry") {
    Some(entry_style) => {
      assert_eq(entry_style.get("fill"), Some("#f9f"))
      assert_eq(entry_style.get("stroke"), Some("#333"))
    }
    None => fail("missing classDef entry")
  }

  match graph.node_styles.get("A") {
    Some(node_style) => {
      assert_eq(node_style.get("fill"), Some("#fff"))
      assert_eq(node_style.get("stroke"), Some("#000"))
    }
    None => fail("missing node style for A")
  }
}

///|
test "Parser applies style to multiple nodes" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph LR
      #|A --> B
      #|style A,B fill:#111,stroke:#222
    ),
  )

  assert_eq(graph.node_styles.length(), 2)
  assert_true(graph.node_styles.get("A") is Some(_))
  assert_true(graph.node_styles.get("B") is Some(_))
}
