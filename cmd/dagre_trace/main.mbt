///|
priv struct DagreTraceKernel {
  nodes : Array[@model.MermaidNode]
  rank_by_id : Map[String, Int]
  max_rank : Int
  edges : Array[@model.MermaidEdge]
}

///|
fn main {
  run()
}

///|
fn print_usage() -> Unit {
  let usage =
    #|Usage:
    #|  moon run cmd/dagre_trace -- --case case1
    #|  moon run cmd/dagre_trace -- --case case2
    #|  moon run cmd/dagre_trace -- --case case3
    #|  moon run cmd/dagre_trace -- --case all
    #|Flags:
    #|  --case   case1 | case2 | case3 | all
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
fn bool_literal(value : Bool) -> String {
  if value {
    "true"
  } else {
    "false"
  }
}

///|
fn sorted_int_keys_for_barycenters(
  entries : Map[Int, Map[String, String]],
) -> Array[Int] {
  let keys : Array[Int] = []
  for rank, _ in entries {
    keys.push(rank)
  }
  keys.sort()
  keys
}

///|
fn sorted_string_keys_for_barycenter_rank(
  entries : Map[String, String],
) -> Array[String] {
  let keys : Array[String] = []
  for node_id, _ in entries {
    keys.push(node_id)
  }
  keys.sort()
  keys
}

///|
fn dump_trace(
  trace : @layout_engine_graph_lane_core.DagreParityOrderTrace,
) -> Unit {
  for trace_index, rank_nodes in trace.rank_nodes_trace {
    for rank, node_ids in rank_nodes {
      let joined_node_ids = node_ids.join(",")
      println("TRACE\t\{trace_index}\t\{rank}\t\{joined_node_ids}")
    }
  }
  for step in trace.sweep_step_trace {
    println(
      "PASS\t\{step.pass_index}\t\{bool_literal(step.incoming_from_neighbor)}\t\{bool_literal(step.bias_right)}\t\{step.candidate_crossings}",
    )
    for rank, node_ids in step.rank_nodes {
      let joined_node_ids = node_ids.join(",")
      println("PASS_LAYER\t\{step.pass_index}\t\{rank}\t\{joined_node_ids}")
    }
    for rank in sorted_int_keys_for_barycenters(step.barycenters_by_rank) {
      match step.barycenters_by_rank.get(rank) {
        Some(entries) =>
          for node_id in sorted_string_keys_for_barycenter_rank(entries) {
            match entries.get(node_id) {
              Some(value) =>
                println(
                  "BARY\t\{step.pass_index}\t\{rank}\t\{node_id}\t\{value}",
                )
              None => ()
            }
          }
        None => ()
      }
    }
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
fn case1_kernel() -> DagreTraceKernel {
  {
    nodes: [
      flow_node("A"),
      flow_node("B"),
      flow_node("M"),
      flow_node("X"),
      flow_node("Y"),
      flow_node("__lane_dummy_f_4_1"),
      flow_node("__lane_dummy_f_5_1"),
    ],
    rank_by_id: {
      "A": 0,
      "B": 0,
      "M": 1,
      "X": 2,
      "Y": 2,
      "__lane_dummy_f_4_1": 1,
      "__lane_dummy_f_5_1": 1,
    },
    max_rank: 2,
    edges: [
      flow_edge("A", "M"),
      flow_edge("B", "M"),
      flow_edge("M", "X"),
      flow_edge("M", "Y"),
      flow_edge("A", "__lane_dummy_f_4_1"),
      flow_edge("__lane_dummy_f_4_1", "Y"),
      flow_edge("B", "__lane_dummy_f_5_1"),
      flow_edge("__lane_dummy_f_5_1", "X"),
    ],
  }
}

///|
fn case2_kernel() -> DagreTraceKernel {
  {
    nodes: [
      flow_node("A"),
      flow_node("B"),
      flow_node("D"),
      flow_node("__lane_dummy_f_2_1"),
      flow_node("__lane_dummy_f_6_1"),
      flow_node("C"),
      flow_node("__lane_dummy_f_3_1"),
      flow_node("__lane_dummy_f_7_1"),
      flow_node("E"),
      flow_node("F"),
    ],
    rank_by_id: {
      "A": 0,
      "B": 0,
      "D": 1,
      "__lane_dummy_f_2_1": 1,
      "__lane_dummy_f_6_1": 1,
      "C": 1,
      "__lane_dummy_f_3_1": 1,
      "__lane_dummy_f_7_1": 1,
      "E": 2,
      "F": 2,
    },
    max_rank: 2,
    edges: [
      flow_edge("A", "D"),
      flow_edge("B", "C"),
      flow_edge("A", "__lane_dummy_f_2_1"),
      flow_edge("__lane_dummy_f_2_1", "E"),
      flow_edge("B", "__lane_dummy_f_3_1"),
      flow_edge("__lane_dummy_f_3_1", "F"),
      flow_edge("C", "F"),
      flow_edge("D", "E"),
      flow_edge("A", "__lane_dummy_f_6_1"),
      flow_edge("__lane_dummy_f_6_1", "F"),
      flow_edge("B", "__lane_dummy_f_7_1"),
      flow_edge("__lane_dummy_f_7_1", "E"),
    ],
  }
}

///|
fn case3_kernel() -> DagreTraceKernel {
  {
    nodes: [
      flow_node("A"),
      flow_node("B"),
      flow_node("C"),
      flow_node("D"),
      flow_node("E"),
      flow_node("F"),
      flow_node("G"),
      flow_node("H"),
    ],
    rank_by_id: {
      "A": 0,
      "B": 0,
      "C": 1,
      "D": 1,
      "E": 2,
      "F": 2,
      "G": 3,
      "H": 3,
    },
    max_rank: 3,
    edges: [
      flow_edge("A", "C"),
      flow_edge("A", "D"),
      flow_edge("B", "C"),
      flow_edge("B", "D"),
      flow_edge("C", "E"),
      flow_edge("D", "F"),
      flow_edge("C", "F"),
      flow_edge("D", "E"),
      flow_edge("E", "G"),
      flow_edge("F", "H"),
      flow_edge("E", "H"),
      flow_edge("F", "G"),
    ],
  }
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
      let trace = @layout_engine_graph_lane_core.collect_dagre_parity_order_trace(
        found.nodes,
        found.rank_by_id,
        found.max_rank,
        found.edges,
      )
      dump_trace(trace)
      true
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
        println("CASE\tcase1")
        let _ = dump_case_trace("case1")
        println("CASE\tcase2")
        let _ = dump_case_trace("case2")
        println("CASE\tcase3")
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
