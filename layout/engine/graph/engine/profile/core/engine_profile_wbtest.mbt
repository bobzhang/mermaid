///|
fn flow_node(id : String) -> @model.MermaidNode {
  { id, label: id, shape: Rectangle }
}

///|
fn flow_edge(source : String, target : String) -> @model.MermaidEdge {
  {
    source,
    target,
    label: Some("\{source}->\{target}"),
    style: Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: Some("-->"),
  }
}

///|
fn flow_graph() -> @model.MermaidGraph {
  let nodes : Map[String, @model.MermaidNode] = {
    "A": flow_node("A"),
    "B": flow_node("B"),
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
    direction: LR,
    nodes,
    edges: [flow_edge("A", "B")],
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
test "engine profile resolves stable routing policy per engine" {
  let legacy_policy = resolve_graph_engine_routing_policy(Legacy)
  assert_eq(legacy_policy.enable_target_boundary_ports, false)
  assert_eq(legacy_policy.preserve_assigned_endpoint_ports, false)

  let dagre_policy = resolve_graph_engine_routing_policy(DagreParity)
  assert_eq(dagre_policy.enable_target_boundary_ports, true)
  assert_eq(dagre_policy.preserve_assigned_endpoint_ports, true)

  let elk_policy = resolve_graph_engine_routing_policy(Elk)
  assert_eq(elk_policy.enable_target_boundary_ports, true)
  assert_eq(elk_policy.preserve_assigned_endpoint_ports, false)

  let elk_layered_policy = resolve_graph_engine_routing_policy(ElkLayered)
  assert_eq(elk_layered_policy.enable_target_boundary_ports, true)
  assert_eq(elk_layered_policy.preserve_assigned_endpoint_ports, false)
}

///|
test "engine profile runner emits valid backend snapshots for every engine" {
  let request : @layout_engine_graph_contract_core.GraphLayoutBackendRequest = {
    graph: flow_graph(),
    options: @model.RenderOptions::default(),
    use_subgraph_redirects: true,
    compact_fanin: false,
  }

  let legacy_backend = run_graph_layout_engine_backend(request, Legacy)
  assert_eq(legacy_backend.phase_snapshots.length(), 4)
  assert_eq(legacy_backend.phase_snapshots[0].phase, "setup")
  assert_eq(legacy_backend.phase_snapshots[1].phase, "rank")
  assert_eq(legacy_backend.phase_snapshots[2].phase, "placement")
  assert_eq(legacy_backend.phase_snapshots[3].phase, "final")
  assert_true(legacy_backend.phase_snapshots[1].rank_layer_count > 0)
  assert_true(legacy_backend.phase_snapshots[3].width > 0)
  assert_true(legacy_backend.phase_snapshots[3].height > 0)

  let dagre_backend = run_graph_layout_engine_backend(request, DagreParity)
  assert_eq(dagre_backend.phase_snapshots.length(), 4)
  assert_eq(dagre_backend.phase_snapshots[0].phase, "setup")
  assert_eq(dagre_backend.phase_snapshots[1].phase, "rank")
  assert_eq(dagre_backend.phase_snapshots[2].phase, "placement")
  assert_eq(dagre_backend.phase_snapshots[3].phase, "final")
  assert_true(dagre_backend.phase_snapshots[1].rank_layer_count > 0)
  assert_true(dagre_backend.phase_snapshots[3].width > 0)
  assert_true(dagre_backend.phase_snapshots[3].height > 0)

  let elk_backend = run_graph_layout_engine_backend(request, Elk)
  assert_eq(elk_backend.phase_snapshots.length(), 4)
  assert_eq(elk_backend.phase_snapshots[0].phase, "setup")
  assert_eq(elk_backend.phase_snapshots[1].phase, "rank")
  assert_eq(elk_backend.phase_snapshots[2].phase, "placement")
  assert_eq(elk_backend.phase_snapshots[3].phase, "final")
  assert_true(elk_backend.phase_snapshots[1].rank_layer_count > 0)
  assert_true(elk_backend.phase_snapshots[3].width > 0)
  assert_true(elk_backend.phase_snapshots[3].height > 0)

  let elk_layered_backend = run_graph_layout_engine_backend(request, ElkLayered)
  assert_eq(elk_layered_backend.phase_snapshots.length(), 4)
  assert_eq(elk_layered_backend.phase_snapshots[0].phase, "setup")
  assert_eq(elk_layered_backend.phase_snapshots[1].phase, "rank")
  assert_eq(elk_layered_backend.phase_snapshots[2].phase, "placement")
  assert_eq(elk_layered_backend.phase_snapshots[3].phase, "final")
  assert_true(elk_layered_backend.phase_snapshots[1].rank_layer_count > 0)
  assert_true(elk_layered_backend.phase_snapshots[3].width > 0)
  assert_true(elk_layered_backend.phase_snapshots[3].height > 0)
}
