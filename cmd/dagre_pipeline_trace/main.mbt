///|
priv struct DagrePipelineKernel {
  graph : @model.MermaidGraph
}

///|
fn main {
  run()
}

///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(v) => v
    None => fallback
  }
}

///|
fn print_usage() -> Unit {
  let usage =
    #|Usage:
    #|  moon run cmd/dagre_pipeline_trace -- --case case1
    #|  moon run cmd/dagre_pipeline_trace -- --case case2
    #|  moon run cmd/dagre_pipeline_trace -- --case case3
    #|  moon run cmd/dagre_pipeline_trace -- --case all
    #|  moon run cmd/dagre_pipeline_trace -- --source "graph LR\nA --> B"
    #|Flags:
    #|  --case   case1 | case2 | case3 | all
    #|  --source  Mermaid source text
    #|  --help   Show this help
    #|
  println(usage.trim_end().to_string())
}

///|
fn cli_args_without_program() -> Array[String] {
  let all_args = @env.args()
  if all_args.length() <= 1 {
    []
  } else {
    let args : Array[String] = []
    for i in 1..<all_args.length() {
      args.push(all_args[i])
    }
    args
  }
}

///|
fn parse_case_arg(args : Array[String]) -> String? {
  if args.length() == 0 {
    return Some("all")
  }
  if args.length() == 1 {
    let arg = args[0]
    if arg == "--help" {
      return Some("help")
    }
    if arg is [.. "--case=", .. raw_case] {
      let case_name = raw_case.trim().to_lower()
      if case_name == "" {
        return None
      }
      return Some(case_name.to_string())
    }
    return None
  }
  if args.length() == 2 && args[0] == "--case" {
    let case_name = args[1].trim().to_lower()
    if case_name == "" {
      return None
    }
    return Some(case_name.to_string())
  }
  None
}

///|
fn parse_source_arg(args : Array[String]) -> String? {
  if args.length() == 1 {
    let arg = args[0]
    if arg is [.. "--source=", .. raw_source] {
      let source = raw_source.trim()
      if source == "" {
        return None
      }
      return Some(source.to_string())
    }
  }
  if args.length() == 2 && args[0] == "--source" {
    let source = args[1].trim()
    if source == "" {
      return None
    }
    return Some(source.to_string())
  }
  None
}

///|
fn direction_tag(direction : @model.Direction) -> String {
  match direction {
    TD => "TD"
    TB => "TB"
    LR => "LR"
    BT => "BT"
    RL => "RL"
  }
}

///|
fn flow_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn flow_edge(source : String, target : String) -> @model.MermaidEdge {
  {
    source,
    target,
    label: None,
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn flow_graph(
  node_ids : Array[String],
  edges : Array[(String, String)],
  direction : @model.Direction,
) -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {}
  for node_id in node_ids {
    nodes[node_id] = flow_node(node_id)
  }
  let graph_edges : Array[@model.MermaidEdge] = []
  for edge in edges {
    let (source, target) = edge
    graph_edges.push(flow_edge(source, target))
  }
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  let sequence_blocks : Array[@model.SequenceBlock] = []
  let sequence_notes : Array[@model.SequenceNote] = []
  let sequence_activation_commands : Array[@model.SequenceActivationCommand] = []
  {
    diagram_kind: Flowchart,
    direction,
    nodes,
    node_definition_order: node_ids.copy(),
    edges: graph_edges,
    subgraphs: [],
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order: [],
    sequence_actor_kinds,
    sequence_blocks,
    sequence_notes,
    sequence_activation_commands,
  }
}

///|
fn case1_kernel() -> DagrePipelineKernel {
  {
    graph: flow_graph(
      ["A", "B", "M", "X", "Y"],
      [("A", "M"), ("B", "M"), ("M", "X"), ("M", "Y"), ("A", "Y"), ("B", "X")],
      LR,
    ),
  }
}

///|
fn case2_kernel() -> DagrePipelineKernel {
  {
    graph: flow_graph(
      ["A", "B", "C", "D", "E", "F"],
      [
        ("A", "D"),
        ("B", "C"),
        ("A", "E"),
        ("B", "F"),
        ("C", "F"),
        ("D", "E"),
        ("A", "F"),
        ("B", "E"),
      ],
      LR,
    ),
  }
}

///|
fn case3_kernel() -> DagrePipelineKernel {
  {
    graph: flow_graph(
      ["A", "B", "C", "D", "E", "F", "G", "H"],
      [
        ("A", "C"),
        ("A", "D"),
        ("B", "C"),
        ("B", "D"),
        ("C", "E"),
        ("D", "F"),
        ("C", "F"),
        ("D", "E"),
        ("E", "G"),
        ("F", "H"),
        ("E", "H"),
        ("F", "G"),
      ],
      LR,
    ),
  }
}

///|
fn sorted_graph_node_ids(graph : @model.MermaidGraph) -> Array[String] {
  let ids : Array[String] = []
  for node_id, _ in graph.nodes {
    ids.push(node_id)
  }
  ids.sort()
  ids
}

///|
fn rank_layers(
  setup_state : @layout_engine_graph_legacy_setup_core.LegacyLayoutSetupState,
) -> Array[Array[String]] {
  let max_rank = setup_state.lane_state.flow_max_rank
  let layers : Array[Array[(Int, String)]] = []
  for _ in 0..<=max_rank {
    layers.push([])
  }
  for node in setup_state.nodes_in_order {
    let rank = option_int_or(
      setup_state.lane_state.flow_rank_by_node_id.get(node.id),
      0,
    )
    let lane = option_int_or(
      setup_state.lane_state.flow_lane_by_node_id.get(node.id),
      0,
    )
    if rank < 0 {
      continue
    }
    if rank >= layers.length() {
      for _ in layers.length()..<=rank {
        layers.push([])
      }
    }
    layers[rank].push((lane, node.id))
  }
  let normalized_layers : Array[Array[String]] = []
  for layer in layers {
    layer.sort_by((left, right) => {
      let (left_lane, left_id) = left
      let (right_lane, right_id) = right
      if left_lane != right_lane {
        left_lane.compare(right_lane)
      } else {
        left_id.compare(right_id)
      }
    })
    let ids : Array[String] = []
    for node in layer {
      let (_, node_id) = node
      ids.push(node_id)
    }
    normalized_layers.push(ids)
  }
  normalized_layers
}

///|
fn dump_case_trace(case_name : String) -> Bool {
  let kernel = if case_name == "case1" {
    Some(case1_kernel())
  } else if case_name == "case2" {
    Some(case2_kernel())
  } else if case_name == "case3" {
    Some(case3_kernel())
  } else {
    None
  }
  match kernel {
    Some(found) => {
      dump_graph_trace(case_name, found.graph)
      true
    }
    None => false
  }
}

///|
fn dump_graph_trace(case_name : String, graph : @model.MermaidGraph) -> Unit {
  let options : @model.RenderOptions = {
    ..@model.RenderOptions::default(),
    layout_engine: Some(DagreParity),
  }
  let setup_state = @layout_engine_graph_legacy_setup_core.build_legacy_layout_setup(
    graph, options, true, false,
  )
  let placement_state = @layout_engine_graph_placement_core.run_legacy_placement_phase(
    graph, setup_state, true, false,
  )

  println("CASE\t\{case_name}")
  println("DIRECTION\t\{direction_tag(graph.direction)}")
  for edge in graph.edges {
    println("EDGE\t\{edge.source}\t\{edge.target}")
  }

  let sorted_node_ids = sorted_graph_node_ids(graph)
  for node in setup_state.nodes_in_order {
    println("NODE_ORDER\t\{node.id}")
  }
  for node_id in sorted_node_ids {
    match placement_state.positioned_by_id.get(node_id) {
      Some(node) =>
        println("NODE_SIZE\t\{node_id}\t\{node.width}\t\{node.height}")
      None => ()
    }
  }
  for node_id in sorted_node_ids {
    println(
      "RANK\t\{node_id}\t\{option_int_or(setup_state.lane_state.flow_rank_by_node_id.get(node_id), 0)}",
    )
  }
  let layers = rank_layers(setup_state)
  for rank, layer in layers {
    let joined_layer = layer.join(",")
    println("LAYER\t\{rank}\t\{joined_layer}")
  }
  for node_id in sorted_node_ids {
    match placement_state.positioned_by_id.get(node_id) {
      Some(node) => println("POS\t\{node_id}\t\{node.x}\t\{node.y}")
      None => ()
    }
  }
}

///|
fn dump_source_trace(source : String) -> Bool {
  let parsed : Result[@model.MermaidGraph, @model.MermaidError] = try? @parser_header_core.parse_mermaid(
    source,
  )
  match parsed {
    Ok(graph) => {
      dump_graph_trace("source", graph)
      true
    }
    Err(err) => {
      println("Error: failed to parse source: \{err}")
      false
    }
  }
}

///|
fn run() -> Unit {
  let args = cli_args_without_program()
  match parse_source_arg(args) {
    Some(source) => {
      let ok = dump_source_trace(source)
      if !ok {
        print_usage()
      }
      return
    }
    None => ()
  }
  match parse_case_arg(args) {
    Some(case_name) =>
      if case_name == "help" {
        print_usage()
      } else if case_name == "all" {
        let _ = dump_case_trace("case1")
        let _ = dump_case_trace("case2")
        let _ = dump_case_trace("case3")
      } else if !dump_case_trace(case_name) {
        println("Error: unknown case '\{case_name}'")
        print_usage()
      }
    None => {
      println("Error: invalid arguments")
      print_usage()
    }
  }
}
