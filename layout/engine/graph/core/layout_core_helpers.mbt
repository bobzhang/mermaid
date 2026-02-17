///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn int_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn resolve_padding(options : RenderOptions) -> Int {
  option_int_or(options.padding, 40)
}

///|
fn resolve_node_spacing(options : RenderOptions) -> Int {
  option_int_or(options.node_spacing, 130)
}

///|
fn resolve_layer_spacing(options : RenderOptions) -> Int {
  option_int_or(options.layer_spacing, 90)
}

///|
fn resolve_horizontal_state_node_spacing(
  options : RenderOptions,
  nodes_in_order : Array[MermaidNode],
  fallback : Int,
) -> Int {
  match options.node_spacing {
    Some(_) => fallback
    None => {
      let mut max_width = 0
      for node in nodes_in_order {
        let (width, _) = node_dimensions(node)
        max_width = max_width.max(width)
      }
      (max_width + 50).max(72)
    }
  }
}

///|
fn node_dimensions(node : MermaidNode) -> (Int, Int) {
  let label_lines = node.label
    .split("\n")
    .map(part => part.to_string())
    .to_array()
  let mut longest_line = 0
  for line in label_lines {
    longest_line = longest_line.max(line.length())
  }

  match node.shape {
    StateStart => (14, 14)
    StateEnd => (14, 14)
    Circle => {
      let diameter = (longest_line * 8 + 14).max(24)
      (diameter, diameter)
    }
    DoubleCircle => {
      let diameter = (longest_line * 8 + 22).max(34)
      (diameter, diameter)
    }
    ClassEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 36 + detail_rows * 16 + 10
      (width, height)
    }
    ErEntity => {
      let min_width = 120
      let width = min_width.max(longest_line * 8 + 30)
      let detail_rows = (label_lines.length() - 1).max(1)
      let height = 34 + detail_rows * 16 + 10
      (width, height)
    }
    _ => {
      let min_width = 70
      let width = min_width.max(longest_line * 8 + 24)
      let height = (24 + label_lines.length() * 14).max(44)
      (width, height)
    }
  }
}

///|
fn layout_direction_is_horizontal(direction : Direction) -> Bool {
  direction is (LR | RL)
}

///|
fn layout_direction_is_reverse(direction : Direction) -> Bool {
  direction is (RL | BT)
}

///|
fn reorder_nodes_for_flow_layout(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
) -> Array[MermaidNode] {
  let indegree_by_id : Map[String, Int] = {}
  let outdegree_by_id : Map[String, Int] = {}
  for node in nodes_in_order {
    indegree_by_id[node.id] = 0
    outdegree_by_id[node.id] = 0
  }

  for edge in edges {
    match indegree_by_id.get(edge.target) {
      Some(indegree) => indegree_by_id[edge.target] = indegree + 1
      None => ()
    }
    match outdegree_by_id.get(edge.source) {
      Some(outdegree) => outdegree_by_id[edge.source] = outdegree + 1
      None => ()
    }
  }

  let leading_state_starts : Array[MermaidNode] = []
  let trailing_nodes : Array[MermaidNode] = []
  for node in nodes_in_order {
    let indegree = option_int_or(indegree_by_id.get(node.id), 0)
    let outdegree = option_int_or(outdegree_by_id.get(node.id), 0)
    let user_defined_state_start = match node.shape {
      StateStart => !node.id.has_prefix("state_start_")
      _ => false
    }
    if user_defined_state_start && indegree == 0 && outdegree > 0 {
      leading_state_starts.push(node)
    } else {
      trailing_nodes.push(node)
    }
  }

  if leading_state_starts.length() == 0 {
    return nodes_in_order
  }

  let reordered : Array[MermaidNode] = []
  for node in leading_state_starts {
    reordered.push(node)
  }
  for node in trailing_nodes {
    reordered.push(node)
  }
  reordered
}

///|
fn is_state_graph(graph : MermaidGraph) -> Bool {
  for _, node in graph.nodes {
    match node.shape {
      StateStart | StateEnd => return true
      _ => ()
    }
  }
  false
}

///|
fn is_class_or_er_graph(graph : MermaidGraph) -> Bool {
  for _, node in graph.nodes {
    match node.shape {
      ClassEntity | ErEntity => return true
      _ => ()
    }
  }
  false
}

///|
fn use_enhanced_horizontal_state_flow_lanes(
  nodes_in_order : Array[MermaidNode],
) -> Bool {
  let mut circle_node_count = 0
  for node in nodes_in_order {
    match node.shape {
      Circle => circle_node_count += 1
      DoubleCircle => circle_node_count += 1
      StateStart | StateEnd => ()
      _ => return false
    }
  }
  circle_node_count >= 3
}

///|
fn find_positioned_group_index(
  groups : Array[PositionedGroup],
  group_id : String,
) -> Int? {
  for i, group in groups {
    if group.id == group_id {
      return Some(i)
    }
  }
  None
}
