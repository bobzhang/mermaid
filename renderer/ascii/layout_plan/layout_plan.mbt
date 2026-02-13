///|
pub enum AsciiPlanKind {
  Sequence
  Class
  Er
  StateFlatGrid
  FlowSubgraph
  NodesOnly
}

///|
pub struct AsciiStateFlatGridLayout {
  nodes_in_order : Array[@model.MermaidNode]
  grid_positions : Map[String, @layout.LayoutStateGridCoord]
  edge_paths : Array[Array[@layout.AsciiGridCoord]]
}

///|
pub struct AsciiFlowSubgraphLayout {
  positioned : @model.PositionedGraph
}

///|
pub struct AsciiLayoutPlan {
  kind : AsciiPlanKind
  graph : @model.MermaidGraph
  state_flat_grid : AsciiStateFlatGridLayout?
  flow_subgraph : AsciiFlowSubgraphLayout?
}

///|
fn graph_is_shape(
  graph : @model.MermaidGraph,
  expected : @model.NodeShape,
) -> Bool {
  if graph.nodes.length() == 0 {
    return false
  }
  for _, node in graph.nodes {
    if node.shape != expected {
      return false
    }
  }
  true
}

///|
fn graph_has_shape(
  graph : @model.MermaidGraph,
  expected : @model.NodeShape,
) -> Bool {
  for _, node in graph.nodes {
    if node.shape == expected {
      return true
    }
  }
  false
}

///|
fn build_state_flat_grid_layout(
  graph : @model.MermaidGraph,
) -> AsciiStateFlatGridLayout {
  let nodes_in_order = @layout.layout_state_nodes_in_definition_order(graph)
  let grid_positions = @layout.layout_state_grid_positions(
    graph, nodes_in_order,
  )
  let blocked = @layout.layout_state_grid_blocked_cells(grid_positions)
  let (max_grid_x, max_grid_y) = if grid_positions.length() == 0 {
    (0, 0)
  } else {
    @layout.layout_state_grid_bounds(grid_positions)
  }
  let edge_paths : Array[Array[@layout.AsciiGridCoord]] = []
  for edge in graph.edges {
    let path = match
      @layout.layout_state_edge_grid_path_td(
        grid_positions,
        blocked,
        max_grid_x,
        max_grid_y,
        edge.source,
        edge.target,
      ) {
      Some(found) => found
      None => []
    }
    edge_paths.push(path)
  }
  { nodes_in_order, grid_positions, edge_paths }
}

///|
fn build_flow_subgraph_layout(
  graph : @model.MermaidGraph,
) -> AsciiFlowSubgraphLayout {
  {
    positioned: @layout.layout_graph_for_ascii(
      graph,
      @model.RenderOptions::default(),
    ),
  }
}

///|
pub fn build_plan(graph : @model.MermaidGraph) -> AsciiLayoutPlan {
  let sequence_mode = graph_is_shape(graph, SequenceParticipant)
  if sequence_mode {
    return { kind: Sequence, graph, state_flat_grid: None, flow_subgraph: None }
  }

  let class_mode = graph_is_shape(graph, ClassEntity)
  if class_mode {
    return { kind: Class, graph, state_flat_grid: None, flow_subgraph: None }
  }

  let er_mode = graph_is_shape(graph, ErEntity)
  if er_mode {
    return { kind: Er, graph, state_flat_grid: None, flow_subgraph: None }
  }

  let state_mode = graph_has_shape(graph, StateStart) ||
    graph_has_shape(graph, StateEnd)
  let td_like_direction = graph.direction is (TD | TB)

  if state_mode && td_like_direction {
    return {
      kind: StateFlatGrid,
      graph,
      state_flat_grid: Some(build_state_flat_grid_layout(graph)),
      flow_subgraph: None,
    }
  }

  if state_mode {
    return {
      kind: FlowSubgraph,
      graph,
      state_flat_grid: None,
      flow_subgraph: Some(build_flow_subgraph_layout(graph)),
    }
  }

  if graph.subgraphs.length() == 0 && td_like_direction {
    return {
      kind: StateFlatGrid,
      graph,
      state_flat_grid: Some(build_state_flat_grid_layout(graph)),
      flow_subgraph: None,
    }
  }

  if graph.subgraphs.length() > 0 {
    return {
      kind: FlowSubgraph,
      graph,
      state_flat_grid: None,
      flow_subgraph: Some(build_flow_subgraph_layout(graph)),
    }
  }

  if graph.edges.length() == 0 {
    return {
      kind: NodesOnly,
      graph,
      state_flat_grid: None,
      flow_subgraph: None,
    }
  }

  {
    kind: FlowSubgraph,
    graph,
    state_flat_grid: None,
    flow_subgraph: Some(build_flow_subgraph_layout(graph)),
  }
}
