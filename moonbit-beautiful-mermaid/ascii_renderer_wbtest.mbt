///|
test "trim_flow_canvas_output trims outer blank lines and shared indent" {
  let raw = "\n\n   +---+\n   | A |\n   +---+\n\n"
  assert_eq(trim_flow_canvas_output(raw), "+---+\n| A |\n+---+")
}

///|
test "trim_flow_canvas_output preserves relative indentation" {
  let raw = "\n    root\n      child\n"
  assert_eq(trim_flow_canvas_output(raw), "root\n  child")
}

///|
test "trim_flow_canvas_output returns empty for blank canvas text" {
  let raw = "\n   \n\t\n"
  assert_eq(trim_flow_canvas_output(raw), "")
}

///|
test "node_label_for_ascii hides synthetic state pseudostate ids" {
  let nodes : Map[String, MermaidNode] = {}
  nodes["state_start_1"] = MermaidNode::{
    id: "state_start_1",
    label: "",
    shape: NodeShape::StateStart,
  }
  nodes["Idle"] = MermaidNode::{ id: "Idle", label: "Idle", shape: NodeShape::Rounded }

  let graph = MermaidGraph::{
    direction: Direction::TD,
    nodes,
    edges: [],
    subgraphs: [],
    class_defs: {},
    class_assignments: {},
    node_styles: {},
    sequence_actor_order: [],
    sequence_actor_kinds: {},
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }

  assert_eq(node_label_for_ascii(graph, "state_start_1"), "")
  assert_eq(node_label_for_ascii(graph, "Idle"), "Idle")
}
