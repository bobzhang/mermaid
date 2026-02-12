///|
struct LayoutStateGridCoord {
  x : Int
  y : Int
} derive(Eq, Show)

///|
struct LayoutStateEdgeDir {
  x : Int
  y : Int
} derive(Eq)

///|
fn layout_state_target_ids(graph : MermaidGraph) -> Map[String, Bool] {
  let target_ids : Map[String, Bool] = {}
  for edge in graph.edges {
    target_ids[edge.target] = true
  }
  target_ids
}

///|
fn layout_state_children_in_order(
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
fn layout_state_nodes_in_definition_order(
  graph : MermaidGraph,
) -> Array[MermaidNode] {
  let nodes : Array[MermaidNode] = []
  for _, node in graph.nodes {
    nodes.push(node)
  }
  nodes
}

///|
fn layout_state_grid_positions(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
) -> Map[String, LayoutStateGridCoord] {
  let positions : Map[String, LayoutStateGridCoord] = {}
  let highest_position_by_level : Map[Int, Int] = {}
  let target_ids = layout_state_target_ids(graph)

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
        for child_id in layout_state_children_in_order(graph, node.id) {
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
fn layout_state_grid_bounds(
  positions : Map[String, LayoutStateGridCoord],
) -> (Int, Int) {
  let mut max_x = 0
  let mut max_y = 0
  for _, position in positions {
    max_x = max_x.max(position.x + 8)
    max_y = max_y.max(position.y + 8)
  }
  (max_x, max_y)
}

///|
fn layout_state_grid_blocked_cells(
  positions : Map[String, LayoutStateGridCoord],
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
fn layout_state_dir_up() -> LayoutStateEdgeDir {
  { x: 1, y: 0 }
}

///|
fn layout_state_dir_down() -> LayoutStateEdgeDir {
  { x: 1, y: 2 }
}

///|
fn layout_state_dir_left() -> LayoutStateEdgeDir {
  { x: 0, y: 1 }
}

///|
fn layout_state_dir_right() -> LayoutStateEdgeDir {
  { x: 2, y: 1 }
}

///|
fn layout_state_dir_upper_right() -> LayoutStateEdgeDir {
  { x: 2, y: 0 }
}

///|
fn layout_state_dir_upper_left() -> LayoutStateEdgeDir {
  { x: 0, y: 0 }
}

///|
fn layout_state_dir_lower_right() -> LayoutStateEdgeDir {
  { x: 2, y: 2 }
}

///|
fn layout_state_dir_lower_left() -> LayoutStateEdgeDir {
  { x: 0, y: 2 }
}

///|
fn layout_state_dir_opposite(
  direction : LayoutStateEdgeDir,
) -> LayoutStateEdgeDir {
  if direction == layout_state_dir_up() {
    return layout_state_dir_down()
  }
  if direction == layout_state_dir_down() {
    return layout_state_dir_up()
  }
  if direction == layout_state_dir_left() {
    return layout_state_dir_right()
  }
  if direction == layout_state_dir_right() {
    return layout_state_dir_left()
  }
  if direction == layout_state_dir_upper_right() {
    return layout_state_dir_lower_left()
  }
  if direction == layout_state_dir_upper_left() {
    return layout_state_dir_lower_right()
  }
  if direction == layout_state_dir_lower_right() {
    return layout_state_dir_upper_left()
  }
  layout_state_dir_upper_right()
}

///|
fn layout_state_determine_direction(
  from : LayoutStateGridCoord,
  to : LayoutStateGridCoord,
) -> LayoutStateEdgeDir {
  if from.x == to.x {
    if from.y < to.y {
      layout_state_dir_down()
    } else {
      layout_state_dir_up()
    }
  } else if from.y == to.y {
    if from.x < to.x {
      layout_state_dir_right()
    } else {
      layout_state_dir_left()
    }
  } else if from.x < to.x {
    if from.y < to.y {
      layout_state_dir_lower_right()
    } else {
      layout_state_dir_upper_right()
    }
  } else if from.y < to.y {
    layout_state_dir_lower_left()
  } else {
    layout_state_dir_upper_left()
  }
}

///|

///|
fn layout_state_determine_start_end_dirs_td(
  from : LayoutStateGridCoord,
  to : LayoutStateGridCoord,
) -> (
  LayoutStateEdgeDir,
  LayoutStateEdgeDir,
  LayoutStateEdgeDir,
  LayoutStateEdgeDir,
) {
  let direction = layout_state_determine_direction(from, to)
  let is_backwards = direction == layout_state_dir_up() ||
    direction == layout_state_dir_upper_left() ||
    direction == layout_state_dir_upper_right()

  if direction == layout_state_dir_lower_right() {
    (
      layout_state_dir_right(),
      layout_state_dir_up(),
      layout_state_dir_down(),
      layout_state_dir_left(),
    )
  } else if direction == layout_state_dir_upper_right() {
    (
      layout_state_dir_right(),
      layout_state_dir_down(),
      layout_state_dir_up(),
      layout_state_dir_left(),
    )
  } else if direction == layout_state_dir_lower_left() {
    (
      layout_state_dir_left(),
      layout_state_dir_up(),
      layout_state_dir_down(),
      layout_state_dir_right(),
    )
  } else if direction == layout_state_dir_upper_left() {
    (
      layout_state_dir_right(),
      layout_state_dir_right(),
      layout_state_dir_up(),
      layout_state_dir_right(),
    )
  } else if is_backwards && direction == layout_state_dir_up() {
    (
      layout_state_dir_right(),
      layout_state_dir_right(),
      layout_state_dir_up(),
      layout_state_dir_down(),
    )
  } else {
    let opposite = layout_state_dir_opposite(direction)
    (direction, opposite, direction, opposite)
  }
}

///|
fn layout_state_grid_coord_with_dir(
  coord : LayoutStateGridCoord,
  direction : LayoutStateEdgeDir,
) -> AsciiGridCoord {
  { x: coord.x + direction.x, y: coord.y + direction.y }
}

///|
fn layout_state_merge_grid_path(
  path : Array[AsciiGridCoord],
) -> Array[AsciiGridCoord] {
  ascii_grid_merge_path(path)
}

///|
fn layout_state_preferred_path(
  start : AsciiGridCoord,
  ending : AsciiGridCoord,
  blocked : Map[String, Bool],
  max_x : Int,
  max_y : Int,
) -> Array[AsciiGridCoord]? {
  match ascii_grid_pathfind(start, ending, blocked, 0, max_x, 0, max_y) {
    Some(path) => Some(layout_state_merge_grid_path(path))
    None => None
  }
}

///|
fn layout_state_pick_shorter_path(
  preferred_path : Array[AsciiGridCoord]?,
  alternative_path : Array[AsciiGridCoord]?,
) -> Array[AsciiGridCoord]? {
  match (preferred_path, alternative_path) {
    (Some(preferred), Some(alternative)) =>
      if preferred.length() <= alternative.length() {
        Some(preferred)
      } else {
        Some(alternative)
      }
    (Some(preferred), None) => Some(preferred)
    (None, Some(alternative)) => Some(alternative)
    (None, None) => None
  }
}

///|
fn layout_state_edge_grid_path_td(
  positions : Map[String, LayoutStateGridCoord],
  blocked : Map[String, Bool],
  max_x : Int,
  max_y : Int,
  source_id : String,
  target_id : String,
) -> Array[AsciiGridCoord]? {
  match (positions.get(source_id), positions.get(target_id)) {
    (Some(source_coord), Some(target_coord)) => {
      let (preferred, preferred_opp, alternative, alternative_opp) = layout_state_determine_start_end_dirs_td(
        source_coord, target_coord,
      )
      let preferred_start = layout_state_grid_coord_with_dir(
        source_coord, preferred,
      )
      let preferred_end = layout_state_grid_coord_with_dir(
        target_coord, preferred_opp,
      )
      let preferred_path = layout_state_preferred_path(
        preferred_start, preferred_end, blocked, max_x, max_y,
      )

      let alternative_start = layout_state_grid_coord_with_dir(
        source_coord, alternative,
      )
      let alternative_end = layout_state_grid_coord_with_dir(
        target_coord, alternative_opp,
      )
      let alternative_path = layout_state_preferred_path(
        alternative_start, alternative_end, blocked, max_x, max_y,
      )
      layout_state_pick_shorter_path(preferred_path, alternative_path)
    }
    _ => None
  }
}
