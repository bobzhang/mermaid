///|
/// Legacy group-building request assembled by the legacy orchestrator.
pub(all) struct LegacyGroupBuildRequest {
  graph : MermaidGraph
  padding : Int
  horizontal : Bool
  reverse : Bool
  state_graph : Bool
  node_spacing : Int
  layer_spacing : Int
  positioned_nodes : Array[PositionedNode]
  positioned_by_id : Map[String, PositionedNode]
  positioned_index_by_id : Map[String, Int]
}

///|
/// Builds positioned subgraph groups and registers their anchor nodes.
pub fn build_legacy_positioned_groups(
  request : LegacyGroupBuildRequest,
) -> Array[PositionedGroup] {
  let graph = request.graph
  let padding = request.padding
  let horizontal = request.horizontal
  let reverse = request.reverse
  let state_graph = request.state_graph
  let node_spacing = request.node_spacing
  let layer_spacing = request.layer_spacing
  let positioned_nodes = request.positioned_nodes
  let positioned_by_id = request.positioned_by_id
  let positioned_index_by_id = request.positioned_index_by_id

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
  } else {
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
