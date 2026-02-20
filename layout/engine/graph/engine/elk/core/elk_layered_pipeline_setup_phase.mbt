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
      let min_width = 76
      // Keep ELK default node boxes close to Mermaid's rendered flowchart nodes.
      let width = min_width.max(longest_line * 8 + 60)
      let height = (30 + label_lines.length() * 24).max(54)
      (width, height)
    }
  }
}

///|
fn setup_phase_snapshot(
  request : GraphLayoutBackendRequest,
  nodes_in_order : Array[MermaidNode],
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "setup",
    node_count: nodes_in_order.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    rank_layer_count: 0,
    width: 0,
    height: 0,
  }
}

///|
fn placement_phase_snapshot(
  request : GraphLayoutBackendRequest,
  positioned_nodes : Array[PositionedNode],
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "placement",
    node_count: positioned_nodes.length(),
    edge_count: request.graph.edges.length(),
    group_count: request.graph.subgraphs.length(),
    rank_layer_count: 0,
    width: 0,
    height: 0,
  }
}

///|
fn final_phase_snapshot(
  positioned_graph : PositionedGraph,
) -> GraphLayoutPhaseSnapshot {
  {
    phase: "final",
    node_count: positioned_graph.nodes.length(),
    edge_count: positioned_graph.edges.length(),
    group_count: positioned_graph.groups.length(),
    rank_layer_count: 0,
    width: positioned_graph.width,
    height: positioned_graph.height,
  }
}

///|
fn build_order_index_by_node_id(
  nodes_in_order : Array[MermaidNode],
) -> Map[String, Int] {
  let order_index_by_node_id : Map[String, Int] = {}
  for i, node in nodes_in_order {
    order_index_by_node_id[node.id] = i
  }
  order_index_by_node_id
}

///|
priv struct ElkLayeredSetupState {
  graph : MermaidGraph
  options : RenderOptions
  use_subgraph_redirects : Bool
  compact_fanin : Bool
  subgraph_entry_by_id : Map[String, String]
  subgraph_exit_by_id : Map[String, String]
  nodes_in_order : Array[MermaidNode]
  horizontal : Bool
  reverse : Bool
  base_order_index_by_node_id : Map[String, Int]
  node_ids_in_order : Array[String]
}

///|
fn run_elk_layered_setup_phase(
  request : GraphLayoutBackendRequest,
) -> ElkLayeredSetupState {
  let graph = request.graph
  let options = request.options
  let use_subgraph_redirects = request.use_subgraph_redirects
  let compact_fanin = request.compact_fanin
  let prep_state = @layout_engine_graph_prep_core.prepare_graph_inputs(
    graph, use_subgraph_redirects,
  )
  let subgraph_entry_by_id = prep_state.subgraph_entry_by_id
  let subgraph_exit_by_id = prep_state.subgraph_exit_by_id
  // ELK layered uses model/input order as the baseline ordering signal.
  // Keep parser/prep order here instead of dagre-oriented flow reordering.
  let nodes_in_order = prep_state.nodes_in_order
  let horizontal = @layout_engine_graph_internal_core.layout_direction_is_horizontal(
    graph.direction,
  )
  let reverse = @layout_engine_graph_internal_core.layout_direction_is_reverse(
    graph.direction,
  )
  let base_order_index_by_node_id = build_order_index_by_node_id(nodes_in_order)
  let node_ids_in_order : Array[String] = []
  for node in nodes_in_order {
    node_ids_in_order.push(node.id)
  }
  {
    graph,
    options,
    use_subgraph_redirects,
    compact_fanin,
    subgraph_entry_by_id,
    subgraph_exit_by_id,
    nodes_in_order,
    horizontal,
    reverse,
    base_order_index_by_node_id,
    node_ids_in_order,
  }
}

///|
priv struct ElkLayeredNodeSizeState {
  width_by_node_id : Map[String, Int]
  height_by_node_id : Map[String, Int]
  global_max_width : Int
  global_max_height : Int
}

///|
fn build_elk_layered_node_size_state(
  nodes_in_order : Array[MermaidNode],
) -> ElkLayeredNodeSizeState {
  let width_by_node_id : Map[String, Int] = {}
  let height_by_node_id : Map[String, Int] = {}
  let mut global_max_width = 0
  let mut global_max_height = 0
  for node in nodes_in_order {
    let (width, height) = node_dimensions(node)
    width_by_node_id[node.id] = width
    height_by_node_id[node.id] = height
    global_max_width = global_max_width.max(width)
    global_max_height = global_max_height.max(height)
  }
  { width_by_node_id, height_by_node_id, global_max_width, global_max_height }
}

///|
fn compute_max_rank_size(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
) -> Int {
  let mut max_rank_size = 1
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => max_rank_size = max_rank_size.max(node_ids.length())
      None => ()
    }
  }
  max_rank_size
}

///|
priv struct ElkLayeredSpacingState {
  padding : Int
  node_spacing : Int
  layer_spacing : Int
  major_gap : Int
  minor_step : Int
  max_rank_minor_span : Int
}

///|
fn run_elk_layered_spacing_phase(
  options : RenderOptions,
  horizontal : Bool,
  max_rank_size : Int,
  node_size_state : ElkLayeredNodeSizeState,
) -> ElkLayeredSpacingState {
  let padding = @layout_engine_graph_internal_core.option_int_or(
    options.padding,
    40,
  )
  let node_spacing = @layout_engine_graph_internal_core.option_int_or(
    options.node_spacing,
    130,
  )
  let layer_spacing = @layout_engine_graph_internal_core.option_int_or(
    options.layer_spacing,
    90,
  )
  let major_gap_seed = if horizontal { node_spacing } else { layer_spacing }
  let minor_gap = if horizontal { layer_spacing } else { node_spacing }
  let global_major_size = if horizontal {
    node_size_state.global_max_width
  } else {
    node_size_state.global_max_height
  }
  let major_gap = (major_gap_seed.max(
    global_major_size + (major_gap_seed / 5).max(20),
  ) -
  70).max(8)
  let min_minor_step = if horizontal {
    node_size_state.global_max_height + 12
  } else {
    node_size_state.global_max_width + 12
  }
  let minor_step = minor_gap.max(min_minor_step)
  let max_rank_minor_span = (max_rank_size - 1).max(0) * minor_step
  {
    padding,
    node_spacing,
    layer_spacing,
    major_gap,
    minor_step,
    max_rank_minor_span,
  }
}
