///|
/// A coordinate on the state diagram layout grid.
pub(all) struct LayoutStateGridCoord {
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
/// Returns graph nodes in their original definition order.
pub fn layout_state_nodes_in_definition_order(
  graph : MermaidGraph,
) -> Array[MermaidNode] {
  let nodes : Array[MermaidNode] = []
  for _, node in graph.nodes {
    nodes.push(node)
  }
  nodes
}

///|
/// Computes grid positions for state diagram nodes.
pub fn layout_state_grid_positions(
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
/// Computes the bounding box of the state diagram grid.
pub fn layout_state_grid_bounds(
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
/// Computes the set of grid cells blocked by node positions.
pub fn layout_state_grid_blocked_cells(
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
fn layout_state_clone_grid_path(
  path : Array[AsciiGridCoord],
) -> Array[AsciiGridCoord] {
  let copied : Array[AsciiGridCoord] = []
  for point in path {
    copied.push(point)
  }
  copied
}

///|
fn layout_state_edge_pair_key(source_id : String, target_id : String) -> String {
  "\{source_id}->\{target_id}"
}

///|
fn layout_state_paths_are_reverse(
  path : Array[AsciiGridCoord],
  reverse_path : Array[AsciiGridCoord],
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
fn layout_state_is_diagonal_edge(
  positions : Map[String, LayoutStateGridCoord],
  source_id : String,
  target_id : String,
) -> Bool {
  match (positions.get(source_id), positions.get(target_id)) {
    (Some(source), Some(target)) => source.x != target.x && source.y != target.y
    _ => false
  }
}

///|
fn layout_state_block_path_inner_cells(
  blocked : Map[String, Bool],
  path : Array[AsciiGridCoord],
) -> Unit {
  if path.length() <= 2 {
    return
  }
  for i in 1..<(path.length() - 1) {
    blocked[ascii_grid_key(path[i])] = true
  }
}

///|
fn layout_state_preferred_path(
  start : AsciiGridCoord,
  ending : AsciiGridCoord,
  blocked : Map[String, Bool],
  max_x : Int,
  max_y : Int,
) -> Array[AsciiGridCoord]? {
  match
    @layout_engine_pathfinder_core.ascii_grid_pathfind(
      start, ending, blocked, 0, max_x, 0, max_y,
    ) {
    Some(path) =>
      Some(@layout_engine_pathfinder_core.ascii_grid_merge_path(path))
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
/// Routes an edge path on the state grid in top-down direction.
pub fn layout_state_edge_grid_path_td(
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

///|
fn layout_state_grid_to_point(
  coord : AsciiGridCoord,
  origin_x : Int,
  origin_y : Int,
  cell_x : Int,
  cell_y : Int,
) -> Point {
  { x: origin_x + coord.x * cell_x, y: origin_y + coord.y * cell_y }
}

///|
fn layout_state_grid_path_to_points(
  path : Array[AsciiGridCoord],
  origin_x : Int,
  origin_y : Int,
  cell_x : Int,
  cell_y : Int,
) -> Array[Point] {
  let points : Array[Point] = []
  for coord in path {
    points.push(
      layout_state_grid_to_point(coord, origin_x, origin_y, cell_x, cell_y),
    )
  }
  points
}

///|
fn layout_state_best_label_segment(points : Array[Point]) -> (Point, Point)? {
  if points.length() < 2 {
    return None
  }
  let mut best_start = points[0]
  let mut best_end = points[1]
  let mut best_length = 0
  for i in 1..<points.length() {
    let start = points[i - 1]
    let ending = points[i]
    let length = (ending.x - start.x).abs() + (ending.y - start.y).abs()
    if length > best_length {
      best_length = length
      best_start = start
      best_end = ending
    }
  }
  Some((best_start, best_end))
}

///|
fn layout_state_label_position(
  points : Array[Point],
  label_slots_by_anchor : Map[String, Int],
) -> Point? {
  match layout_state_best_label_segment(points) {
    Some((start, ending)) => {
      let base = midpoint(start, ending)
      let key = label_anchor_key(base)
      let slot = option_int_or(label_slots_by_anchor.get(key), 0)
      label_slots_by_anchor[key] = slot + 1
      Some({
        x: base.x + label_overlap_offset_x(slot),
        y: base.y + label_overlap_offset(slot),
      })
    }
    None => None
  }
}

///|
fn layout_state_label_position_from_source_segment(
  points : Array[Point],
  label_slots_by_anchor : Map[String, Int],
) -> Point? {
  if points.length() < 2 {
    return None
  }
  let base = midpoint(points[0], points[1])
  let key = label_anchor_key(base)
  let slot = option_int_or(label_slots_by_anchor.get(key), 0)
  label_slots_by_anchor[key] = slot + 1
  Some({
    x: base.x + label_overlap_offset_x(slot),
    y: base.y + label_overlap_offset(slot),
  })
}

///|
fn layout_state_has_labeled_reverse_edge(
  graph : MermaidGraph,
  source_id : String,
  target_id : String,
) -> Bool {
  for edge in graph.edges {
    if edge.source == target_id &&
      edge.target == source_id &&
      edge.label is Some(_) {
      return true
    }
  }
  false
}

///|
fn layout_state_is_back_edge(
  positions : Map[String, LayoutStateGridCoord],
  source_id : String,
  target_id : String,
) -> Bool {
  match (positions.get(source_id), positions.get(target_id)) {
    (Some(source), Some(target)) => source.y > target.y
    _ => false
  }
}

///|
fn layout_state_empty_positioned_graph() -> PositionedGraph {
  {
    width: 0,
    height: 0,
    nodes: [],
    edges: [],
    groups: [],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
}

///|
fn layout_flat_state_graph_for_ascii_grid(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  let nodes_in_order = layout_state_nodes_in_definition_order(graph)
  let grid_positions = layout_state_grid_positions(graph, nodes_in_order)
  if grid_positions.length() == 0 {
    return layout_state_empty_positioned_graph()
  }

  let padding = resolve_padding(options)
  let node_spacing = resolve_node_spacing(options)
  let layer_spacing = resolve_layer_spacing(options)
  let cell_x = (node_spacing / 3).max(54)
  let cell_x_step = cell_x + 12
  let cell_y = (layer_spacing / 4).max(25)
  let origin_x = padding + cell_x_step * 2
  let origin_y = padding + cell_y * 2

  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  for node in nodes_in_order {
    match grid_positions.get(node.id) {
      Some(coord) => {
        let positioned = PositionedNode::{
          id: node.id,
          label: node.label,
          shape: node.shape,
          x: origin_x + (coord.x + 1) * cell_x_step,
          y: origin_y + (coord.y + 1) * cell_y,
          width: cell_x * 2,
          height: cell_y * 2,
          inline_style: resolve_inline_style(graph, node.id),
        }
        positioned_nodes.push(positioned)
        positioned_by_id[node.id] = positioned
      }
      None => ()
    }
  }

  let positioned_groups : Array[PositionedGroup] = []
  let mut empty_group_top = padding
  for subgraph in graph.subgraphs {
    match build_positioned_group(subgraph, positioned_by_id, false, false) {
      Some(group) => positioned_groups.push(group)
      None => {
        let empty_group = build_empty_group_tree_at(
          subgraph, padding, empty_group_top, false, false,
        )
        positioned_groups.push(empty_group)
        empty_group_top = empty_group_top +
          empty_group.height +
          subgraph_group_padding()
      }
    }
  }
  for group in positioned_groups {
    register_group_anchors(group, positioned_by_id, true)
  }

  let blocked = layout_state_grid_blocked_cells(grid_positions)
  let (max_grid_x, max_grid_y) = layout_state_grid_bounds(grid_positions)
  let positioned_edges : Array[PositionedEdge] = []
  let routed_paths_by_pair : Map[String, Array[AsciiGridCoord]] = {}
  let label_slots_by_anchor : Map[String, Int] = {}
  for edge in graph.edges {
    match
      (positioned_by_id.get(edge.source), positioned_by_id.get(edge.target)) {
      (Some(source), Some(target)) => {
        let mut routed_grid_path = layout_state_edge_grid_path_td(
          grid_positions,
          blocked,
          max_grid_x,
          max_grid_y,
          edge.source,
          edge.target,
        )

        let reverse_key = layout_state_edge_pair_key(edge.target, edge.source)
        match (routed_grid_path, routed_paths_by_pair.get(reverse_key)) {
          (Some(path), Some(reverse_path)) =>
            if layout_state_is_diagonal_edge(
                grid_positions,
                edge.source,
                edge.target,
              ) &&
              layout_state_paths_are_reverse(path, reverse_path) {
              let blocked_with_reverse : Map[String, Bool] = {}
              for key, value in blocked {
                blocked_with_reverse[key] = value
              }
              layout_state_block_path_inner_cells(
                blocked_with_reverse, reverse_path,
              )
              match
                layout_state_edge_grid_path_td(
                  grid_positions,
                  blocked_with_reverse,
                  max_grid_x,
                  max_grid_y,
                  edge.source,
                  edge.target,
                ) {
                Some(alternative_path) =>
                  if !layout_state_paths_are_reverse(
                      alternative_path, reverse_path,
                    ) {
                    routed_grid_path = Some(alternative_path)
                  }
                None => ()
              }
            }
          _ => ()
        }

        let edge_key = layout_state_edge_pair_key(edge.source, edge.target)
        let points = match routed_grid_path {
          Some(path) => {
            routed_paths_by_pair[edge_key] = layout_state_clone_grid_path(path)
            if path.length() >= 2 {
              layout_state_grid_path_to_points(
                path, origin_x, origin_y, cell_x_step, cell_y,
              )
            } else {
              edge_points_for(source, target, false, edge.style)
            }
          }
          None => edge_points_for(source, target, false, edge.style)
        }
        let label_position = match edge.label {
          Some(_) =>
            if layout_state_has_labeled_reverse_edge(
                graph,
                edge.source,
                edge.target,
              ) ||
              layout_state_is_back_edge(
                grid_positions,
                edge.source,
                edge.target,
              ) {
              layout_state_label_position_from_source_segment(
                points, label_slots_by_anchor,
              )
            } else {
              layout_state_label_position(points, label_slots_by_anchor)
            }
          None => None
        }
        positioned_edges.push({
          source: edge.source,
          target: edge.target,
          label: edge.label,
          style: edge.style,
          has_arrow_start: edge.has_arrow_start,
          has_arrow_end: edge.has_arrow_end,
          relation_operator: edge.relation_operator,
          points,
          label_position,
        })
      }
      _ => ()
    }
  }

  let mut global_min_x = padding
  let mut global_min_y = padding
  let mut global_max_x = padding
  let mut global_max_y = padding

  for node in positioned_nodes {
    global_min_x = global_min_x.min(node.x - node.width / 2)
    global_min_y = global_min_y.min(node.y - node.height / 2)
    global_max_x = global_max_x.max(node.x + node.width / 2)
    global_max_y = global_max_y.max(node.y + node.height / 2)
  }
  for edge in positioned_edges {
    for point in edge.points {
      global_min_x = global_min_x.min(point.x)
      global_min_y = global_min_y.min(point.y)
      global_max_x = global_max_x.max(point.x)
      global_max_y = global_max_y.max(point.y)
    }
    match edge.label_position {
      Some(position) => {
        global_min_x = global_min_x.min(position.x)
        global_min_y = global_min_y.min(position.y)
        global_max_x = global_max_x.max(position.x)
        global_max_y = global_max_y.max(position.y)
      }
      None => ()
    }
  }
  for group in positioned_groups {
    global_min_x = global_min_x.min(positioned_group_min_x(group))
    global_min_y = global_min_y.min(positioned_group_min_y(group))
    global_max_x = global_max_x.max(positioned_group_max_x(group))
    global_max_y = global_max_y.max(positioned_group_max_y(group))
  }

  let shift_x = if global_min_x < padding { padding - global_min_x } else { 0 }
  let shift_y = if global_min_y < padding { padding - global_min_y } else { 0 }
  if shift_x > 0 || shift_y > 0 {
    for i, node in positioned_nodes {
      positioned_nodes[i] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: node.x + shift_x,
        y: node.y + shift_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
    }
    for i, edge in positioned_edges {
      let shifted_points : Array[Point] = []
      for point in edge.points {
        shifted_points.push({ x: point.x + shift_x, y: point.y + shift_y })
      }
      let shifted_label = match edge.label_position {
        Some(position) =>
          Some(Point::{ x: position.x + shift_x, y: position.y + shift_y })
        None => None
      }
      positioned_edges[i] = {
        source: edge.source,
        target: edge.target,
        label: edge.label,
        style: edge.style,
        has_arrow_start: edge.has_arrow_start,
        has_arrow_end: edge.has_arrow_end,
        relation_operator: edge.relation_operator,
        points: shifted_points,
        label_position: shifted_label,
      }
    }
    for i, group in positioned_groups {
      positioned_groups[i] = shift_positioned_group(group, shift_x, shift_y)
    }
  }

  {
    width: global_max_x + shift_x + padding,
    height: global_max_y + shift_y + padding,
    nodes: positioned_nodes,
    edges: positioned_edges,
    groups: positioned_groups,
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
}
