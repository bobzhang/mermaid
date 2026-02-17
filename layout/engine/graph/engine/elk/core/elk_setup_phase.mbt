///|
fn directed_edge_key(source_id : String, target_id : String) -> String {
  "\{source_id}->\{target_id}"
}

///|
priv struct ElkGraphComplexity {
  max_outdegree : Int
  max_indegree : Int
  longest_edge_label_len : Int
  labeled_edge_count : Int
  reciprocal_edge_count : Int
}

///|
fn graph_complexity(graph : MermaidGraph) -> ElkGraphComplexity {
  let outdegree_by_id : Map[String, Int] = {}
  let indegree_by_id : Map[String, Int] = {}
  let directed_count_by_key : Map[String, Int] = {}
  let mut longest_edge_label_len = 0
  let mut labeled_edge_count = 0
  for edge in graph.edges {
    let source_outdegree = @layout_engine_graph_internal_core.option_int_or(
      outdegree_by_id.get(edge.source),
      0,
    )
    outdegree_by_id[edge.source] = source_outdegree + 1
    let target_indegree = @layout_engine_graph_internal_core.option_int_or(
      indegree_by_id.get(edge.target),
      0,
    )
    indegree_by_id[edge.target] = target_indegree + 1
    let directed_key = directed_edge_key(edge.source, edge.target)
    directed_count_by_key[directed_key] = @layout_engine_graph_internal_core.option_int_or(
        directed_count_by_key.get(directed_key),
        0,
      ) +
      1
    match edge.label {
      Some(label) => {
        labeled_edge_count += 1
        let label_len = label.length()
        if label_len > longest_edge_label_len {
          longest_edge_label_len = label_len
        }
      }
      None => ()
    }
  }

  let mut max_outdegree = 0
  for _, outdegree in outdegree_by_id {
    if outdegree > max_outdegree {
      max_outdegree = outdegree
    }
  }
  let mut max_indegree = 0
  for _, indegree in indegree_by_id {
    if indegree > max_indegree {
      max_indegree = indegree
    }
  }
  let mut reciprocal_edge_count = 0
  for edge in graph.edges {
    let reverse_key = directed_edge_key(edge.target, edge.source)
    if @layout_engine_graph_internal_core.option_int_or(
        directed_count_by_key.get(reverse_key),
        0,
      ) >
      0 {
      reciprocal_edge_count += 1
    }
  }

  {
    max_outdegree,
    max_indegree,
    longest_edge_label_len,
    labeled_edge_count,
    reciprocal_edge_count,
  }
}

///|
fn graph_edge_density_per_node_pct(graph : MermaidGraph) -> Int {
  if graph.nodes.length() == 0 {
    0
  } else {
    graph.edges.length() * 100 / graph.nodes.length()
  }
}

///|
fn elk_node_spacing(
  base_spacing : Int,
  graph : MermaidGraph,
  complexity : ElkGraphComplexity,
) -> Int {
  let fanout_boost = ((complexity.max_outdegree - 1).max(0) * 7).min(42)
  let indegree_boost = ((complexity.max_indegree - 2).max(0) * 4).min(16)
  let label_boost = (complexity.longest_edge_label_len - 4).max(0).min(24)
  let reciprocal_boost = (complexity.reciprocal_edge_count * 4).min(16)
  let edge_density_pct = graph_edge_density_per_node_pct(graph)
  let density_compact = (if graph.nodes.length() >= 24 {
      18
    } else if graph.nodes.length() >= 16 {
      10
    } else {
      0
    }) +
    ((edge_density_pct - 170).max(0) / 5).min(18)
  (base_spacing +
  fanout_boost +
  indegree_boost +
  label_boost +
  reciprocal_boost -
  density_compact)
  .max(90)
  .min(198)
}

///|
fn elk_layer_spacing(
  base_spacing : Int,
  graph : MermaidGraph,
  complexity : ElkGraphComplexity,
) -> Int {
  let labeled_edge_ratio_pct = if graph.edges.length() == 0 {
    0
  } else {
    complexity.labeled_edge_count * 100 / graph.edges.length()
  }
  let label_ratio_boost = (labeled_edge_ratio_pct / 10).min(12)
  let longest_label_boost = (complexity.longest_edge_label_len - 8)
    .max(0)
    .min(16)
  let reciprocal_boost = (complexity.reciprocal_edge_count * 3).min(12)
  let edge_density_pct = graph_edge_density_per_node_pct(graph)
  let density_compact = (if graph.nodes.length() >= 24 {
      12
    } else if graph.nodes.length() >= 16 {
      8
    } else {
      0
    }) +
    ((edge_density_pct - 180).max(0) / 8).min(12)
  (base_spacing +
  label_ratio_boost +
  longest_label_boost +
  reciprocal_boost -
  density_compact)
  .max(70)
  .min(165)
}

///|
/// Derives ELK-preferred render options for the graph.
///
/// Explicit `node_spacing` / `layer_spacing` from the caller are preserved.
fn derive_elk_render_options(
  graph : MermaidGraph,
  options : RenderOptions,
) -> RenderOptions {
  let complexity = graph_complexity(graph)
  let state_graph = @layout_engine_graph_internal_core.is_state_graph(graph)
  let resolved_node_spacing = match options.node_spacing {
    Some(spacing) => Some(spacing)
    None =>
      if state_graph {
        None
      } else {
        Some(
          elk_node_spacing(
            @layout_engine_graph_internal_core.resolve_node_spacing(options),
            graph,
            complexity,
          ),
        )
      }
  }
  let resolved_layer_spacing = match options.layer_spacing {
    Some(spacing) => Some(spacing)
    None =>
      if state_graph {
        None
      } else {
        Some(
          elk_layer_spacing(
            @layout_engine_graph_internal_core.resolve_layer_spacing(options),
            graph,
            complexity,
          ),
        )
      }
  }
  {
    bg: options.bg,
    fg: options.fg,
    line: options.line,
    accent: options.accent,
    muted: options.muted,
    surface: options.surface,
    border: options.border,
    font: options.font,
    padding: options.padding,
    node_spacing: resolved_node_spacing,
    layer_spacing: resolved_layer_spacing,
    transparent: options.transparent,
    layout_engine: options.layout_engine,
  }
}
