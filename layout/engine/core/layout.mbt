///|
pub type LayoutStateGridCoord = @layout_engine_graph_core.LayoutStateGridCoord

///|
pub fn layout_state_nodes_in_definition_order(
  graph : @model.MermaidGraph,
) -> Array[@model.MermaidNode] {
  @layout_engine_graph_core.layout_state_nodes_in_definition_order(graph)
}

///|
pub fn layout_state_grid_positions(
  graph : @model.MermaidGraph,
  nodes_in_order : Array[@model.MermaidNode],
) -> Map[String, LayoutStateGridCoord] {
  @layout_engine_graph_core.layout_state_grid_positions(graph, nodes_in_order)
}

///|
pub fn layout_state_grid_bounds(
  positions : Map[String, LayoutStateGridCoord],
) -> (Int, Int) {
  @layout_engine_graph_core.layout_state_grid_bounds(positions)
}

///|
pub fn layout_state_grid_blocked_cells(
  positions : Map[String, LayoutStateGridCoord],
) -> Map[String, Bool] {
  @layout_engine_graph_core.layout_state_grid_blocked_cells(positions)
}

///|
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
pub fn layout_graph(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
) -> @model.PositionedGraph {
  @layout_engine_graph_core.layout_graph(graph, options)
}

///|
pub fn layout_graph_for_ascii(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
) -> @model.PositionedGraph {
  @layout_engine_graph_core.layout_graph_for_ascii(graph, options)
}
