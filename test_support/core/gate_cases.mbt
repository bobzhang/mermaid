///|
/// Public type `GateCase`.
pub struct GateCase {
  name : String
  input : String
  direction : String
  expected_node_count : Int
  expected_edge_count : Int
  padding_x : Int
  padding_y : Int
  expected_ascii : String
  expected_unicode : String
  expected_svg_fragments : Array[String]
}

///|
/// Public function `gate_cases`.
pub fn gate_cases() -> Array[GateCase] {
  [
    {
      name: "flow_basic",
      input: (
        #|graph TD
        #|A --> B
      ),
      direction: "TD",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+---+
        #||   |
        #|| A |
        #||   |
        #|+---+
        #|  |
        #|  |
        #|  |
        #|  |
        #|  v
        #|+---+
        #||   |
        #|| B |
        #||   |
        #|+---+
      ),
      expected_unicode: (
        #|┌───┐
        #|│   │
        #|│ A │
        #|│   │
        #|└─┬─┘
        #|  │
        #|  │
        #|  │
        #|  │
        #|  ▼
        #|┌───┐
        #|│   │
        #|│ B │
        #|│   │
        #|└───┘
      ),
      expected_svg_fragments: [
        "<svg", "<polyline", ">A</text>", ">B</text>", "marker-end=\"url(#arrowhead)\"",
      ],
    },
    {
      name: "flow_labeled_shapes",
      input: (
        #|graph LR
        #|A[Start] -->|Yes| B{Done}
      ),
      direction: "LR",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+-------+     +------+
        #||       |     |      |
        #|| Start |-Yes>| Done |
        #||       |     |      |
        #|+-------+     +------+
      ),
      expected_unicode: (
        #|┌───────┐     ┌──────┐
        #|│       │     │      │
        #|│ Start ├─Yes►│ Done │
        #|│       │     │      │
        #|└───────┘     └──────┘
      ),
      expected_svg_fragments: [
        "<svg", "<polygon", ">Start</text>", ">Done</text>", ">Yes</text>",
      ],
    },
    {
      name: "flow_bidirectional_thick",
      input: (
        #|graph TD
        #|A <==> B
      ),
      direction: "TD",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+---+
        #||   |
        #|| A |
        #||   |
        #|+---+
        #|  |
        #|  |
        #|  |
        #|  |
        #|  v
        #|+---+
        #||   |
        #|| B |
        #||   |
        #|+---+
      ),
      expected_unicode: (
        #|┌───┐
        #|│   │
        #|│ A │
        #|│   │
        #|└─┬─┘
        #|  │
        #|  │
        #|  │
        #|  │
        #|  ▼
        #|┌───┐
        #|│   │
        #|│ B │
        #|│   │
        #|└───┘
      ),
      expected_svg_fragments: [
        "<svg", "marker-end=\"url(#arrowhead)\"", "marker-start=\"url(#arrowhead-start)\"",
        "stroke-width=\"1.5\"",
      ],
    },
    {
      name: "flow_dotted_no_arrow",
      input: (
        #|graph TD
        #|A -.- B
      ),
      direction: "TD",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+---+
        #||   |
        #|| A |
        #||   |
        #|+---+
        #|  |
        #|  |
        #|  |
        #|  |
        #|  v
        #|+---+
        #||   |
        #|| B |
        #||   |
        #|+---+
      ),
      expected_unicode: (
        #|┌───┐
        #|│   │
        #|│ A │
        #|│   │
        #|└─┬─┘
        #|  │
        #|  │
        #|  │
        #|  │
        #|  ▼
        #|┌───┐
        #|│   │
        #|│ B │
        #|│   │
        #|└───┘
      ),
      expected_svg_fragments: [
        "<svg", "stroke-dasharray=\"4 4\"", ">A</text>", ">B</text>",
      ],
    },
    {
      name: "flow_chained_edges",
      input: (
        #|graph LR
        #|A --> B --> C
      ),
      direction: "LR",
      expected_node_count: 3,
      expected_edge_count: 2,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+---+     +---+     +---+
        #||   |     |   |     |   |
        #|| A |---->| B |---->| C |
        #||   |     |   |     |   |
        #|+---+     +---+     +---+
      ),
      expected_unicode: (
        #|┌───┐     ┌───┐     ┌───┐
        #|│   │     │   │     │   │
        #|│ A ├────►│ B ├────►│ C │
        #|│   │     │   │     │   │
        #|└───┘     └───┘     └───┘
      ),
      expected_svg_fragments: [
        "<svg", "<polyline", ">A</text>", ">B</text>", ">C</text>",
      ],
    },
    {
      name: "flow_parallel_targets",
      input: (
        #|graph LR
        #|A --> B & C
      ),
      direction: "LR",
      expected_node_count: 3,
      expected_edge_count: 2,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+---+     +---+
        #||   |     |   |
        #|| A |---->| B |
        #||   |     |   |
        #|+---+     +---+
        #|  |
        #|  |
        #|  |
        #|  |
        #|  |
        #|  |       +---+
        #|  |       |   |
        #|  +------>| C |
        #|          |   |
        #|          +---+
      ),
      expected_unicode: (
        #|┌───┐     ┌───┐
        #|│   │     │   │
        #|│ A ├────►│ B │
        #|│   │     │   │
        #|└─┬─┘     └───┘
        #|  │
        #|  │
        #|  │
        #|  │
        #|  │
        #|  │       ┌───┐
        #|  │       │   │
        #|  └──────►│ C │
        #|          │   │
        #|          └───┘
      ),
      expected_svg_fragments: [
        "<svg", "<polyline", ">A</text>", ">B</text>", ">C</text>",
      ],
    },
    {
      name: "state_basic",
      input: (
        #|stateDiagram-v2
        #|[*] --> Idle
        #|Idle --> Processing: start
        #|Processing --> [*]
      ),
      direction: "TD",
      expected_node_count: 4,
      expected_edge_count: 3,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+------------+
        #||            |
        #||            |
        #||            |
        #|+------------+
        #|       |
        #|       |
        #|       |
        #|       |
        #|       v
        #|+------------+
        #||            |
        #||    Idle    |
        #||            |
        #|+------------+
        #|       |
        #|       |
        #|     start
        #|       |
        #|       v
        #|+------------+
        #||            |
        #|| Processing |
        #||            |
        #|+------------+
        #|       |
        #|       |
        #|       |
        #|       |
        #|       v
        #|+------------+
        #||            |
        #||            |
        #||            |
        #|+------------+
      ),
      expected_unicode: (
        #|┌────────────┐
        #|│            │
        #|│            │
        #|│            │
        #|└──────┬─────┘
        #|       │
        #|       │
        #|       │
        #|       │
        #|       ▼
        #|┌────────────┐
        #|│            │
        #|│    Idle    │
        #|│            │
        #|└──────┬─────┘
        #|       │
        #|       │
        #|     start
        #|       │
        #|       ▼
        #|┌────────────┐
        #|│            │
        #|│ Processing │
        #|│            │
        #|└──────┬─────┘
        #|       │
        #|       │
        #|       │
        #|       │
        #|       ▼
        #|┌────────────┐
        #|│            │
        #|│            │
        #|│            │
        #|└────────────┘
      ),
      expected_svg_fragments: [
        "<svg", "class=\"state-start\"", ">Idle</text>", ">Processing</text>",
      ],
    },
    {
      name: "state_direction_override",
      input: (
        #|stateDiagram-v2
        #|direction LR
        #|[*] --> A
        #|A --> [*]
      ),
      direction: "LR",
      expected_node_count: 3,
      expected_edge_count: 2,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: (
        #|+--+     +---+     +--+
        #||  |     |   |     |  |
        #||  |---->| A |---->|  |
        #||  |     |   |     |  |
        #|+--+     +---+     +--+
      ),
      expected_unicode: (
        #|┌──┐     ┌───┐     ┌──┐
        #|│  │     │   │     │  │
        #|│  ├────►│ A ├────►│  │
        #|│  │     │   │     │  │
        #|└──┘     └───┘     └──┘
      ),
      expected_svg_fragments: ["<svg", "class=\"state-start\"", ">A</text>"],
    },
  ]
}
