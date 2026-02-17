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
      x: 240,
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

  let groups = build_legacy_positioned_groups(
    graph, 40, true, false, false, 130, 90, positioned_nodes, positioned_by_id, positioned_index_by_id,
  )

  assert_eq(groups.length(), 1)
  assert_eq(groups[0].id, "SG")
  assert_true(groups[0].width > 0)
  assert_true(positioned_by_id.contains("SG"))
}
