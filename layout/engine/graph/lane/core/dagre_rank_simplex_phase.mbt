///|
fn dagre_rank_directed_edge_key(
  source_index : Int,
  target_index : Int,
) -> String {
  "\{source_index}->\{target_index}"
}

///|
priv struct DagreNetworkSimplexPreparedGraph {
  node_index_by_id : Map[String, Int]
  edge_source_index : Array[Int]
  edge_target_index : Array[Int]
  edge_minlen : Array[Int]
  edge_weight : Array[Int]
  directed_edge_index_by_key : Map[String, Int]
  out_edge_indices_by_source : Array[Array[Int]]
  in_edge_indices_by_target : Array[Array[Int]]
  incident_edge_indices_by_node : Array[Array[Int]]
}

///|
priv struct DagreNetworkSimplexSeedState {
  longest_path_rank_by_node_index : Array[Int]
  feasible_rank_by_node_index : Array[Int]
  tree_incident_edge_indices_by_node : Array[Array[Int]]
  tree_edge_u : Array[Int]
  tree_edge_v : Array[Int]
  tree_edge_cutvalue : Array[Int]
  tree_edge_active : Array[Bool]
  feasible_root_index : Int
}

///|
priv struct DagreNetworkSimplexCutPhaseState {
  parent_by_node : Array[Int]
  low_by_node : Array[Int]
  lim_by_node : Array[Int]
  tree_edge_cutvalue : Array[Int]
  leave_tree_edge_index : Int?
  enter_graph_edge_index : Int?
}

///|
priv struct DagreNetworkSimplexExchangeStep {
  leave_tree_edge_u : Int
  leave_tree_edge_v : Int
  enter_graph_edge_source : Int
  enter_graph_edge_target : Int
  rank_by_node_index : Array[Int]
  parent_by_node : Array[Int]
  low_by_node : Array[Int]
  lim_by_node : Array[Int]
  tree_edge_u : Array[Int]
  tree_edge_v : Array[Int]
  tree_edge_cutvalue : Array[Int]
  tree_edge_active : Array[Bool]
}

///|
fn prepare_dagre_network_simplex_graph(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  relaxed_edge_indices : Array[Int],
  reversed_back_edge_indices : Array[Int],
) -> DagreNetworkSimplexPreparedGraph {
  let node_index_by_id : Map[String, Int] = {}
  for i, node in nodes_in_order {
    node_index_by_id[node.id] = i
  }

  let edge_source_index : Array[Int] = []
  let edge_target_index : Array[Int] = []
  let edge_minlen : Array[Int] = []
  let edge_weight : Array[Int] = []
  let directed_edge_index_by_key : Map[String, Int] = {}
  let out_edge_indices_by_source : Array[Array[Int]] = []
  let in_edge_indices_by_target : Array[Array[Int]] = []
  let incident_edge_indices_by_node : Array[Array[Int]] = []
  for _ in 0..<nodes_in_order.length() {
    out_edge_indices_by_source.push([])
    in_edge_indices_by_target.push([])
    incident_edge_indices_by_node.push([])
  }

  fn append_rank_edge(
    source_index : Int,
    target_index : Int,
    minlen : Int,
    weight : Int,
  ) -> Unit {
    let key = dagre_rank_directed_edge_key(source_index, target_index)
    match directed_edge_index_by_key.get(key) {
      Some(edge_index) => {
        edge_weight[edge_index] = edge_weight[edge_index] + weight
        if minlen > edge_minlen[edge_index] {
          edge_minlen[edge_index] = minlen
        }
      }
      None => {
        let edge_index = edge_source_index.length()
        directed_edge_index_by_key[key] = edge_index
        edge_source_index.push(source_index)
        edge_target_index.push(target_index)
        edge_minlen.push(minlen)
        edge_weight.push(weight)
        out_edge_indices_by_source[source_index].push(edge_index)
        in_edge_indices_by_target[target_index].push(edge_index)
        incident_edge_indices_by_node[source_index].push(edge_index)
        incident_edge_indices_by_node[target_index].push(edge_index)
      }
    }
  }

  for edge_index in relaxed_edge_indices {
    let edge = edges[edge_index]
    match
      (node_index_by_id.get(edge.source), node_index_by_id.get(edge.target)) {
      (Some(source_index), Some(target_index)) =>
        append_rank_edge(source_index, target_index, 1, 1)
      _ => ()
    }
  }
  for edge_index in reversed_back_edge_indices {
    let edge = edges[edge_index]
    match
      (node_index_by_id.get(edge.source), node_index_by_id.get(edge.target)) {
      (Some(source_index), Some(target_index)) =>
        append_rank_edge(target_index, source_index, 1, 1)
      _ => ()
    }
  }

  if edge_source_index.length() > 0 {
    // Dagre's feasible-tree phase requires connectivity. We add zero-cost
    // virtual connectors between weak components to satisfy that precondition
    // without distorting weighted edge optimization.
    let component_by_node_index : Array[Int] = []
    let component_representative : Array[Int] = []
    for _ in 0..<nodes_in_order.length() {
      component_by_node_index.push(-1)
    }
    let stack : Array[Int] = []
    for start_node_index in 0..<nodes_in_order.length() {
      if component_by_node_index[start_node_index] >= 0 {
        continue
      }
      let component_index = component_representative.length()
      component_representative.push(start_node_index)
      component_by_node_index[start_node_index] = component_index
      stack.push(start_node_index)
      while stack.length() > 0 {
        let node_index = stack[stack.length() - 1]
        let _ = stack.pop()
        for edge_index in incident_edge_indices_by_node[node_index] {
          let edge_source = edge_source_index[edge_index]
          let edge_target = edge_target_index[edge_index]
          let other = if edge_source == node_index {
            edge_target
          } else {
            edge_source
          }
          if component_by_node_index[other] >= 0 {
            continue
          }
          component_by_node_index[other] = component_index
          stack.push(other)
        }
      }
    }
    if component_representative.length() > 1 {
      let root_index = component_representative[0]
      for i in 1..<component_representative.length() {
        append_rank_edge(root_index, component_representative[i], 0, 0)
      }
    }
  }

  {
    node_index_by_id,
    edge_source_index,
    edge_target_index,
    edge_minlen,
    edge_weight,
    directed_edge_index_by_key,
    out_edge_indices_by_source,
    in_edge_indices_by_target,
    incident_edge_indices_by_node,
  }
}

///|
fn collect_dagre_network_simplex_seed_state(
  nodes_in_order : Array[MermaidNode],
  prepared_graph : DagreNetworkSimplexPreparedGraph,
) -> DagreNetworkSimplexSeedState? {
  let edge_source_index = prepared_graph.edge_source_index
  let edge_target_index = prepared_graph.edge_target_index
  let edge_minlen = prepared_graph.edge_minlen
  let out_edge_indices_by_source = prepared_graph.out_edge_indices_by_source
  let in_edge_indices_by_target = prepared_graph.in_edge_indices_by_target
  let incident_edge_indices_by_node = prepared_graph.incident_edge_indices_by_node

  let feasible_rank_by_node_index : Array[Int] = []
  for _ in 0..<nodes_in_order.length() {
    feasible_rank_by_node_index.push(0)
  }
  let visit_state_by_node_index : Array[Int] = []
  for _ in 0..<nodes_in_order.length() {
    visit_state_by_node_index.push(0)
  }
  let mut has_rank_cycle = false

  fn edge_slack(edge_index : Int) -> Int {
    let source_index = edge_source_index[edge_index]
    let target_index = edge_target_index[edge_index]
    feasible_rank_by_node_index[target_index] -
    feasible_rank_by_node_index[source_index] -
    edge_minlen[edge_index]
  }

  fn longest_path_dfs(node_index : Int) -> Int {
    let visit_state = visit_state_by_node_index[node_index]
    if visit_state == 2 {
      return feasible_rank_by_node_index[node_index]
    }
    if visit_state == 1 {
      has_rank_cycle = true
      return feasible_rank_by_node_index[node_index]
    }
    visit_state_by_node_index[node_index] = 1
    let mut has_outgoing = false
    let mut best_rank = 0
    for edge_index in out_edge_indices_by_source[node_index] {
      let target_index = edge_target_index[edge_index]
      let target_rank = longest_path_dfs(target_index)
      let candidate_rank = target_rank - edge_minlen[edge_index]
      if !has_outgoing || candidate_rank < best_rank {
        best_rank = candidate_rank
        has_outgoing = true
      }
    }
    let resolved_rank = if has_outgoing { best_rank } else { 0 }
    feasible_rank_by_node_index[node_index] = resolved_rank
    visit_state_by_node_index[node_index] = 2
    resolved_rank
  }

  for node_index in 0..<nodes_in_order.length() {
    if in_edge_indices_by_target[node_index].length() == 0 {
      let _ = longest_path_dfs(node_index)
    }
  }
  for node_index in 0..<nodes_in_order.length() {
    if visit_state_by_node_index[node_index] == 0 {
      let _ = longest_path_dfs(node_index)
    }
  }
  if has_rank_cycle {
    return None
  }
  let longest_path_rank_by_node_index = feasible_rank_by_node_index.copy()

  let node_in_tree : Array[Bool] = []
  let tree_incident_edge_indices_by_node : Array[Array[Int]] = []
  for _ in 0..<nodes_in_order.length() {
    node_in_tree.push(false)
    tree_incident_edge_indices_by_node.push([])
  }
  let tree_edge_u : Array[Int] = []
  let tree_edge_v : Array[Int] = []
  let tree_edge_cutvalue : Array[Int] = []
  let tree_edge_active : Array[Bool] = []

  fn tree_find_edge_index(left : Int, right : Int) -> Int {
    for tree_edge_index in tree_incident_edge_indices_by_node[left] {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      let edge_left = tree_edge_u[tree_edge_index]
      let edge_right = tree_edge_v[tree_edge_index]
      if (edge_left == left && edge_right == right) ||
        (edge_left == right && edge_right == left) {
        return tree_edge_index
      }
    }
    -1
  }

  fn tree_add_edge(left : Int, right : Int) -> Unit {
    if tree_find_edge_index(left, right) >= 0 {
      return
    }
    let tree_edge_index = tree_edge_u.length()
    tree_edge_u.push(left)
    tree_edge_v.push(right)
    tree_edge_cutvalue.push(0)
    tree_edge_active.push(true)
    tree_incident_edge_indices_by_node[left].push(tree_edge_index)
    tree_incident_edge_indices_by_node[right].push(tree_edge_index)
  }

  fn tight_tree_expand() -> Int {
    fn expand_from_tight_neighbors(node_index : Int) -> Unit {
      for edge_index in incident_edge_indices_by_node[node_index] {
        let source_index = edge_source_index[edge_index]
        let target_index = edge_target_index[edge_index]
        let other_index = if source_index == node_index {
          target_index
        } else {
          source_index
        }
        if node_in_tree[other_index] || edge_slack(edge_index) != 0 {
          continue
        }
        node_in_tree[other_index] = true
        tree_add_edge(node_index, other_index)
        expand_from_tight_neighbors(other_index)
      }
    }

    for node_index in 0..<nodes_in_order.length() {
      if node_in_tree[node_index] {
        expand_from_tight_neighbors(node_index)
      }
    }
    let mut tree_node_count = 0
    for is_in_tree in node_in_tree {
      if is_in_tree {
        tree_node_count += 1
      }
    }
    tree_node_count
  }

  fn find_min_slack_crossing_edge() -> Int? {
    let mut has_edge = false
    let mut best_edge_index = 0
    let mut best_slack = 0
    for edge_index in 0..<edge_source_index.length() {
      let source_index = edge_source_index[edge_index]
      let target_index = edge_target_index[edge_index]
      if node_in_tree[source_index] == node_in_tree[target_index] {
        continue
      }
      let slack_value = edge_slack(edge_index)
      if !has_edge || slack_value < best_slack {
        has_edge = true
        best_slack = slack_value
        best_edge_index = edge_index
      }
    }
    if has_edge {
      Some(best_edge_index)
    } else {
      None
    }
  }

  fn shift_tree_ranks(delta : Int) -> Unit {
    if delta == 0 {
      return
    }
    for node_index in 0..<nodes_in_order.length() {
      if node_in_tree[node_index] {
        feasible_rank_by_node_index[node_index] = feasible_rank_by_node_index[node_index] +
          delta
      }
    }
  }

  let feasible_root_index = 0
  node_in_tree[feasible_root_index] = true
  while tight_tree_expand() < nodes_in_order.length() {
    match find_min_slack_crossing_edge() {
      Some(edge_index) => {
        let source_index = edge_source_index[edge_index]
        let delta = edge_slack(edge_index)
        if node_in_tree[source_index] {
          shift_tree_ranks(delta)
        } else {
          shift_tree_ranks(-delta)
        }
      }
      None => return None
    }
  }

  Some({
    longest_path_rank_by_node_index,
    feasible_rank_by_node_index,
    tree_incident_edge_indices_by_node,
    tree_edge_u,
    tree_edge_v,
    tree_edge_cutvalue,
    tree_edge_active,
    feasible_root_index,
  })
}

///|
fn collect_dagre_network_simplex_cut_phase_state(
  nodes_in_order : Array[MermaidNode],
  prepared_graph : DagreNetworkSimplexPreparedGraph,
  seed_state : DagreNetworkSimplexSeedState,
) -> DagreNetworkSimplexCutPhaseState? {
  let edge_source_index = prepared_graph.edge_source_index
  let edge_target_index = prepared_graph.edge_target_index
  let edge_minlen = prepared_graph.edge_minlen
  let edge_weight = prepared_graph.edge_weight
  let directed_edge_index_by_key = prepared_graph.directed_edge_index_by_key
  let incident_edge_indices_by_node = prepared_graph.incident_edge_indices_by_node
  let rank_by_node_index = seed_state.feasible_rank_by_node_index
  let tree_incident_edge_indices_by_node = seed_state.tree_incident_edge_indices_by_node
  let tree_edge_u = seed_state.tree_edge_u
  let tree_edge_v = seed_state.tree_edge_v
  let tree_edge_cutvalue = seed_state.tree_edge_cutvalue.copy()
  let tree_edge_active = seed_state.tree_edge_active.copy()
  let feasible_root_index = seed_state.feasible_root_index
  let parent_by_node : Array[Int] = []
  let low_by_node : Array[Int] = []
  let lim_by_node : Array[Int] = []
  for _ in 0..<nodes_in_order.length() {
    parent_by_node.push(-1)
    low_by_node.push(0)
    lim_by_node.push(0)
  }

  fn edge_slack(edge_index : Int) -> Int {
    let source_index = edge_source_index[edge_index]
    let target_index = edge_target_index[edge_index]
    rank_by_node_index[target_index] -
    rank_by_node_index[source_index] -
    edge_minlen[edge_index]
  }

  fn tree_other_node(tree_edge_index : Int, node_index : Int) -> Int {
    let left = tree_edge_u[tree_edge_index]
    if left == node_index {
      tree_edge_v[tree_edge_index]
    } else {
      left
    }
  }

  fn tree_find_edge_index(left : Int, right : Int) -> Int {
    for tree_edge_index in tree_incident_edge_indices_by_node[left] {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      let edge_left = tree_edge_u[tree_edge_index]
      let edge_right = tree_edge_v[tree_edge_index]
      if (edge_left == left && edge_right == right) ||
        (edge_left == right && edge_right == left) {
        return tree_edge_index
      }
    }
    -1
  }

  fn assign_low_lim(
    node_index : Int,
    parent_index : Int,
    next_lim : Int,
    visit_state_by_node : Array[Int],
  ) -> Int {
    let visit_state = visit_state_by_node[node_index]
    if visit_state == 1 {
      return next_lim
    }
    if visit_state == 2 {
      return next_lim
    }
    visit_state_by_node[node_index] = 1
    let low = next_lim
    let mut cursor = next_lim
    for tree_edge_index in tree_incident_edge_indices_by_node[node_index] {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      let other_index = tree_other_node(tree_edge_index, node_index)
      if other_index == parent_index {
        continue
      }
      cursor = assign_low_lim(
        other_index, node_index, cursor, visit_state_by_node,
      )
    }
    low_by_node[node_index] = low
    lim_by_node[node_index] = cursor
    parent_by_node[node_index] = parent_index
    visit_state_by_node[node_index] = 2
    cursor + 1
  }

  fn collect_postorder(
    node_index : Int,
    parent_index : Int,
    postorder : Array[Int],
    visited : Array[Bool],
  ) -> Unit {
    if visited[node_index] {
      return
    }
    visited[node_index] = true
    for tree_edge_index in tree_incident_edge_indices_by_node[node_index] {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      let other_index = tree_other_node(tree_edge_index, node_index)
      if other_index == parent_index {
        continue
      }
      collect_postorder(other_index, node_index, postorder, visited)
    }
    postorder.push(node_index)
  }

  fn directed_edge_index(source_index : Int, target_index : Int) -> Int? {
    directed_edge_index_by_key.get(
      dagre_rank_directed_edge_key(source_index, target_index),
    )
  }

  fn calc_tree_cut_value(child_index : Int) -> Int {
    let parent_index = parent_by_node[child_index]
    if parent_index < 0 {
      return 0
    }
    let mut child_is_tail = true
    let mut graph_edge_index = -1
    match directed_edge_index(child_index, parent_index) {
      Some(edge_index) => graph_edge_index = edge_index
      None =>
        match directed_edge_index(parent_index, child_index) {
          Some(edge_index) => {
            graph_edge_index = edge_index
            child_is_tail = false
          }
          None => return 0
        }
    }

    let mut cut_value = edge_weight[graph_edge_index]
    for edge_index in incident_edge_indices_by_node[child_index] {
      let source_index = edge_source_index[edge_index]
      let target_index = edge_target_index[edge_index]
      let is_out_edge = source_index == child_index
      let other_index = if is_out_edge { target_index } else { source_index }
      if other_index == parent_index {
        continue
      }
      let points_to_head = is_out_edge == child_is_tail
      let other_weight = edge_weight[edge_index]
      let weight_delta = if points_to_head {
        other_weight
      } else {
        -other_weight
      }
      cut_value = cut_value + weight_delta
      let tree_edge_index = tree_find_edge_index(child_index, other_index)
      if tree_edge_index >= 0 {
        let other_cut_value = tree_edge_cutvalue[tree_edge_index]
        let cut_delta = if points_to_head {
          -other_cut_value
        } else {
          other_cut_value
        }
        cut_value = cut_value + cut_delta
      }
    }
    cut_value
  }

  fn reinitialize_tree_state() -> Bool {
    for node_index in 0..<nodes_in_order.length() {
      parent_by_node[node_index] = -1
      low_by_node[node_index] = 0
      lim_by_node[node_index] = 0
    }
    let mut active_tree_edge_count = 0
    for tree_edge_index in 0..<tree_edge_active.length() {
      if tree_edge_active[tree_edge_index] {
        active_tree_edge_count += 1
      }
    }
    if active_tree_edge_count != nodes_in_order.length() - 1 {
      return false
    }
    let low_lim_visit_state : Array[Int] = []
    for _ in 0..<nodes_in_order.length() {
      low_lim_visit_state.push(0)
    }
    let _ = assign_low_lim(feasible_root_index, -1, 1, low_lim_visit_state)
    for node_index in 0..<nodes_in_order.length() {
      if low_lim_visit_state[node_index] != 2 {
        return false
      }
    }
    let postorder : Array[Int] = []
    let postorder_visited : Array[Bool] = []
    for _ in 0..<nodes_in_order.length() {
      postorder_visited.push(false)
    }
    collect_postorder(feasible_root_index, -1, postorder, postorder_visited)
    for node_index in 0..<nodes_in_order.length() {
      if !postorder_visited[node_index] {
        return false
      }
    }
    for node_index in postorder {
      if node_index == feasible_root_index {
        continue
      }
      let parent_index = parent_by_node[node_index]
      if parent_index < 0 {
        continue
      }
      let tree_edge_index = tree_find_edge_index(node_index, parent_index)
      if tree_edge_index < 0 {
        continue
      }
      tree_edge_cutvalue[tree_edge_index] = calc_tree_cut_value(node_index)
    }
    true
  }

  fn find_leave_tree_edge() -> Int? {
    for tree_edge_index in 0..<tree_edge_u.length() {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      if tree_edge_cutvalue[tree_edge_index] < 0 {
        return Some(tree_edge_index)
      }
    }
    None
  }

  fn is_descendant(node_index : Int, root_index : Int) -> Bool {
    low_by_node[root_index] <= lim_by_node[node_index] &&
    lim_by_node[node_index] <= lim_by_node[root_index]
  }

  fn find_enter_graph_edge(leave_tree_edge_index : Int) -> Int? {
    let mut tail_index = tree_edge_u[leave_tree_edge_index]
    let mut flip = false
    let head_index = tree_edge_v[leave_tree_edge_index]

    let mut directed_tail = tail_index
    let mut directed_head = head_index
    if directed_edge_index(directed_tail, directed_head) is None {
      directed_tail = head_index
      directed_head = tail_index
    }
    tail_index = directed_tail
    if lim_by_node[directed_tail] > lim_by_node[directed_head] {
      tail_index = directed_head
      flip = true
    }

    let mut has_candidate = false
    let mut best_edge_index = 0
    let mut best_slack = 0
    for edge_index in 0..<edge_source_index.length() {
      let source_index = edge_source_index[edge_index]
      let target_index = edge_target_index[edge_index]
      let source_in_tail = is_descendant(source_index, tail_index)
      let target_in_tail = is_descendant(target_index, tail_index)
      if source_in_tail != flip || target_in_tail == flip {
        continue
      }
      let slack_value = edge_slack(edge_index)
      if !has_candidate || slack_value < best_slack {
        has_candidate = true
        best_edge_index = edge_index
        best_slack = slack_value
      }
    }
    if has_candidate {
      Some(best_edge_index)
    } else {
      None
    }
  }

  if !reinitialize_tree_state() {
    return None
  }
  let leave_tree_edge_index = find_leave_tree_edge()
  let enter_graph_edge_index = match leave_tree_edge_index {
    Some(leave_tree_edge_index) => find_enter_graph_edge(leave_tree_edge_index)
    None => None
  }
  Some({
    parent_by_node,
    low_by_node,
    lim_by_node,
    tree_edge_cutvalue,
    leave_tree_edge_index,
    enter_graph_edge_index,
  })
}

///|
fn collect_dagre_network_simplex_ranks_with_trace(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  relaxed_edge_indices : Array[Int],
  reversed_back_edge_indices : Array[Int],
  capture_exchange_trace : Bool,
) -> (Map[String, Int], Int, Bool, Array[DagreNetworkSimplexExchangeStep]) {
  let rank_by_id : Map[String, Int] = {}
  let exchange_trace : Array[DagreNetworkSimplexExchangeStep] = []
  for node in nodes_in_order {
    rank_by_id[node.id] = 0
  }
  if nodes_in_order.length() == 0 {
    return (rank_by_id, 0, true, exchange_trace)
  }

  let prepared_graph = prepare_dagre_network_simplex_graph(
    nodes_in_order, edges, relaxed_edge_indices, reversed_back_edge_indices,
  )
  let node_index_by_id = prepared_graph.node_index_by_id
  let edge_source_index = prepared_graph.edge_source_index
  let edge_target_index = prepared_graph.edge_target_index
  let edge_minlen = prepared_graph.edge_minlen
  let edge_weight = prepared_graph.edge_weight
  let directed_edge_index_by_key = prepared_graph.directed_edge_index_by_key
  let incident_edge_indices_by_node = prepared_graph.incident_edge_indices_by_node

  if edge_source_index.length() == 0 {
    return (rank_by_id, 0, true, exchange_trace)
  }

  let seed_state = collect_dagre_network_simplex_seed_state(
    nodes_in_order, prepared_graph,
  )
  guard seed_state is Some(seed) else {
    return (rank_by_id, 0, false, exchange_trace)
  }
  let rank_by_node_index = seed.feasible_rank_by_node_index
  if seed.longest_path_rank_by_node_index.length() != nodes_in_order.length() {
    return (rank_by_id, 0, false, exchange_trace)
  }
  let tree_incident_edge_indices_by_node = seed.tree_incident_edge_indices_by_node
  let tree_edge_u = seed.tree_edge_u
  let tree_edge_v = seed.tree_edge_v
  let tree_edge_cutvalue = seed.tree_edge_cutvalue
  let tree_edge_active = seed.tree_edge_active
  let feasible_root_index = seed.feasible_root_index
  let parent_by_node : Array[Int] = []
  let low_by_node : Array[Int] = []
  let lim_by_node : Array[Int] = []
  for _ in 0..<nodes_in_order.length() {
    parent_by_node.push(-1)
    low_by_node.push(0)
    lim_by_node.push(0)
  }

  fn edge_slack(edge_index : Int) -> Int {
    let source_index = edge_source_index[edge_index]
    let target_index = edge_target_index[edge_index]
    rank_by_node_index[target_index] -
    rank_by_node_index[source_index] -
    edge_minlen[edge_index]
  }

  fn tree_other_node(tree_edge_index : Int, node_index : Int) -> Int {
    let left = tree_edge_u[tree_edge_index]
    if left == node_index {
      tree_edge_v[tree_edge_index]
    } else {
      left
    }
  }

  fn tree_find_edge_index(left : Int, right : Int) -> Int {
    for tree_edge_index in tree_incident_edge_indices_by_node[left] {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      let edge_left = tree_edge_u[tree_edge_index]
      let edge_right = tree_edge_v[tree_edge_index]
      if (edge_left == left && edge_right == right) ||
        (edge_left == right && edge_right == left) {
        return tree_edge_index
      }
    }
    -1
  }

  fn tree_add_edge(left : Int, right : Int) -> Unit {
    if tree_find_edge_index(left, right) >= 0 {
      return
    }
    let tree_edge_index = tree_edge_u.length()
    tree_edge_u.push(left)
    tree_edge_v.push(right)
    tree_edge_cutvalue.push(0)
    tree_edge_active.push(true)
    tree_incident_edge_indices_by_node[left].push(tree_edge_index)
    tree_incident_edge_indices_by_node[right].push(tree_edge_index)
  }

  fn remove_tree_edge_index_from_incident(
    node_index : Int,
    tree_edge_index : Int,
  ) -> Unit {
    let retained : Array[Int] = []
    for incident_index in tree_incident_edge_indices_by_node[node_index] {
      if incident_index == tree_edge_index {
        continue
      }
      retained.push(incident_index)
    }
    tree_incident_edge_indices_by_node[node_index] = retained
  }

  fn tree_remove_edge(tree_edge_index : Int) -> Unit {
    if !tree_edge_active[tree_edge_index] {
      return
    }
    tree_edge_active[tree_edge_index] = false
    let left = tree_edge_u[tree_edge_index]
    let right = tree_edge_v[tree_edge_index]
    remove_tree_edge_index_from_incident(left, tree_edge_index)
    remove_tree_edge_index_from_incident(right, tree_edge_index)
  }

  fn sorted_active_tree_edge_indices(node_index : Int) -> Array[Int] {
    let ordered : Array[Int] = []
    for tree_edge_index in tree_incident_edge_indices_by_node[node_index] {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      ordered.push(tree_edge_index)
    }
    ordered.sort_by((left_edge_index, right_edge_index) => {
      let left_other = tree_other_node(left_edge_index, node_index)
      let right_other = tree_other_node(right_edge_index, node_index)
      let other_cmp = left_other.compare(right_other)
      if other_cmp != 0 {
        return other_cmp
      }
      left_edge_index.compare(right_edge_index)
    })
    ordered
  }

  fn assign_low_lim(
    node_index : Int,
    parent_index : Int,
    next_lim : Int,
    visit_state_by_node : Array[Int],
  ) -> Int {
    let visit_state = visit_state_by_node[node_index]
    if visit_state == 1 {
      return next_lim
    }
    if visit_state == 2 {
      return next_lim
    }
    visit_state_by_node[node_index] = 1
    let low = next_lim
    let mut cursor = next_lim
    for tree_edge_index in sorted_active_tree_edge_indices(node_index) {
      let other_index = tree_other_node(tree_edge_index, node_index)
      if other_index == parent_index {
        continue
      }
      cursor = assign_low_lim(
        other_index, node_index, cursor, visit_state_by_node,
      )
    }
    low_by_node[node_index] = low
    lim_by_node[node_index] = cursor
    parent_by_node[node_index] = parent_index
    visit_state_by_node[node_index] = 2
    cursor + 1
  }

  fn collect_postorder(
    node_index : Int,
    parent_index : Int,
    postorder : Array[Int],
    visited : Array[Bool],
  ) -> Unit {
    if visited[node_index] {
      return
    }
    visited[node_index] = true
    for tree_edge_index in sorted_active_tree_edge_indices(node_index) {
      let other_index = tree_other_node(tree_edge_index, node_index)
      if other_index == parent_index {
        continue
      }
      collect_postorder(other_index, node_index, postorder, visited)
    }
    postorder.push(node_index)
  }

  fn directed_edge_index(source_index : Int, target_index : Int) -> Int? {
    directed_edge_index_by_key.get(
      dagre_rank_directed_edge_key(source_index, target_index),
    )
  }

  fn calc_tree_cut_value(child_index : Int) -> Int {
    let parent_index = parent_by_node[child_index]
    if parent_index < 0 {
      return 0
    }
    let mut child_is_tail = true
    let mut graph_edge_index = -1
    match directed_edge_index(child_index, parent_index) {
      Some(edge_index) => graph_edge_index = edge_index
      None =>
        match directed_edge_index(parent_index, child_index) {
          Some(edge_index) => {
            graph_edge_index = edge_index
            child_is_tail = false
          }
          None => return 0
        }
    }

    let mut cut_value = edge_weight[graph_edge_index]
    for edge_index in incident_edge_indices_by_node[child_index] {
      let source_index = edge_source_index[edge_index]
      let target_index = edge_target_index[edge_index]
      let is_out_edge = source_index == child_index
      let other_index = if is_out_edge { target_index } else { source_index }
      if other_index == parent_index {
        continue
      }
      let points_to_head = is_out_edge == child_is_tail
      let other_weight = edge_weight[edge_index]
      let weight_delta = if points_to_head {
        other_weight
      } else {
        -other_weight
      }
      cut_value = cut_value + weight_delta
      let tree_edge_index = tree_find_edge_index(child_index, other_index)
      if tree_edge_index >= 0 {
        let other_cut_value = tree_edge_cutvalue[tree_edge_index]
        let cut_delta = if points_to_head {
          -other_cut_value
        } else {
          other_cut_value
        }
        cut_value = cut_value + cut_delta
      }
    }
    cut_value
  }

  fn reinitialize_tree_state() -> Bool {
    for node_index in 0..<nodes_in_order.length() {
      parent_by_node[node_index] = -1
      low_by_node[node_index] = 0
      lim_by_node[node_index] = 0
    }
    let mut active_tree_edge_count = 0
    for tree_edge_index in 0..<tree_edge_active.length() {
      if tree_edge_active[tree_edge_index] {
        active_tree_edge_count += 1
      }
    }
    if active_tree_edge_count != nodes_in_order.length() - 1 {
      return false
    }
    let low_lim_visit_state : Array[Int] = []
    for _ in 0..<nodes_in_order.length() {
      low_lim_visit_state.push(0)
    }
    let _ = assign_low_lim(feasible_root_index, -1, 1, low_lim_visit_state)
    for node_index in 0..<nodes_in_order.length() {
      if low_lim_visit_state[node_index] != 2 {
        return false
      }
    }
    let postorder : Array[Int] = []
    let postorder_visited : Array[Bool] = []
    for _ in 0..<nodes_in_order.length() {
      postorder_visited.push(false)
    }
    collect_postorder(feasible_root_index, -1, postorder, postorder_visited)
    for node_index in 0..<nodes_in_order.length() {
      if !postorder_visited[node_index] {
        return false
      }
    }
    for node_index in postorder {
      if node_index == feasible_root_index {
        continue
      }
      let parent_index = parent_by_node[node_index]
      if parent_index < 0 {
        continue
      }
      let tree_edge_index = tree_find_edge_index(node_index, parent_index)
      if tree_edge_index < 0 {
        continue
      }
      tree_edge_cutvalue[tree_edge_index] = calc_tree_cut_value(node_index)
    }
    true
  }

  fn find_leave_tree_edge() -> Int? {
    for tree_edge_index in 0..<tree_edge_u.length() {
      if !tree_edge_active[tree_edge_index] {
        continue
      }
      if tree_edge_cutvalue[tree_edge_index] < 0 {
        return Some(tree_edge_index)
      }
    }
    None
  }

  fn is_descendant(node_index : Int, root_index : Int) -> Bool {
    low_by_node[root_index] <= lim_by_node[node_index] &&
    lim_by_node[node_index] <= lim_by_node[root_index]
  }

  fn find_enter_graph_edge(leave_tree_edge_index : Int) -> Int? {
    let mut tail_index = tree_edge_u[leave_tree_edge_index]
    let mut flip = false
    let head_index = tree_edge_v[leave_tree_edge_index]

    let mut directed_tail = tail_index
    let mut directed_head = head_index
    if directed_edge_index(directed_tail, directed_head) is None {
      directed_tail = head_index
      directed_head = tail_index
    }
    tail_index = directed_tail
    if lim_by_node[directed_tail] > lim_by_node[directed_head] {
      tail_index = directed_head
      flip = true
    }

    let mut has_candidate = false
    let mut best_edge_index = 0
    let mut best_slack = 0
    for edge_index in 0..<edge_source_index.length() {
      let source_index = edge_source_index[edge_index]
      let target_index = edge_target_index[edge_index]
      let source_in_tail = is_descendant(source_index, tail_index)
      let target_in_tail = is_descendant(target_index, tail_index)
      if source_in_tail != flip || target_in_tail == flip {
        continue
      }
      let slack_value = edge_slack(edge_index)
      if !has_candidate || slack_value < best_slack {
        has_candidate = true
        best_edge_index = edge_index
        best_slack = slack_value
      }
    }
    if has_candidate {
      Some(best_edge_index)
    } else {
      None
    }
  }

  fn update_ranks_from_tree() -> Unit {
    let preorder : Array[Int] = [feasible_root_index]
    while preorder.length() > 0 {
      let node_index = preorder[preorder.length() - 1]
      let _ = preorder.pop()
      for tree_edge_index in sorted_active_tree_edge_indices(node_index) {
        let child_index = tree_other_node(tree_edge_index, node_index)
        if parent_by_node[child_index] != node_index {
          continue
        }
        let mut flipped = false
        let mut edge_index = -1
        match directed_edge_index(child_index, node_index) {
          Some(found_edge_index) => edge_index = found_edge_index
          None =>
            match directed_edge_index(node_index, child_index) {
              Some(found_edge_index) => {
                edge_index = found_edge_index
                flipped = true
              }
              None => ()
            }
        }
        if edge_index < 0 {
          continue
        }
        let rank_delta = if flipped {
          edge_minlen[edge_index]
        } else {
          -edge_minlen[edge_index]
        }
        rank_by_node_index[child_index] = rank_by_node_index[node_index] +
          rank_delta
        preorder.push(child_index)
      }
    }
  }

  let initial_cut_phase_state = collect_dagre_network_simplex_cut_phase_state(
    nodes_in_order, prepared_graph, seed,
  )
  guard initial_cut_phase_state is Some(initial_cut_phase) else {
    return (rank_by_id, 0, false, exchange_trace)
  }
  for node_index in 0..<nodes_in_order.length() {
    parent_by_node[node_index] = initial_cut_phase.parent_by_node[node_index]
    low_by_node[node_index] = initial_cut_phase.low_by_node[node_index]
    lim_by_node[node_index] = initial_cut_phase.lim_by_node[node_index]
  }
  for tree_edge_index in 0..<tree_edge_cutvalue.length() {
    tree_edge_cutvalue[tree_edge_index] = initial_cut_phase.tree_edge_cutvalue[tree_edge_index]
  }

  let mut next_leave_tree_edge_index = initial_cut_phase.leave_tree_edge_index
  let mut next_enter_graph_edge_index = initial_cut_phase.enter_graph_edge_index
  let max_exchange_count = edge_source_index.length() * nodes_in_order.length() +
    1
  let mut exchange_count = 0
  while true {
    match next_leave_tree_edge_index {
      Some(leave_tree_edge_index) =>
        match next_enter_graph_edge_index {
          Some(enter_graph_edge_index) => {
            tree_remove_edge(leave_tree_edge_index)
            let source_index = edge_source_index[enter_graph_edge_index]
            let target_index = edge_target_index[enter_graph_edge_index]
            tree_add_edge(source_index, target_index)
            if !reinitialize_tree_state() {
              return (rank_by_id, 0, false, exchange_trace)
            }
            update_ranks_from_tree()
            if capture_exchange_trace {
              exchange_trace.push({
                leave_tree_edge_u: tree_edge_u[leave_tree_edge_index],
                leave_tree_edge_v: tree_edge_v[leave_tree_edge_index],
                enter_graph_edge_source: source_index,
                enter_graph_edge_target: target_index,
                rank_by_node_index: rank_by_node_index.copy(),
                parent_by_node: parent_by_node.copy(),
                low_by_node: low_by_node.copy(),
                lim_by_node: lim_by_node.copy(),
                tree_edge_u: tree_edge_u.copy(),
                tree_edge_v: tree_edge_v.copy(),
                tree_edge_cutvalue: tree_edge_cutvalue.copy(),
                tree_edge_active: tree_edge_active.copy(),
              })
            }
            next_leave_tree_edge_index = find_leave_tree_edge()
            next_enter_graph_edge_index = match next_leave_tree_edge_index {
              Some(leave_tree_edge_index) =>
                find_enter_graph_edge(leave_tree_edge_index)
              None => None
            }
            exchange_count += 1
            if exchange_count > max_exchange_count {
              return (rank_by_id, 0, false, exchange_trace)
            }
          }
          None => break
        }
      None => break
    }
  }

  let mut min_rank = rank_by_node_index[0]
  let mut max_rank = rank_by_node_index[0]
  for node_index in 1..<rank_by_node_index.length() {
    let rank = rank_by_node_index[node_index]
    min_rank = min_rank.min(rank)
    max_rank = max_rank.max(rank)
  }
  if min_rank < 0 {
    for node_index in 0..<rank_by_node_index.length() {
      rank_by_node_index[node_index] = rank_by_node_index[node_index] - min_rank
    }
    max_rank = max_rank - min_rank
  }

  for node in nodes_in_order {
    match node_index_by_id.get(node.id) {
      Some(node_index) => rank_by_id[node.id] = rank_by_node_index[node_index]
      None => ()
    }
  }
  (rank_by_id, max_rank, true, exchange_trace)
}

///|
fn dagre_network_simplex_exchange_trace_checksum(
  exchange_trace : Array[DagreNetworkSimplexExchangeStep],
) -> Int {
  let mut checksum = 0
  for step in exchange_trace {
    checksum = checksum + step.leave_tree_edge_u + step.leave_tree_edge_v
    checksum = checksum +
      step.enter_graph_edge_source +
      step.enter_graph_edge_target
    checksum = checksum + step.rank_by_node_index.length()
    checksum = checksum +
      step.parent_by_node.length() +
      step.low_by_node.length() +
      step.lim_by_node.length()
    checksum = checksum + step.tree_edge_u.length() + step.tree_edge_v.length()
    checksum = checksum +
      step.tree_edge_cutvalue.length() +
      step.tree_edge_active.length()
  }
  checksum
}

///|
fn collect_dagre_network_simplex_ranks(
  nodes_in_order : Array[MermaidNode],
  edges : Array[MermaidEdge],
  relaxed_edge_indices : Array[Int],
  reversed_back_edge_indices : Array[Int],
) -> (Map[String, Int], Int, Bool) {
  let (ranks, max_rank, ok, exchange_trace) = collect_dagre_network_simplex_ranks_with_trace(
    nodes_in_order, edges, relaxed_edge_indices, reversed_back_edge_indices, false,
  )
  let _ = dagre_network_simplex_exchange_trace_checksum(exchange_trace)
  (ranks, max_rank, ok)
}
