///|
priv struct ElkTraceKernel {
  direction : @model.Direction
  nodes : Array[String]
  edges : Array[(String, String)]
}

///|
fn main {
  run()
}

///|
fn print_usage() -> Unit {
  let usage =
    #|Usage:
    #|  moon run cmd/elk_trace -- --case fanout
    #|  moon run cmd/elk_trace -- --case feedback_mesh
    #|  moon run cmd/elk_trace -- --case long_span
    #|  moon run cmd/elk_trace -- --case all
    #|Flags:
    #|  --case   fanout | feedback_mesh | long_span | all
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
fn empty_graph_maps() -> (
  Map[String, Map[String, String]],
  Map[String, String],
  Map[String, Map[String, String]],
  Map[String, @model.SequenceParticipantKind],
) {
  ({}, {}, {}, {})
}

///|
fn build_graph(kernel : ElkTraceKernel) -> @model.MermaidGraph {
  let node_map : Map[String, @model.MermaidNode] = {}
  for node_id in kernel.nodes {
    node_map[node_id] = flow_node(node_id)
  }
  let edges : Array[@model.MermaidEdge] = []
  for edge in kernel.edges {
    let (source, target) = edge
    edges.push(flow_edge(source, target))
  }
  let (class_defs, class_assignments, node_styles, sequence_actor_kinds) = empty_graph_maps()
  {
    diagram_kind: Flowchart,
    direction: kernel.direction,
    nodes: node_map,
    edges,
    subgraphs: [],
    class_defs,
    class_assignments,
    node_styles,
    sequence_actor_order: [],
    sequence_actor_kinds,
    sequence_blocks: [],
    sequence_notes: [],
    sequence_activation_commands: [],
  }
}

///|
fn fanout_kernel() -> ElkTraceKernel {
  {
    direction: LR,
    nodes: ["A", "B", "C", "D", "E", "F"],
    edges: [
      ("A", "B"),
      ("A", "C"),
      ("A", "D"),
      ("B", "E"),
      ("C", "E"),
      ("D", "F"),
      ("E", "F"),
    ],
  }
}

///|
fn feedback_mesh_kernel() -> ElkTraceKernel {
  {
    direction: LR,
    nodes: ["S", "A", "B", "C", "D", "T"],
    edges: [
      ("S", "A"),
      ("S", "B"),
      ("A", "C"),
      ("B", "C"),
      ("C", "D"),
      ("D", "T"),
      ("D", "B"),
      ("C", "A"),
    ],
  }
}

///|
fn long_span_kernel() -> ElkTraceKernel {
  {
    direction: LR,
    nodes: ["N0", "N1", "N2", "N3", "N4", "N5", "N6"],
    edges: [
      ("N0", "N1"),
      ("N1", "N2"),
      ("N2", "N3"),
      ("N3", "N4"),
      ("N4", "N5"),
      ("N5", "N6"),
      ("N0", "N4"),
      ("N1", "N5"),
      ("N2", "N6"),
      ("N6", "N3"),
    ],
  }
}

///|
fn kernel_by_case_name(case_name : String) -> ElkTraceKernel? {
  if case_name == "fanout" {
    Some(fanout_kernel())
  } else if case_name == "feedback_mesh" {
    Some(feedback_mesh_kernel())
  } else if case_name == "long_span" {
    Some(long_span_kernel())
  } else {
    None
  }
}

///|
fn dump_rank_layers(prefix : String, layers : Array[Array[String]]) -> Unit {
  for rank, node_ids in layers {
    let joined_node_ids = node_ids.join(",")
    println("\{prefix}\t\{rank}\t\{joined_node_ids}")
  }
}

///|
fn sorted_string_keys(entries : Map[String, Int]) -> Array[String] {
  let keys : Array[String] = []
  for key, _ in entries {
    keys.push(key)
  }
  keys.sort()
  keys
}

///|
fn sorted_oriented_edges(
  edges : Array[(String, String)],
) -> Array[(String, String)] {
  let sorted = edges.copy()
  sorted.sort_by((left, right) => {
    let (left_source, left_target) = left
    let (right_source, right_target) = right
    let source_cmp = left_source.compare(right_source)
    if source_cmp != 0 {
      source_cmp
    } else {
      left_target.compare(right_target)
    }
  })
  sorted
}

///|
fn dump_case_trace(case_name : String) -> Bool {
  match kernel_by_case_name(case_name) {
    Some(kernel) => {
      let graph = build_graph(kernel)
      let options = {
        ..@model.RenderOptions::default(),
        layout_engine: Some(Elk),
      }
      let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
        graph,
        options,
        use_subgraph_redirects: true,
        compact_fanin: false,
      }
      match
        @layout_engine_graph_engine_elk_core.collect_elk_layered_rank_trace(
          request,
        ) {
        Some(trace) => {
          println("SEED\t\{trace.rank_seed_strategy}")
          for node_id in sorted_string_keys(trace.rank_seed_rank_by_node_id) {
            match trace.rank_seed_rank_by_node_id.get(node_id) {
              Some(rank) => println("SEED_RANK\t\{node_id}\t\{rank}")
              None => ()
            }
          }
          for
            node_id in sorted_string_keys(
              trace.rank_seed_order_index_by_node_id,
            ) {
            match trace.rank_seed_order_index_by_node_id.get(node_id) {
              Some(order_index) =>
                println("SEED_ORDER\t\{node_id}\t\{order_index}")
              None => ()
            }
          }
          for edge in sorted_oriented_edges(trace.rank_seed_oriented_edges) {
            let (source_id, target_id) = edge
            println("SEED_EDGE\t\{source_id}\t\{target_id}")
          }
          dump_rank_layers("SEED_LAYER", trace.rank_seed_layers)
          dump_rank_layers("RANK_LAYER", trace.rank_layers)
          true
        }
        None => {
          println("Error: graph does not support elk layered trace")
          false
        }
      }
    }
    None => false
  }
}

///|
fn run() -> Unit {
  let args = cli_args_without_program()
  match parse_case_arg(args) {
    Some(case_name) =>
      if case_name == "help" {
        print_usage()
      } else if case_name == "all" {
        println("CASE\tfanout")
        let _ = dump_case_trace("fanout")
        println("CASE\tfeedback_mesh")
        let _ = dump_case_trace("feedback_mesh")
        println("CASE\tlong_span")
        let _ = dump_case_trace("long_span")
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
