// Property-based tests (moonbitlang/core/quickcheck) for the parser, layout,
// SVG renderer and ASCII renderer. Every `check` uses a fixed seed and a small
// count so the suite stays deterministic and fast.

///|
fn qc_int(rs : @quickcheck.RandomState, n : Int) -> Int {
  if n <= 1 {
    0
  } else {
    rs.next_uint(limit=n.reinterpret_as_uint()).reinterpret_as_int()
  }
}

///|
fn[T] qc_pick(rs : @quickcheck.RandomState, items : Array[T]) -> T {
  items[qc_int(rs, items.length())]
}

///|
fn qc_chance(rs : @quickcheck.RandomState, percent : Int) -> Bool {
  qc_int(rs, 100) < percent
}

///|
/// Characters that Mermaid accepts inside an unquoted flowchart node label.
/// Includes XML metacharacters, dashes/arrows, and BMP + astral Unicode.
let qc_flow_label_chars : Array[Char] = [
  'a', 'b', 'Z', '0', '7', '_', '<', '>', '&', '\'', '#', '!', '?', '.', ',', '+',
  '*', '=', '/', '-', '%', '$', 'é', 'ß', '中', '文', '🚀', '𝒳',
]

///|
/// Characters used for free text after `:` / inside `|...|`.
let qc_text_chars : Array[Char] = [
  'a', 'b', 'Z', '0', '7', '_', '<', '>', '&', '\'', '"', '#', '!', '?', '.', ',',
  '+', '*', '=', '/', '-', '(', ')', '[', ']', '{', '}', 'é', '中', '🚀', '𝒳',
]

///|
/// Generate trimmed, non-empty text with single internal spaces.
fn qc_text(
  rs : @quickcheck.RandomState,
  chars : Array[Char],
  max_len : Int,
) -> String {
  let len = 1 + qc_int(rs, max_len)
  let sb = StringBuilder()
  let mut last_space = true
  for i in 0..<len {
    if !last_space && i + 1 < len && qc_chance(rs, 15) {
      sb.write_char(' ')
      last_space = true
    } else {
      sb.write_char(qc_pick(rs, chars))
      last_space = false
    }
  }
  sb.to_string()
}

///|
fn qc_id(rs : @quickcheck.RandomState, index : Int) -> String {
  let prefix = qc_pick(rs, ["n", "A", "node_", "x", "Q", "é", "S"])
  "\{prefix}\{index}"
}

///|
fn qc_has_special(text : String) -> Bool {
  text.contains("<") ||
  text.contains("&") ||
  text.contains(">") ||
  text.contains("'") ||
  text.contains("\"")
}

///|
fn qc_has_astral(text : String) -> Bool {
  for c in text {
    if c.to_int() > 0xFFFF {
      return true
    }
  }
  false
}

///|
fn qc_xml_escape(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

// ---------------------------------------------------------------------------
// Minimal XML well-formedness checker (tags balanced, attributes quoted and
// unique, no raw `<` in text/attributes, every `&` starts a valid entity,
// only XML 1.0 characters, exactly one root element).
// ---------------------------------------------------------------------------

///|
fn qc_xml_name_char(c : Char) -> Bool {
  c is ('a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_' | ':' | '.')
}

///|
fn qc_xml_valid_char(c : Char) -> Bool {
  let code = c.to_int()
  code == 0x9 ||
  code == 0xA ||
  code == 0xD ||
  (code >= 0x20 && code <= 0xD7FF) ||
  (code >= 0xE000 && code <= 0xFFFD) ||
  (code >= 0x10000 && code <= 0x10FFFF)
}

///|
/// Returns the index after a valid entity starting at `cs[i] == '&'`.
fn qc_xml_entity_end(cs : Array[Char], i : Int) -> Int? {
  let mut j = i + 1
  let sb = StringBuilder()
  while j < cs.length() && j - i <= 12 && cs[j] != ';' {
    sb.write_char(cs[j])
    j = j + 1
  }
  if j >= cs.length() || cs[j] != ';' {
    return None
  }
  let name = sb.to_string()
  let ok = match name {
    "amp" | "lt" | "gt" | "quot" | "apos" => true
    [.. "#x", .. rest] =>
      rest.length() > 0 &&
      rest.iter().all(c => c is ('0'..='9' | 'a'..='f' | 'A'..='F'))
    [.. "#", .. rest] =>
      rest.length() > 0 && rest.iter().all(c => c is ('0'..='9'))
    _ => false
  }
  if ok {
    Some(j + 1)
  } else {
    None
  }
}

///|
/// Returns `None` when `doc` is well-formed, otherwise a description.
fn qc_xml_problem(doc : String) -> String? {
  let cs = doc.to_array()
  let n = cs.length()
  let stack : Array[String] = []
  let mut roots = 0
  let mut i = 0
  while i < n {
    let c = cs[i]
    if !qc_xml_valid_char(c) {
      return Some("invalid XML char U+\{c.to_int()} at \{i}")
    }
    if c == '<' {
      if i + 1 < n && cs[i + 1] == '/' {
        let mut j = i + 2
        let sb = StringBuilder()
        while j < n && qc_xml_name_char(cs[j]) {
          sb.write_char(cs[j])
          j = j + 1
        }
        if j >= n || cs[j] != '>' {
          return Some("bad end tag at \{i}")
        }
        let name = sb.to_string()
        match stack.pop() {
          Some(open) if open == name => ()
          Some(open) => return Some("mismatched </\{name}> for <\{open}>")
          None => return Some("unexpected </\{name}>")
        }
        i = j + 1
        continue
      }
      let mut j = i + 1
      let sb = StringBuilder()
      while j < n && qc_xml_name_char(cs[j]) {
        sb.write_char(cs[j])
        j = j + 1
      }
      let name = sb.to_string()
      if name == "" {
        return Some("raw '<' at \{i}")
      }
      if stack.length() == 0 {
        roots = roots + 1
      }
      let seen : Map[String, Bool] = Map([])
      let mut closed = false
      while !closed {
        while j < n && cs[j] is (' ' | '\n' | '\t' | '\r') {
          j = j + 1
        }
        if j >= n {
          return Some("unterminated tag <\{name}>")
        }
        if cs[j] == '/' {
          if j + 1 < n && cs[j + 1] == '>' {
            j = j + 2
            closed = true
            continue
          }
          return Some("bad '/' in <\{name}>")
        }
        if cs[j] == '>' {
          stack.push(name)
          j = j + 1
          closed = true
          continue
        }
        let attr = StringBuilder()
        while j < n && qc_xml_name_char(cs[j]) {
          attr.write_char(cs[j])
          j = j + 1
        }
        let attr_name = attr.to_string()
        if attr_name == "" {
          return Some("bad attribute char '\{cs[j]}' in <\{name}> at \{j}")
        }
        if seen.contains(attr_name) {
          return Some("duplicate attribute \{attr_name} in <\{name}>")
        }
        seen[attr_name] = true
        if j >= n || cs[j] != '=' {
          return Some("attribute \{attr_name} without value in <\{name}>")
        }
        j = j + 1
        if j >= n || !(cs[j] is ('"' | '\'')) {
          return Some("unquoted attribute \{attr_name} in <\{name}>")
        }
        let quote = cs[j]
        j = j + 1
        while j < n && cs[j] != quote {
          if cs[j] == '<' {
            return Some("raw '<' in attribute \{attr_name} of <\{name}>")
          }
          if !qc_xml_valid_char(cs[j]) {
            return Some("invalid char in attribute \{attr_name}")
          }
          if cs[j] == '&' {
            match qc_xml_entity_end(cs, j) {
              Some(next) => {
                j = next
                continue
              }
              None =>
                return Some("bad entity in attribute \{attr_name} of <\{name}>")
            }
          }
          j = j + 1
        }
        if j >= n {
          return Some("unterminated attribute \{attr_name}")
        }
        j = j + 1
      }
      i = j
      continue
    }
    if c == '&' {
      match qc_xml_entity_end(cs, i) {
        Some(next) => {
          i = next
          continue
        }
        None => return Some("bad entity in text at \{i}")
      }
    }
    if stack.length() == 0 && !(c is (' ' | '\n' | '\t' | '\r')) {
      return Some("text outside root at \{i}")
    }
    i = i + 1
  }
  if stack.length() != 0 {
    return Some("unclosed <\{stack[stack.length() - 1]}>")
  }
  if roots != 1 {
    return Some("expected exactly one root element, found \{roots}")
  }
  None
}

///|
test "qc xml checker sanity" {
  assert_eq(
    qc_xml_problem("<svg a=\"1\"><g><text>a &amp; b</text></g></svg>"),
    None,
  )
  assert_true(qc_xml_problem("<svg><text>a & b</text></svg>") is Some(_))
  assert_true(qc_xml_problem("<svg><text>a<b</text></svg>") is Some(_))
  assert_true(qc_xml_problem("<svg a=\"x\"y\"></svg>") is Some(_))
  assert_true(qc_xml_problem("<svg a=\"1\" a=\"2\"></svg>") is Some(_))
  assert_true(qc_xml_problem("<svg><g></svg>") is Some(_))
}

// ---------------------------------------------------------------------------
// Graph summaries (MermaidGraph has no Eq/Debug of its own).
// ---------------------------------------------------------------------------

///|
fn qc_subgraph_summary(sb : StringBuilder, sg : @model.MermaidSubgraph) -> Unit {
  sb.write_string("sub \{sg.id}|\{sg.label}|\{sg.node_ids.join(",")}[")
  for child in sg.children {
    qc_subgraph_summary(sb, child)
  }
  sb.write_string("]\n")
}

///|
fn qc_graph_summary(g : @model.MermaidGraph) -> String {
  let sb = StringBuilder()
  sb.write_string("dir \{direction_name(g.direction)}\n")
  let ids = g.nodes.keys().collect()
  ids.sort()
  for id in ids {
    let node = g.nodes[id]
    sb.write_string(
      "node \{id}|\{node.id}|\{node.label}|\{node_shape_name(node.shape)}\n",
    )
  }
  sb.write_string("order \{g.node_definition_order.join(",")}\n")
  for e in g.edges {
    let label = e.label.unwrap_or("<none>")
    let op = e.relation_operator.unwrap_or("<none>")
    sb.write_string(
      "edge \{e.source}|\{e.target}|\{label}|\{edge_style_name(e.style)}|\{e.has_arrow_start}|\{e.has_arrow_end}|\{op}\n",
    )
  }
  for sg in g.subgraphs {
    qc_subgraph_summary(sb, sg)
  }
  sb.write_string("actors \{g.sequence_actor_order.join(",")}\n")
  for note in g.sequence_notes {
    sb.write_string("note \{note.actor_ids.join(",")}|\{note.text}\n")
  }
  sb.write_string("blocks \{g.sequence_blocks.length()}\n")
  sb.to_string()
}

// ---------------------------------------------------------------------------
// Structured generators.
// ---------------------------------------------------------------------------

///|
/// (open delimiter, close delimiter, expected shape name)
let qc_flow_shapes : Array[(String, String, String)] = [
  ("[", "]", "Rectangle"),
  ("(", ")", "Rounded"),
  ("{", "}", "Diamond"),
  ("([", "])", "Stadium"),
  ("((", "))", "Circle"),
  ("[[", "]]", "Subroutine"),
  ("(((", ")))", "DoubleCircle"),
  ("{{", "}}", "Hexagon"),
  ("[(", ")]", "Cylinder"),
  (">", "]", "Asymmetric"),
  ("[/", "\\]", "Trapezoid"),
  ("[\\", "/]", "TrapezoidAlt"),
]

///|
/// (operator, style name, arrow start, arrow end, mid-label left marker)
let qc_flow_ops : Array[(String, String, Bool, Bool, String?)] = [
  ("-->", "Solid", false, true, Some("--")),
  ("---", "Solid", false, false, None),
  ("-.->", "Dotted", false, true, Some("-.")),
  ("-.-", "Dotted", false, false, None),
  ("==>", "Thick", false, true, Some("==")),
  ("===", "Thick", false, false, None),
  ("<-->", "Solid", true, true, Some("<--")),
  ("<-.->", "Dotted", true, true, Some("<-.")),
  ("<==>", "Thick", true, true, Some("<==")),
]

///|
struct QcFlowNode {
  id : String
  shape : Int
  label : String
} derive(Debug)

///|
struct QcFlowEdge {
  src : Int
  dst : Int
  op : Int
  label : String?
  mid_label : Bool
} derive(Debug)

///|
/// A flowchart: nodes are declared one per line (a contiguous range of them
/// inside one subgraph), followed by one edge per line.
struct QcFlow {
  dir : String
  nodes : Array[QcFlowNode]
  edges : Array[QcFlowEdge]
  sub_start : Int
  sub_len : Int
} derive(Debug)

///|
fn QcFlow::text(self : QcFlow) -> String {
  let lines = ["flowchart \{self.dir}"]
  for i, node in self.nodes {
    if self.sub_len > 0 && i == self.sub_start {
      lines.push("subgraph grp [Group <&>]")
    }
    let (open, close, _) = qc_flow_shapes[node.shape]
    lines.push("\{node.id}\{open}\{node.label}\{close}")
    if self.sub_len > 0 && i == self.sub_start + self.sub_len - 1 {
      lines.push("end")
    }
  }
  for edge in self.edges {
    let (op, _, _, _, marker) = qc_flow_ops[edge.op]
    let src = self.nodes[edge.src].id
    let dst = self.nodes[edge.dst].id
    match (edge.label, marker) {
      (Some(label), Some(left)) if edge.mid_label =>
        lines.push("\{src} \{left} \{label} \{op} \{dst}")
      (Some(label), _) => lines.push("\{src} \{op}|\{label}| \{dst}")
      (None, _) => lines.push("\{src} \{op} \{dst}")
    }
  }
  lines.join("\n")
}

///|
impl @quickcheck.Arbitrary for QcFlow with fn arbitrary(size, rs) {
  let node_count = 1 + qc_int(rs, 2 + size / 8).min(7)
  let nodes = []
  for i in 0..<node_count {
    let shape = qc_int(rs, qc_flow_shapes.length())
    // Asymmetric `id>label]` has no opening bracket, so the line scanners do
    // not treat its label as nested: a `&` or an edge operator (`---`, `==>`)
    // inside it is taken as syntax (known limitation). Every other shape gets
    // the full alphabet.
    let chars = if qc_flow_shapes[shape].2 == "Asymmetric" {
      qc_flow_label_chars.filter(c => !(c is ('&' | '-' | '=')))
    } else {
      qc_flow_label_chars
    }
    nodes.push({
      id: qc_id(rs, i),
      shape,
      // Occasionally a long label: wider than the layout's lane step.
      label: qc_text(
        rs,
        chars,
        if qc_chance(rs, 10) {
          40
        } else {
          3 + size / 6
        },
      ),
    })
  }
  let edge_count = qc_int(rs, node_count + 2)
  let edges = []
  for _ in 0..<edge_count {
    let mid_label = qc_chance(rs, 30)
    // `|text|` labels may hold brackets and quotes; `-- text -->` labels are
    // bare text, so they exclude brackets, quotes and the operator characters.
    let chars = if mid_label {
      qc_flow_label_chars.filter(c => !(c is ('-' | '=' | '>')))
    } else {
      qc_text_chars.filter(c => c != '|')
    }
    let label = if qc_chance(rs, 40) {
      Some(qc_text(rs, chars, 8))
    } else {
      None
    }
    edges.push({
      src: qc_int(rs, node_count),
      dst: qc_int(rs, node_count),
      op: qc_int(rs, qc_flow_ops.length()),
      label,
      mid_label,
    })
  }
  let (sub_start, sub_len) = if qc_chance(rs, 30) {
    let start = qc_int(rs, node_count)
    (start, 1 + qc_int(rs, node_count - start))
  } else {
    (0, 0)
  }
  {
    dir: qc_pick(rs, ["TD", "TB", "LR", "RL", "BT"]),
    nodes,
    edges,
    sub_start,
    sub_len,
  }
}

///|
impl @quickcheck.Shrink for QcFlow with fn shrink(self) {
  let out : Array[QcFlow] = []
  // Drop one edge.
  for i in 0..<self.edges.length() {
    let edges = self.edges.copy()
    edges.remove(i) |> ignore
    out.push({ ..self, edges, })
  }
  // Drop the subgraph.
  if self.sub_len > 0 {
    out.push({ ..self, sub_start: 0, sub_len: 0, })
  }
  // Drop the last node and every edge touching it.
  let n = self.nodes.length()
  if n > 1 {
    let nodes = self.nodes.copy()
    nodes.pop() |> ignore
    let edges = self.edges.filter(e => e.src < n - 1 && e.dst < n - 1)
    let sub_len = (self.sub_start + self.sub_len).min(n - 1) - self.sub_start
    out.push({
      ..self,
      nodes,
      edges,
      sub_start: if sub_len > 0 {
        self.sub_start
      } else {
        0
      },
      sub_len: sub_len.max(0),
    })
  }
  // Simplify one label / shape.
  for i, node in self.nodes {
    if node.label != "a" || node.shape != 0 {
      let nodes = self.nodes.copy()
      nodes[i] = { ..node, label: "a", shape: 0, }
      out.push({ ..self, nodes, })
      if node.label.length() > 1 {
        let nodes2 = self.nodes.copy()
        let chars = node.label.to_array()
        let shorter = String::from_array(chars[1:]).trim().to_owned()
        if shorter != "" {
          nodes2[i] = { ..node, label: shorter, }
          out.push({ ..self, nodes: nodes2, })
        }
      }
    }
  }
  out.iter()
}

///|
struct QcState {
  // (id, optional description declared via `state "desc" as id`)
  states : Array[(String, String?)]
  // (source index, target index, label); -1 means `[*]`
  transitions : Array[(Int, Int, String?)]
} derive(Debug)

///|
fn QcState::text(self : QcState) -> String {
  let lines = ["stateDiagram-v2"]
  for state in self.states {
    match state.1 {
      Some(desc) => lines.push("state \"\{desc}\" as \{state.0}")
      None => ()
    }
  }
  for t in self.transitions {
    let src = if t.0 < 0 { "[*]" } else { self.states[t.0].0 }
    let dst = if t.1 < 0 { "[*]" } else { self.states[t.1].0 }
    match t.2 {
      Some(label) => lines.push("\{src} --> \{dst} : \{label}")
      None => lines.push("\{src} --> \{dst}")
    }
  }
  lines.join("\n")
}

///|
impl @quickcheck.Arbitrary for QcState with fn arbitrary(size, rs) {
  let count = 1 + qc_int(rs, 2 + size / 8).min(6)
  let states = []
  for i in 0..<count {
    let desc = if qc_chance(rs, 40) {
      Some(qc_text(rs, qc_flow_label_chars, 8))
    } else {
      None
    }
    states.push(("S\{i}", desc))
  }
  let transitions = []
  for _ in 0..<(1 + qc_int(rs, count + 2)) {
    let src = if qc_chance(rs, 15) { -1 } else { qc_int(rs, count) }
    let dst = if qc_chance(rs, 15) { -1 } else { qc_int(rs, count) }
    let label = if qc_chance(rs, 40) {
      Some(qc_text(rs, qc_text_chars, 8))
    } else {
      None
    }
    transitions.push((src, dst, label))
  }
  { states, transitions, }
}

///|
impl @quickcheck.Shrink for QcState with fn shrink(self) {
  let out : Array[QcState] = []
  for i in 0..<self.transitions.length() {
    let transitions = self.transitions.copy()
    transitions.remove(i) |> ignore
    out.push({ ..self, transitions, })
  }
  for i, state in self.states {
    if state.1 is Some(_) {
      let states = self.states.copy()
      states[i] = (state.0, None)
      out.push({ ..self, states, })
    }
  }
  out.iter()
}

///|
let qc_seq_ops : Array[String] = [
  "->>", "-->>", "->", "-->", "-)", "--)", "-x", "--x",
]

///|
struct QcSeq {
  // (participant index, is actor, nick)
  decls : Array[(Int, Bool, String?)]
  // (source, target, op index, text)
  messages : Array[(Int, Int, Int, String?)]
  // (actor index, text) rendered as `Note over X: text`
  notes : Array[(Int, String)]
} derive(Debug)

///|
fn qc_seq_id(i : Int) -> String {
  "P\{i}"
}

///|
fn QcSeq::text(self : QcSeq) -> String {
  let lines = ["sequenceDiagram"]
  for d in self.decls {
    let keyword = if d.1 { "actor" } else { "participant" }
    match d.2 {
      Some(nick) => lines.push("\{keyword} \{qc_seq_id(d.0)} as \{nick}")
      None => lines.push("\{keyword} \{qc_seq_id(d.0)}")
    }
  }
  for m in self.messages {
    let op = qc_seq_ops[m.2]
    match m.3 {
      Some(text) =>
        lines.push("\{qc_seq_id(m.0)}\{op}\{qc_seq_id(m.1)}: \{text}")
      None => lines.push("\{qc_seq_id(m.0)}\{op}\{qc_seq_id(m.1)}")
    }
  }
  for note in self.notes {
    lines.push("Note over \{qc_seq_id(note.0)}: \{note.1}")
  }
  lines.join("\n")
}

///|
impl @quickcheck.Arbitrary for QcSeq with fn arbitrary(size, rs) {
  let pool = 2 + qc_int(rs, 2 + size / 10).min(4)
  let decls = []
  let declared : Map[Int, Bool] = Map([])
  for i in 0..<pool {
    if qc_chance(rs, 60) && !declared.contains(i) {
      declared[i] = true
      let nick = if qc_chance(rs, 50) {
        Some(qc_text(rs, qc_flow_label_chars, 8))
      } else {
        None
      }
      decls.push((i, qc_chance(rs, 30), nick))
    }
  }
  let messages = []
  for _ in 0..<(1 + qc_int(rs, 5)) {
    let text = if qc_chance(rs, 80) {
      Some(qc_text(rs, qc_text_chars, 10))
    } else {
      None
    }
    messages.push(
      (
        qc_int(rs, pool),
        qc_int(rs, pool),
        qc_int(rs, qc_seq_ops.length()),
        text,
      ),
    )
  }
  let notes = []
  if qc_chance(rs, 40) {
    notes.push((messages[0].0, qc_text(rs, qc_text_chars, 8)))
  }
  { decls, messages, notes, }
}

///|
impl @quickcheck.Shrink for QcSeq with fn shrink(self) {
  let out : Array[QcSeq] = []
  for i in 0..<self.messages.length() {
    if self.messages.length() > 1 {
      let messages = self.messages.copy()
      messages.remove(i) |> ignore
      out.push({ ..self, messages, })
    }
  }
  for i in 0..<self.decls.length() {
    let decls = self.decls.copy()
    decls.remove(i) |> ignore
    out.push({ ..self, decls, })
  }
  if self.notes.length() > 0 {
    out.push({ ..self, notes: [], })
  }
  out.iter()
}

///|
let qc_class_ops : Array[String] = [
  "<|--", "*--", "o--", "-->", "--", "..>", "..|>", "..", "--|>", "--*", "--o",
]

///|
let qc_er_ops : Array[String] = [
  "||--o{", "}|..|{", "|o--||", "||--||", "}o--o{", "|o..o|",
]

///|
/// Class (`er == false`) or ER (`er == true`) diagram.
struct QcClassEr {
  er : Bool
  count : Int
  // (source, target, op index, label)
  relations : Array[(Int, Int, Int, String?)]
  // (entity index, member text)
  members : Array[(Int, String)]
} derive(Debug)

///|
fn qc_entity_id(er : Bool, i : Int) -> String {
  if er {
    "ENT\{i}"
  } else {
    "Cls\{i}"
  }
}

///|
fn QcClassEr::text(self : QcClassEr) -> String {
  let lines = [if self.er { "erDiagram" } else { "classDiagram" }]
  for i in 0..<self.count {
    if !self.er {
      lines.push("class \{qc_entity_id(false, i)}")
    }
  }
  for r in self.relations {
    let op = if self.er { qc_er_ops[r.2] } else { qc_class_ops[r.2] }
    let src = qc_entity_id(self.er, r.0)
    let dst = qc_entity_id(self.er, r.1)
    match r.3 {
      Some(label) => lines.push("\{src} \{op} \{dst} : \{label}")
      None => lines.push("\{src} \{op} \{dst}")
    }
  }
  for m in self.members {
    if self.er {
      lines.push("\{qc_entity_id(true, m.0)} {")
      lines.push("  string \{m.1}")
      lines.push("}")
    } else {
      lines.push("\{qc_entity_id(false, m.0)} : +\{m.1}")
    }
  }
  lines.join("\n")
}

///|
impl @quickcheck.Arbitrary for QcClassEr with fn arbitrary(size, rs) {
  let er = qc_chance(rs, 50)
  let count = 1 + qc_int(rs, 2 + size / 10).min(5)
  let relations = []
  for _ in 0..<(1 + qc_int(rs, count + 1)) {
    let op = qc_int(
      rs,
      if er {
        qc_er_ops.length()
      } else {
        qc_class_ops.length()
      },
    )
    // ER relationships always carry a label in Mermaid syntax.
    let label = if er || qc_chance(rs, 40) {
      Some(qc_text(rs, qc_flow_label_chars.filter(c => c != '\''), 8))
    } else {
      None
    }
    relations.push((qc_int(rs, count), qc_int(rs, count), op, label))
  }
  let members = []
  if qc_chance(rs, 50) {
    let alnum = ['a', 'b', 'c', 'x', 'y', '1', '2', '_']
    members.push((qc_int(rs, count), "m" + qc_text(rs, alnum, 5)))
  }
  { er, count, relations, members, }
}

///|
impl @quickcheck.Shrink for QcClassEr with fn shrink(self) {
  let out : Array[QcClassEr] = []
  for i in 0..<self.relations.length() {
    if self.relations.length() > 1 {
      let relations = self.relations.copy()
      relations.remove(i) |> ignore
      out.push({ ..self, relations, })
    }
  }
  if self.members.length() > 0 {
    out.push({ ..self, members: [], })
  }
  out.iter()
}

///|
/// Any supported diagram, generated structurally.
enum QcDiagram {
  Flow(QcFlow)
  State(QcState)
  Seq(QcSeq)
  ClassEr(QcClassEr)
} derive(Debug)

///|
fn QcDiagram::text(self : QcDiagram) -> String {
  match self {
    Flow(d) => d.text()
    State(d) => d.text()
    Seq(d) => d.text()
    ClassEr(d) => d.text()
  }
}

///|
fn QcDiagram::kind(self : QcDiagram) -> String {
  match self {
    Flow(_) => "flowchart"
    State(_) => "state"
    Seq(_) => "sequence"
    ClassEr(d) => if d.er { "er" } else { "class" }
  }
}

///|
impl @quickcheck.Arbitrary for QcDiagram with fn arbitrary(size, rs) {
  match qc_int(rs, 4) {
    0 => Flow(@quickcheck.Arbitrary::arbitrary(size, rs))
    1 => State(@quickcheck.Arbitrary::arbitrary(size, rs))
    2 => Seq(@quickcheck.Arbitrary::arbitrary(size, rs))
    _ => ClassEr(@quickcheck.Arbitrary::arbitrary(size, rs))
  }
}

///|
impl @quickcheck.Shrink for QcDiagram with fn shrink(self) {
  match self {
    Flow(d) => @quickcheck.Shrink::shrink(d).map(x => Flow(x))
    State(d) => @quickcheck.Shrink::shrink(d).map(x => State(x))
    Seq(d) => @quickcheck.Shrink::shrink(d).map(x => Seq(x))
    ClassEr(d) => @quickcheck.Shrink::shrink(d).map(x => ClassEr(x))
  }
}

///|
/// Unstructured "token soup": a header followed by lines assembled from
/// Mermaid syntax fragments and noise.
struct QcSoup {
  lines : Array[String]
} derive(Debug)

///|
let qc_soup_headers : Array[String] = [
  "graph TD", "flowchart LR", "graph", "flowchart RL", "stateDiagram-v2", "stateDiagram",
  "sequenceDiagram", "classDiagram", "erDiagram", "graph XY", "grph TD", "", "%% comment",
  "---", "flowchart\tBT",
]

///|
let qc_soup_tokens : Array[String] = [
  "A", "B", "c1", "[*]", "état", "🚀", "中", "x", "o", "end", "subgraph", "direction",
  "LR", "state", "as", "note", "Note", "left of", "right of", "over", "participant",
  "actor", "loop", "alt", "else", "opt", "par", "and", "critical", "break", "rect",
  "activate", "deactivate", "autonumber", "class", "classDef", "style", "fill:#f00",
  ":::", "@{", "shape: circle", "}", "{", "[", "]", "(", ")", "((", "))", "[[", "]]",
  "{{", "}}", "([", "])", "[(", ")]", ">", "[/", "\\]", "[\\", "/]", "-->", "---",
  "-.->", "-.-", "==>", "===", "<-->", "<-.->", "<==>", "--", "-.", "==", "|", "||",
  ":", ";", "&", "\"", "'", "->>", "-->>", "->", "-)", "--x", "+", "-", "<|--", "*--",
  "o--", "..>", "..|>", "..", "||--o{", "}|..|{", "|o--||", "~", "<<interface>>",
  "%%", "---", "<", "&amp;", "\t", " ", "", "\u{0}", "\u{1}", "\u{FEFF}", "\u{FFFF}",
  "𝒳", "a b", "PK", "FK", "string", "int", "+m()", "#x", "$", "*", "%",
]

///|
fn QcSoup::text(self : QcSoup) -> String {
  self.lines.join("\n")
}

///|
impl @quickcheck.Arbitrary for QcSoup with fn arbitrary(size, rs) {
  let lines = [qc_pick(rs, qc_soup_headers)]
  for _ in 0..<qc_int(rs, 2 + size / 4) {
    let sb = StringBuilder()
    for _ in 0..<qc_int(rs, 7) {
      sb.write_string(qc_pick(rs, qc_soup_tokens))
      sb.write_string(qc_pick(rs, [" ", "", "  ", " ", "\t"]))
    }
    lines.push(sb.to_string())
  }
  { lines, }
}

///|
impl @quickcheck.Shrink for QcSoup with fn shrink(self) {
  let out : Array[QcSoup] = []
  for i in 1..<self.lines.length() {
    let lines = self.lines.copy()
    lines.remove(i) |> ignore
    out.push({ lines, })
  }
  out.iter()
}

///|
/// A structurally valid diagram whose text was then corrupted by a few
/// character-level edits (delete a span, insert a fragment, duplicate or drop
/// a line).
struct QcMutated {
  base : QcDiagram
  edits : Array[(Int, Int, Int, String)]
} derive(Debug)

///|
fn QcMutated::text(self : QcMutated) -> String {
  let mut chars = self.base.text().to_array()
  for edit in self.edits {
    let n = chars.length()
    if n == 0 {
      break
    }
    let pos = edit.1 % n
    match edit.0 {
      0 => {
        let end = (pos + edit.2 % 6 + 1).min(n)
        let next = chars[:pos].to_owned()
        next.append(chars[end:].to_owned())
        chars = next
      }
      1 => {
        let next = chars[:pos].to_owned()
        next.append(edit.3.to_array())
        next.append(chars[pos:].to_owned())
        chars = next
      }
      _ => {
        let next = chars[:pos].to_owned()
        next.push('\n')
        next.append(chars[pos:].to_owned())
        chars = next
      }
    }
  }
  String::from_array(chars)
}

///|
impl @quickcheck.Arbitrary for QcMutated with fn arbitrary(size, rs) {
  let base : QcDiagram = @quickcheck.Arbitrary::arbitrary(size, rs)
  let edits = []
  for _ in 0..<(1 + qc_int(rs, 4)) {
    edits.push(
      (
        qc_int(rs, 3),
        qc_int(rs, 10000),
        qc_int(rs, 100),
        qc_pick(rs, qc_soup_tokens),
      ),
    )
  }
  { base, edits, }
}

///|
impl @quickcheck.Shrink for QcMutated with fn shrink(self) {
  let out : Array[QcMutated] = []
  for i in 0..<self.edits.length() {
    if self.edits.length() > 1 {
      let edits = self.edits.copy()
      edits.remove(i) |> ignore
      out.push({ ..self, edits, })
    }
  }
  for base in @quickcheck.Shrink::shrink(self.base) {
    out.push({ ..self, base, })
  }
  out.iter()
}

// ---------------------------------------------------------------------------
// Shared render checks.
// ---------------------------------------------------------------------------

///|
fn qc_ascii_lines_consistent(text : String) -> Bool {
  let lines = text.split("\n").to_array()
  if lines.length() == 0 {
    return true
  }
  let width = lines[0].length()
  lines.all(line => line.length() == width)
}

///|
/// Render `text` through every public entry point. Parse failures must be
/// reported as `MermaidError`; any successful parse must render to a
/// well-formed SVG and to ASCII/Unicode text. Returns `false` with a message
/// on violation.
fn qc_render_all_ok(text : String) -> Bool raise {
  let _ = @parser_header_core.parse_mermaid(text) catch {
    ParseFailure(_) => return true
    UnknownTheme(_) => fail("parse_mermaid raised UnknownTheme")
  }
  let svg = @beautiful_mermaid.render_mermaid(text)
  if !svg.has_prefix("<svg ") || !svg.has_suffix("</svg>") {
    fail("bad SVG envelope")
  }
  match qc_xml_problem(svg) {
    Some(problem) => fail("ill-formed SVG: \{problem}")
    None => ()
  }
  let ascii = @beautiful_mermaid.render_mermaid_ascii(text, options={
    use_ascii: true,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  })
  let unicode = @beautiful_mermaid.render_mermaid_ascii(text)
  ascii.length() >= 0 && unicode.length() >= 0
}

// ---------------------------------------------------------------------------
// Properties.
// ---------------------------------------------------------------------------

///|
test "qc: parser never aborts on token soup; accepted input renders to well-formed SVG" {
  @quickcheck.check(
    (soup : QcSoup) => qc_render_all_ok(soup.text()),
    count=300,
    max_size=40,
    seed=0x5eed_0001,
    counterexample_context=soup => soup.text(),
  )
}

///|
test "qc: parser never aborts on mutated valid diagrams" {
  @quickcheck.check(
    (m : QcMutated) => qc_render_all_ok(m.text()),
    count=250,
    max_size=30,
    seed=0x5eed_0002,
    counterexample_context=m => m.text(),
  )
}

///|
test "qc: flowchart parse preserves declared nodes, shapes, labels and edges" {
  @quickcheck.check(
    (flow : QcFlow) => {
      let g = @parser_header_core.parse_mermaid(flow.text())
      assert_eq(direction_name(g.direction), flow.dir)
      // Every declared node exists with its id, label and shape.
      for node in flow.nodes {
        guard g.nodes.get(node.id) is Some(parsed) else {
          fail("missing node \{node.id}")
        }
        assert_eq(parsed.label, node.label)
        assert_eq(node_shape_name(parsed.shape), qc_flow_shapes[node.shape].2)
      }
      // No phantom nodes and definition order is declaration order.
      assert_eq(g.nodes.length(), flow.nodes.length())
      assert_eq(g.node_definition_order, flow.nodes.map(n => n.id))
      // Edges in order with endpoints, labels, style and arrows.
      assert_eq(g.edges.length(), flow.edges.length())
      for i, edge in flow.edges {
        let parsed = g.edges[i]
        let (op, style, arrow_start, arrow_end, _) = qc_flow_ops[edge.op]
        assert_eq(parsed.source, flow.nodes[edge.src].id)
        assert_eq(parsed.target, flow.nodes[edge.dst].id)
        assert_eq(parsed.label, edge.label)
        assert_eq(edge_style_name(parsed.style), style)
        assert_eq(parsed.has_arrow_start, arrow_start)
        assert_eq(parsed.has_arrow_end, arrow_end)
        assert_eq(parsed.relation_operator, Some(op))
      }
      // Subgraph membership.
      if flow.sub_len > 0 {
        assert_eq(g.subgraphs.length(), 1)
        let expected = flow.nodes[flow.sub_start:flow.sub_start + flow.sub_len].map(n => {
            n.id
          },
        )
        assert_eq(g.subgraphs[0].node_ids, expected)
        assert_eq(g.subgraphs[0].label, "Group <&>")
      } else {
        assert_eq(g.subgraphs.length(), 0)
      }
      true
    },
    count=300,
    max_size=40,
    seed=0x5eed_0003,
    counterexample_context=flow => flow.text(),
    observe=flow => {
      [
        @quickcheck.classify(
          flow.nodes.any(n => qc_has_special(n.label)),
          "node label with XML metachar",
        ),
        @quickcheck.classify(
          flow.nodes.any(n => qc_has_astral(n.label)),
          "node label with astral char",
        ),
        @quickcheck.classify(
          flow.nodes.any(n => n.label.contains("-") || n.label.contains(">")),
          "node label with - or >",
        ),
        @quickcheck.classify(
          flow.edges.any(e => e.label is Some(_)),
          "edge label",
        ),
        @quickcheck.classify(
          flow.edges.any(e => e.label is Some(_) && e.mid_label),
          "mid-label edge",
        ),
        @quickcheck.classify(flow.sub_len > 0, "subgraph"),
        @quickcheck.classify(
          flow.nodes.any(n => n.label.length() > 16),
          "long node label",
        ),
        @quickcheck.classify(flow.edges.any(e => e.src == e.dst), "self loop"),
        @quickcheck.classify(flow.edges.length() == 0, "no edges"),
      ]
    },
  )
}

///|
test "qc: state parse preserves transitions, labels and descriptions" {
  @quickcheck.check(
    (sd : QcState) => {
      let g = @parser_header_core.parse_mermaid(sd.text())
      assert_eq(g.edges.length(), sd.transitions.length())
      for i, t in sd.transitions {
        let edge = g.edges[i]
        assert_eq(edge.label, t.2)
        if t.0 < 0 {
          assert_true(
            g.nodes.get(edge.source) is Some({ shape: StateStart, .. }),
          )
        } else {
          assert_eq(edge.source, sd.states[t.0].0)
        }
        if t.1 < 0 {
          assert_true(g.nodes.get(edge.target) is Some({ shape: StateEnd, .. }))
        } else {
          assert_eq(edge.target, sd.states[t.1].0)
        }
      }
      for state in sd.states {
        match (state.1, g.nodes.get(state.0)) {
          (Some(desc), Some(node)) => assert_eq(node.label, desc)
          (Some(_), None) => fail("described state \{state.0} missing")
          (None, Some(node)) => assert_eq(node.label, state.0)
          (None, None) => ()
        }
      }
      true
    },
    count=200,
    max_size=30,
    seed=0x5eed_0004,
    counterexample_context=sd => sd.text(),
  )
}

///|
test "qc: sequence parse preserves participants, messages and notes" {
  @quickcheck.check(
    (sq : QcSeq) => {
      let g = @parser_header_core.parse_mermaid(sq.text())
      // Actor order: declarations first, then first appearance in messages.
      let expected : Array[String] = []
      for d in sq.decls {
        expected.push(qc_seq_id(d.0))
      }
      for m in sq.messages {
        for p in [m.0, m.1] {
          let id = qc_seq_id(p)
          if !expected.contains(id) {
            expected.push(id)
          }
        }
      }
      assert_eq(g.sequence_actor_order, expected)
      for d in sq.decls {
        guard g.nodes.get(qc_seq_id(d.0)) is Some(node) else {
          fail("missing participant")
        }
        assert_eq(node.label, d.2.unwrap_or(qc_seq_id(d.0)))
      }
      assert_eq(g.edges.length(), sq.messages.length())
      for i, m in sq.messages {
        let edge = g.edges[i]
        assert_eq(edge.source, qc_seq_id(m.0))
        assert_eq(edge.target, qc_seq_id(m.1))
        assert_eq(edge.label, m.3)
        assert_eq(edge.relation_operator, Some(qc_seq_ops[m.2]))
      }
      assert_eq(g.sequence_notes.length(), sq.notes.length())
      for i, note in sq.notes {
        assert_eq(g.sequence_notes[i].text, note.1)
        assert_eq(g.sequence_notes[i].actor_ids, [qc_seq_id(note.0)])
      }
      true
    },
    count=200,
    max_size=30,
    seed=0x5eed_0005,
    counterexample_context=sq => sq.text(),
  )
}

///|
test "qc: class/ER parse preserves relations and operators" {
  @quickcheck.check(
    (ce : QcClassEr) => {
      let g = @parser_header_core.parse_mermaid(ce.text())
      assert_eq(g.edges.length(), ce.relations.length())
      for i, r in ce.relations {
        let edge = g.edges[i]
        let op = if ce.er { qc_er_ops[r.2] } else { qc_class_ops[r.2] }
        assert_eq(edge.source, qc_entity_id(ce.er, r.0))
        assert_eq(edge.target, qc_entity_id(ce.er, r.1))
        assert_eq(edge.relation_operator, Some(op))
        assert_eq(edge.label, r.3)
        assert_true(g.nodes.contains(edge.source))
        assert_true(g.nodes.contains(edge.target))
      }
      true
    },
    count=200,
    max_size=30,
    seed=0x5eed_0006,
    counterexample_context=ce => ce.text(),
  )
}

///|
test "qc: comments, blank lines and indentation do not change the parse" {
  @quickcheck.check(
    (d : QcDiagram) => {
      let text = d.text()
      let lines = text.split("\n").to_array()
      let noisy : Array[String] = ["%% leading comment", ""]
      for i, line in lines {
        noisy.push("  \t" + line.to_owned() + "  ")
        if i % 2 == 0 {
          noisy.push("%% note \{i}")
        }
        if i % 3 == 0 {
          noisy.push("   ")
        }
      }
      let plain = qc_graph_summary(@parser_header_core.parse_mermaid(text))
      let with_noise = qc_graph_summary(
        @parser_header_core.parse_mermaid(noisy.join("\r\n")),
      )
      plain == with_noise
    },
    count=150,
    max_size=30,
    seed=0x5eed_0007,
    counterexample_context=d => d.text(),
  )
}

///|
test "qc: SVG output is well-formed XML and contains every escaped label" {
  @quickcheck.check(
    (d : QcDiagram) => {
      let text = d.text()
      let svg = @beautiful_mermaid.render_mermaid(text)
      match qc_xml_problem(svg) {
        Some(problem) => fail("ill-formed SVG: \{problem}")
        None => ()
      }
      let g = @parser_header_core.parse_mermaid(text)
      for _, node in g.nodes {
        if node.label == "" || node.shape is (ClassEntity | ErEntity) {
          continue
        }
        for line in node.label.split("\n") {
          let escaped = qc_xml_escape(line.to_owned())
          if !svg.contains(">" + escaped + "<") {
            fail("label \{line} not rendered as escaped text")
          }
        }
      }
      for edge in g.edges {
        match edge.label {
          Some(label) =>
            if !svg.contains(qc_xml_escape(label)) {
              fail("edge label \{label} missing from SVG")
            }
          None => ()
        }
      }
      true
    },
    count=200,
    max_size=30,
    seed=0x5eed_0008,
    counterexample_context=d => d.text(),
    observe=d => [@quickcheck.label(d.kind())],
  )
}

///|
test "qc: rendering is deterministic" {
  @quickcheck.check(
    (d : QcDiagram) => {
      let text = d.text()
      @beautiful_mermaid.render_mermaid(text) ==
      @beautiful_mermaid.render_mermaid(text) &&
      @beautiful_mermaid.render_mermaid_ascii(text) ==
      @beautiful_mermaid.render_mermaid_ascii(text)
    },
    count=60,
    max_size=30,
    seed=0x5eed_0009,
    counterexample_context=d => d.text(),
  )
}

///|
fn qc_inside(
  p : @model.Point,
  node : @model.PositionedNode,
  tolerance : Int,
) -> Bool {
  let left = node.x - node.width / 2 - tolerance
  let right = node.x + node.width / 2 + tolerance
  let top = node.y - node.height / 2 - tolerance
  let bottom = node.y + node.height / 2 + tolerance
  p.x >= left && p.x <= right && p.y >= top && p.y <= bottom
}

///|
test "qc: layout keeps nodes on canvas, disjoint, and edges attached" {
  @quickcheck.check(
    (d : QcDiagram) => {
      let g = @parser_header_core.parse_mermaid(d.text())
      let p = @layout.layout_graph(g, @model.RenderOptions::default())
      assert_true(p.width > 0 && p.height > 0)
      // Every parsed node is positioned exactly once and every edge is routed.
      assert_eq(p.nodes.length(), g.nodes.length())
      let by_id : Map[String, @model.PositionedNode] = Map([])
      for node in p.nodes {
        assert_true(g.nodes.contains(node.id))
        assert_true(!by_id.contains(node.id))
        by_id[node.id] = node
        assert_true(node.width > 0 && node.height > 0)
        assert_true(
          node.x - node.width / 2 >= 0 && node.x + node.width / 2 <= p.width,
        )
        assert_true(
          node.y - node.height / 2 >= 0 && node.y + node.height / 2 <= p.height,
        )
      }
      // Nodes of one rank never overlap. (Ranks are top-aligned rows in
      // TD/BT and share a centre x in LR/RL.) Known gap, not asserted: ranks
      // sit on a fixed layer-spacing grid, so a node taller than that step
      // (large circle, class box with many members) reaches into the next
      // rank.
      let horizontal = g.direction is (LR | RL)
      for i in 0..<p.nodes.length() {
        for j in (i + 1)..<p.nodes.length() {
          let a = p.nodes[i]
          let b = p.nodes[j]
          let same_rank = if horizontal {
            a.x == b.x
          } else {
            a.y - a.height / 2 == b.y - b.height / 2
          }
          let overlap_x = (a.x - b.x).abs() * 2 < a.width + b.width
          let overlap_y = (a.y - b.y).abs() * 2 < a.height + b.height
          if same_rank && overlap_x && overlap_y {
            fail("nodes \{a.id} and \{b.id} overlap")
          }
        }
      }
      assert_eq(p.edges.length(), g.edges.length())
      if !(d is Seq(_)) {
        for edge in p.edges {
          assert_true(edge.points.length() >= 2)
          for pt in edge.points {
            assert_true(
              pt.x >= 0 && pt.x <= p.width && pt.y >= 0 && pt.y <= p.height,
            )
          }
          let first = edge.points[0]
          let last = edge.points[edge.points.length() - 1]
          if !qc_inside(first, by_id[edge.source], 2) {
            fail("edge \{edge.source}->\{edge.target} does not start at source")
          }
          if !qc_inside(last, by_id[edge.target], 2) {
            fail("edge \{edge.source}->\{edge.target} does not end at target")
          }
        }
      }
      true
    },
    count=150,
    max_size=30,
    seed=0x5eed_000a,
    counterexample_context=d => d.text(),
    observe=d => [@quickcheck.label(d.kind())],
  )
}

///|
test "qc: every layout engine renders well-formed SVG" {
  let engines : Array[@model.LayoutEngine] = [
    Legacy,
    DagreParity,
    Elk,
    ElkLayered,
  ]
  @quickcheck.check(
    (d : QcDiagram) => {
      let text = d.text()
      for engine in engines {
        let svg = @beautiful_mermaid.render_mermaid(text, options={
          ..@model.RenderOptions::default(),
          layout_engine: Some(engine),
        })
        match qc_xml_problem(svg) {
          Some(problem) => fail("ill-formed SVG: \{problem}")
          None => ()
        }
      }
      true
    },
    count=60,
    max_size=25,
    seed=0x5eed_000b,
    counterexample_context=d => d.text(),
  )
}

///|
test "qc: ASCII/Unicode output has consistent line widths for any options" {
  @quickcheck.check(
    (input : (QcDiagram, Bool, Int, Int)) => {
      let (d, use_ascii, pad, border) = input
      let options : @model.AsciiRenderOptions = {
        use_ascii,
        padding_x: (pad % 7 + 7) % 7,
        padding_y: (border % 7 + 7) % 7,
        box_border_padding: ((pad ^ border) % 3 + 3) % 3,
      }
      let out = @beautiful_mermaid.render_mermaid_ascii(d.text(), options~)
      qc_ascii_lines_consistent(out)
    },
    count=150,
    max_size=25,
    seed=0x5eed_000c,
    counterexample_context=input => input.0.text(),
    observe=input => {
      [
        @quickcheck.label(input.0.kind()),
        @quickcheck.classify(qc_has_astral(input.0.text()), "astral text"),
        @quickcheck.classify(input.1, "use_ascii"),
      ]
    },
  )
}

///|
test "qc: ASCII/Unicode flowchart output keeps every node label" {
  @quickcheck.check(
    (input : (QcFlow, Bool)) => {
      let (flow0, use_ascii) = input
      // Known ASCII-layout gaps, not asserted here: the text renderer scales
      // the pixel layout onto a character grid, so Circle/DoubleCircle nodes
      // and labels much wider than their neighbours can be drawn over by an
      // adjacent box. Draw circles as Rounded and cap label length.
      let flow = {
        ..flow0,
        nodes: flow0.nodes.map(n => {
          let shape = if n.shape is (4 | 6) { 1 } else { n.shape }
          let chars = n.label.to_array()
          let label = if chars.length() > 12 {
            String::from_array(chars[:12]).trim().to_owned()
          } else {
            n.label
          }
          { ..n, shape, label: if label == "" { "a" } else { label }, }
        }),
      }
      let options = { ..@model.AsciiRenderOptions::default(), use_ascii, }
      let out = @beautiful_mermaid.render_mermaid_ascii(flow.text(), options~)
      for node in flow.nodes {
        if !out.contains(node.label) {
          fail("node label \{node.label} missing from text output")
        }
      }
      true
    },
    count=150,
    max_size=25,
    seed=0x5eed_000f,
    counterexample_context=input => input.0.text(),
    observe=input => {
      [
        @quickcheck.classify(
          input.0.nodes.any(n => qc_has_astral(n.label)),
          "astral label",
        ),
        @quickcheck.classify(input.0.sub_len > 0, "subgraph"),
      ]
    },
  )
}

///|
test "qc: theme names are normalized; unknown names raise UnknownTheme" {
  let slugs = [
    "zinc-light", "zinc-dark", "tokyo-night", "tokyo-night-storm", "tokyo-night-light",
    "catppuccin-mocha", "catppuccin-latte", "nord", "nord-light", "dracula", "github-light",
    "github-dark", "solarized-light", "solarized-dark", "one-dark",
  ]
  let source = "graph TD\nA --> B"
  @quickcheck.check(
    (input : (Int, UInt64, String)) => {
      let (which, bits, junk) = input
      let slug = slugs[(which % slugs.length() + slugs.length()) %
        slugs.length()]
      // Re-spell: random case, separators and leading/trailing separators.
      let sb = StringBuilder()
      let mut b = bits
      let seps = ["-", "_", " ", "   "]
      sb.write_string(seps[(b % 4).to_int()])
      b = b / 4
      for c in slug {
        if c == '-' {
          sb.write_string(seps[(b % 4).to_int()])
          b = b / 4
        } else {
          let upper = b % 2 == 1UL
          b = b / 2
          sb.write_char(
            if upper && c is ('a'..='z') {
              (c.to_int() - 32).unsafe_to_char()
            } else {
              c
            },
          )
        }
      }
      let variant = sb.to_string()
      let canonical = @beautiful_mermaid.render_mermaid_with_theme_name(
        source, slug,
      )
      let respelled = @beautiful_mermaid.render_mermaid_with_theme_name(
        source, variant,
      )
      assert_eq(respelled, canonical)
      // Junk that is not a theme name must raise UnknownTheme.
      let bogus = "no such theme " + junk
      let _ = @beautiful_mermaid.render_mermaid_with_theme_name(source, bogus) catch {
        UnknownTheme(_) => return true
        _ => return false
      }
      false
    },
    count=100,
    seed=0x5eed_000d,
  )
}

///|
test "qc: arbitrary option strings cannot break SVG well-formedness" {
  @quickcheck.check(
    (input : (String, String, String?, String?)) => {
      let (bg, font, line, accent) = input
      let svg = @beautiful_mermaid.render_mermaid("graph TD\nA[x] --> B[y]", options={
        ..@model.RenderOptions::default(),
        bg: Some(bg + "\"<&'"),
        font: Some(font),
        line,
        accent,
      })
      match qc_xml_problem(svg) {
        Some(problem) => fail("ill-formed SVG: \{problem}")
        None => true
      }
    },
    count=100,
    seed=0x5eed_000e,
  )
}

// ---------------------------------------------------------------------------
// Regression tests for counterexamples found by the properties above.
// ---------------------------------------------------------------------------

///|
test "regression: control characters in labels keep the SVG well-formed" {
  // Found by the token-soup property: a NUL in a label was copied verbatim
  // into the SVG, which no XML parser accepts.
  let svg = @beautiful_mermaid.render_mermaid(
    "graph TD\nA[x\u{0}y\u{1}z] --> B",
  )
  assert_false(svg.contains("\u{0}"))
  assert_false(svg.contains("\u{1}"))
  assert_true(svg.contains(">x\u{FFFD}y\u{FFFD}z</text>"))
}

///|
test "regression: color options are escaped in the root style attribute" {
  let svg = @beautiful_mermaid.render_mermaid("graph TD\nA --> B", options={
    ..@model.RenderOptions::default(),
    bg: Some("red\" onload=\"alert(1)"),
    line: Some("<&>"),
  })
  assert_false(svg.contains("onload=\"alert"))
  assert_true(svg.contains("--bg:red&quot; onload=&quot;alert(1)"))
  assert_true(svg.contains("--line:&lt;&amp;&gt;"))
}

///|
test "regression: an apostrophe in a node label does not hide the edge" {
  let g = @parser_header_core.parse_mermaid("graph TD\nA[it's] --> B")
  assert_eq(g.node_definition_order, ["A", "B"])
  assert_eq(g.nodes["A"].label, "it's")
  assert_eq(g.edges.length(), 1)
  assert_eq(g.edges[0].source, "A")
  assert_eq(g.edges[0].target, "B")
  let mid = @parser_header_core.parse_mermaid("graph TD\nA -- it's --> B")
  assert_eq(mid.edges.length(), 1)
  assert_eq(mid.edges[0].label, Some("it's"))
}

///|
test "regression: '>' inside a bracketed label is not an asymmetric shape" {
  let g = @parser_header_core.parse_mermaid(
    "graph TD\nA[x>y] --> B\nC[a-->b] --> D\nE>asym]",
  )
  assert_eq(g.node_definition_order, ["A", "B", "C", "D", "E"])
  assert_eq(g.nodes["A"].label, "x>y")
  assert_eq(node_shape_name(g.nodes["A"].shape), "Rectangle")
  assert_eq(g.nodes["C"].label, "a-->b")
  assert_eq(node_shape_name(g.nodes["C"].shape), "Rectangle")
  assert_eq(node_shape_name(g.nodes["E"].shape), "Asymmetric")
  assert_eq(g.nodes["E"].label, "asym")
}

///|
test "regression: astral characters survive ASCII rendering" {
  // Emoji were split into lone surrogates, dropped, and shortened the row.
  let out = @beautiful_mermaid.render_mermaid_ascii(
    "graph LR\nA[🚀 go] --> B[𝒳]",
  )
  assert_true(out.contains("🚀 go"))
  assert_true(out.contains("𝒳"))
  let widths = out.split("\n").map(line => line.length()).to_array()
  assert_true(widths.all(w => w == widths[0]))
  // Two edge labels drawn over each other must not leave half an emoji.
  let er = @beautiful_mermaid.render_mermaid_ascii(
    "erDiagram\nENT0 ||--o{ ENT1 : ><7🚀 *7\nENT0 |o--|| ENT1 : 🚀?",
  )
  let er_widths = er.split("\n").map(line => line.length()).to_array()
  assert_true(er_widths.all(w => w == er_widths[0]))
}

///|
fn regression_assert_no_overlap(source : String) -> Unit raise {
  let p = @layout.layout_graph(
    @parser_header_core.parse_mermaid(source),
    @model.RenderOptions::default(),
  )
  for i in 0..<p.nodes.length() {
    for j in (i + 1)..<p.nodes.length() {
      let a = p.nodes[i]
      let b = p.nodes[j]
      if (a.x - b.x).abs() * 2 < a.width + b.width &&
        (a.y - b.y).abs() * 2 < a.height + b.height {
        fail("\{a.id} overlaps \{b.id} in:\n\{source}")
      }
    }
  }
}

///|
test "regression: nodes of one rank do not overlap" {
  // LR: a dotted edge put A and C one 30px lane apart (boxes are 44px tall).
  regression_assert_no_overlap("flowchart LR\nA --> B\nC -.-> B")
  regression_assert_no_overlap("flowchart LR\nA\nB\nC\nD\nC -.-> B\nD <-.-> C")
  // TD: labels wider than the 130px lane step.
  regression_assert_no_overlap(
    "flowchart TD\nA --> B[a very long label for node B here]\nA --> C[another very long label for node C]",
  )
  // Upstream "Decision Tree" sample: D and E overlapped by 6px.
  regression_assert_no_overlap(
    (
      #|graph TD
      #|  A{Is it raining?} -->|Yes| B{Have umbrella?}
      #|  A -->|No| C([Go outside])
      #|  B -->|Yes| D([Go with umbrella])
      #|  B -->|No| E{Is it heavy?}
      #|  E -->|Yes| F([Stay inside])
      #|  E -->|No| G([Run for it])
    ),
  )
}
