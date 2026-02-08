///|
struct StateGridCoord {
  x : Int
  y : Int
} derive(Eq, Show)

///|
fn state_grid_target_ids(graph : MermaidGraph) -> Map[String, Bool] {
  let target_ids : Map[String, Bool] = {}
  for edge in graph.edges {
    target_ids[edge.target] = true
  }
  target_ids
}

///|
fn state_grid_children_in_order(
  graph : MermaidGraph,
  node_id : String,
) -> Array[String] {
  let children : Array[String] = []
  for edge in graph.edges {
    if edge.source == node_id && !children.contains(edge.target) {
      children.push(edge.target)
    }
  }
  children
}

///|
fn state_grid_positions(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
) -> Map[String, StateGridCoord] {
  let positions : Map[String, StateGridCoord] = {}
  let highest_position_by_level : Map[Int, Int] = {}
  let target_ids = state_grid_target_ids(graph)

  for node in nodes_in_order {
    if target_ids.contains(node.id) {
      continue
    }
    let highest = option_int_or(highest_position_by_level.get(0), 0)
    positions[node.id] = StateGridCoord::{ x: highest, y: 0 }
    highest_position_by_level[0] = highest + 4
  }
  if positions.length() == 0 && nodes_in_order.length() > 0 {
    let first_id = nodes_in_order[0].id
    positions[first_id] = StateGridCoord::{ x: 0, y: 0 }
    highest_position_by_level[0] = 4
  }

  for node in nodes_in_order {
    match positions.get(node.id) {
      Some(position) => {
        let child_level = position.y + 4
        let mut highest = option_int_or(highest_position_by_level.get(child_level), 0)
        for child_id in state_grid_children_in_order(graph, node.id) {
          if positions.contains(child_id) {
            continue
          }
          positions[child_id] = StateGridCoord::{ x: highest, y: child_level }
          highest = highest + 4
        }
        highest_position_by_level[child_level] = highest
      }
      None => ()
    }
  }

  let mut fallback_level = 0
  for node in nodes_in_order {
    if positions.contains(node.id) {
      continue
    }
    let highest = option_int_or(highest_position_by_level.get(fallback_level), 0)
    positions[node.id] = StateGridCoord::{ x: highest, y: fallback_level }
    highest_position_by_level[fallback_level] = highest + 4
    fallback_level = fallback_level + 4
  }

  positions
}

///|
fn state_nodes_in_definition_order(graph : MermaidGraph) -> Array[MermaidNode] {
  let nodes : Array[MermaidNode] = []
  for entry in graph.nodes.to_array() {
    let (_, node) = entry
    nodes.push(node)
  }
  nodes
}

test "state_grid_positions matches lifecycle sample topology" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let positions = state_grid_positions(graph, state_nodes_in_definition_order(graph))

  assert_eq(positions.get("state_start_1"), Some(StateGridCoord::{ x: 0, y: 0 }))
  assert_eq(positions.get("Closed"), Some(StateGridCoord::{ x: 0, y: 4 }))
  assert_eq(positions.get("Connecting"), Some(StateGridCoord::{ x: 0, y: 8 }))
  assert_eq(positions.get("Connected"), Some(StateGridCoord::{ x: 0, y: 12 }))
  assert_eq(positions.get("Disconnecting"), Some(StateGridCoord::{ x: 0, y: 16 }))
  assert_eq(positions.get("Reconnecting"), Some(StateGridCoord::{ x: 4, y: 16 }))
  assert_eq(positions.get("state_end_1"), Some(StateGridCoord::{ x: 4, y: 8 }))
}

///|
test "state_grid_positions matches composite sample topology" {
  let source = "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]"
  let graph = parse_mermaid(source)
  let positions = state_grid_positions(graph, state_nodes_in_definition_order(graph))

  assert_eq(positions.get("state_start_1"), Some(StateGridCoord::{ x: 0, y: 0 }))
  assert_eq(positions.get("Idle"), Some(StateGridCoord::{ x: 0, y: 4 }))
  assert_eq(positions.get("Processing"), Some(StateGridCoord::{ x: 0, y: 8 }))
  assert_eq(positions.get("parse"), Some(StateGridCoord::{ x: 4, y: 0 }))
  assert_eq(positions.get("validate"), Some(StateGridCoord::{ x: 4, y: 4 }))
  assert_eq(positions.get("execute"), Some(StateGridCoord::{ x: 4, y: 8 }))
  assert_eq(positions.get("Complete"), Some(StateGridCoord::{ x: 0, y: 12 }))
  assert_eq(positions.get("Error"), Some(StateGridCoord::{ x: 4, y: 12 }))
  assert_eq(positions.get("state_end_1"), Some(StateGridCoord::{ x: 0, y: 16 }))
}
