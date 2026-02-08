///|
fn make_svg_test_graph(edges : Array[PositionedEdge]) -> PositionedGraph {
  PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [],
    edges,
    groups: [],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
}

///|
fn make_svg_test_node(label : String) -> PositionedNode {
  PositionedNode::{
    id: "A",
    label,
    shape: NodeShape::Rectangle,
    x: 100,
    y: 100,
    width: 80,
    height: 40,
    inline_style: None,
  }
}

///|
fn make_svg_test_node_with_shape(shape : NodeShape) -> PositionedNode {
  PositionedNode::{
    id: "A",
    label: "Test",
    shape,
    x: 100,
    y: 100,
    width: 80,
    height: 40,
    inline_style: None,
  }
}

///|
fn make_svg_test_edge(points : Array[Point]) -> PositionedEdge {
  PositionedEdge::{
    source: "A",
    target: "B",
    label: None,
    style: EdgeStyle::Solid,
    has_arrow_start: false,
    has_arrow_end: true,
    relation_operator: None,
    points,
    label_position: None,
  }
}

///|
fn count_occurrences(text : String, pattern : String) -> Int {
  if pattern == "" {
    return 0
  }
  let mut count = 0
  let mut start = 0
  while start < text.length() {
    let remaining = (try! text[start:]).to_string()
    match remaining.find(pattern) {
      Some(found) => {
        count += 1
        start = start + found + pattern.length()
      }
      None => break
    }
  }
  count
}

///|
test "SVG renderer skips edges with fewer than two points" {
  let graph = make_svg_test_graph([
    make_svg_test_edge([Point::{ x: 10, y: 20 }]),
    make_svg_test_edge([Point::{ x: 20, y: 30 }, Point::{ x: 60, y: 70 }]),
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_eq(count_occurrences(svg, "<polyline class=\"edge\""), 1)
}

///|
test "SVG renderer uses explicit edge label position" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: Some("Go"),
      style: EdgeStyle::Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: None,
      points: [Point::{ x: 100, y: 120 }, Point::{ x: 100, y: 200 }],
      label_position: Some(Point::{ x: 50, y: 80 }),
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("class=\"edge-label\" x=\"50\" y=\"80\""))
}

///|
test "SVG renderer escapes special characters in node labels" {
  let graph = PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [make_svg_test_node("<script> & \"quotes\" 'apos'")],
    edges: [],
    groups: [],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("&lt;script&gt;"))
  assert_true(svg.contains("&amp;"))
  assert_true(svg.contains("&quot;quotes&quot;"))
  assert_true(svg.contains("&#39;apos&#39;"))
}

///|
test "SVG renderer falls back to midpoint for labels without explicit position" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: Some("Yes"),
      style: EdgeStyle::Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: None,
      points: [Point::{ x: 100, y: 120 }, Point::{ x: 100, y: 200 }],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("class=\"edge-label\" x=\"100\" y=\"160\""))
}

///|
test "SVG renderer includes Google Fonts import" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("fonts.googleapis.com"))
  assert_true(svg.contains("family=Inter"))
}

///|
test "SVG renderer escapes ampersand in Google Fonts import URL" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("&amp;display=swap"))
}

///|
test "SVG renderer URL-encodes custom font name in import URL" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Roboto Mono",
    false,
  )

  assert_true(svg.contains("Roboto%20Mono"))
  assert_true(svg.contains("font-family:'Roboto Mono'"))
}

///|
test "SVG renderer URL-encodes reserved characters in custom font name" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "A+B/C",
    false,
  )

  assert_true(svg.contains("family=A%2BB%2FC"))
}

///|
test "SVG renderer URL-encodes non-ASCII font name in import URL" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Noto Sans 中文",
    false,
  )

  assert_true(svg.contains("Noto%20Sans%20%E4%B8%AD%E6%96%87"))
}

///|
test "SVG renderer root includes viewBox dimensions" {
  let graph = make_svg_test_graph([])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("<svg xmlns=\"http://www.w3.org/2000/svg\""))
  assert_true(svg.contains("width=\"400\""))
  assert_true(svg.contains("height=\"300\""))
  assert_true(svg.contains("viewBox=\"0 0 400 300\""))
}

///|
test "SVG renderer root style defines derived tokens with color-mix fallbacks" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains("--_text:var(--fg)"))
  assert_true(
    svg.contains(
      "--_line:var(--line,color-mix(in srgb,var(--fg) 30%,var(--bg)))",
    ),
  )
  assert_true(
    svg.contains(
      "--_text-sec:var(--muted,color-mix(in srgb,var(--fg) 60%,var(--bg)))",
    ),
  )
  assert_true(
    svg.contains(
      "--_text-muted:var(--muted,color-mix(in srgb,var(--fg) 40%,var(--bg)))",
    ),
  )
  assert_true(
    svg.contains(
      "--_node-fill:var(--surface,color-mix(in srgb,var(--fg) 3%,var(--bg)))",
    ),
  )
  assert_true(
    svg.contains(
      "--_node-stroke:var(--border,color-mix(in srgb,var(--fg) 20%,var(--bg)))",
    ),
  )
  assert_true(svg.contains("--_group-fill:var(--bg)"))
  assert_true(
    svg.contains("--_group-hdr:color-mix(in srgb,var(--fg) 5%,var(--bg))"),
  )
  assert_true(
    svg.contains("--_inner-stroke:color-mix(in srgb,var(--fg) 12%,var(--bg))"),
  )
}

///|
test "SVG renderer root style sets background from CSS variable" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains("background:var(--bg)"))
}

///|
test "SVG renderer transparent root style omits background" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    true,
  )
  assert_true(!svg.contains("background:var(--bg)"))
}

///|
test "SVG renderer root style only sets required CSS vars by default" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains("style=\"--bg:#FFFFFF;--fg:#27272A;background:var(--bg)\""))
  assert_true(!svg.contains("--line:"))
  assert_true(!svg.contains("--accent:"))
  assert_true(!svg.contains("--muted:"))
  assert_true(!svg.contains("--surface:"))
  assert_true(!svg.contains("--border:"))
}

///|
test "SVG renderer root style includes optional CSS vars when provided" {
  let colors = DiagramColors::{
    bg: "#111111",
    fg: "#eeeeee",
    line: Some("#123456"),
    accent: Some("#234567"),
    muted: Some("#345678"),
    surface: Some("#456789"),
    border: Some("#56789a"),
  }
  let svg = render_svg(make_svg_test_graph([]), colors, "Inter", false)

  assert_true(svg.contains("--line:#123456"))
  assert_true(svg.contains("--accent:#234567"))
  assert_true(svg.contains("--muted:#345678"))
  assert_true(svg.contains("--surface:#456789"))
  assert_true(svg.contains("--border:#56789a"))
}

///|
test "SVG renderer base edge class uses 0.75 stroke width" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(".edge{fill:none;stroke:var(--_line);stroke-width:0.75}"),
  )
}

///|
test "SVG renderer label class uses derived text fill at 13px" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains(".label{fill:var(--_text);font-size:13px}"))
}

///|
test "SVG renderer state-start class uses derived text fill" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains(".state-start{fill:var(--_text)}"))
}

///|
test "SVG renderer edge-label class uses text-muted fill at 11px" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(".edge-label{fill:var(--_text-muted);font-size:11px}"),
  )
}

///|
test "SVG renderer edge-endpoint class uses text-muted fill at 11px" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(".edge-endpoint{fill:var(--_text-muted);font-size:11px}"),
  )
}

///|
test "SVG renderer class-row class uses text-muted fill at 11px" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains(".class-row{fill:var(--_text-muted);font-size:11px}"))
}

///|
test "SVG renderer node-header class uses group header fill and node stroke" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".node-header{fill:var(--_group-hdr);stroke:var(--_node-stroke);stroke-width:1}",
    ),
  )
}

///|
test "SVG renderer node-shape class uses node fill and stroke tokens" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".node-shape{fill:var(--_node-fill);stroke:var(--_node-stroke);stroke-width:1.5}",
    ),
  )
}

///|
test "SVG renderer node-divider class uses node-stroke token" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains(".node-divider{stroke:var(--_node-stroke);stroke-width:1}"))
}

///|
test "SVG renderer edge-label background uses inner-stroke border" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(".edge-label-bg{fill:var(--bg);stroke:var(--_inner-stroke);stroke-width:0.5}"),
  )
}

///|
test "SVG renderer lifeline class uses 0.75 stroke width" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".lifeline{fill:none;stroke:var(--_line);stroke-width:0.75;stroke-dasharray:6 4}",
    ),
  )
}

///|
test "SVG renderer sequence-actor class uses derived line token" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(".sequence-actor{fill:none;stroke:var(--_line);stroke-width:1.5}"),
  )
}

///|
test "SVG renderer sequence-divider class uses 0.75 stroke width" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".sequence-divider{stroke:var(--_line);stroke-width:0.75;stroke-dasharray:6 4}",
    ),
  )
}

///|
test "SVG renderer sequence-note class uses 0.75 stroke width" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".sequence-note{fill:var(--_group-hdr);stroke:var(--_node-stroke);stroke-width:0.75}",
    ),
  )
}

///|
test "SVG renderer sequence-note-fold class uses inner-stroke fill" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains(".sequence-note-fold{fill:var(--_inner-stroke)}"))
}

///|
test "SVG renderer sequence-note-text class uses text-muted fill" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(".sequence-note-text{fill:var(--_text-muted);font-size:11px}"),
  )
}

///|
test "SVG renderer sequence-activation class uses node fill/stroke and 0.75 width" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".sequence-activation{fill:var(--_node-fill);stroke:var(--_node-stroke);stroke-width:0.75}",
    ),
  )
}

///|
test "SVG renderer sequence block and tab classes use upstream stroke and color tokens" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".sequence-block{fill:none;stroke:var(--_node-stroke);stroke-width:1}",
    ),
  )
  assert_true(
    svg.contains(
      ".sequence-block-tab{fill:var(--_group-hdr);stroke:var(--_node-stroke);stroke-width:1}",
    ),
  )
}

///|
test "SVG renderer sequence-block-label class uses text-sec fill" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".sequence-block-label{fill:var(--_text-sec);font-size:11px;font-weight:600}",
    ),
  )
}

///|
test "SVG renderer sequence-divider-label class uses text-muted fill" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(
    svg.contains(
      ".sequence-divider-label{fill:var(--_text-muted);font-size:11px}",
    ),
  )
}

///|
test "SVG renderer edge-label midpoint follows polyline segments" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: Some("L"),
      style: EdgeStyle::Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: None,
      points: [
        Point::{ x: 0, y: 0 },
        Point::{ x: 100, y: 0 },
        Point::{ x: 100, y: 100 },
      ],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("class=\"edge-label\" x=\"100\" y=\"0\""))
}

///|
test "SVG renderer renders thick edge with width 1.5" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: None,
      style: EdgeStyle::Thick,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: None,
      points: [Point::{ x: 10, y: 20 }, Point::{ x: 60, y: 70 }],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("stroke-width=\"1.5\""))
}

///|
test "SVG renderer state pseudostates use text color fills" {
  let graph = PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [
      PositionedNode::{
        id: "start",
        label: "",
        shape: NodeShape::StateStart,
        x: 80,
        y: 80,
        width: 28,
        height: 28,
        inline_style: None,
      },
      PositionedNode::{
        id: "end",
        label: "",
        shape: NodeShape::StateEnd,
        x: 160,
        y: 80,
        width: 28,
        height: 28,
        inline_style: None,
      },
    ],
    edges: [],
    groups: [],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("fill=\"var(--_text)\""))
  assert_true(svg.contains("stroke=\"none\""))
  assert_true(svg.contains("fill=\"none\""))
}

///|
test "SVG renderer solid edges omit dasharray" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: None,
      style: EdgeStyle::Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: None,
      points: [Point::{ x: 5, y: 5 }, Point::{ x: 20, y: 20 }],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("<polyline class=\"edge\""))
  assert_true(!svg.contains("stroke-dasharray=\"4 4\""))
}

///|
test "SVG renderer markers use arrow CSS variable" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("id=\"arrowhead\""))
  assert_true(svg.contains("fill=\"var(--_arrow)\""))
}

///|
test "SVG renderer defines both start and end arrow markers in defs" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains("<defs>"))
  assert_true(svg.contains("id=\"arrowhead\""))
  assert_true(svg.contains("id=\"arrowhead-start\""))
  assert_true(svg.contains("</defs>"))
}

///|
test "SVG renderer flowchart arrow markers use 8x4.8 geometry and reversed start orientation" {
  let svg = render_svg(
    make_svg_test_graph([]),
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(
    svg.contains(
      "id=\"arrowhead\" markerWidth=\"8\" markerHeight=\"4.8\" refX=\"8\" refY=\"2.4\" orient=\"auto\"",
    ),
  )
  assert_true(
    svg.contains(
      "id=\"arrowhead-start\" markerWidth=\"8\" markerHeight=\"4.8\" refX=\"0\" refY=\"2.4\" orient=\"auto-start-reverse\"",
    ),
  )
}

///|
test "SVG renderer omits edge-label elements when edge has no label" {
  let graph = make_svg_test_graph([
    make_svg_test_edge([Point::{ x: 100, y: 120 }, Point::{ x: 100, y: 200 }]),
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(!svg.contains("class=\"edge-label\""))
  assert_true(!svg.contains("class=\"edge-label-bg\""))
}

///|
test "SVG renderer rectangle and rounded nodes include ry attribute" {
  let rect_svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [make_svg_test_node_with_shape(NodeShape::Rectangle)],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(rect_svg.contains("rx=\"0\" ry=\"0\""))

  let rounded_svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [make_svg_test_node_with_shape(NodeShape::Rounded)],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(rounded_svg.contains("rx=\"6\" ry=\"6\""))
}

///|
test "SVG renderer stadium uses half-height corner radius for rx and ry" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "S",
          label: "Stadium",
          shape: NodeShape::Stadium,
          x: 100,
          y: 100,
          width: 100,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )
  assert_true(svg.contains("rx=\"20\" ry=\"20\""))
}

///|
test "SVG renderer asymmetric shape is a left-pointed flag" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "F",
          label: "Flag",
          shape: NodeShape::Asymmetric,
          x: 100,
          y: 100,
          width: 80,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("points=\"72,80 140,80 140,120 72,120 60,100\""))
}

///|
test "SVG renderer doublecircle uses 5px inner ring gap" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "D",
          label: "Dbl",
          shape: NodeShape::DoubleCircle,
          x: 100,
          y: 100,
          width: 40,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("r=\"20\""))
  assert_true(svg.contains("r=\"15\""))
}

///|
test "SVG renderer circle uses min(width,height) radius" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "C",
          label: "Circle",
          shape: NodeShape::Circle,
          x: 100,
          y: 100,
          width: 80,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("r=\"20\""))
}

///|
test "SVG renderer doublecircle radius uses min(width,height)" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "D",
          label: "Double",
          shape: NodeShape::DoubleCircle,
          x: 100,
          y: 100,
          width: 90,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("r=\"20\""))
  assert_true(svg.contains("r=\"15\""))
}

///|
test "SVG renderer trapezoid uses width-proportional 15 percent inset" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "T",
          label: "Trap",
          shape: NodeShape::Trapezoid,
          x: 100,
          y: 100,
          width: 80,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("points=\"72,80 128,80 140,120 60,120\""))
}

///|
test "SVG renderer trapezoid-alt uses width-proportional 15 percent inset" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "TA",
          label: "TrapAlt",
          shape: NodeShape::TrapezoidAlt,
          x: 100,
          y: 100,
          width: 80,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("points=\"60,80 140,80 128,120 72,120\""))
}

///|
test "SVG renderer cylinder uses 7px ellipse cap radius" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "C",
          label: "Cyl",
          shape: NodeShape::Cylinder,
          x: 100,
          y: 100,
          width: 80,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("y=\"87\" width=\"80\" height=\"26\""))
  assert_true(svg.contains("stroke=\"none\""))
  assert_true(svg.contains("x1=\"60\" y1=\"87\" x2=\"60\" y2=\"113\""))
  assert_true(svg.contains("x1=\"140\" y1=\"87\" x2=\"140\" y2=\"113\""))
  assert_true(svg.contains("cy=\"87\" rx=\"40\" ry=\"7\""))
  assert_true(svg.contains("cy=\"113\" rx=\"40\" ry=\"7\""))
}

///|
test "SVG renderer hexagon uses height-based quarter inset" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "H",
          label: "Hex",
          shape: NodeShape::Hexagon,
          x: 100,
          y: 100,
          width: 80,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(
    svg.contains("points=\"70,80 130,80 140,100 130,120 70,120 60,100\""),
  )
}

///|
test "SVG renderer bidirectional edges include both markers" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: None,
      style: EdgeStyle::Solid,
      has_arrow_start: true,
      has_arrow_end: true,
      relation_operator: None,
      points: [Point::{ x: 20, y: 30 }, Point::{ x: 60, y: 70 }],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("marker-start=\"url(#arrowhead-start)\""))
  assert_true(svg.contains("marker-end=\"url(#arrowhead)\""))
}

///|
test "SVG renderer escapes injection in inline fill style attribute" {
  let inline_style : Map[String, String] = {}
  inline_style["fill"] = "red\" onmouseover=\"alert(1)"
  let graph = PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [
      PositionedNode::{
        id: "A",
        label: "Node",
        shape: NodeShape::Rectangle,
        x: 100,
        y: 100,
        width: 80,
        height: 40,
        inline_style: Some(inline_style),
      },
    ],
    edges: [],
    groups: [],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(!svg.contains("onmouseover=\"alert"))
  assert_true(svg.contains("red&quot; onmouseover=&quot;alert(1)"))
}

///|
test "SVG renderer edge-label midpoint uses Euclidean segment lengths" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: Some("M"),
      style: EdgeStyle::Solid,
      has_arrow_start: false,
      has_arrow_end: true,
      relation_operator: None,
      points: [
        Point::{ x: 0, y: 0 },
        Point::{ x: 10, y: 10 },
        Point::{ x: 20, y: 10 },
      ],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  // Euclidean midpoint is around (8.5,8.5), integer position should be close.
  assert_true(svg.contains("class=\"edge-label\" x=\"8\" y=\"8\""))
}

///|
test "SVG renderer escapes injection in inline stroke-width style attribute" {
  let inline_style : Map[String, String] = {}
  inline_style["stroke-width"] = "2\" onmouseover=\"alert(1)"
  let graph = PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [
      PositionedNode::{
        id: "A",
        label: "Node",
        shape: NodeShape::Rectangle,
        x: 100,
        y: 100,
        width: 80,
        height: 40,
        inline_style: Some(inline_style),
      },
    ],
    edges: [],
    groups: [],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(!svg.contains("onmouseover=\"alert"))
  assert_true(svg.contains("2&quot; onmouseover=&quot;alert(1)"))
}

///|
test "SVG renderer escapes special characters in group labels" {
  let graph = PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [],
    edges: [],
    groups: [
      PositionedGroup::{
        id: "g1",
        label: "A < B",
        x: 20,
        y: 20,
        width: 120,
        height: 80,
        children: [],
      },
    ],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("A &lt; B"))
}

///|
test "SVG renderer group primitives use derived group tokens" {
  let graph = PositionedGraph::{
    width: 400,
    height: 300,
    nodes: [],
    edges: [],
    groups: [
      PositionedGroup::{
        id: "g1",
        label: "Outer",
        x: 20,
        y: 20,
        width: 120,
        height: 80,
        children: [],
      },
    ],
    sequence_lifelines: [],
    sequence_activations: [],
    sequence_blocks: [],
    sequence_notes: [],
  }
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(
    svg.contains(
      "class=\"group-outer\" x=\"20\" y=\"20\" width=\"120\" height=\"80\" rx=\"0\" ry=\"0\" fill=\"var(--_group-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\"",
    ),
  )
  assert_true(
    svg.contains(
      "class=\"group-header\" x=\"20\" y=\"20\" width=\"120\" height=\"24\" rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\"",
    ),
  )
  assert_true(svg.contains("class=\"group-label\" x=\"28\" y=\"32\""))
  assert_true(svg.contains("fill=\"var(--_text-sec)\">Outer</text>"))
}

///|
test "SVG renderer no-arrow edges omit marker attributes" {
  let graph = make_svg_test_graph([
    PositionedEdge::{
      source: "A",
      target: "B",
      label: None,
      style: EdgeStyle::Solid,
      has_arrow_start: false,
      has_arrow_end: false,
      relation_operator: None,
      points: [Point::{ x: 20, y: 30 }, Point::{ x: 60, y: 70 }],
      label_position: None,
    },
  ])
  let svg = render_svg(graph, DiagramColors::default(), "Inter", false)

  assert_true(svg.contains("<polyline class=\"edge\""))
  assert_true(!svg.contains("marker-start="))
  assert_true(!svg.contains("marker-end="))
}

///|
test "SVG renderer subroutine uses 8px inset vertical lines" {
  let svg = render_svg(
    PositionedGraph::{
      width: 400,
      height: 300,
      nodes: [
        PositionedNode::{
          id: "S",
          label: "Sub",
          shape: NodeShape::Subroutine,
          x: 150,
          y: 120,
          width: 100,
          height: 40,
          inline_style: None,
        },
      ],
      edges: [],
      groups: [],
      sequence_lifelines: [],
      sequence_activations: [],
      sequence_blocks: [],
      sequence_notes: [],
    },
    DiagramColors::default(),
    "Inter",
    false,
  )

  assert_true(svg.contains("rx=\"0\" ry=\"0\""))
  assert_true(svg.contains("x1=\"108\""))
  assert_true(svg.contains("x1=\"192\""))
}
