///|

///|
fn label_position_for(edges : Array[PositionedEdge], label : String) -> Point? {
  for edge in edges {
    match (edge.label, edge.label_position) {
      (Some(text), Some(point)) => if text == label { return Some(point) }
      _ => ()
    }
  }
  None
}

///|
fn find_positioned_node(
  nodes : Array[PositionedNode],
  node_id : String,
) -> PositionedNode raise {
  for node in nodes {
    if node.id == node_id {
      return node
    }
  }
  fail("missing positioned node \{node_id}")
}

///|
fn find_positioned_edge(
  edges : Array[PositionedEdge],
  source_id : String,
  target_id : String,
) -> PositionedEdge raise {
  for edge in edges {
    if edge.source == source_id && edge.target == target_id {
      return edge
    }
  }
  fail("missing positioned edge \{source_id} -> \{target_id}")
}

///|
test "Layout invariants: nodes stay inside canvas" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nA[Start] --> B{Check} --> C((Done))",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for node in positioned.nodes {
    assert_true(node.x - node.width / 2 >= 0)
    assert_true(node.y - node.height / 2 >= 0)
    assert_true(node.x + node.width / 2 <= positioned.width)
    assert_true(node.y + node.height / 2 <= positioned.height)
  }
}

///|
test "Layout builds positioned groups for flowchart subgraphs" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph Backend\nA --> B\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let group = positioned.groups[0]
  assert_eq(group.label, "Backend")

  let node_a = find_positioned_node(positioned.nodes, "A")
  let node_b = find_positioned_node(positioned.nodes, "B")

  assert_true(node_a.x - node_a.width / 2 >= group.x)
  assert_true(node_a.y - node_a.height / 2 >= group.y)
  assert_true(node_b.x + node_b.width / 2 <= group.x + group.width)
  assert_true(node_b.y + node_b.height / 2 <= group.y + group.height)
}

///|
test "Layout keeps nested positioned groups inside parent group" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph Outer\nsubgraph Inner\nA --> B\nend\nC --> D\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let outer = positioned.groups[0]
  assert_eq(outer.label, "Outer")
  assert_eq(outer.children.length(), 1)

  let inner = outer.children[0]
  assert_eq(inner.label, "Inner")
  assert_true(inner.x >= outer.x)
  assert_true(inner.y >= outer.y)
  assert_true(inner.x + inner.width <= outer.x + outer.width)
  assert_true(inner.y + inner.height <= outer.y + outer.height)
}

///|
test "Layout flowchart subgraph direction override keeps single-edge axis stable" {
  let base_graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph one\nA --> B\nend",
  )
  let override_graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph one\ndirection LR\nA --> B\nend",
  )

  let base_positioned = layout_graph(base_graph, RenderOptions::default())
  let override_positioned = layout_graph(
    override_graph,
    RenderOptions::default(),
  )

  let base_a = find_positioned_node(base_positioned.nodes, "A")
  let base_b = find_positioned_node(base_positioned.nodes, "B")
  let override_a = find_positioned_node(override_positioned.nodes, "A")
  let override_b = find_positioned_node(override_positioned.nodes, "B")

  let base_dx = (base_b.x - base_a.x).abs()
  let base_dy = (base_b.y - base_a.y).abs()
  let override_dx = (override_b.x - override_a.x).abs()
  let override_dy = (override_b.y - override_a.y).abs()

  assert_true(base_dy > base_dx)
  assert_true(override_dy >= override_dx)

  let base_edge = find_positioned_edge(base_positioned.edges, "A", "B")
  let override_edge = find_positioned_edge(override_positioned.edges, "A", "B")
  let base_edge_dx = (base_edge.points[1].x - base_edge.points[0].x).abs()
  let base_edge_dy = (base_edge.points[1].y - base_edge.points[0].y).abs()
  let override_edge_dx = (override_edge.points[1].x - override_edge.points[0].x).abs()
  let override_edge_dy = (override_edge.points[1].y - override_edge.points[0].y).abs()

  assert_true(base_edge_dy > base_edge_dx)
  assert_true(override_edge_dy >= override_edge_dx)
}

///|
test "Layout state composite direction override changes internal axis" {
  let base_graph = try! @parser.parse_mermaid(
    "stateDiagram-v2\nstate Processing {\n  parse --> validate\n}\n[*] --> Processing\nProcessing --> [*]",
  )
  let override_graph = try! @parser.parse_mermaid(
    "stateDiagram-v2\nstate Processing {\n  direction LR\n  parse --> validate\n}\n[*] --> Processing\nProcessing --> [*]",
  )

  let base_positioned = layout_graph(base_graph, RenderOptions::default())
  let override_positioned = layout_graph(
    override_graph,
    RenderOptions::default(),
  )

  let base_parse = find_positioned_node(base_positioned.nodes, "parse")
  let base_validate = find_positioned_node(base_positioned.nodes, "validate")
  let override_parse = find_positioned_node(override_positioned.nodes, "parse")
  let override_validate = find_positioned_node(
    override_positioned.nodes,
    "validate",
  )

  let base_dx = (base_validate.x - base_parse.x).abs()
  let base_dy = (base_validate.y - base_parse.y).abs()
  let override_dx = (override_validate.x - override_parse.x).abs()
  let override_dy = (override_validate.y - override_parse.y).abs()

  assert_true(base_dy > base_dx)
  assert_true(override_dx > override_dy)

  let base_edge = find_positioned_edge(
    base_positioned.edges,
    "parse",
    "validate",
  )
  let override_edge = find_positioned_edge(
    override_positioned.edges,
    "parse",
    "validate",
  )
  let base_edge_dx = (base_edge.points[1].x - base_edge.points[0].x).abs()
  let base_edge_dy = (base_edge.points[1].y - base_edge.points[0].y).abs()
  let override_edge_dx = (override_edge.points[1].x - override_edge.points[0].x).abs()
  let override_edge_dy = (override_edge.points[1].y - override_edge.points[0].y).abs()

  assert_true(base_edge_dy > base_edge_dx)
  assert_true(override_edge_dx > override_edge_dy)
}

///|
test "Layout ascii state composite keeps node edge targets over group anchors" {
  let graph = try! @parser.parse_mermaid(
    "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]",
  )
  let positioned = layout_graph_for_ascii(graph, RenderOptions::default())

  let processing_edge = find_positioned_edge(
    positioned.edges,
    "Idle",
    "Processing",
  )
  let edge_end = processing_edge.points[processing_edge.points.length() - 1]

  let mut processing_group_x = -1
  for group in positioned.groups {
    if group.id == "Processing" {
      processing_group_x = group.x
      break
    }
  }

  assert_true(processing_group_x >= 0)
  assert_true(edge_end.x < processing_group_x)
}

///|
test "Layout keeps subgraph-defined-first content near top in TD" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph Pipeline\nZZ1[Push Code] --> ZZ2{Tests Pass?}\nZZ2 -->|Yes| ZZ3[Build Image]\nend\nZZ3 --> AA([Deploy])\nAA --> BB{QA?}\nBB -->|Yes| CC((Production))",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let group = positioned.groups[0]
  let deploy = find_positioned_node(positioned.nodes, "AA")

  let group_bottom = group.y + group.height
  let deploy_top = deploy.y - deploy.height / 2
  assert_true(group_bottom <= deploy_top)
}

///|
test "Layout subgraph direction override arranges child subgraphs horizontally" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph Outer\ndirection LR\nsubgraph Left\nA --> B\nend\nsubgraph Right\nC --> D\nend\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let outer = positioned.groups[0]
  assert_eq(outer.children.length(), 2)
  let left_group = outer.children[0]
  let right_group = outer.children[1]

  assert_true(right_group.x > left_group.x + left_group.width)
  assert_true((right_group.y - left_group.y).abs() <= left_group.height)
}

///|
test "Layout subgraph direction override arranges empty child subgraphs horizontally" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nsubgraph Outer\ndirection LR\nsubgraph Left\nend\nsubgraph Right\nend\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.groups.length(), 1)
  let outer = positioned.groups[0]
  assert_eq(outer.children.length(), 2)
  let left_group = outer.children[0]
  let right_group = outer.children[1]

  assert_true(right_group.x > left_group.x + left_group.width)
  assert_true((right_group.y - left_group.y).abs() <= left_group.height)
}

///|
test "Layout invariants: edges have endpoints and labels have positions" {
  let graph = try! @parser.parse_mermaid("graph LR\nA -->|yes| B\nB -.- C")
  let positioned = layout_graph(graph, RenderOptions::default())

  for edge in positioned.edges {
    assert_true(edge.points.length() >= 2)
    match edge.label {
      Some(_) => assert_true(edge.label_position is Some(_))
      None => assert_true(edge.label_position is None)
    }
  }
}

///|
test "Layout invariants: LR is wider, TD is taller" {
  let lr_graph = try! @parser.parse_mermaid("graph LR\nA --> B --> C")
  let td_graph = try! @parser.parse_mermaid("graph TD\nA --> B --> C")

  let lr_layout = layout_graph(lr_graph, RenderOptions::default())
  let td_layout = layout_graph(td_graph, RenderOptions::default())

  assert_true(lr_layout.width > td_layout.width)
  assert_true(td_layout.height > lr_layout.height)
}

///|
test "Layout RL reverses horizontal node ordering and edge direction" {
  let rl_graph = try! @parser.parse_mermaid("graph RL\nA --> B --> C")
  let positioned = layout_graph(rl_graph, RenderOptions::default())

  let node_a = find_positioned_node(positioned.nodes, "A")
  let node_b = find_positioned_node(positioned.nodes, "B")
  let node_c = find_positioned_node(positioned.nodes, "C")

  assert_true(node_a.x > node_b.x)
  assert_true(node_b.x > node_c.x)

  let edge_ab = find_positioned_edge(positioned.edges, "A", "B")
  let edge_bc = find_positioned_edge(positioned.edges, "B", "C")
  assert_true(edge_ab.points[0].x > edge_ab.points[1].x)
  assert_true(edge_bc.points[0].x > edge_bc.points[1].x)
}

///|
test "Layout BT reverses vertical node ordering and edge direction" {
  let bt_graph = try! @parser.parse_mermaid("graph BT\nA --> B --> C")
  let positioned = layout_graph(bt_graph, RenderOptions::default())

  let node_a = find_positioned_node(positioned.nodes, "A")
  let node_b = find_positioned_node(positioned.nodes, "B")
  let node_c = find_positioned_node(positioned.nodes, "C")

  assert_true(node_a.y > node_b.y)
  assert_true(node_b.y > node_c.y)

  let edge_ab = find_positioned_edge(positioned.edges, "A", "B")
  let edge_bc = find_positioned_edge(positioned.edges, "B", "C")
  assert_true(edge_ab.points[0].y > edge_ab.points[1].y)
  assert_true(edge_bc.points[0].y > edge_bc.points[1].y)
}

///|
test "Layout resolves inline styles with node override precedence" {
  let graph = try! @parser.parse_mermaid(
    "graph TD\nA[Start]:::entry --> B[End]\nclassDef entry fill:#f9f,stroke:#333,color:#111\nstyle A stroke:#000,color:#fff",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let mut style_a : Map[String, String]? = None
  let mut style_b : Map[String, String]? = None

  for node in positioned.nodes {
    if node.id == "A" {
      style_a = node.inline_style
    }
    if node.id == "B" {
      style_b = node.inline_style
    }
  }

  match style_a {
    Some(style) => {
      assert_eq(style.get("fill"), Some("#f9f"))
      assert_eq(style.get("stroke"), Some("#000"))
      assert_eq(style.get("color"), Some("#fff"))
    }
    None => fail("missing inline style for A")
  }
  assert_true(style_b is None)
}

///|
test "Layout sequence messages are vertically separated" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nAlice->>Bob: Hello\nBob-->>Alice: Hi",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 2)
  let first_y = positioned.edges[0].points[0].y
  let second_y = positioned.edges[1].points[0].y
  assert_true(second_y > first_y)
}

///|
test "Layout sequence adds block and divider spacing" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Login\nalt Success\nB-->>A: 200\nelse Failure\nB-->>A: 500\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.edges.length(), 3)
  assert_eq(positioned.sequence_blocks.length(), 1)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 64)
  assert_true(positioned.sequence_blocks[0].dividers.length() == 1)
}

///|
test "Layout sequence includes notes and activation bars" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nactor U as User\nparticipant S as Server\nU->>+S: Request\nNote right of S: Process\nS-->>-U: Response",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_notes.length() == 1)
  assert_true(positioned.sequence_activations.length() == 1)
  assert_true(positioned.sequence_lifelines.length() == 2)
  assert_true(
    positioned.sequence_activations[0].bottom_y >
    positioned.sequence_activations[0].top_y,
  )
}

///|
test "Layout sequence increases divider offset on horizontal label overlap" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nC->>S: Login\nalt Valid credentials\nS-->>C: 200 OK\nelse Bad\nS-->>C: 401\nelse Account locked\nS-->>C: 403 Forbidden\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.sequence_blocks[0].dividers.length() == 2)
  let first_divider = positioned.sequence_blocks[0].dividers[0]
  let second_divider = positioned.sequence_blocks[0].dividers[1]

  let first_message_y = positioned.edges[2].points[0].y
  let second_message_y = positioned.edges[3].points[0].y

  assert_eq(first_message_y - first_divider.y, 28)
  assert_eq(second_message_y - second_divider.y, 36)
}

///|
test "Layout sequence ignores standalone activate/deactivate commands" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nparticipant A\nparticipant B\nactivate A\nA->>B: Work\ndeactivate A",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_activations.length() == 0)
}

///|
test "Layout sequence keeps block header tab above first in-block message label" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Before\nloop Repeat\nA->>B: Inside\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.edges.length() == 2)

  let block = positioned.sequence_blocks[0]
  let first_in_block_message_y = positioned.edges[1].points[0].y
  let tab_bottom = block.y + 18
  let message_label_y = first_in_block_message_y - 6

  assert_true(tab_bottom < message_label_y)
  assert_true(message_label_y - tab_bottom >= 10)
}

///|
test "Layout sequence keeps block header below previous message arrow" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Previous\nalt Valid\nB->>A: Response\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.edges.length() == 2)

  let previous_message_y = positioned.edges[0].points[0].y
  let block_top = positioned.sequence_blocks[0].y

  assert_true(previous_message_y < block_top)
  assert_true(block_top - previous_message_y >= 20)
}

///|
test "Layout sequence keeps divider label above following message label" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Login\nalt Success\nB->>A: 200\nelse Failure\nB->>A: 500\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider = block.dividers[0]
  let next_message_y = positioned.edges[2].points[0].y
  let divider_label_bottom = divider.y + 14
  let message_label_y = next_message_y - 6

  assert_true(divider_label_bottom < message_label_y)
  assert_true(message_label_y - divider_label_bottom >= 2)
}

///|
test "Layout sequence ignores activation commands with self messages" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nparticipant A\nactivate A\nA->>A: Think\ndeactivate A",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 1)
  assert_true(positioned.sequence_activations.length() == 0)
  assert_true(positioned.edges[0].points.length() >= 4)
}

///|
test "Layout sequence height increases with block header extra spacing" {
  let plain_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: One\nB->>A: Two\nA->>B: Three",
  )
  let block_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: One\nloop Repeat\nB->>A: Two\nend\nA->>B: Three",
  )

  let plain_positioned = layout_graph(plain_graph, RenderOptions::default())
  let block_positioned = layout_graph(block_graph, RenderOptions::default())

  assert_true(block_positioned.height > plain_positioned.height)
  assert_eq(block_positioned.height - plain_positioned.height, 28)
}

///|
test "Layout sequence height increases with divider extra spacing" {
  let no_divider_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: M1\nB->>A: M2\nA->>B: M3\nB->>A: M4",
  )
  let with_divider_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: M1\nalt Case1\nB->>A: M2\nelse Case2\nA->>B: M3\nelse Case3\nB->>A: M4\nend",
  )

  let no_divider_positioned = layout_graph(
    no_divider_graph,
    RenderOptions::default(),
  )
  let with_divider_positioned = layout_graph(
    with_divider_graph,
    RenderOptions::default(),
  )

  assert_true(with_divider_positioned.height > no_divider_positioned.height)
  assert_eq(with_divider_positioned.height - no_divider_positioned.height, 76)
}

///|
test "Layout sequence block top stays above first in-block message by pad" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Before\nloop Retry\nA->>B: Inside\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  assert_true(positioned.edges.length() == 2)

  let block = positioned.sequence_blocks[0]
  let first_in_block_message_y = positioned.edges[1].points[0].y

  assert_true(block.y < first_in_block_message_y)
  assert_eq(first_in_block_message_y - block.y, 40)
}

///|
test "Layout sequence divider row is between adjacent messages" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Login\nalt Success\nB->>A: 200\nelse Failure\nB->>A: 500\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider_y = block.dividers[0].y
  let before_divider_message_y = positioned.edges[1].points[0].y
  let after_divider_message_y = positioned.edges[2].points[0].y

  assert_true(divider_y > before_divider_message_y)
  assert_true(divider_y < after_divider_message_y)
}

///|
test "Layout sequence block height encloses in-block messages" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Before\nalt Yes\nB->>A: Response 1\nelse No\nB->>A: Response 2\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(positioned.edges.length() == 3)

  let first_in_block_message_y = positioned.edges[1].points[0].y
  let last_in_block_message_y = positioned.edges[2].points[0].y

  assert_true(block.y < first_in_block_message_y)
  assert_true(block.y + block.height > last_in_block_message_y)
}

///|
test "Layout sequence base spacing is uniform without blocks" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: First\nB->>A: Second\nA->>B: Third",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 3)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 40)
  assert_eq(y2 - y1, 40)
}

///|
test "Layout sequence spacing after block returns to base row height" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Before\nloop Retry\nA->>B: Attempt\nend\nA->>B: After",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 3)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 40)
}

///|
test "Layout sequence multiple dividers each add divider extra spacing" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nC->>S: Login\nalt Valid\nS-->>C: 200\nelse Invalid\nS-->>C: 401\nelse Locked\nS-->>C: 403\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 4)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  let y3 = positioned.edges[3].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 64)
  assert_eq(y3 - y2, 64)
}

///|
test "Layout sequence par divider spacing matches alt divider spacing" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nG->>A: Validate\npar Fetch user\nG->>U: Get user\nand Fetch orders\nG->>O: Get orders\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 3)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  let y2 = positioned.edges[2].points[0].y
  assert_eq(y1 - y0, 68)
  assert_eq(y2 - y1, 64)
}

///|
test "Layout sequence note right of last actor stays within diagram bounds" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote right of B: Right-side note\nB-->>A: Hi",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout sequence note left of first actor stays within diagram bounds" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote left of A: Left-side note\nB-->>A: Hi",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout sequence notes on both sides stay within diagram bounds" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote left of A: Left note\nNote right of B: Right note\nB-->>A: Hi",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_eq(positioned.sequence_notes.length(), 2)
  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout state cycle offsets opposite-direction edge labels" {
  let graph = try! @parser.parse_mermaid(
    "stateDiagram-v2\n[*] --> Ready\nReady --> Running : start\nRunning --> Paused : pause\nPaused --> Running : resume\nRunning --> Stopped : stop\nStopped --> [*]",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let pause_label = label_position_for(positioned.edges, "pause")
  let resumed_label = label_position_for(positioned.edges, "resume")

  match (pause_label, resumed_label) {
    (Some(pause), Some(resumed)) => {
      assert_true(pause.x != resumed.x || pause.y != resumed.y)
      assert_true(
        (pause.x - resumed.x).abs() >= 8 || (pause.y - resumed.y).abs() >= 8,
      )
    }
    _ => fail("missing pause/resume label positions")
  }
}

///|
test "Layout sequence note over actor stays within diagram bounds" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote over A: Centered note\nB-->>A: Hi",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  for note in positioned.sequence_notes {
    assert_true(note.x >= 0)
    assert_true(note.x + note.width <= positioned.width)
  }
}

///|
test "Layout sequence shift preserves actor message and lifeline alignment" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote left of A: This shifts everything\nB-->>A: Reply",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  let actor_node : Map[String, PositionedNode] = {}
  for node in positioned.nodes {
    actor_node[node.id] = node
  }

  for edge in positioned.edges {
    match (actor_node.get(edge.source), actor_node.get(edge.target)) {
      (Some(source), Some(target)) => {
        let start_expected = source.x +
          (if target.x > source.x {
            source.width / 2
          } else {
            -source.width / 2
          })
        let end_expected = target.x +
          (if target.x > source.x {
            -target.width / 2
          } else {
            target.width / 2
          })
        assert_eq(edge.points[0].x, start_expected)
        assert_eq(edge.points[edge.points.length() - 1].x, end_expected)
      }
      _ => fail("missing source/target actor in positioned nodes")
    }
  }

  for lifeline in positioned.sequence_lifelines {
    match actor_node.get(lifeline.actor_id) {
      Some(node) => assert_eq(lifeline.x, node.x)
      None => fail("missing actor for lifeline")
    }
  }
}

///|
test "Layout sequence without notes has no extra horizontal shift" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nB-->>A: Hi",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.nodes.length() >= 1)
  let first = positioned.nodes[0]
  let first_left = first.x - first.width / 2
  assert_eq(first_left, resolve_padding(RenderOptions::default()))
}

///|
test "Layout sequence right-side note expands diagram width" {
  let without_note_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nB-->>A: Hi",
  )
  let with_note_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote right of B: Extra wide note text here\nB-->>A: Hi",
  )

  let without_note = layout_graph(without_note_graph, RenderOptions::default())
  let with_note = layout_graph(with_note_graph, RenderOptions::default())

  assert_true(with_note.width > without_note.width)
}

///|
test "Layout sequence left-side note shifts actors right" {
  let without_note_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nB-->>A: Hi",
  )
  let with_note_graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Hello\nNote left of A: Left note\nB-->>A: Hi",
  )

  let without_note = layout_graph(without_note_graph, RenderOptions::default())
  let with_note = layout_graph(with_note_graph, RenderOptions::default())

  assert_true(without_note.nodes.length() >= 1)
  assert_true(with_note.nodes.length() >= 1)
  assert_true(with_note.nodes[0].x > without_note.nodes[0].x)
  assert_true(with_note.sequence_notes.length() >= 1)
  assert_true(with_note.sequence_notes[0].x >= 0)
}

///|
test "Layout sequence opt block header adds extra spacing" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Request\nopt Cache available\nB-->>A: Cached response\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 2)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  assert_eq(y1 - y0, 68)
}

///|
test "Layout sequence critical block header adds extra spacing" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>DB: BEGIN\ncritical Transaction\nA->>DB: UPDATE\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.edges.length() == 2)
  let y0 = positioned.edges[0].points[0].y
  let y1 = positioned.edges[1].points[0].y
  assert_eq(y1 - y0, 68)
}

///|
test "Layout sequence multiple dividers are between corresponding messages" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nC->>S: Login\nalt Valid\nS-->>C: 200\nelse Invalid\nS-->>C: 401\nelse Locked\nS-->>C: 403\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 2)
  assert_true(positioned.edges.length() == 4)

  assert_true(block.dividers[0].y > positioned.edges[1].points[0].y)
  assert_true(block.dividers[0].y < positioned.edges[2].points[0].y)
  assert_true(block.dividers[1].y > positioned.edges[2].points[0].y)
  assert_true(block.dividers[1].y < positioned.edges[3].points[0].y)
}

///|
test "Layout sequence divider line stays below previous message arrow" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Login\nalt Success\nB->>A: 200 OK\nelse Failure\nB->>A: 500 Error\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider_y = block.dividers[0].y
  let previous_message_y = positioned.edges[1].points[0].y
  assert_true(previous_message_y < divider_y)
  assert_true(divider_y - previous_message_y >= 10)
}

///|
test "Layout sequence three-branch alt keeps header and divider clearance" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nC->>S: Login\nalt Valid\nS-->>C: 200\nelse Invalid\nS-->>C: 401\nelse Locked\nS-->>C: 403\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 2)
  assert_true(positioned.edges.length() == 4)

  let tab_bottom = block.y + 18
  let first_in_block_label_y = positioned.edges[1].points[0].y - 6
  assert_true(tab_bottom < first_in_block_label_y)

  for i in 0..<block.dividers.length() {
    let divider = block.dividers[i]
    let message_after = positioned.edges[i + 2]
    let divider_label_bottom = divider.y + 14
    let message_label_y = message_after.points[0].y - 6
    assert_true(divider_label_bottom < message_label_y)
  }

  assert_true(block.dividers[0].y > positioned.edges[1].points[0].y)
  assert_true(block.dividers[1].y > positioned.edges[2].points[0].y)
}

///|
test "Layout sequence long divider labels trigger larger offset" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nparticipant C as Client\nparticipant S as Server\nC->>S: Login\nalt Valid credentials\nS-->>C: 200 OK\nelse Account locked\nS-->>C: 403 Forbidden\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider = block.dividers[0]
  let message_after = positioned.edges[2]
  let divider_label_baseline = divider.y + 14
  let message_label_baseline = message_after.points[0].y - 6
  let baseline_clearance = message_label_baseline - divider_label_baseline

  assert_true(baseline_clearance >= 14)
}

///|
test "Layout sequence short divider labels keep default offset" {
  let graph = try! @parser.parse_mermaid(
    "sequenceDiagram\nA->>B: Login\nalt Yes\nB->>A: 200\nelse No\nB->>A: 500\nend",
  )
  let positioned = layout_graph(graph, RenderOptions::default())

  assert_true(positioned.sequence_blocks.length() == 1)
  let block = positioned.sequence_blocks[0]
  assert_true(block.dividers.length() == 1)
  assert_true(positioned.edges.length() == 3)

  let divider = block.dividers[0]
  let message_after = positioned.edges[2]
  let baseline_clearance = message_after.points[0].y - 6 - (divider.y + 14)

  assert_eq(baseline_clearance, 8)
}
