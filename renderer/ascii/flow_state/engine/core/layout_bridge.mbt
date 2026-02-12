///|
fn layout_graph_for_ascii(
  graph : MermaidGraph,
  options : RenderOptions,
) -> PositionedGraph {
  @layout.layout_graph_for_ascii(graph, options)
}

///|
fn layout_state_nodes_in_definition_order(
  graph : MermaidGraph,
) -> Array[MermaidNode] {
  @layout.layout_state_nodes_in_definition_order(graph)
}

///|
fn layout_state_grid_positions(
  graph : MermaidGraph,
  nodes_in_order : Array[MermaidNode],
) -> Map[String, LayoutStateGridCoord] {
  @layout.layout_state_grid_positions(graph, nodes_in_order)
}

///|
fn layout_state_grid_bounds(
  positions : Map[String, LayoutStateGridCoord],
) -> (Int, Int) {
  @layout.layout_state_grid_bounds(positions)
}

///|
fn layout_state_grid_blocked_cells(
  positions : Map[String, LayoutStateGridCoord],
) -> Map[String, Bool] {
  @layout.layout_state_grid_blocked_cells(positions)
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
  @layout.layout_state_edge_grid_path_td(
    positions, blocked, max_x, max_y, source_id, target_id,
  )
}
