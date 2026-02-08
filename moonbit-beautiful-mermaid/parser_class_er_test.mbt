///|
test "Parser supports class diagram relationships" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nA <|-- B : inherits\nC ..> D : uses",
  )

  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.nodes.length(), 4)
  assert_eq(graph.edges.length(), 2)

  let first = graph.edges[0]
  assert_eq(first.source, "A")
  assert_eq(first.target, "B")
  assert_eq(first.label, Some("inherits"))
  assert_eq(first.has_arrow_start, true)
  assert_eq(first.has_arrow_end, false)
}

///|
test "Parser supports reversed class relationship operators" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nFlyable <|.. Bird\nEngine --* Car\nDepartment --o University",
  )

  assert_eq(graph.edges.length(), 3)

  let first = graph.edges[0]
  assert_eq(first.source, "Flyable")
  assert_eq(first.target, "Bird")
  assert_eq(first.relation_operator, Some("<|.."))
  assert_true(first.has_arrow_start)
  assert_true(!first.has_arrow_end)

  let second = graph.edges[1]
  assert_eq(second.source, "Engine")
  assert_eq(second.target, "Car")
  assert_eq(second.relation_operator, Some("--*"))
  assert_true(!second.has_arrow_start)
  assert_true(!second.has_arrow_end)

  let third = graph.edges[2]
  assert_eq(third.source, "Department")
  assert_eq(third.target, "University")
  assert_eq(third.relation_operator, Some("--o"))
  assert_true(!third.has_arrow_start)
  assert_true(!third.has_arrow_end)
}

///|
test "Parser accepts class relationships with cardinality tokens" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nCustomer \"1\" --> \"*\" Order : places",
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "Customer")
  assert_eq(edge.target, "Order")
  assert_eq(edge.relation_operator, Some("-->"))
  assert_eq(edge.label, Some("places"))
}

///|
test "Parser accepts class relationships with range cardinality tokens" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nService \"0..1\" ..> \"1..*\" Repository : depends",
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "Service")
  assert_eq(edge.target, "Repository")
  assert_eq(edge.relation_operator, Some("..>"))
  assert_eq(edge.label, Some("depends"))
  assert_eq(edge.style.to_string(), "Dotted")
}

///|
test "Parser captures class members from blocks and property lines" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nclass Animal {\n  +String name\n  +eat() void\n}\nAnimal : +weight int",
  )

  assert_eq(graph.nodes.length(), 1)
  match graph.nodes.get("Animal") {
    Some(node) => {
      assert_eq(node.shape.to_string(), "ClassEntity")
      assert_true(node.label.contains("Animal"))
      assert_true(node.label.contains("+name: String"))
      assert_true(node.label.contains("+eat: void"))
      assert_true(node.label.contains("+int: weight"))
    }
    None => fail("missing class node Animal")
  }
}

///|
test "Parser parses inline class attributes in Type Name form" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nclass Animal\nAnimal : +String name\nAnimal : +int age",
  )

  match graph.nodes.get("Animal") {
    Some(node) => {
      assert_true(node.label.contains("Animal"))
      assert_true(node.label.contains("+name: String"))
      assert_true(node.label.contains("+age: int"))
    }
    None => fail("missing class node Animal")
  }
}

///|
test "Parser captures inline class annotation declarations" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nclass Shape { <<abstract>> }",
  )

  assert_eq(graph.nodes.length(), 1)
  match graph.nodes.get("Shape") {
    Some(node) => {
      assert_eq(node.shape.to_string(), "ClassEntity")
      assert_true(node.label.contains("Shape"))
      assert_true(node.label.contains("<<abstract>>"))
    }
    None => fail("missing class node Shape")
  }
}

///|
test "Parser normalizes class member visibilities including package scope" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "classDiagram\nclass MyClass {\n  +String publicField\n  -int privateField\n  #double protectedField\n  ~bool packageField\n}",
  )

  match graph.nodes.get("MyClass") {
    Some(node) => {
      assert_true(node.label.contains("+publicField: String"))
      assert_true(node.label.contains("-privateField: int"))
      assert_true(node.label.contains("#protectedField: double"))
      assert_true(node.label.contains("~packageField: bool"))
    }
    None => fail("missing class node MyClass")
  }
}

///|
test "Parser supports ER diagram relationships" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nCUSTOMER ||--o{ ORDER : places",
  )

  assert_eq(graph.direction.to_string(), "TD")
  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].source, "CUSTOMER")
  assert_eq(graph.edges[0].target, "ORDER")
  assert_eq(graph.edges[0].label, Some("places"))
  match graph.nodes.get("ORDER") {
    Some(node) => assert_eq(node.shape.to_string(), "ErEntity")
    None => fail("missing entity ORDER")
  }
}

///|
test "Parser captures ER attributes from entity blocks" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nCUSTOMER {\n  string name PK\n  int age\n}",
  )

  match graph.nodes.get("CUSTOMER") {
    Some(node) => {
      assert_true(node.label.contains("CUSTOMER"))
      assert_true(node.label.contains("PK string name"))
      assert_true(node.label.contains("int age"))
    }
    None => fail("missing entity CUSTOMER")
  }
}

///|
test "Parser captures non-identifying ER relationships as dotted" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nUSER ||..o{ LOG : generates",
  )

  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "USER")
  assert_eq(edge.target, "LOG")
  assert_eq(edge.label, Some("generates"))
  assert_eq(edge.style.to_string(), "Dotted")
  assert_eq(edge.relation_operator, Some("||..o{"))
}

///|
test "Parser handles complete ER e-commerce schema" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nCUSTOMER {\n  int id PK\n  string name\n  string email UK\n}\nORDER {\n  int id PK\n  date created\n  int customer_id FK\n}\nLINE_ITEM {\n  int id PK\n  int quantity\n  int order_id FK\n  int product_id FK\n}\nPRODUCT {\n  int id PK\n  string name\n  float price\n}\nCUSTOMER ||--o{ ORDER : places\nORDER ||--|{ LINE_ITEM : contains\nPRODUCT ||--o{ LINE_ITEM : includes",
  )

  assert_eq(graph.nodes.length(), 4)
  assert_eq(graph.edges.length(), 3)

  match graph.nodes.get("CUSTOMER") {
    Some(node) => {
      assert_true(node.label.contains("PK int id"))
      assert_true(node.label.contains("UK string email"))
    }
    None => fail("missing CUSTOMER entity")
  }
  match graph.nodes.get("LINE_ITEM") {
    Some(node) => {
      assert_true(node.label.contains("FK int order_id"))
      assert_true(node.label.contains("FK int product_id"))
    }
    None => fail("missing LINE_ITEM entity")
  }
  assert_eq(graph.edges[0].label, Some("places"))
  assert_eq(graph.edges[1].label, Some("contains"))
  assert_eq(graph.edges[2].label, Some("includes"))
}

///|
test "Parser normalizes ER attributes with keys and quoted comments" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nUSER {\n  string email UK \"user email address\"\n}",
  )

  match graph.nodes.get("USER") {
    Some(node) =>
      assert_true(node.label.contains("UK string email \"user email address\""))
    None => fail("missing USER entity")
  }
}

///|
test "Parser preserves ER attribute quoted comments" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nUSER {\n  string email \"contact address\"\n}",
  )

  match graph.nodes.get("USER") {
    Some(node) => assert_true(node.label.contains("\"contact address\""))
    None => fail("missing USER entity")
  }
}

///|
test "Parser supports mixed ER cardinality operators" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nA |o--|{ B : connects",
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "A")
  assert_eq(edge.target, "B")
  assert_eq(edge.relation_operator, Some("|o--|{"))
  assert_eq(edge.label, Some("connects"))
}

///|
test "Parser supports one-to-one ER cardinality operator" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nPERSON ||--|| PASSPORT : has",
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "PERSON")
  assert_eq(edge.target, "PASSPORT")
  assert_eq(edge.relation_operator, Some("||--||"))
  assert_eq(edge.label, Some("has"))
  assert_eq(edge.style.to_string(), "Solid")
}

///|
test "Parser supports many-to-zero-many ER cardinality operator" {
  let graph = try! @beautiful_mermaid.parse_mermaid(
    "erDiagram\nPRODUCT }|--o{ TAG : has",
  )

  assert_eq(graph.nodes.length(), 2)
  assert_eq(graph.edges.length(), 1)
  let edge = graph.edges[0]
  assert_eq(edge.source, "PRODUCT")
  assert_eq(edge.target, "TAG")
  assert_eq(edge.relation_operator, Some("}|--o{"))
  assert_eq(edge.label, Some("has"))
  assert_eq(edge.style.to_string(), "Solid")
}
