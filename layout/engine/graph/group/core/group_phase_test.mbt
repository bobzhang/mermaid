///|
fn test_graph(
  nodes : Map[String, @model.MermaidNode],
  subgraphs : Array[@model.MermaidSubgraph],
) -> @model.MermaidGraph {
  {
    diagram_kind: Flowchart,
    direction: TD,
    nodes,
    edges: [],
    subgraphs,
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn test_positioned_state() -> (
  Array[@model.PositionedNode],
  Map[String, @model.PositionedNode],
  Map[String, Int],
) {
  let positioned_nodes : Array[@model.PositionedNode] = [
    {
      id: "A",
      label: "A",
      shape: Rectangle,
      x: 100,
      y: 100,
      width: 80,
      height: 40,
      inline_style: None,
    },
    {
      id: "B",
      label: "B",
      shape: Rectangle,
      x: 260,
      y: 100,
      width: 80,
      height: 40,
      inline_style: None,
    },
  ]
  let positioned_by_id : Map[String, @model.PositionedNode] = {
    "A": positioned_nodes[0],
    "B": positioned_nodes[1],
  }
  let positioned_index_by_id : Map[String, Int] = { "A": 0, "B": 1 }
  (positioned_nodes, positioned_by_id, positioned_index_by_id)
}

///|
fn test_compact_horizontal_positioned_state() -> (
  Array[@model.PositionedNode],
  Map[String, @model.PositionedNode],
  Map[String, Int],
) {
  let positioned_nodes : Array[@model.PositionedNode] = [
    {
      id: "A",
      label: "A",
      shape: Rectangle,
      x: 100,
      y: 100,
      width: 80,
      height: 40,
      inline_style: None,
    },
    {
      id: "B",
      label: "B",
      shape: Rectangle,
      x: 150,
      y: 100,
      width: 80,
      height: 40,
      inline_style: None,
    },
  ]
  let positioned_by_id : Map[String, @model.PositionedNode] = {
    "A": positioned_nodes[0],
    "B": positioned_nodes[1],
  }
  let positioned_index_by_id : Map[String, Int] = { "A": 0, "B": 1 }
  (positioned_nodes, positioned_by_id, positioned_index_by_id)
}

///|
test "group builds positioned group and registers anchor" {
  let subgraph : @model.MermaidSubgraph = {
    id: "SG",
    label: "Group",
    node_ids: ["A", "B"],
    children: [],
    direction: None,
  }
  let nodes : Map[String, @model.MermaidNode] = {
    "A": { id: "A", label: "A", shape: Rectangle },
    "B": { id: "B", label: "B", shape: Rectangle },
  }
  let graph = test_graph(nodes, [subgraph])
  let (positioned_nodes, positioned_by_id, positioned_index_by_id) = test_positioned_state()

  let groups = build_legacy_positioned_groups(
    graph, 40, true, false, false, false, 130, 90, positioned_nodes, positioned_by_id,
    positioned_index_by_id,
  )

  assert_eq(groups.length(), 1)
  assert_eq(groups[0].id, "SG")
  assert_true(groups[0].width > 0)
  assert_true(positioned_by_id.contains("SG"))
}

///|
test "horizontal dagre parity keeps top-level flow subgraphs unshifted" {
  let first : @model.MermaidSubgraph = {
    id: "SG1",
    label: "First",
    node_ids: ["A"],
    children: [],
    direction: None,
  }
  let second : @model.MermaidSubgraph = {
    id: "SG2",
    label: "Second",
    node_ids: ["B"],
    children: [],
    direction: None,
  }
  let nodes : Map[String, @model.MermaidNode] = {
    "A": { id: "A", label: "A", shape: Rectangle },
    "B": { id: "B", label: "B", shape: Rectangle },
  }
  let graph : @model.MermaidGraph = {
    ..test_graph(nodes, [first, second]),
    direction: LR,
  }

  let (shifted_nodes, shifted_by_id, shifted_indexes) = test_compact_horizontal_positioned_state()
  let shifted_groups = build_legacy_positioned_groups(
    graph, 40, true, false, false, false, 130, 90, shifted_nodes, shifted_by_id,
    shifted_indexes,
  )

  let (parity_nodes, parity_by_id, parity_indexes) = test_compact_horizontal_positioned_state()
  let parity_groups = build_legacy_positioned_groups(
    graph, 40, true, false, false, true, 130, 90, parity_nodes, parity_by_id, parity_indexes,
  )

  assert_eq(shifted_groups.length(), 2)
  assert_eq(parity_groups.length(), 2)
  assert_true(shifted_groups[1].x > parity_groups[1].x)
  assert_true(shifted_nodes[1].x > parity_nodes[1].x)
  assert_eq(
    match shifted_by_id.get("B") {
      Some(node) => node.x
      None => -1
    },
    shifted_nodes[1].x,
  )
  assert_eq(
    match parity_by_id.get("B") {
      Some(node) => node.x
      None => -1
    },
    parity_nodes[1].x,
  )
}

///|
test "non-horizontal dagre parity keeps top-level flow subgraphs unshifted" {
  let first : @model.MermaidSubgraph = {
    id: "SG1",
    label: "First",
    node_ids: ["A"],
    children: [],
    direction: None,
  }
  let second : @model.MermaidSubgraph = {
    id: "SG2",
    label: "Second",
    node_ids: ["B"],
    children: [],
    direction: None,
  }
  let nodes : Map[String, @model.MermaidNode] = {
    "A": { id: "A", label: "A", shape: Rectangle },
    "B": { id: "B", label: "B", shape: Rectangle },
  }
  let graph = test_graph(nodes, [first, second])

  let (shifted_nodes, shifted_by_id, shifted_indexes) = test_positioned_state()
  let shifted_groups = build_legacy_positioned_groups(
    graph, 40, false, false, false, false, 130, 90, shifted_nodes, shifted_by_id,
    shifted_indexes,
  )

  let (parity_nodes, parity_by_id, parity_indexes) = test_positioned_state()
  let parity_groups = build_legacy_positioned_groups(
    graph, 40, false, false, false, true, 130, 90, parity_nodes, parity_by_id, parity_indexes,
  )

  assert_eq(shifted_groups.length(), 2)
  assert_eq(parity_groups.length(), 2)
  assert_true(shifted_groups[1].y > shifted_groups[0].y)
  assert_eq(parity_groups[0].y, parity_groups[1].y)
  assert_true(shifted_nodes[1].y > parity_nodes[1].y)
  assert_eq(
    match shifted_by_id.get("B") {
      Some(node) => node.y
      None => -1
    },
    shifted_nodes[1].y,
  )
  assert_eq(
    match parity_by_id.get("B") {
      Some(node) => node.y
      None => -1
    },
    parity_nodes[1].y,
  )
}
