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
    positions[node.id] = { x: highest, y: 0 }
    highest_position_by_level[0] = highest + 4
  }
  if positions.length() == 0 && nodes_in_order.length() > 0 {
    let first_id = nodes_in_order[0].id
    positions[first_id] = { x: 0, y: 0 }
    highest_position_by_level[0] = 4
  }

  for node in nodes_in_order {
    match positions.get(node.id) {
      Some(position) => {
        let child_level = position.y + 4
        let mut highest = option_int_or(
          highest_position_by_level.get(child_level),
          0,
        )
        for child_id in state_grid_children_in_order(graph, node.id) {
          if positions.contains(child_id) {
            continue
          }
          positions[child_id] = { x: highest, y: child_level }
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
    let highest = option_int_or(
      highest_position_by_level.get(fallback_level),
      0,
    )
    positions[node.id] = { x: highest, y: fallback_level }
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

///|
test "state_grid_positions matches lifecycle sample topology" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let positions = state_grid_positions(
    graph,
    state_nodes_in_definition_order(graph),
  )

  assert_eq(positions.get("state_start_1"), Some({ x: 0, y: 0 }))
  assert_eq(positions.get("Closed"), Some({ x: 0, y: 4 }))
  assert_eq(positions.get("Connecting"), Some({ x: 0, y: 8 }))
  assert_eq(positions.get("Connected"), Some({ x: 0, y: 12 }))
  assert_eq(positions.get("Disconnecting"), Some({ x: 0, y: 16 }))
  assert_eq(positions.get("Reconnecting"), Some({ x: 4, y: 16 }))
  assert_eq(positions.get("state_end_1"), Some({ x: 4, y: 8 }))
}

///|
test "state_grid_positions matches composite sample topology" {
  let source = "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]"
  let graph = parse_mermaid(source)
  let positions = state_grid_positions(
    graph,
    state_nodes_in_definition_order(graph),
  )

  assert_eq(positions.get("state_start_1"), Some({ x: 0, y: 0 }))
  assert_eq(positions.get("Idle"), Some({ x: 0, y: 4 }))
  assert_eq(positions.get("Processing"), Some({ x: 0, y: 8 }))
  assert_eq(positions.get("parse"), Some({ x: 4, y: 0 }))
  assert_eq(positions.get("validate"), Some({ x: 4, y: 4 }))
  assert_eq(positions.get("execute"), Some({ x: 4, y: 8 }))
  assert_eq(positions.get("Complete"), Some({ x: 0, y: 12 }))
  assert_eq(positions.get("Error"), Some({ x: 4, y: 12 }))
  assert_eq(positions.get("state_end_1"), Some({ x: 0, y: 16 }))
}

///|
struct StateEdgeDir {
  x : Int
  y : Int
} derive(Eq)

///|
fn state_dir_up() -> StateEdgeDir {
  { x: 1, y: 0 }
}

///|
fn state_dir_down() -> StateEdgeDir {
  { x: 1, y: 2 }
}

///|
fn state_dir_left() -> StateEdgeDir {
  { x: 0, y: 1 }
}

///|
fn state_dir_right() -> StateEdgeDir {
  { x: 2, y: 1 }
}

///|
fn state_dir_upper_right() -> StateEdgeDir {
  { x: 2, y: 0 }
}

///|
fn state_dir_upper_left() -> StateEdgeDir {
  { x: 0, y: 0 }
}

///|
fn state_dir_lower_right() -> StateEdgeDir {
  { x: 2, y: 2 }
}

///|
fn state_dir_lower_left() -> StateEdgeDir {
  { x: 0, y: 2 }
}

///|
fn state_dir_opposite(direction : StateEdgeDir) -> StateEdgeDir {
  if direction == state_dir_up() {
    return state_dir_down()
  }
  if direction == state_dir_down() {
    return state_dir_up()
  }
  if direction == state_dir_left() {
    return state_dir_right()
  }
  if direction == state_dir_right() {
    return state_dir_left()
  }
  if direction == state_dir_upper_right() {
    return state_dir_lower_left()
  }
  if direction == state_dir_upper_left() {
    return state_dir_lower_right()
  }
  if direction == state_dir_lower_right() {
    return state_dir_upper_left()
  }
  state_dir_upper_right()
}

///|
fn state_determine_direction(
  from : StateGridCoord,
  to : StateGridCoord,
) -> StateEdgeDir {
  if from.x == to.x {
    if from.y < to.y {
      state_dir_down()
    } else {
      state_dir_up()
    }
  } else if from.y == to.y {
    if from.x < to.x {
      state_dir_right()
    } else {
      state_dir_left()
    }
  } else if from.x < to.x {
    if from.y < to.y {
      state_dir_lower_right()
    } else {
      state_dir_upper_right()
    }
  } else if from.y < to.y {
    state_dir_lower_left()
  } else {
    state_dir_upper_left()
  }
}

///|
fn state_determine_start_end_dirs_td(
  from : StateGridCoord,
  to : StateGridCoord,
) -> (StateEdgeDir, StateEdgeDir, StateEdgeDir, StateEdgeDir) {
  let direction = state_determine_direction(from, to)
  let is_backwards = direction == state_dir_up() ||
    direction == state_dir_upper_left() ||
    direction == state_dir_upper_right()

  if direction == state_dir_lower_right() {
    (state_dir_right(), state_dir_up(), state_dir_down(), state_dir_left())
  } else if direction == state_dir_upper_right() {
    (state_dir_right(), state_dir_down(), state_dir_up(), state_dir_left())
  } else if direction == state_dir_lower_left() {
    (state_dir_left(), state_dir_up(), state_dir_down(), state_dir_right())
  } else if direction == state_dir_upper_left() {
    (state_dir_right(), state_dir_right(), state_dir_up(), state_dir_right())
  } else if is_backwards && direction == state_dir_up() {
    (state_dir_right(), state_dir_right(), state_dir_up(), state_dir_down())
  } else {
    let opposite = state_dir_opposite(direction)
    (direction, opposite, direction, opposite)
  }
}

///|
fn state_grid_coord_with_dir(
  coord : StateGridCoord,
  direction : StateEdgeDir,
) -> AsciiGridCoord {
  { x: coord.x + direction.x, y: coord.y + direction.y }
}

///|
fn state_grid_path_to_text(path : Array[AsciiGridCoord]) -> String {
  let parts : Array[String] = []
  for point in path {
    parts.push("(\{point.x},\{point.y})")
  }
  parts.iter().join(" -> ")
}

///|
fn state_points_are_reverse(
  path : Array[Point],
  reverse_path : Array[Point],
) -> Bool {
  if path.length() != reverse_path.length() {
    return false
  }
  let len = path.length()
  for i in 0..<len {
    if path[i] != reverse_path[len - 1 - i] {
      return false
    }
  }
  true
}

///|
fn merge_state_grid_path(path : Array[AsciiGridCoord]) -> Array[AsciiGridCoord] {
  if path.length() <= 2 {
    return path
  }
  let merged : Array[AsciiGridCoord] = [path[0]]
  for i in 1..<(path.length() - 1) {
    let previous = path[i - 1]
    let current = path[i]
    let next = path[i + 1]
    let previous_dx = current.x - previous.x
    let previous_dy = current.y - previous.y
    let next_dx = next.x - current.x
    let next_dy = next.y - current.y
    if previous_dx == next_dx && previous_dy == next_dy {
      continue
    }
    merged.push(current)
  }
  merged.push(path[path.length() - 1])
  merged
}

///|
fn state_grid_bounds(positions : Map[String, StateGridCoord]) -> (Int, Int) {
  let mut max_x = 0
  let mut max_y = 0
  for _, position in positions {
    max_x = max_x.max(position.x + 8)
    max_y = max_y.max(position.y + 8)
  }
  (max_x, max_y)
}

///|
fn state_grid_blocked_cells(
  positions : Map[String, StateGridCoord],
) -> Map[String, Bool] {
  let blocked : Map[String, Bool] = {}
  for _, position in positions {
    for y in position.y..<(position.y + 3) {
      for x in position.x..<(position.x + 3) {
        blocked[ascii_grid_key({ x, y })] = true
      }
    }
  }
  blocked
}

///|
fn state_edge_path_text_td(
  positions : Map[String, StateGridCoord],
  blocked : Map[String, Bool],
  source_id : String,
  target_id : String,
) -> String {
  let (max_x, max_y) = state_grid_bounds(positions)
  match (positions.get(source_id), positions.get(target_id)) {
    (Some(source_coord), Some(target_coord)) => {
      let (preferred, preferred_opp, alternative, alternative_opp) = state_determine_start_end_dirs_td(
        source_coord, target_coord,
      )

      let preferred_start = state_grid_coord_with_dir(source_coord, preferred)
      let preferred_end = state_grid_coord_with_dir(target_coord, preferred_opp)
      let preferred_path = match
        ascii_grid_pathfind(
          preferred_start, preferred_end, blocked, 0, max_x, 0, max_y,
        ) {
        Some(path) => Some(merge_state_grid_path(path))
        None => None
      }

      let alternative_start = state_grid_coord_with_dir(
        source_coord, alternative,
      )
      let alternative_end = state_grid_coord_with_dir(
        target_coord, alternative_opp,
      )
      let alternative_path = match
        ascii_grid_pathfind(
          alternative_start, alternative_end, blocked, 0, max_x, 0, max_y,
        ) {
        Some(path) => Some(merge_state_grid_path(path))
        None => None
      }

      match (preferred_path, alternative_path) {
        (Some(preferred_value), Some(alternative_value)) =>
          if preferred_value.length() <= alternative_value.length() {
            state_grid_path_to_text(preferred_value)
          } else {
            state_grid_path_to_text(alternative_value)
          }
        (Some(preferred_value), None) =>
          state_grid_path_to_text(preferred_value)
        (None, Some(alternative_value)) =>
          state_grid_path_to_text(alternative_value)
        (None, None) => "NONE"
      }
    }
    _ => "NONE"
  }
}

///|
test "state edge path prototype matches key lifecycle routes" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let positions = state_grid_positions(
    graph,
    state_nodes_in_definition_order(graph),
  )
  let blocked = state_grid_blocked_cells(positions)

  assert_eq(
    state_edge_path_text_td(positions, blocked, "Connected", "Reconnecting"),
    "(2,13) -> (5,13) -> (5,16)",
  )
  let reconnect_closed_path = state_edge_path_text_td(
    positions, blocked, "Reconnecting", "Closed",
  )
  assert_eq(
    reconnect_closed_path, "(5,16) -> (5,15) -> (4,15) -> (4,12) -> (3,12) -> (3,5) -> (2,5)",
  )
  assert_eq(
    state_edge_path_text_td(positions, blocked, "Closed", "state_end_1"),
    "(2,5) -> (5,5) -> (5,8)",
  )
}

///|
test "state flat layout reroutes diagonal reverse edge pair" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let positioned = layout_flat_state_graph_for_ascii_grid(
    graph,
    RenderOptions::default(),
  )

  let mut forward_points : Array[Point] = []
  let mut reverse_points : Array[Point] = []
  for edge in positioned.edges {
    if edge.source == "Connected" && edge.target == "Reconnecting" {
      forward_points = edge.points
    }
    if edge.source == "Reconnecting" && edge.target == "Connected" {
      reverse_points = edge.points
    }
  }

  assert_eq(forward_points.length() > 0, true)
  assert_eq(reverse_points.length() > 0, true)
  assert_eq(state_points_are_reverse(forward_points, reverse_points), false)
}

///|
test "state flat layout places reverse-pair labels near source segments" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let positioned = layout_flat_state_graph_for_ascii_grid(
    graph,
    RenderOptions::default(),
  )

  let mut error_label : Point? = None
  let mut success_label : Point? = None
  for edge in positioned.edges {
    if edge.source == "Connected" &&
      edge.target == "Reconnecting" &&
      edge.label == Some("error") {
      error_label = edge.label_position
    }
    if edge.source == "Reconnecting" &&
      edge.target == "Connected" &&
      edge.label == Some("success") {
      success_label = edge.label_position
    }
  }

  match (error_label, success_label) {
    (Some(error_position), Some(success_position)) => {
      assert_eq(success_position.x > error_position.x, true)
      assert_eq(success_position.y > error_position.y, true)
    }
    _ => fail("expected both reverse-pair label positions to be present")
  }
}

///|
test "state flat layout anchors diagonal back-edge label near source side" {
  let source = "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
  let graph = parse_mermaid(source)
  let positioned = layout_flat_state_graph_for_ascii_grid(
    graph,
    RenderOptions::default(),
  )

  let mut error_label : Point? = None
  let mut max_retries_label : Point? = None
  for edge in positioned.edges {
    if edge.source == "Connected" &&
      edge.target == "Reconnecting" &&
      edge.label == Some("error") {
      error_label = edge.label_position
    }
    if edge.source == "Reconnecting" &&
      edge.target == "Closed" &&
      edge.label == Some("max_retries") {
      max_retries_label = edge.label_position
    }
  }

  match (error_label, max_retries_label) {
    (Some(error_position), Some(max_retries_position)) => {
      assert_eq(max_retries_position.x > error_position.x, true)
      assert_eq(max_retries_position.y > error_position.y, true)
    }
    _ =>
      fail("expected both error and max_retries label positions to be present")
  }
}
