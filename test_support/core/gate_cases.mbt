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
} derive(Eq, Show, ToJson)

///|
/// Public function `gate_cases`.
pub fn gate_cases() -> Array[GateCase] {
  [
    {
      name: "flow_basic",
      input: "graph TD\nA --> B",
      direction: "TD",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+---+\n|   |\n| A |\n|   |\n+---+\n  |\n  |\n  |\n  |\n  v\n+---+\n|   |\n| B |\n|   |\n+---+",
      expected_unicode: "┌───┐\n│   │\n│ A │\n│   │\n└─┬─┘\n  │\n  │\n  │\n  │\n  ▼\n┌───┐\n│   │\n│ B │\n│   │\n└───┘",
      expected_svg_fragments: [
        "<svg", "<polyline", ">A</text>", ">B</text>", "marker-end=\"url(#arrowhead)\"",
      ],
    },
    {
      name: "flow_labeled_shapes",
      input: "graph LR\nA[Start] -->|Yes| B{Done}",
      direction: "LR",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+-------+     +------+\n|       |     |      |\n| Start |-Yes>| Done |\n|       |     |      |\n+-------+     +------+",
      expected_unicode: "┌───────┐     ┌──────┐\n│       │     │      │\n│ Start ├─Yes►│ Done │\n│       │     │      │\n└───────┘     └──────┘",
      expected_svg_fragments: [
        "<svg", "<polygon", ">Start</text>", ">Done</text>", ">Yes</text>",
      ],
    },
    {
      name: "flow_bidirectional_thick",
      input: "graph TD\nA <==> B",
      direction: "TD",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+---+\n|   |\n| A |\n|   |\n+---+\n  |\n  |\n  |\n  |\n  v\n+---+\n|   |\n| B |\n|   |\n+---+",
      expected_unicode: "┌───┐\n│   │\n│ A │\n│   │\n└─┬─┘\n  │\n  │\n  │\n  │\n  ▼\n┌───┐\n│   │\n│ B │\n│   │\n└───┘",
      expected_svg_fragments: [
        "<svg", "marker-end=\"url(#arrowhead)\"", "marker-start=\"url(#arrowhead-start)\"",
        "stroke-width=\"1.5\"",
      ],
    },
    {
      name: "flow_dotted_no_arrow",
      input: "graph TD\nA -.- B",
      direction: "TD",
      expected_node_count: 2,
      expected_edge_count: 1,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+---+\n|   |\n| A |\n|   |\n+---+\n  |\n  |\n  |\n  |\n  v\n+---+\n|   |\n| B |\n|   |\n+---+",
      expected_unicode: "┌───┐\n│   │\n│ A │\n│   │\n└─┬─┘\n  │\n  │\n  │\n  │\n  ▼\n┌───┐\n│   │\n│ B │\n│   │\n└───┘",
      expected_svg_fragments: [
        "<svg", "stroke-dasharray=\"4 4\"", ">A</text>", ">B</text>",
      ],
    },
    {
      name: "flow_chained_edges",
      input: "graph LR\nA --> B --> C",
      direction: "LR",
      expected_node_count: 3,
      expected_edge_count: 2,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |---->| C |\n|   |     |   |     |   |\n+---+     +---+     +---+",
      expected_unicode: "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├────►│ C │\n│   │     │   │     │   │\n└───┘     └───┘     └───┘",
      expected_svg_fragments: [
        "<svg", "<polyline", ">A</text>", ">B</text>", ">C</text>",
      ],
    },
    {
      name: "flow_parallel_targets",
      input: "graph LR\nA --> B & C",
      direction: "LR",
      expected_node_count: 3,
      expected_edge_count: 2,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+\n  |\n  |\n  |\n  |\n  |\n  |       +---+\n  |       |   |\n  +------>| C |\n          |   |\n          +---+",
      expected_unicode: "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└─┬─┘     └───┘\n  │\n  │\n  │\n  │\n  │\n  │       ┌───┐\n  │       │   │\n  └──────►│ C │\n          │   │\n          └───┘",
      expected_svg_fragments: [
        "<svg", "<polyline", ">A</text>", ">B</text>", ">C</text>",
      ],
    },
    {
      name: "state_basic",
      input: "stateDiagram-v2\n[*] --> Idle\nIdle --> Processing: start\nProcessing --> [*]",
      direction: "TD",
      expected_node_count: 4,
      expected_edge_count: 3,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+------------+\n|            |\n|            |\n|            |\n+------------+\n       |\n       |\n       |\n       |\n       v\n+------------+\n|            |\n|    Idle    |\n|            |\n+------------+\n       |\n       |\n     start\n       |\n       v\n+------------+\n|            |\n| Processing |\n|            |\n+------------+\n       |\n       |\n       |\n       |\n       v\n+------------+\n|            |\n|            |\n|            |\n+------------+",
      expected_unicode: "┌────────────┐\n│            │\n│            │\n│            │\n└──────┬─────┘\n       │\n       │\n       │\n       │\n       ▼\n┌────────────┐\n│            │\n│    Idle    │\n│            │\n└──────┬─────┘\n       │\n       │\n     start\n       │\n       ▼\n┌────────────┐\n│            │\n│ Processing │\n│            │\n└──────┬─────┘\n       │\n       │\n       │\n       │\n       ▼\n┌────────────┐\n│            │\n│            │\n│            │\n└────────────┘",
      expected_svg_fragments: [
        "<svg", "class=\"state-start\"", ">Idle</text>", ">Processing</text>",
      ],
    },
    {
      name: "state_direction_override",
      input: "stateDiagram-v2\ndirection LR\n[*] --> A\nA --> [*]",
      direction: "LR",
      expected_node_count: 3,
      expected_edge_count: 2,
      padding_x: 5,
      padding_y: 5,
      expected_ascii: "+--+     +---+     +--+\n|  |     |   |     |  |\n|  |---->| A |---->|  |\n|  |     |   |     |  |\n+--+     +---+     +--+",
      expected_unicode: "┌──┐     ┌───┐     ┌──┐\n│  │     │   │     │  │\n│  ├────►│ A ├────►│  │\n│  │     │   │     │  │\n└──┘     └───┘     └──┘",
      expected_svg_fragments: ["<svg", "class=\"state-start\"", ">A</text>"],
    },
  ]
}
