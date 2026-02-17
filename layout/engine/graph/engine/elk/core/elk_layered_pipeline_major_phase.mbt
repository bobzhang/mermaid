///|
fn rank_pair_key(left_rank : Int, right_rank : Int) -> String {
  if left_rank <= right_rank {
    "\{left_rank}->\{right_rank}"
  } else {
    "\{right_rank}->\{left_rank}"
  }
}

///|
fn edge_label_major_extent(label : String, horizontal : Bool) -> Int {
  let lines = label.split("\n").map(line => line.to_string()).to_array()
  let mut longest_line = 0
  for line in lines {
    longest_line = longest_line.max(line.length())
  }
  if horizontal {
    longest_line * 6 + 12
  } else {
    lines.length() * 13 + 8
  }
}

///|
fn build_rank_pair_label_major_gap(
  graph : MermaidGraph,
  use_subgraph_redirects : Bool,
  subgraph_entry_by_id : Map[String, String],
  subgraph_exit_by_id : Map[String, String],
  rank_by_node_id : Map[String, Int],
  horizontal : Bool,
) -> Map[String, Int] {
  let rank_pair_label_major_gap : Map[String, Int] = {}
  for edge in graph.edges {
    let source_id = resolve_edge_endpoint_id(
      edge.source,
      use_subgraph_redirects,
      subgraph_exit_by_id,
    )
    let target_id = resolve_edge_endpoint_id(
      edge.target,
      use_subgraph_redirects,
      subgraph_entry_by_id,
    )
    let source_rank = option_int_or(rank_by_node_id.get(source_id), -1)
    let target_rank = option_int_or(rank_by_node_id.get(target_id), -1)
    if source_rank < 0 || target_rank <= source_rank {
      continue
    }
    let label_major_gap = match edge.label {
      Some(label) => edge_label_major_extent(label, horizontal) + 8
      None => 0
    }
    if label_major_gap <= 0 {
      continue
    }
    for rank in source_rank..<target_rank {
      let key = rank_pair_key(rank, rank + 1)
      let current = option_int_or(rank_pair_label_major_gap.get(key), 0)
      if label_major_gap > current {
        rank_pair_label_major_gap[key] = label_major_gap
      }
    }
  }
  rank_pair_label_major_gap
}

///|
fn rank_pair_major_step(
  left_rank : Int,
  right_rank : Int,
  base_major_step : Int,
  rank_pair_label_major_gap : Map[String, Int],
) -> Int {
  let label_clearance = option_int_or(
    rank_pair_label_major_gap.get(rank_pair_key(left_rank, right_rank)),
    0,
  )
  if label_clearance <= base_major_step {
    base_major_step
  } else {
    // Dampen label-driven expansion so long labels gain room without causing
    // large global stretching on small graphs.
    let overflow = label_clearance - base_major_step
    base_major_step + overflow * 2 / 3
  }
}

///|
fn build_major_center_by_rank(
  max_rank : Int,
  reverse : Bool,
  padding : Int,
  base_major_step : Int,
  rank_pair_label_major_gap : Map[String, Int],
) -> Map[Int, Int] {
  let major_center_by_rank : Map[Int, Int] = {}
  let major_start = padding + 70
  let mut displayed_major_center = major_start
  for displayed_rank in 0..<=max_rank {
    let rank = if reverse { max_rank - displayed_rank } else { displayed_rank }
    if displayed_rank > 0 {
      let previous_displayed_rank = displayed_rank - 1
      let previous_rank = if reverse {
        max_rank - previous_displayed_rank
      } else {
        previous_displayed_rank
      }
      let step = rank_pair_major_step(
        previous_rank, rank, base_major_step, rank_pair_label_major_gap,
      )
      displayed_major_center += step
    }
    major_center_by_rank[rank] = displayed_major_center
  }
  major_center_by_rank
}

///|
fn build_axis_coords_by_node_id(
  rank_node_ids_by_rank : Map[Int, Array[String]],
  max_rank : Int,
  major_center_by_rank : Map[Int, Int],
  minor_coord_by_node_id : Map[String, Int],
  padding : Int,
  horizontal : Bool,
) -> (Map[String, Int], Map[String, Int]) {
  let x_by_node_id : Map[String, Int] = {}
  let y_by_node_id : Map[String, Int] = {}
  for rank in 0..<=max_rank {
    match rank_node_ids_by_rank.get(rank) {
      Some(node_ids) => {
        let major_center = option_int_or(
          major_center_by_rank.get(rank),
          padding + 70,
        )
        for node_id in node_ids {
          let minor_coord = option_int_or(
            minor_coord_by_node_id.get(node_id),
            padding + 70,
          )
          if horizontal {
            x_by_node_id[node_id] = major_center
            y_by_node_id[node_id] = minor_coord
          } else {
            x_by_node_id[node_id] = minor_coord
            y_by_node_id[node_id] = major_center
          }
        }
      }
      None => ()
    }
  }
  (x_by_node_id, y_by_node_id)
}

///|
fn build_positioned_nodes_from_axis_coords(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
  width_by_node_id : Map[String, Int],
  height_by_node_id : Map[String, Int],
  x_by_node_id : Map[String, Int],
  y_by_node_id : Map[String, Int],
  padding : Int,
) -> (Array[PositionedNode], Map[String, PositionedNode]) {
  let positioned_nodes : Array[PositionedNode] = []
  let positioned_by_id : Map[String, PositionedNode] = {}
  for node in nodes_in_order {
    let width = option_int_or(width_by_node_id.get(node.id), 70)
    let height = option_int_or(height_by_node_id.get(node.id), 44)
    let positioned = PositionedNode::{
      id: node.id,
      label: node.label,
      shape: node.shape,
      x: option_int_or(x_by_node_id.get(node.id), padding + 70),
      y: option_int_or(y_by_node_id.get(node.id), padding + 70),
      width,
      height,
      inline_style: resolve_inline_style(graph, node.id),
    }
    positioned_nodes.push(positioned)
    positioned_by_id[node.id] = positioned
  }
  (positioned_nodes, positioned_by_id)
}

///|
fn build_node_horizontal_by_id(
  positioned_nodes : Array[PositionedNode],
  horizontal : Bool,
) -> Map[String, Bool] {
  let node_horizontal_by_id : Map[String, Bool] = {}
  for node in positioned_nodes {
    node_horizontal_by_id[node.id] = horizontal
  }
  node_horizontal_by_id
}

///|
fn positioned_nodes_layout_extent(
  positioned_nodes : Array[PositionedNode],
  padding : Int,
) -> (Int, Int) {
  let mut max_right = padding
  let mut max_bottom = padding
  for node in positioned_nodes {
    max_right = max_right.max(node.x + node.width / 2)
    max_bottom = max_bottom.max(node.y + node.height / 2)
  }
  (max_right, max_bottom)
}

///|
fn finalize_elk_layered_positioned_graph(
  graph : MermaidGraph,
  padding : Int,
  horizontal : Bool,
  reverse : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  use_subgraph_redirects : Bool,
  subgraph_exit_by_id : Map[String, String],
  subgraph_entry_by_id : Map[String, String],
  routing_policy : GraphBackendRoutingPolicy,
  positioned_nodes : Array[PositionedNode],
  positioned_by_id : Map[String, PositionedNode],
  node_horizontal_by_id : Map[String, Bool],
  max_right : Int,
  max_bottom : Int,
) -> PositionedGraph {
  let positioned_index_by_id = positioned_index_by_node_id(positioned_nodes)
  let positioned_groups = @layout_engine_graph_group_core.build_legacy_positioned_groups(
    graph, padding, horizontal, reverse, false, node_spacing, layer_spacing, positioned_nodes,
    positioned_by_id, positioned_index_by_id,
  )
  let positioned_edges = @layout_engine_graph_routing_core.route_legacy_positioned_edges(
    graph,
    false,
    false,
    horizontal,
    layer_spacing,
    node_spacing,
    use_subgraph_redirects,
    subgraph_exit_by_id,
    subgraph_entry_by_id,
    positioned_nodes,
    positioned_by_id,
    node_horizontal_by_id,
    routing_policy.enable_target_boundary_ports,
    routing_policy.preserve_assigned_endpoint_ports,
    false,
  )
  @layout_engine_graph_finalize_core.finalize_positioned_graph(
    padding, max_right, max_bottom, positioned_nodes, positioned_edges, positioned_groups,
  )
}

///|
fn elk_graph_supports_layered_pipeline(graph : MermaidGraph) -> Bool {
  graph.diagram_kind is Flowchart &&
  !@layout_engine_graph_internal_core.is_state_graph(graph) &&
  !@layout_engine_graph_internal_core.is_class_or_er_graph(graph)
}

///|
fn should_use_elk_layered_pipeline(graph : MermaidGraph) -> Bool {
  elk_graph_supports_layered_pipeline(graph)
}
