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
    #|  moon run cmd/elk_trace -- --source "graph LR\nA --> B\nB --> C"
    #|  moon run cmd/elk_trace -- --case fanout --sweep-kernel edge-slot
    #|  moon run cmd/elk_trace -- --case fanout --trial-count 5
    #|  moon run cmd/elk_trace -- --case fanout --sweep-pass-count 6
    #|  moon run cmd/elk_trace -- --case fanout --compare-kernels
    #|  moon run cmd/elk_trace -- --case all
    #|Flags:
    #|  --case   fanout | feedback_mesh | long_span | all
    #|  --source Mermaid source text (use shell command substitution for fixture files)
    #|  --sweep-kernel  default | neighbor-mean | edge-slot
    #|  --trial-count  Positive crossing trial count override
    #|  --sweep-pass-count  Positive crossing sweep-pass override
    #|  --compare-kernels  Print default-vs-edge-slot rank trace comparison summary
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
priv struct ElkTraceCliArgs {
  show_help : Bool
  case_name : String?
  source : String?
  sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel
  trial_count_override : Int?
  sweep_pass_count_override : Int?
  compare_kernels : Bool
}

///|
fn decode_source_arg(raw : String) -> String {
  raw
  .replace_all(old="\\n", new="\n")
  .replace_all(old="\\t", new="\t")
  .replace_all(old="\\r", new="\r")
}

///|
fn decode_sweep_kernel_arg(
  raw : String,
) -> @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel? {
  match raw.trim().to_lower() {
    "default" => Some(Default)
    "neighbor-mean" => Some(NeighborMeanBidirectional)
    "edge-slot" => Some(NeighborMeanEdgeSlotBidirectional)
    _ => None
  }
}

///|
fn decode_positive_int_arg(raw : String) -> Int? {
  let normalized = raw.trim().to_string()
  if normalized == "" {
    return None
  }
  let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
    normalized,
  )
  match parsed {
    Ok(value) => if value > 0 { Some(value) } else { None }
    Err(_) => None
  }
}

///|
fn parse_cli_args(args : Array[String]) -> ElkTraceCliArgs? {
  let mut show_help = false
  let mut case_name : String? = None
  let mut source : String? = None
  let mut sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel = Default
  let mut trial_count_override : Int? = None
  let mut sweep_pass_count_override : Int? = None
  let mut compare_kernels = false

  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--help" {
      show_help = true
      i += 1
      continue
    }
    if arg == "--case" {
      if i + 1 >= args.length() {
        return None
      }
      let parsed_case_name = args[i + 1].trim().to_lower()
      if parsed_case_name == "" {
        return None
      }
      case_name = Some(parsed_case_name.to_string())
      i += 2
      continue
    }
    if arg == "--source" {
      if i + 1 >= args.length() {
        return None
      }
      let parsed_source = decode_source_arg(args[i + 1])
      if parsed_source.trim() == "" {
        return None
      }
      source = Some(parsed_source.to_string())
      i += 2
      continue
    }
    if arg == "--sweep-kernel" {
      if i + 1 >= args.length() {
        return None
      }
      match decode_sweep_kernel_arg(args[i + 1]) {
        Some(parsed_kernel) => sweep_kernel = parsed_kernel
        None => return None
      }
      i += 2
      continue
    }
    if arg == "--compare-kernels" {
      compare_kernels = true
      i += 1
      continue
    }
    if arg == "--trial-count" {
      if i + 1 >= args.length() {
        return None
      }
      match decode_positive_int_arg(args[i + 1]) {
        Some(value) => trial_count_override = Some(value)
        None => return None
      }
      i += 2
      continue
    }
    if arg == "--sweep-pass-count" {
      if i + 1 >= args.length() {
        return None
      }
      match decode_positive_int_arg(args[i + 1]) {
        Some(value) => sweep_pass_count_override = Some(value)
        None => return None
      }
      i += 2
      continue
    }
    if arg is [.. "--case=", .. raw_case] {
      let parsed_case_name = raw_case.trim().to_lower()
      if parsed_case_name == "" {
        return None
      }
      case_name = Some(parsed_case_name.to_string())
      i += 1
      continue
    }
    if arg is [.. "--source=", .. raw_source] {
      let parsed_source = decode_source_arg(raw_source.to_string())
      if parsed_source.trim() == "" {
        return None
      }
      source = Some(parsed_source.to_string())
      i += 1
      continue
    }
    if arg is [.. "--sweep-kernel=", .. raw_sweep_kernel] {
      match decode_sweep_kernel_arg(raw_sweep_kernel.to_string()) {
        Some(parsed_kernel) => sweep_kernel = parsed_kernel
        None => return None
      }
      i += 1
      continue
    }
    if arg is [.. "--trial-count=", .. raw_trial_count] {
      match decode_positive_int_arg(raw_trial_count.to_string()) {
        Some(value) => trial_count_override = Some(value)
        None => return None
      }
      i += 1
      continue
    }
    if arg is [.. "--sweep-pass-count=", .. raw_sweep_pass_count] {
      match decode_positive_int_arg(raw_sweep_pass_count.to_string()) {
        Some(value) => sweep_pass_count_override = Some(value)
        None => return None
      }
      i += 1
      continue
    }
    return None
  }

  if case_name is Some(_) && source is Some(_) {
    return None
  }

  let resolved_case_name = if show_help {
    case_name
  } else {
    match case_name {
      Some(name) => Some(name)
      None => if source is Some(_) { None } else { Some("all") }
    }
  }
  Some({
    show_help,
    case_name: resolved_case_name,
    source,
    sweep_kernel,
    trial_count_override,
    sweep_pass_count_override,
    compare_kernels,
  })
}

///|
fn build_graph(kernel : ElkTraceKernel) -> @model.MermaidGraph {
  let node_map : Map[String, @model.MermaidNode] = {}
  for node_id in kernel.nodes {
    node_map[node_id] = { id: node_id, label: node_id, shape: Rectangle }
  }
  let edges : Array[@model.MermaidEdge] = []
  for edge in kernel.edges {
    let (source, target) = edge
    edges.push({
      source,
      target,
      label: None,
      style: Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: Some("-->"),
    })
  }
  let class_defs : Map[String, Map[String, String]] = {}
  let class_assignments : Map[String, String] = {}
  let node_styles : Map[String, Map[String, String]] = {}
  let sequence_actor_kinds : Map[String, @model.SequenceParticipantKind] = {}
  {
    diagram_kind: Flowchart,
    direction: kernel.direction,
    nodes: node_map,
    node_definition_order: kernel.nodes.copy(),
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
  match case_name {
    "fanout" => Some(fanout_kernel())
    "feedback_mesh" => Some(feedback_mesh_kernel())
    "long_span" => Some(long_span_kernel())
    _ => None
  }
}

///|
fn dump_graph_trace(
  graph : @model.MermaidGraph,
  sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Bool {
  let options = { ..@model.RenderOptions::default(), layout_engine: Some(Elk) }
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options,
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  match
    @layout_engine_graph_engine_elk_core.collect_elk_layered_rank_trace_lines_with_crossing_overrides(
      request, sweep_kernel, trial_count_override, sweep_pass_count_override,
    ) {
    Some(lines) => {
      for line in lines {
        println(line)
      }
      true
    }
    None => {
      println("Error: graph does not support elk layered trace")
      false
    }
  }
}

///|
fn dump_graph_kernel_comparison(
  graph : @model.MermaidGraph,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Bool {
  let options = { ..@model.RenderOptions::default(), layout_engine: Some(Elk) }
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options,
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  match
    @layout_engine_graph_engine_elk_core.collect_elk_layered_rank_trace_kernel_comparison_lines_with_crossing_overrides(
      request,
      Default,
      NeighborMeanEdgeSlotBidirectional,
      trial_count_override,
      sweep_pass_count_override,
    ) {
    Some(lines) => {
      for line in lines {
        println(line)
      }
      true
    }
    None => {
      println("Error: graph does not support elk layered trace")
      false
    }
  }
}

///|
fn dump_case_trace(
  case_name : String,
  sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Bool {
  match kernel_by_case_name(case_name) {
    Some(kernel) =>
      dump_graph_trace(
        build_graph(kernel),
        sweep_kernel,
        trial_count_override,
        sweep_pass_count_override,
      )
    None => false
  }
}

///|
fn dump_case_kernel_comparison(
  case_name : String,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Bool {
  match kernel_by_case_name(case_name) {
    Some(kernel) =>
      dump_graph_kernel_comparison(
        build_graph(kernel),
        trial_count_override,
        sweep_pass_count_override,
      )
    None => false
  }
}

///|
fn dump_source_trace(
  source : String,
  sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Bool {
  let graph_result : Result[@model.MermaidGraph, @model.MermaidError] = try? @parser_header_core.parse_mermaid(
    source,
  )
  match graph_result {
    Ok(graph) =>
      dump_graph_trace(
        graph, sweep_kernel, trial_count_override, sweep_pass_count_override,
      )
    Err(err) => {
      println("Error: failed to parse --source payload")
      println("\{err}")
      false
    }
  }
}

///|
fn dump_source_kernel_comparison(
  source : String,
  trial_count_override : Int?,
  sweep_pass_count_override : Int?,
) -> Bool {
  let graph_result : Result[@model.MermaidGraph, @model.MermaidError] = try? @parser_header_core.parse_mermaid(
    source,
  )
  match graph_result {
    Ok(graph) =>
      dump_graph_kernel_comparison(
        graph, trial_count_override, sweep_pass_count_override,
      )
    Err(err) => {
      println("Error: failed to parse --source payload")
      println("\{err}")
      false
    }
  }
}

///|
fn run() -> Unit {
  let args = cli_args_without_program()
  match parse_cli_args(args) {
    Some(parsed_args) =>
      if parsed_args.show_help {
        print_usage()
      } else if parsed_args.source is Some(source) {
        if parsed_args.compare_kernels {
          if !dump_source_kernel_comparison(
              source,
              parsed_args.trial_count_override,
              parsed_args.sweep_pass_count_override,
            ) {
            print_usage()
          }
        } else if !dump_source_trace(
            source,
            parsed_args.sweep_kernel,
            parsed_args.trial_count_override,
            parsed_args.sweep_pass_count_override,
          ) {
          print_usage()
        }
      } else if parsed_args.case_name is Some(case_name) {
        if case_name == "all" {
          for case_name in ["fanout", "feedback_mesh", "long_span"] {
            println("CASE\t\{case_name}")
            if parsed_args.compare_kernels {
              let _ = dump_case_kernel_comparison(
                case_name,
                parsed_args.trial_count_override,
                parsed_args.sweep_pass_count_override,
              )
            } else {
              let _ = dump_case_trace(
                case_name,
                parsed_args.sweep_kernel,
                parsed_args.trial_count_override,
                parsed_args.sweep_pass_count_override,
              )
            }
          }
        } else if parsed_args.compare_kernels &&
          !dump_case_kernel_comparison(
            case_name,
            parsed_args.trial_count_override,
            parsed_args.sweep_pass_count_override,
          ) {
          println("Error: unknown case '\{case_name}'")
          print_usage()
        } else if !parsed_args.compare_kernels &&
          !dump_case_trace(
            case_name,
            parsed_args.sweep_kernel,
            parsed_args.trial_count_override,
            parsed_args.sweep_pass_count_override,
          ) {
          println("Error: unknown case '\{case_name}'")
          print_usage()
        }
      } else {
        println("Error: invalid arguments")
        print_usage()
      }
    None => {
      println("Error: invalid arguments")
      print_usage()
    }
  }
}
