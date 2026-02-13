/// Finds a path between two grid coordinates using A* pathfinding.
pub fn ascii_grid_pathfind(
  start : AsciiGridCoord,
  end : AsciiGridCoord,
  blocked : Map[String, Bool],
  min_x : Int,
  max_x : Int,
  min_y : Int,
  max_y : Int,
) -> Array[AsciiGridCoord]? {
  @layout_core.ascii_grid_pathfind(
    start, end, blocked, min_x, max_x, min_y, max_y,
  )
}

/// Merges collinear segments in a grid path to reduce waypoints.
pub fn ascii_grid_merge_path(
  path : Array[AsciiGridCoord],
) -> Array[AsciiGridCoord] {
  @layout_core.ascii_grid_merge_path(path)
}

/// Returns graph nodes in their original definition order.
pub fn layout_state_nodes_in_definition_order(
  graph : @model.MermaidGraph,
) -> Array[@model.MermaidNode] {
  @layout_core.layout_state_nodes_in_definition_order(graph)
}

/// Computes grid positions for state diagram nodes.
pub fn layout_state_grid_positions(
  graph : @model.MermaidGraph,
  nodes_in_order : Array[@model.MermaidNode],
) -> Map[String, LayoutStateGridCoord] {
  @layout_core.layout_state_grid_positions(graph, nodes_in_order)
}

/// Computes the bounding box of the state diagram grid.
pub fn layout_state_grid_bounds(
  positions : Map[String, LayoutStateGridCoord],
) -> (Int, Int) {
  @layout_core.layout_state_grid_bounds(positions)
}

/// Computes the set of grid cells blocked by node positions.
pub fn layout_state_grid_blocked_cells(
  positions : Map[String, LayoutStateGridCoord],
) -> Map[String, Bool] {
  @layout_core.layout_state_grid_blocked_cells(positions)
}

/// Routes an edge path on the state grid in top-down direction.
pub fn layout_state_edge_grid_path_td(
  positions : Map[String, LayoutStateGridCoord],
  blocked : Map[String, Bool],
  max_x : Int,
  max_y : Int,
  source_id : String,
  target_id : String,
) -> Array[AsciiGridCoord]? {
  @layout_core.layout_state_edge_grid_path_td(
    positions, blocked, max_x, max_y, source_id, target_id,
  )
}

/// Lays out a mermaid graph for SVG rendering.
pub fn layout_graph(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
) -> @model.PositionedGraph {
  @layout_core.layout_graph(graph, options)
}

/// Lays out a mermaid graph for ASCII text rendering.
pub fn layout_graph_for_ascii(
  graph : @model.MermaidGraph,
  options : @model.RenderOptions,
) -> @model.PositionedGraph {
  @layout_core.layout_graph_for_ascii(graph, options)
}
