///|
fn resolve_subgraph_layout_direction(
  subgraph_direction : Direction?,
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> (Bool, Bool) {
  match subgraph_direction {
    Some(direction) =>
      (
        layout_direction_is_horizontal(direction),
        layout_direction_is_reverse(direction),
      )
    None => (inherited_horizontal, inherited_reverse)
  }
}

///|
fn merge_style(
  target : Map[String, String],
  style : Map[String, String]?,
) -> Unit {
  match style {
    Some(found) =>
      for entry in found.to_array() {
        let (key, value) = entry
        target[key] = value
      }
    None => ()
  }
}

///|
/// Resolves inline style for a node from class and node-level declarations.
pub fn resolve_inline_style(
  graph : MermaidGraph,
  node_id : String,
) -> Map[String, String]? {
  let resolved : Map[String, String] = {}
  let class_style = match graph.class_assignments.get(node_id) {
    Some(class_name) => graph.class_defs.get(class_name)
    None => None
  }

  merge_style(resolved, class_style)
  merge_style(resolved, graph.node_styles.get(node_id))

  if resolved.length() == 0 {
    None
  } else {
    Some(resolved)
  }
}

///|
/// Resolves edge endpoints through subgraph redirects when enabled.
pub fn resolve_edge_endpoint_id(
  node_id : String,
  use_subgraph_redirects : Bool,
  redirects : Map[String, String],
) -> String {
  if use_subgraph_redirects {
    match redirects.get(node_id) {
      Some(found) => found
      None => node_id
    }
  } else {
    node_id
  }
}

///|
/// Returns true when graph nodes are all sequence participants.
pub fn is_sequence_graph(graph : MermaidGraph) -> Bool {
  let nodes = graph.nodes.values().to_array()
  if nodes.length() == 0 {
    return false
  }
  for node in nodes {
    if node.shape != SequenceParticipant {
      return false
    }
  }
  true
}

///|
/// Returns default padding used around positioned subgraph content.
pub fn subgraph_group_padding() -> Int {
  12
}

///|
fn subgraph_group_header_height() -> Int {
  24
}

///|
fn subgraph_group_min_width(_label : String) -> Int {
  80
}

///|
fn subgraph_group_min_height() -> Int {
  subgraph_group_header_height() + subgraph_group_padding() * 2 + 20
}

///|
fn include_bounds(
  has_bounds : Bool,
  min_left : Int,
  min_top : Int,
  max_right : Int,
  max_bottom : Int,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> (Bool, Int, Int, Int, Int) {
  if has_bounds {
    (
      true,
      min_left.min(left),
      min_top.min(top),
      max_right.max(right),
      max_bottom.max(bottom),
    )
  } else {
    (true, left, top, right, bottom)
  }
}

///|
/// Builds positioned placeholder bounds for an empty subgraph tree.
pub fn build_empty_group_tree_at(
  subgraph : MermaidSubgraph,
  x : Int,
  y : Int,
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> PositionedGroup {
  let (horizontal, reverse) = resolve_subgraph_layout_direction(
    subgraph.direction,
    inherited_horizontal,
    inherited_reverse,
  )
  let group_padding = subgraph_group_padding()
  let header_height = subgraph_group_header_height()
  let children : Array[PositionedGroup] = []
  let child_groups : Array[PositionedGroup] = []
  let mut max_child_right = x
  let mut max_child_bottom = y

  for child_subgraph in subgraph.children {
    let child_group = build_empty_group_tree_at(
      child_subgraph, 0, 0, horizontal, reverse,
    )
    child_groups.push(child_group)
  }

  if child_groups.length() > 0 {
    if horizontal {
      let mut total_width = 0
      let mut max_height = 0
      for child_group in child_groups {
        total_width += child_group.width
        max_height = max_height.max(child_group.height)
      }
      total_width += group_padding * (child_groups.length() - 1)
      let content_left = x + group_padding
      let content_top = y + header_height + group_padding
      let mut left = content_left
      let mut right = content_left + total_width
      for child_group in child_groups {
        let child_x = if reverse { right - child_group.width } else { left }
        let child_y = content_top + (max_height - child_group.height) / 2
        let shifted_group = shift_positioned_group(
          child_group,
          child_x - child_group.x,
          child_y - child_group.y,
        )
        children.push(shifted_group)
        max_child_right = max_child_right.max(
          shifted_group.x + shifted_group.width,
        )
        max_child_bottom = max_child_bottom.max(
          shifted_group.y + shifted_group.height,
        )
        if reverse {
          right = right - child_group.width - group_padding
        } else {
          left = left + child_group.width + group_padding
        }
      }
    } else {
      let mut total_height = 0
      let mut max_width = 0
      for child_group in child_groups {
        total_height += child_group.height
        max_width = max_width.max(child_group.width)
      }
      total_height += group_padding * (child_groups.length() - 1)
      let content_left = x + group_padding
      let content_top = y + header_height + group_padding
      let mut top = content_top
      let mut bottom = content_top + total_height
      for child_group in child_groups {
        let child_x = content_left + (max_width - child_group.width) / 2
        let child_y = if reverse { bottom - child_group.height } else { top }
        let shifted_group = shift_positioned_group(
          child_group,
          child_x - child_group.x,
          child_y - child_group.y,
        )
        children.push(shifted_group)
        max_child_right = max_child_right.max(
          shifted_group.x + shifted_group.width,
        )
        max_child_bottom = max_child_bottom.max(
          shifted_group.y + shifted_group.height,
        )
        if reverse {
          bottom = bottom - child_group.height - group_padding
        } else {
          top = top + child_group.height + group_padding
        }
      }
    }
  }

  let mut width = subgraph_group_min_width(subgraph.label)
  let mut height = subgraph_group_min_height()
  if child_groups.length() > 0 {
    width = width.max(max_child_right - x + group_padding)
    height = height.max(max_child_bottom - y + group_padding)
  }

  { id: subgraph.id, label: subgraph.label, x, y, width, height, children }
}

///|
/// Builds positioned bounds for a subgraph using existing positioned nodes.
pub fn build_positioned_group(
  subgraph : MermaidSubgraph,
  positioned_by_id : Map[String, PositionedNode],
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
) -> PositionedGroup? {
  let (subgraph_horizontal, subgraph_reverse) = resolve_subgraph_layout_direction(
    subgraph.direction,
    inherited_horizontal,
    inherited_reverse,
  )
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  let children : Array[PositionedGroup] = []
  let missing_children : Array[MermaidSubgraph] = []

  for child_subgraph in subgraph.children {
    match
      build_positioned_group(
        child_subgraph, positioned_by_id, subgraph_horizontal, subgraph_reverse,
      ) {
      Some(child_group) => {
        children.push(child_group)
        let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
          has_bounds,
          min_left,
          min_top,
          max_right,
          max_bottom,
          child_group.x,
          child_group.y,
          child_group.x + child_group.width,
          child_group.y + child_group.height,
        )
        has_bounds = next_has
        min_left = next_left
        min_top = next_top
        max_right = next_right
        max_bottom = next_bottom
      }
      None => missing_children.push(child_subgraph)
    }
  }

  for node_id in subgraph.node_ids {
    match positioned_by_id.get(node_id) {
      Some(node) => {
        let node_left = node.x - node.width / 2
        let node_top = node.y - node.height / 2
        let node_right = node.x + node.width / 2
        let node_bottom = node.y + node.height / 2
        let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
          has_bounds, min_left, min_top, max_right, max_bottom, node_left, node_top,
          node_right, node_bottom,
        )
        has_bounds = next_has
        min_left = next_left
        min_top = next_top
        max_right = next_right
        max_bottom = next_bottom
      }
      None => ()
    }
  }

  if !has_bounds {
    return None
  }

  let group_padding = subgraph_group_padding()
  let header_height = subgraph_group_header_height()
  let content_width = max_right - min_left
  let content_height = max_bottom - min_top
  let min_group_width = subgraph_group_min_width(subgraph.label)
  let min_group_height = subgraph_group_min_height()
  let mut width = (content_width + group_padding * 2).max(min_group_width)
  let mut height = (content_height + header_height + group_padding * 2).max(
    min_group_height,
  )
  let x = min_left - group_padding
  let y = min_top - header_height - group_padding
  let mut empty_child_top = y + height + group_padding
  for missing_child in missing_children {
    let child_group = build_empty_group_tree_at(
      missing_child,
      x + group_padding,
      empty_child_top,
      subgraph_horizontal,
      subgraph_reverse,
    )
    children.push(child_group)
    width = width.max(child_group.x + child_group.width - x + group_padding)
    height = height.max(child_group.y + child_group.height - y + group_padding)
    empty_child_top = child_group.y + child_group.height + group_padding
  }

  Some({ id: subgraph.id, label: subgraph.label, x, y, width, height, children })
}

///|
fn shift_positioned_group(
  group : PositionedGroup,
  shift_x : Int,
  shift_y : Int,
) -> PositionedGroup {
  let shifted_children : Array[PositionedGroup] = []
  for child in group.children {
    shifted_children.push(shift_positioned_group(child, shift_x, shift_y))
  }
  {
    id: group.id,
    label: group.label,
    x: group.x + shift_x,
    y: group.y + shift_y,
    width: group.width,
    height: group.height,
    children: shifted_children,
  }
}

///|
fn apply_subgraph_direction_override_to_members(
  node_ids : Array[String],
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Unit {
  let member_indexes : Array[Int] = []
  for node_id in node_ids {
    match positioned_index_by_id.get(node_id) {
      Some(index) => member_indexes.push(index)
      None => ()
    }
  }

  if member_indexes.length() < 2 {
    return
  }

  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  for index in member_indexes {
    let node = positioned_nodes[index]
    let left = node.x - node.width / 2
    let top = node.y - node.height / 2
    let right = node.x + node.width / 2
    let bottom = node.y + node.height / 2
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, left, top, right, bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }

  if !has_bounds {
    return
  }

  if horizontal {
    let mut left = min_left
    let mut right = max_right
    let center_y = (min_top + max_bottom) / 2
    for index in member_indexes {
      let node = positioned_nodes[index]
      let x = if reverse {
        right - node.width / 2
      } else {
        left + node.width / 2
      }
      positioned_nodes[index] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x,
        y: center_y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
      if reverse {
        right = right - node.width - node_spacing
      } else {
        left = left + node.width + node_spacing
      }
    }
  } else {
    let mut top = min_top
    let mut bottom = max_bottom
    let center_x = (min_left + max_right) / 2
    for index in member_indexes {
      let node = positioned_nodes[index]
      let y = if reverse {
        bottom - node.height / 2
      } else {
        top + node.height / 2
      }
      positioned_nodes[index] = {
        id: node.id,
        label: node.label,
        shape: node.shape,
        x: center_x,
        y,
        width: node.width,
        height: node.height,
        inline_style: node.inline_style,
      }
      if reverse {
        bottom = bottom - node.height - layer_spacing
      } else {
        top = top + node.height + layer_spacing
      }
    }
  }
}

///|
priv struct SubgraphMemberBlock {
  node_indexes : Array[Int]
  left : Int
  top : Int
  width : Int
  height : Int
}

///|
fn collect_subgraph_node_indexes(
  subgraph : MermaidSubgraph,
  positioned_index_by_id : Map[String, Int],
  seen_node_ids : Map[String, Bool],
  indexes : Array[Int],
) -> Unit {
  for node_id in subgraph.node_ids {
    if seen_node_ids.contains(node_id) {
      continue
    }
    seen_node_ids[node_id] = true
    match positioned_index_by_id.get(node_id) {
      Some(index) => indexes.push(index)
      None => ()
    }
  }
  for child in subgraph.children {
    collect_subgraph_node_indexes(
      child, positioned_index_by_id, seen_node_ids, indexes,
    )
  }
}

///|
fn member_indexes_bounds(
  indexes : Array[Int],
  positioned_nodes : Array[PositionedNode],
) -> (Bool, Int, Int, Int, Int) {
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0
  for index in indexes {
    let node = positioned_nodes[index]
    let left = node.x - node.width / 2
    let top = node.y - node.height / 2
    let right = node.x + node.width / 2
    let bottom = node.y + node.height / 2
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, left, top, right, bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }
  (has_bounds, min_left, min_top, max_right, max_bottom)
}

///|
fn shift_member_indexes(
  indexes : Array[Int],
  dx : Int,
  dy : Int,
  positioned_nodes : Array[PositionedNode],
) -> Unit {
  if dx == 0 && dy == 0 {
    return
  }
  for index in indexes {
    let node = positioned_nodes[index]
    positioned_nodes[index] = {
      id: node.id,
      label: node.label,
      shape: node.shape,
      x: node.x + dx,
      y: node.y + dy,
      width: node.width,
      height: node.height,
      inline_style: node.inline_style,
    }
  }
}

///|
fn apply_subgraph_direction_override_to_children(
  children : Array[MermaidSubgraph],
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Unit {
  let member_blocks : Array[SubgraphMemberBlock] = []
  let mut has_bounds = false
  let mut min_left = 0
  let mut min_top = 0
  let mut max_right = 0
  let mut max_bottom = 0

  for child in children {
    let seen_node_ids : Map[String, Bool] = {}
    let indexes : Array[Int] = []
    collect_subgraph_node_indexes(
      child, positioned_index_by_id, seen_node_ids, indexes,
    )
    let (child_has_bounds, child_left, child_top, child_right, child_bottom) = member_indexes_bounds(
      indexes, positioned_nodes,
    )
    if !child_has_bounds {
      continue
    }
    member_blocks.push({
      node_indexes: indexes,
      left: child_left,
      top: child_top,
      width: child_right - child_left,
      height: child_bottom - child_top,
    })
    let (next_has, next_left, next_top, next_right, next_bottom) = include_bounds(
      has_bounds, min_left, min_top, max_right, max_bottom, child_left, child_top,
      child_right, child_bottom,
    )
    has_bounds = next_has
    min_left = next_left
    min_top = next_top
    max_right = next_right
    max_bottom = next_bottom
  }

  if !has_bounds || member_blocks.length() < 2 {
    return
  }

  if horizontal {
    let mut left = min_left
    let mut right = max_right
    let center_y = (min_top + max_bottom) / 2
    for block in member_blocks {
      let target_left = if reverse { right - block.width } else { left }
      let target_top = center_y - block.height / 2
      let dx = target_left - block.left
      let dy = target_top - block.top
      shift_member_indexes(block.node_indexes, dx, dy, positioned_nodes)
      if reverse {
        right = right - block.width - node_spacing
      } else {
        left = left + block.width + node_spacing
      }
    }
  } else {
    let mut top = min_top
    let mut bottom = max_bottom
    let center_x = (min_left + max_right) / 2
    for block in member_blocks {
      let target_left = center_x - block.width / 2
      let target_top = if reverse { bottom - block.height } else { top }
      let dx = target_left - block.left
      let dy = target_top - block.top
      shift_member_indexes(block.node_indexes, dx, dy, positioned_nodes)
      if reverse {
        bottom = bottom - block.height - layer_spacing
      } else {
        top = top + block.height + layer_spacing
      }
    }
  }
}

///|
/// Applies subgraph-local direction overrides to positioned nodes.
pub fn apply_subgraph_direction_overrides(
  subgraphs : Array[MermaidSubgraph],
  inherited_horizontal : Bool,
  inherited_reverse : Bool,
  inherited_override_active : Bool,
  global_horizontal : Bool,
  global_reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_index_by_id : Map[String, Int],
  node_horizontal_by_id : Map[String, Bool],
) -> Unit {
  for subgraph in subgraphs {
    let (subgraph_horizontal, subgraph_reverse, override_active) = match
      subgraph.direction {
      Some(direction) => {
        let horizontal = layout_direction_is_horizontal(direction)
        let reverse = layout_direction_is_reverse(direction)
        (
          horizontal,
          reverse,
          horizontal != global_horizontal || reverse != global_reverse,
        )
      }
      None =>
        (inherited_horizontal, inherited_reverse, inherited_override_active)
    }

    if override_active {
      for node_id in subgraph.node_ids {
        if positioned_index_by_id.contains(node_id) {
          node_horizontal_by_id[node_id] = subgraph_horizontal
        }
      }
      apply_subgraph_direction_override_to_members(
        subgraph.node_ids,
        subgraph_horizontal,
        subgraph_reverse,
        node_spacing,
        layer_spacing,
        positioned_nodes,
        positioned_index_by_id,
      )
    }

    apply_subgraph_direction_overrides(
      subgraph.children,
      subgraph_horizontal,
      subgraph_reverse,
      override_active,
      global_horizontal,
      global_reverse,
      node_spacing,
      layer_spacing,
      positioned_nodes,
      positioned_index_by_id,
      node_horizontal_by_id,
    )

    if override_active {
      apply_subgraph_direction_override_to_children(
        subgraph.children,
        subgraph_horizontal,
        subgraph_reverse,
        node_spacing,
        layer_spacing,
        positioned_nodes,
        positioned_index_by_id,
      )
    }
  }
}
