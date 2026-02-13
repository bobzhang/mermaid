///|
/// A coordinate on the state diagram layout grid.
pub type LayoutStateGridCoord = @layout_engine_graph_core.LayoutStateGridCoord

///|
/// Returns graph nodes in their original definition order.
pub fn layout_state_nodes_in_definition_order(
  graph : @model.MermaidGraph,
) -> Array[@model.MermaidNode] {
  @layout_engine_graph_core.layout_state_nodes_in_definition_order(graph)
}

///|
/// Computes grid positions for state diagram nodes.
pub fn layout_state_grid_positions(
  graph : @model.MermaidGraph,
  nodes_in_order : Array[@model.MermaidNode],
) -> Map[String, LayoutStateGridCoord] {
  @layout_engine_graph_core.layout_state_grid_positions(graph, nodes_in_order)
}

///|
/// Computes the bounding box of the state diagram grid.
pub fn layout_state_grid_bounds(
  positions : Map[String, LayoutStateGridCoord],
) -> (Int, Int) {
  @layout_engine_graph_core.layout_state_grid_bounds(positions)
}

///|
/// Computes the set of grid cells blocked by node positions.
pub fn layout_state_grid_blocked_cells(
  positions : Map[String, LayoutStateGridCoord],
) -> Map[String, Bool] {
  @layout_engine_graph_core.layout_state_grid_blocked_cells(positions)
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
  @layout_engine_graph_core.layout_state_edge_grid_path_td(
    positions, blocked, max_x, max_y, source_id, target_id,
  )
}

///|
/// Lays out a mermaid graph for SVG rendering.
pub fn layout_graph(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
) -> @model.PositionedGraph {
  @layout_engine_graph_core.layout_graph(graph, options)
}

///|
/// Lays out a mermaid graph for ASCII text rendering.
pub fn layout_graph_for_ascii(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
) -> @model.PositionedGraph {
  @layout_engine_graph_core.layout_graph_for_ascii(graph, options)
}
