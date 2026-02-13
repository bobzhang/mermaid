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
pub struct AsciiSequenceNoteLayout {
  x : Int
  y : Int
  width : Int
  height : Int
  lines : Array[String]
}

///|
pub struct AsciiSequenceActivationLayout {
  actor_idx : Int
  top_y : Int
  bottom_y : Int
}

///|
pub struct AsciiSequenceLayout {
  actors : Array[@model.MermaidNode]
  actor_index : Map[String, Int]
  lifeline_x : Array[Int]
  message_arrow_y : Array[Int]
  message_label_y : Array[Int]
  block_start_y : Array[Int]
  block_end_y : Array[Int]
  divider_y_map : Map[String, Int]
  note_positions : Array[AsciiSequenceNoteLayout]
  activations : Array[AsciiSequenceActivationLayout]
  footer_y : Int
  total_w : Int
  total_h : Int
}

///|
pub struct AsciiClassLayout {
  class_sections_map : Map[String, Array[Array[String]]]
  class_width : Map[String, Int]
  class_height : Map[String, Int]
  class_order : Array[String]
  placed_x : Map[String, Int]
  placed_y : Map[String, Int]
  total_w : Int
  total_h : Int
}

///|
pub struct AsciiErLayout {
  entity_sections : Map[String, Array[Array[String]]]
  entity_width : Map[String, Int]
  entity_height : Map[String, Int]
  entity_order : Array[String]
  placed_x : Map[String, Int]
  placed_y : Map[String, Int]
  total_w : Int
  total_h : Int
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
  sequence_layout : AsciiSequenceLayout?
  class_layout : AsciiClassLayout?
  er_layout : AsciiErLayout?
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
fn sequence_label(node : @model.MermaidNode) -> String {
  if node.label == "" {
    node.id
  } else {
    node.label
  }
}

///|
fn option_int_or(value : Int?, fallback : Int) -> Int {
  match value {
    Some(found) => found
    None => fallback
  }
}

///|
fn sequence_ordered_actors(
  graph : @model.MermaidGraph,
) -> Array[@model.MermaidNode] {
  let ordered : Array[@model.MermaidNode] = []
  let seen : Map[String, Bool] = {}
  for actor_id in graph.sequence_actor_order {
    match graph.nodes.get(actor_id) {
      Some(actor) => {
        ordered.push(actor)
        seen[actor_id] = true
      }
      None => ()
    }
  }
  for entry in graph.nodes.to_array() {
    let (node_id, node) = entry
    if !seen.contains(node_id) {
      ordered.push(node)
    }
  }
  ordered
}

///|
fn sequence_note_lines(text : String) -> Array[String] {
  let escaped = text.split("\\n").map(line => line.to_string()).to_array()
  if escaped.length() > 1 {
    escaped
  } else {
    text.split("\n").map(line => line.to_string()).to_array()
  }
}

///|
fn sequence_operator_has_suffix(operator : String?, suffix : String) -> Bool {
  match operator {
    Some(op) => op.has_suffix(suffix)
    None => false
  }
}

///|
fn sequence_apply_activation_command(
  command : @model.SequenceActivationCommand,
  y : Int,
  actor_index : Map[String, Int],
  activation_starts : Map[String, Array[Int]],
  activations : Array[AsciiSequenceActivationLayout],
) -> Unit {
  match actor_index.get(command.actor_id) {
    Some(actor_idx) =>
      if command.activate {
        let stack = activation_starts.get_or_init(command.actor_id, () => [])
        stack.push(y)
      } else {
        match activation_starts.get(command.actor_id) {
          Some(stack) =>
            if stack.length() > 0 {
              let last_index = stack.length() - 1
              let top_y = stack[last_index]
              let next_stack : Array[Int] = []
              for i in 0..<last_index {
                next_stack.push(stack[i])
              }
              activation_starts[command.actor_id] = next_stack
              activations.push({ actor_idx, top_y, bottom_y: y })
            }
          None => ()
        }
      }
    None => ()
  }
}

///|
fn build_sequence_layout(graph : @model.MermaidGraph) -> AsciiSequenceLayout {
  let actors = sequence_ordered_actors(graph)
  if actors.length() == 0 {
    return {
      actors,
      actor_index: {},
      lifeline_x: [],
      message_arrow_y: [],
      message_label_y: [],
      block_start_y: [],
      block_end_y: [],
      divider_y_map: {},
      note_positions: [],
      activations: [],
      footer_y: 0,
      total_w: 0,
      total_h: 0,
    }
  }

  let box_pad = 1
  let actor_box_h = 3

  let actor_index : Map[String, Int] = {}
  for i, actor in actors {
    actor_index[actor.id] = i
  }

  let actor_widths : Array[Int] = []
  let half_box : Array[Int] = []
  for actor in actors {
    let width = sequence_label(actor).length() + 2 * box_pad + 2
    actor_widths.push(width)
    half_box.push((width + 1) / 2)
  }

  let gap_count = if actors.length() > 0 { actors.length() - 1 } else { 0 }
  let adjacent_width : Array[Int] = []
  for _ in 0..<gap_count {
    adjacent_width.push(0)
  }

  for edge in graph.edges {
    match (actor_index.get(edge.source), actor_index.get(edge.target)) {
      (Some(fi), Some(ti)) =>
        if fi != ti {
          let lo = if fi < ti { fi } else { ti }
          let hi = if fi > ti { fi } else { ti }
          let label_len = match edge.label {
            Some(label) => label.length()
            None => 0
          }
          let needed = label_len + 4
          let num_gaps = hi - lo
          let per_gap = (needed + num_gaps - 1) / num_gaps
          for g in lo..<hi {
            if per_gap > adjacent_width[g] {
              adjacent_width[g] = per_gap
            }
          }
        }
      _ => ()
    }
  }

  let lifeline_x : Array[Int] = [half_box[0]]
  for i in 1..<actors.length() {
    let gap1 = half_box[i - 1] + half_box[i] + 2
    let gap2 = adjacent_width[i - 1] + 2
    let mut gap = 10
    if gap1 > gap {
      gap = gap1
    }
    if gap2 > gap {
      gap = gap2
    }
    lifeline_x.push(lifeline_x[i - 1] + gap)
  }

  let message_arrow_y : Array[Int] = []
  let message_label_y : Array[Int] = []
  let block_start_y : Array[Int] = []
  let block_end_y : Array[Int] = []
  for _ in 0..<graph.sequence_blocks.length() {
    block_start_y.push(-1)
    block_end_y.push(-1)
  }
  let divider_y_map : Map[String, Int] = {}
  let note_positions : Array[AsciiSequenceNoteLayout] = []

  let mut cur_y = actor_box_h
  for message_index, edge in graph.edges {
    for block_index, block in graph.sequence_blocks {
      if block.start_index == message_index {
        cur_y = cur_y + 2
        block_start_y[block_index] = cur_y - 1
      }
    }

    for block_index, block in graph.sequence_blocks {
      for divider_index, divider in block.dividers {
        if divider.index == message_index {
          cur_y = cur_y + 1
          divider_y_map["\{block_index}:\{divider_index}"] = cur_y
          cur_y = cur_y + 1
        }
      }
    }

    cur_y = cur_y + 1
    if edge.source == edge.target {
      message_label_y.push(cur_y + 1)
      message_arrow_y.push(cur_y)
      cur_y = cur_y + 3
    } else {
      message_label_y.push(cur_y)
      message_arrow_y.push(cur_y + 1)
      cur_y = cur_y + 2
    }

    for note in graph.sequence_notes {
      if note.after_index == message_index && note.actor_ids.length() > 0 {
        cur_y = cur_y + 1

        let lines = sequence_note_lines(note.text)
        let mut max_len = 0
        for line in lines {
          max_len = max_len.max(line.length())
        }
        let width = max_len + 4
        let height = lines.length() + 2

        let actor_idx = option_int_or(actor_index.get(note.actor_ids[0]), 0)
        let mut note_x = match note.position {
          Left => lifeline_x[actor_idx] - width - 1
          Right => lifeline_x[actor_idx] + 2
          Over =>
            if note.actor_ids.length() >= 2 {
              let second_actor = note.actor_ids[note.actor_ids.length() - 1]
              let second_idx = option_int_or(
                actor_index.get(second_actor),
                actor_idx,
              )
              (lifeline_x[actor_idx] + lifeline_x[second_idx]) / 2 - width / 2
            } else {
              lifeline_x[actor_idx] - width / 2
            }
        }
        if note_x < 0 {
          note_x = 0
        }

        note_positions.push({ x: note_x, y: cur_y, width, height, lines })
        cur_y = cur_y + height
      }
    }

    for block_index, block in graph.sequence_blocks {
      if block.end_index == message_index {
        cur_y = cur_y + 1
        block_end_y[block_index] = cur_y
        cur_y = cur_y + 1
      }
    }
  }

  cur_y = cur_y + 1
  let footer_y = cur_y
  let total_h = footer_y + actor_box_h

  let mut total_w = lifeline_x[lifeline_x.length() - 1] +
    half_box[half_box.length() - 1] +
    2

  for edge in graph.edges {
    if edge.source != edge.target {
      continue
    }
    match actor_index.get(edge.source) {
      Some(fi) => {
        let label_len = match edge.label {
          Some(label) => label.length()
          None => 0
        }
        let self_right = lifeline_x[fi] + 8 + label_len
        if self_right + 1 > total_w {
          total_w = self_right + 1
        }
      }
      None => ()
    }
  }

  for note_position in note_positions {
    let right = note_position.x + note_position.width + 1
    if right > total_w {
      total_w = right
    }
  }

  let activation_starts : Map[String, Array[Int]] = {}
  let activation_commands_by_after : Map[
    Int,
    Array[@model.SequenceActivationCommand],
  ] = {}
  let activations : Array[AsciiSequenceActivationLayout] = []

  for command in graph.sequence_activation_commands {
    let bucket = activation_commands_by_after.get_or_init(command.after_index, () => {
      []
    })
    bucket.push(command)
  }

  let initial_row_y = if message_arrow_y.length() > 0 {
    message_arrow_y[0]
  } else {
    actor_box_h + 1
  }

  match activation_commands_by_after.get(-1) {
    Some(commands) =>
      for command in commands {
        sequence_apply_activation_command(
          command, initial_row_y, actor_index, activation_starts, activations,
        )
      }
    None => ()
  }

  for edge_index, edge in graph.edges {
    let row_y = message_arrow_y[edge_index]

    if sequence_operator_has_suffix(edge.relation_operator, "+") {
      sequence_apply_activation_command(
        { actor_id: edge.target, activate: true, after_index: edge_index },
        row_y,
        actor_index,
        activation_starts,
        activations,
      )
    }

    if sequence_operator_has_suffix(edge.relation_operator, "-") {
      sequence_apply_activation_command(
        { actor_id: edge.source, activate: false, after_index: edge_index },
        row_y,
        actor_index,
        activation_starts,
        activations,
      )
    }

    match activation_commands_by_after.get(edge_index) {
      Some(commands) => {
        let command_row_y = row_y +
          (if edge.source == edge.target { 2 } else { 1 })
        for command in commands {
          sequence_apply_activation_command(
            command, command_row_y, actor_index, activation_starts, activations,
          )
        }
      }
      None => ()
    }
  }

  for entry in activation_starts.to_array() {
    let (actor_id, stack) = entry
    match actor_index.get(actor_id) {
      Some(actor_idx) =>
        for top_y in stack {
          activations.push({
            actor_idx,
            top_y,
            bottom_y: (footer_y - 1).max(top_y + 1),
          })
        }
      None => ()
    }
  }

  {
    actors,
    actor_index,
    lifeline_x,
    message_arrow_y,
    message_label_y,
    block_start_y,
    block_end_y,
    divider_y_map,
    note_positions,
    activations,
    footer_y,
    total_w,
    total_h,
  }
}

///|
fn class_is_method_detail(detail : StringView) -> Bool {
  if detail.has_suffix(" ()") {
    return true
  }
  if detail.contains("(") && detail.contains(")") {
    return true
  }
  false
}

///|
fn class_strip_method_marker(detail : StringView) -> StringView {
  if detail.strip_suffix(" ()") is Some(a) {
    a.trim()
  } else {
    detail
  }
}

///|
fn class_sections(node : @model.MermaidNode) -> Array[Array[String]] {
  let lines = node.label.split("\n").map(part => part.to_string()).to_array()
  if lines.length() == 0 {
    return [[node.id]]
  }

  let header : Array[String] = []
  let attributes : Array[String] = []
  let methods : Array[String] = []

  for i in 1..<lines.length() {
    let detail = lines[i].trim()
    if detail == "" {
      continue
    }
    let rendered = class_strip_method_marker(detail)
    if detail.has_prefix("<<") && detail.has_suffix(">>") {
      header.push(rendered.to_string())
    } else if class_is_method_detail(detail) {
      methods.push(rendered.to_string())
    } else {
      attributes.push(rendered.to_string())
    }
  }
  header.push(lines[0])

  if attributes.length() == 0 && methods.length() == 0 {
    [header]
  } else if methods.length() == 0 {
    [header, attributes]
  } else {
    [header, attributes, methods]
  }
}

///|
fn class_multibox_size(sections : Array[Array[String]]) -> (Int, Int) {
  let mut max_text_width = 0
  for section in sections {
    for line in section {
      if line.length() > max_text_width {
        max_text_width = line.length()
      }
    }
  }
  let mut total_lines = 0
  for section in sections {
    total_lines = total_lines + section.length().max(1)
  }
  let box_width = max_text_width + 4
  let box_height = total_lines + sections.length() - 1 + 2
  (box_width, box_height)
}

///|
fn map_push_unique(
  mapping : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  let values = mapping.get_or_init(key, () => [])
  if !values.any(item => item == value) {
    values.push(value)
  }
}

///|
fn class_relation_meta(operator : String?) -> (String, Bool, Bool, Bool) {
  match operator {
    Some(op) =>
      if op.has_prefix("<|") {
        let rel_type = if op.contains(".") {
          "realization"
        } else {
          "inheritance"
        }
        (rel_type, false, rel_type == "realization", true)
      } else if op.has_suffix("|>") {
        let rel_type = if op.contains(".") {
          "realization"
        } else {
          "inheritance"
        }
        (rel_type, true, rel_type == "realization", true)
      } else if op.has_prefix("*") {
        ("composition", false, false, false)
      } else if op.has_suffix("*") {
        ("composition", true, false, false)
      } else if op.has_prefix("o") {
        ("aggregation", false, false, false)
      } else if op.has_suffix("o") {
        ("aggregation", true, false, false)
      } else if op.contains(".") {
        ("dependency", true, true, false)
      } else {
        ("association", true, false, false)
      }
    None => ("association", true, false, false)
  }
}

///|
fn build_class_layout(graph : @model.MermaidGraph) -> AsciiClassLayout {
  let classes = graph.nodes.values().to_array()

  let h_gap = 4
  let v_gap = 3

  let class_sections_map : Map[String, Array[Array[String]]] = {}
  let class_width : Map[String, Int] = {}
  let class_height : Map[String, Int] = {}
  let class_order : Array[String] = []

  for cls in classes {
    let sections = class_sections(cls)
    let (box_w, box_h) = class_multibox_size(sections)
    class_sections_map[cls.id] = sections
    class_width[cls.id] = box_w
    class_height[cls.id] = box_h
    class_order.push(cls.id)
  }

  let parents : Map[String, Array[String]] = {}
  let children : Map[String, Array[String]] = {}

  for edge in graph.edges {
    let (_, marker_at_to, _, hierarchical) = class_relation_meta(
      edge.relation_operator,
    )
    let (parent_id, child_id) = if hierarchical && marker_at_to {
      (edge.target, edge.source)
    } else {
      (edge.source, edge.target)
    }
    map_push_unique(parents, child_id, parent_id)
    map_push_unique(children, parent_id, child_id)
  }

  let level : Map[String, Int] = {}
  let queue : Array[String] = []

  for class_id in class_order {
    match parents.get(class_id) {
      Some(found) =>
        if found.length() == 0 {
          level[class_id] = 0
          queue.push(class_id)
        }
      None => {
        level[class_id] = 0
        queue.push(class_id)
      }
    }
  }

  let level_cap = classes.length() - 1
  let mut qi = 0
  while qi < queue.length() {
    let id = queue[qi]
    qi = qi + 1
    match children.get(id) {
      Some(child_ids) =>
        for child_id in child_ids {
          let new_level = match level.get(id) {
            Some(found) => found + 1
            None => 1
          }
          if new_level > level_cap {
            continue
          }
          match level.get(child_id) {
            Some(existing) =>
              if existing < new_level {
                level[child_id] = new_level
                queue.push(child_id)
              }
            None => {
              level[child_id] = new_level
              queue.push(child_id)
            }
          }
        }
      None => ()
    }
  }

  for class_id in class_order {
    if !level.contains(class_id) {
      level[class_id] = 0
    }
  }

  let mut max_level = 0
  for class_id in class_order {
    match level.get(class_id) {
      Some(found) => if found > max_level { max_level = found }
      None => ()
    }
  }

  let level_groups : Array[Array[String]] = []
  for _ in 0..<=max_level {
    level_groups.push([])
  }

  for class_id in class_order {
    match level.get(class_id) {
      Some(found) => level_groups[found].push(class_id)
      None => level_groups[0].push(class_id)
    }
  }

  let placed_x : Map[String, Int] = {}
  let placed_y : Map[String, Int] = {}

  let mut current_y = 0
  for lv in 0..<=max_level {
    let group = level_groups[lv]
    if group.length() == 0 {
      continue
    }
    let mut current_x = 0
    let mut max_h = 0
    for class_id in group {
      let w = class_width.get(class_id).unwrap()
      let h = class_height.get(class_id).unwrap()
      placed_x[class_id] = current_x
      placed_y[class_id] = current_y
      current_x = current_x + w + h_gap
      if h > max_h {
        max_h = h
      }
    }
    current_y = current_y + max_h + v_gap
  }

  let mut total_w = 0
  let mut total_h = 0
  for class_id in class_order {
    let x = placed_x.get(class_id).unwrap()
    let y = placed_y.get(class_id).unwrap()
    let w = class_width.get(class_id).unwrap()
    let h = class_height.get(class_id).unwrap()
    if x + w > total_w {
      total_w = x + w
    }
    if y + h > total_h {
      total_h = y + h
    }
  }

  total_w = total_w + 4
  total_h = total_h + 2 + graph.edges.length() * 3

  {
    class_sections_map,
    class_width,
    class_height,
    class_order,
    placed_x,
    placed_y,
    total_w,
    total_h,
  }
}

///|
fn trim_owned(s : String) -> String {
  s.trim().to_string()
}

///|
fn er_sections(node : @model.MermaidNode) -> Array[Array[String]] {
  let lines = node.label.split("\n").map(part => part.to_string()).to_array()
  if lines.length() == 0 {
    return [[node.id]]
  }

  let header = [lines[0]]
  let attrs : Array[String] = []
  for i in 1..<lines.length() {
    let line = trim_owned(lines[i])
    if line != "" {
      if line.has_prefix("PK ") ||
        line.has_prefix("UK ") ||
        line.has_prefix("FK ") {
        attrs.push(line)
      } else {
        attrs.push("   \{line}")
      }
    }
  }

  if attrs.length() == 0 {
    [header]
  } else {
    [header, attrs]
  }
}

///|
fn build_er_layout(graph : @model.MermaidGraph) -> AsciiErLayout {
  let entities = graph.nodes.values().to_array()

  let h_gap = 6
  let v_gap = 4

  let entity_sections : Map[String, Array[Array[String]]] = {}
  let entity_width : Map[String, Int] = {}
  let entity_height : Map[String, Int] = {}
  let entity_order : Array[String] = []

  for entity in entities {
    let sections = er_sections(entity)
    let (box_w, box_h) = class_multibox_size(sections)
    entity_sections[entity.id] = sections
    entity_width[entity.id] = box_w
    entity_height[entity.id] = box_h
    entity_order.push(entity.id)
  }

  let mut max_per_row = 2
  while max_per_row * max_per_row < entities.length() {
    max_per_row = max_per_row + 1
  }

  let placed_x : Map[String, Int] = {}
  let placed_y : Map[String, Int] = {}

  let mut current_x = 0
  let mut current_y = 0
  let mut max_row_h = 0
  let mut col_count = 0

  for entity_id in entity_order {
    let w = entity_width.get(entity_id).unwrap()
    let h = entity_height.get(entity_id).unwrap()

    if col_count >= max_per_row {
      current_y = current_y + max_row_h + v_gap
      current_x = 0
      max_row_h = 0
      col_count = 0
    }

    placed_x[entity_id] = current_x
    placed_y[entity_id] = current_y

    current_x = current_x + w + h_gap
    if h > max_row_h {
      max_row_h = h
    }
    col_count = col_count + 1
  }

  let mut total_w = 0
  let mut total_h = 0

  for entity_id in entity_order {
    let x = placed_x.get(entity_id).unwrap()
    let y = placed_y.get(entity_id).unwrap()
    let w = entity_width.get(entity_id).unwrap()
    let h = entity_height.get(entity_id).unwrap()
    if x + w > total_w {
      total_w = x + w
    }
    if y + h > total_h {
      total_h = y + h
    }
  }

  total_w = total_w + 4
  if max_per_row > 2 && entities.length() > max_per_row * 2 {
    total_w = total_w + 1
  }
  total_h = total_h + 2 + graph.edges.length() * 3

  {
    entity_sections,
    entity_width,
    entity_height,
    entity_order,
    placed_x,
    placed_y,
    total_w,
    total_h,
  }
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
    return {
      kind: Sequence,
      graph,
      sequence_layout: Some(build_sequence_layout(graph)),
      class_layout: None,
      er_layout: None,
      state_flat_grid: None,
      flow_subgraph: None,
    }
  }

  let class_mode = graph_is_shape(graph, ClassEntity)
  if class_mode {
    return {
      kind: Class,
      graph,
      sequence_layout: None,
      class_layout: Some(build_class_layout(graph)),
      er_layout: None,
      state_flat_grid: None,
      flow_subgraph: None,
    }
  }

  let er_mode = graph_is_shape(graph, ErEntity)
  if er_mode {
    return {
      kind: Er,
      graph,
      sequence_layout: None,
      class_layout: None,
      er_layout: Some(build_er_layout(graph)),
      state_flat_grid: None,
      flow_subgraph: None,
    }
  }

  let state_mode = graph_has_shape(graph, StateStart) ||
    graph_has_shape(graph, StateEnd)
  let td_like_direction = graph.direction is (TD | TB)

  if state_mode && td_like_direction {
    return {
      kind: StateFlatGrid,
      graph,
      sequence_layout: None,
      class_layout: None,
      er_layout: None,
      state_flat_grid: Some(build_state_flat_grid_layout(graph)),
      flow_subgraph: None,
    }
  }

  if state_mode {
    return {
      kind: FlowSubgraph,
      graph,
      sequence_layout: None,
      class_layout: None,
      er_layout: None,
      state_flat_grid: None,
      flow_subgraph: Some(build_flow_subgraph_layout(graph)),
    }
  }

  if graph.subgraphs.length() == 0 && td_like_direction {
    return {
      kind: StateFlatGrid,
      graph,
      sequence_layout: None,
      class_layout: None,
      er_layout: None,
      state_flat_grid: Some(build_state_flat_grid_layout(graph)),
      flow_subgraph: None,
    }
  }

  if graph.subgraphs.length() > 0 {
    return {
      kind: FlowSubgraph,
      graph,
      sequence_layout: None,
      class_layout: None,
      er_layout: None,
      state_flat_grid: None,
      flow_subgraph: Some(build_flow_subgraph_layout(graph)),
    }
  }

  if graph.edges.length() == 0 {
    return {
      kind: NodesOnly,
      graph,
      sequence_layout: None,
      class_layout: None,
      er_layout: None,
      state_flat_grid: None,
      flow_subgraph: None,
    }
  }

  {
    kind: FlowSubgraph,
    graph,
    sequence_layout: None,
    class_layout: None,
    er_layout: None,
    state_flat_grid: None,
    flow_subgraph: Some(build_flow_subgraph_layout(graph)),
  }
}
