///|
fn layout_snapshot_optional_text(value : String?) -> String {
  match value {
    Some(text) => text
    None => "-"
  }
}

///|
fn layout_snapshot_optional_point(point : @model.Point?) -> String {
  match point {
    Some(value) => "\{value.x},\{value.y}"
    None => "-"
  }
}

///|
fn collect_group_layout_lines(
  groups : Array[@model.PositionedGroup],
  parent_id : String,
  lines : Array[String],
) -> Unit {
  for group in groups {
    lines.push(
      "group parent=\{parent_id} id=\{group.id} frame=\{group.x},\{group.y},\{group.width},\{group.height} label=\{group.label}",
    )
    collect_group_layout_lines(group.children, group.id, lines)
  }
}

///|
fn layout_snapshot_section(title : String, lines : Array[String]) -> String {
  let sorted = lines.copy()
  sorted.sort()
  let body = if sorted.length() == 0 {
    "(none)"
  } else {
    sorted.iter().join("\n")
  }
  "[\{title}]\n" + body
}

///|
fn find_positioned_node(
  nodes : Array[@model.PositionedNode],
  node_id : String,
) -> @model.PositionedNode raise {
  for node in nodes {
    if node.id == node_id {
      return node
    }
  }
  fail("missing positioned node \{node_id}")
}

///|
fn positioned_graph_layout_snapshot(
  positioned : @model.PositionedGraph,
) -> String {
  let node_lines : Array[String] = []
  for node in positioned.nodes {
    node_lines.push(
      "node id=\{node.id} shape=\{node.shape} center=\{node.x},\{node.y} size=\{node.width}x\{node.height} label=\{node.label}",
    )
  }

  let edge_lines : Array[String] = []
  for edge in positioned.edges {
    let points = edge.points.iter().map(pt => "\{pt.x},\{pt.y}").join(" -> ")
    edge_lines.push(
      "edge \{edge.source}->\{edge.target} label=\{layout_snapshot_optional_text(edge.label)} label_pos=\{layout_snapshot_optional_point(edge.label_position)} points=\{points}",
    )
  }

  let group_lines : Array[String] = []
  collect_group_layout_lines(positioned.groups, "-", group_lines)

  (
    #|[canvas]
    #|width=
  ) +
  positioned.width.to_string() +
  " height=" +
  positioned.height.to_string() +
  "\n\n" +
  layout_snapshot_section("nodes", node_lines) +
  "\n\n" +
  layout_snapshot_section("edges", edge_lines) +
  "\n\n" +
  layout_snapshot_section("groups", group_lines)
}

///|
fn snapshot_layout_only(
  it : @test.Test,
  filename : String,
  input : String,
) -> Unit raise {
  let graph = @parser_header_core.parse_mermaid(input.trim_end().to_string())
  let positioned = @layout.layout_graph(graph, @model.RenderOptions::default())
  let snapshot = positioned_graph_layout_snapshot(positioned)
  it.write(snapshot)
  it.snapshot(filename~)
}

///|
test "Layout snapshot: flowchart nested subgraph geometry" (it : @test.Test) {
  snapshot_layout_only(
    it,
    "layout_flowchart_nested_subgraph.txt",
    (
      #|graph TD
      #|subgraph Pipeline
      #|direction LR
      #|A[Build] --> B[Test] --> C[Package]
      #|end
      #|A --> D[Notify]
    ),
  )
}

///|
test "Layout snapshot: state composite geometry" (it : @test.Test) {
  snapshot_layout_only(
    it,
    "layout_state_composite.txt",
    (
      #|stateDiagram-v2
      #|[*] --> Idle
      #|Idle --> Active : start
      #|state Active {
      #|  direction LR
      #|  Validate --> Commit
      #|  Commit --> Validate : retry
      #|}
      #|Active --> [*]
    ),
  )
}

///|
test "Layout snapshot: complex NFA-like graph geometry" (it : @test.Test) {
  snapshot_layout_only(
    it,
    "layout_nfa_complex.txt",
    (
      #|graph LR
      #|start@{shape: f-circ}
      #|q0@{shape: circ}
      #|q1@{shape: circ}
      #|q2@{shape: circ}
      #|q3@{shape: circ}
      #|q4@{shape: circ}
      #|q5@{shape: circ}
      #|q6@{shape: circ}
      #|q7@{shape: circ}
      #|acc0@{shape: dbl-circ}
      #|acc1@{shape: dbl-circ}
      #|start --- q0
      #|q0 -.-> q1
      #|q0 -.-> q4
      #|q1 -- a --> q2
      #|q2 -->|b| q3
      #|q3 -.-> q6
      #|q4 -- a --> q5
      #|q5 -->|c| q6
      #|q2 & q5 -->|x| q7
      #|q7 -- d --> acc0
      #|q7 -- e --> acc1
      #|q6 -.-> q0
      #|q6 -.-> q7
    ),
  )
}

///|
test "Layout: complex NFA accept nodes keep distinct positions" {
  let graph = @parser_header_core.parse_mermaid(
    (
      #|graph LR
      #|start@{shape: f-circ}
      #|q0@{shape: circ}
      #|q1@{shape: circ}
      #|q2@{shape: circ}
      #|q3@{shape: circ}
      #|q4@{shape: circ}
      #|q5@{shape: circ}
      #|q6@{shape: circ}
      #|q7@{shape: circ}
      #|acc0@{shape: dbl-circ}
      #|acc1@{shape: dbl-circ}
      #|start --- q0
      #|q0 -.-> q1
      #|q0 -.-> q4
      #|q1 -- a --> q2
      #|q2 -->|b| q3
      #|q3 -.-> q6
      #|q4 -- a --> q5
      #|q5 -->|c| q6
      #|q2 & q5 -->|x| q7
      #|q7 -- d --> acc0
      #|q7 -- e --> acc1
      #|q6 -.-> q0
      #|q6 -.-> q7
    ),
  )
  let positioned = @layout.layout_graph(graph, @model.RenderOptions::default())
  let acc0 = find_positioned_node(positioned.nodes, "acc0")
  let acc1 = find_positioned_node(positioned.nodes, "acc1")
  assert_true(acc0.x != acc1.x || acc0.y != acc1.y)
}
