///|
/// Builds positioned subgraph groups and registers their anchor nodes.
pub fn build_legacy_positioned_groups(
  graph : MermaidGraph,
  padding : Int,
  horizontal : Bool,
  reverse : Bool,
  state_graph : Bool,
  dagre_parity_mode : Bool,
  node_spacing : Int,
  layer_spacing : Int,
  positioned_nodes : Array[PositionedNode],
  positioned_by_id : Map[String, PositionedNode],
  positioned_index_by_id : Map[String, Int],
) -> Array[PositionedGroup] {
  let positioned_groups : Array[PositionedGroup] = []
  let mut empty_group_top = padding
  for subgraph in graph.subgraphs {
    match
      build_positioned_group(subgraph, positioned_by_id, horizontal, reverse) {
      Some(group) => positioned_groups.push(group)
      None => {
        let empty_group = build_empty_group_tree_at(
          subgraph, padding, empty_group_top, horizontal, reverse,
        )
        positioned_groups.push(empty_group)
        empty_group_top = empty_group_top +
          empty_group.height +
          subgraph_group_padding()
      }
    }
  }

  if state_graph {
    shift_top_level_state_subgraphs_right(
      graph, node_spacing, layer_spacing, positioned_nodes, positioned_groups, positioned_index_by_id,
      positioned_by_id,
    )
  } else if !dagre_parity_mode {
    shift_top_level_flow_subgraphs_with_gap(
      graph, horizontal, reverse, layer_spacing, positioned_nodes, positioned_groups,
      positioned_index_by_id, positioned_by_id,
    )
  }

  for group in positioned_groups {
    register_group_anchors(group, positioned_by_id, state_graph)
  }

  positioned_groups
}

///|
/// Builds positioned groups for flat ASCII state layout and registers anchors.
pub fn build_ascii_state_positioned_groups(
  graph : MermaidGraph,
  padding : Int,
  positioned_by_id : Map[String, PositionedNode],
) -> Array[PositionedGroup] {
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
  positioned_groups
}
