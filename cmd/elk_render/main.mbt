///|
struct ElkRenderCliArgs {
  show_help : Bool
  source : String?
  sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel
  trial_count_override : Int?
  sweep_pass_count_override : Int?
  layout_engine : @model.LayoutEngine
}

///|
fn parse_positive_int(raw : String) -> Int? {
  let parsed : Result[Int, @strconv.StrConvError] = try? @strconv.parse_int(
    raw.trim().to_string(),
  )
  match parsed {
    Ok(value) => if value > 0 { Some(value) } else { None }
    Err(_) => None
  }
}

///|
fn parse_sweep_kernel(
  raw : String,
) -> @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel? {
  let normalized = raw.trim().to_lower()
  if normalized == "default" {
    return Some(Default)
  }
  if normalized == "neighbor-mean" || normalized == "neighbor_mean" {
    return Some(NeighborMeanBidirectional)
  }
  if normalized == "edge-slot" || normalized == "edge_slot" {
    return Some(NeighborMeanEdgeSlotBidirectional)
  }
  None
}

///|
fn parse_layout_engine(raw : String) -> @model.LayoutEngine? {
  let normalized = raw.trim().to_lower()
  if normalized == "elk" {
    return Some(Elk)
  }
  if normalized == "elk-layered" || normalized == "elk_layered" {
    return Some(ElkLayered)
  }
  None
}

///|
fn parse_cli_args(args : Array[String]) -> ElkRenderCliArgs? {
  let mut show_help = false
  let mut source : String? = None
  let mut sweep_kernel : @layout_engine_graph_engine_elk_core.ElkLayeredRankTraceSweepKernel = Default
  let mut trial_count_override : Int? = None
  let mut sweep_pass_count_override : Int? = None
  let mut layout_engine : @model.LayoutEngine = Elk
  let mut expect_source = false
  let mut expect_sweep_kernel = false
  let mut expect_trial_count = false
  let mut expect_sweep_pass_count = false
  let mut expect_layout_engine = false

  for arg in args {
    if expect_source {
      if arg is [.. "--", ..] {
        return None
      }
      source = Some(arg)
      expect_source = false
      continue
    }
    if expect_sweep_kernel {
      if arg is [.. "--", ..] {
        return None
      }
      match parse_sweep_kernel(arg) {
        Some(value) => sweep_kernel = value
        None => return None
      }
      expect_sweep_kernel = false
      continue
    }
    if expect_trial_count {
      if arg is [.. "--", ..] {
        return None
      }
      match parse_positive_int(arg) {
        Some(value) => trial_count_override = Some(value)
        None => return None
      }
      expect_trial_count = false
      continue
    }
    if expect_sweep_pass_count {
      if arg is [.. "--", ..] {
        return None
      }
      match parse_positive_int(arg) {
        Some(value) => sweep_pass_count_override = Some(value)
        None => return None
      }
      expect_sweep_pass_count = false
      continue
    }
    if expect_layout_engine {
      if arg is [.. "--", ..] {
        return None
      }
      match parse_layout_engine(arg) {
        Some(value) => layout_engine = value
        None => return None
      }
      expect_layout_engine = false
      continue
    }

    if arg == "--help" {
      show_help = true
      continue
    }
    if arg == "--source" {
      expect_source = true
      continue
    }
    if arg == "--sweep-kernel" {
      expect_sweep_kernel = true
      continue
    }
    if arg == "--trial-count" {
      expect_trial_count = true
      continue
    }
    if arg == "--sweep-pass-count" {
      expect_sweep_pass_count = true
      continue
    }
    if arg == "--layout-engine" {
      expect_layout_engine = true
      continue
    }

    if arg is [.. "--source=", .. raw_source] {
      let source_value = raw_source.to_string()
      if source_value == "" {
        return None
      }
      source = Some(source_value)
      continue
    }
    if arg is [.. "--sweep-kernel=", .. raw_sweep_kernel] {
      match parse_sweep_kernel(raw_sweep_kernel.to_string()) {
        Some(value) => sweep_kernel = value
        None => return None
      }
      continue
    }
    if arg is [.. "--trial-count=", .. raw_trial_count] {
      match parse_positive_int(raw_trial_count.to_string()) {
        Some(value) => trial_count_override = Some(value)
        None => return None
      }
      continue
    }
    if arg is [.. "--sweep-pass-count=", .. raw_sweep_pass_count] {
      match parse_positive_int(raw_sweep_pass_count.to_string()) {
        Some(value) => sweep_pass_count_override = Some(value)
        None => return None
      }
      continue
    }
    if arg is [.. "--layout-engine=", .. raw_layout_engine] {
      match parse_layout_engine(raw_layout_engine.to_string()) {
        Some(value) => layout_engine = value
        None => return None
      }
      continue
    }
    if arg is [.. "--", ..] {
      return None
    }
    if source is Some(_) {
      return None
    }
    source = Some(arg)
  }

  if expect_source ||
    expect_sweep_kernel ||
    expect_trial_count ||
    expect_sweep_pass_count ||
    expect_layout_engine {
    return None
  }
  Some({
    show_help,
    source,
    sweep_kernel,
    trial_count_override,
    sweep_pass_count_override,
    layout_engine,
  })
}

///|
fn usage_text() -> String {
  (
    #|Usage:
    #|  moon run cmd/elk_render -- "graph TD\nA --> B"
    #|  moon run cmd/elk_render -- --trial-count=5 --sweep-pass-count=6 "graph TD\nA --> B"
    #|  moon run cmd/elk_render -- --layout-engine=elk-layered "graph TD\nA --> B"
    #|
    #|Flags:
    #|  --source <text>          Mermaid source payload (or positional arg)
    #|  --sweep-kernel <name>    default | neighbor-mean | edge-slot
    #|  --trial-count <int>      Positive crossing trial-count override
    #|  --sweep-pass-count <int> Positive crossing sweep-pass-count override
    #|  --layout-engine <name>   elk | elk-layered
    #|  --help                   Show this usage text
  )
  .trim_end()
  .to_string()
}

///|
fn cli_args_without_program() -> Array[String] {
  let all_args = @env.args()
  if all_args.length() <= 1 {
    []
  } else {
    let args : Array[String] = []
    for index in 1..<all_args.length() {
      args.push(all_args[index])
    }
    args
  }
}

///|
fn print_usage() -> Unit {
  println(usage_text())
}

///|
fn print_svg_with_overrides(args : ElkRenderCliArgs) -> Unit {
  let source = match args.source {
    Some(value) => value
    None => {
      print_usage()
      return
    }
  }
  let parsed : Result[@model.MermaidGraph, @model.MermaidError] = try? @parser_header_core.parse_mermaid(
    source,
  )
  let graph = match parsed {
    Ok(value) => value
    Err(err) => {
      println("Error: \{err}")
      return
    }
  }
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph,
    options: {
      ..@model.RenderOptions::default(),
      layout_engine: Some(args.layout_engine),
    },
    use_subgraph_redirects: true,
    compact_fanin: false,
  }
  let backend = @layout_engine_graph_engine_elk_core.layout_graph_elk_backend_with_crossing_overrides(
    request,
    args.sweep_kernel,
    args.trial_count_override,
    args.sweep_pass_count_override,
  )
  println(
    @renderer_svg.render_svg(
      backend.positioned_graph,
      @model.DiagramColors::default(),
      "Inter",
      false,
    ),
  )
}

///|
fn run() -> Unit {
  let args = cli_args_without_program()
  match parse_cli_args(args) {
    Some(parsed) =>
      if parsed.show_help {
        print_usage()
      } else {
        print_svg_with_overrides(parsed)
      }
    None => print_usage()
  }
}

///|
fn main {
  run()
}
