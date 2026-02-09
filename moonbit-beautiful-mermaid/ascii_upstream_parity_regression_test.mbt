///|
fn default_ascii_options(
  use_ascii : Bool,
) -> @beautiful_mermaid.AsciiRenderOptions {
  @beautiful_mermaid.AsciiRenderOptions::{
    use_ascii,
    padding_x: 5,
    padding_y: 5,
    box_border_padding: 1,
  }
}

///|
fn assert_text_parity(
  input : String,
  expected_ascii : String,
  expected_unicode : String,
) -> Unit raise {
  let actual_ascii = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=default_ascii_options(true),
  )
  let actual_unicode = try! @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=default_ascii_options(false),
  )

  assert_eq(
    @test_support.normalize_whitespace(actual_ascii),
    @test_support.normalize_whitespace(expected_ascii),
  )
  assert_eq(
    @test_support.normalize_whitespace(actual_unicode),
    @test_support.normalize_whitespace(expected_unicode),
  )
}

///|
fn beautiful_mermaid_source() -> String {
  "stateDiagram-v2\n    direction LR\n    [*] --> Input\n    Input --> Parse: DSL\n    Parse --> Layout: AST\n    Layout --> SVG: Vector\n    Layout --> ASCII: Text\n    SVG --> Theme\n    ASCII --> Theme\n    Theme --> Output\n    Output --> [*]"
}

///|
fn beautiful_mermaid_expected_ascii() -> String {
  [
    "+--+     +-------+     +-------+     +--------+        +-------+     +-------+     +--------+     +--+",
    "|  |     |       |     |       |     |        |        |       |     |       |     |        |     |  |",
    "|  |---->| Input |-DSL>| Parse |-AST>| Layout |Vector->|  SVG  |---->| Theme |---->| Output |---->|  |",
    "|  |     |       |     |       |     |        |        |       |     |       |     |        |     |  |",
    "+--+     +-------+     +-------+     +--------+        +-------+     +-------+     +--------+     +--+",
    "                                          |                              ^",
    "                                          |                              |",
    "                                          |                              |",
    "                                        Text                             |",
    "                                          |                              |",
    "                                          |            +-------+         |",
    "                                          |            |       |         |",
    "                                          +----------->| ASCII |---------+",
    "                                                       |       |", "                                                       +-------+",
  ]
  .iter()
  .join("\n")
}

///|
fn beautiful_mermaid_expected_unicode() -> String {
  [
    "┌──┐     ┌───────┐     ┌───────┐     ┌────────┐        ┌───────┐     ┌───────┐     ┌────────┐     ┌──┐",
    "│  │     │       │     │       │     │        │        │       │     │       │     │        │     │  │",
    "│  ├────►│ Input ├─DSL►│ Parse ├─AST►│ Layout ├Vector─►│  SVG  ├────►│ Theme ├────►│ Output ├────►│  │",
    "│  │     │       │     │       │     │        │        │       │     │       │     │        │     │  │",
    "└──┘     └───────┘     └───────┘     └────┬───┘        └───────┘     └───────┘     └────────┘     └──┘",
    "                                          │                              ▲",
    "                                          │                              │",
    "                                          │                              │",
    "                                        Text                             │",
    "                                          │                              │",
    "                                          │            ┌───────┐         │",
    "                                          │            │       │         │",
    "                                          └───────────►│ ASCII ├─────────┘",
    "                                                       │       │", "                                                       └───────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn git_branching_workflow_source() -> String {
  "graph LR\n  A[main] --> B[develop]\n  B --> C[feature/auth]\n  B --> D[feature/ui]\n  C --> E{PR Review}\n  D --> E\n  E -->|approved| B\n  B --> F[release/1.0]\n  F --> G{Tests?}\n  G -->|pass| A\n  G -->|fail| F"
}

///|
fn git_branching_workflow_expected_ascii() -> String {
  [
    "+------+     +---------+     +--------------+      +-----------+", "|      |     |         |     |              |      |           |",
    "| main |---->| develop |---->| feature/auth |---+->| PR Review |", "|      |     |         |     |              |   |  |           |",
    "+------+     +---------+     +--------------+   |  +-----------+", "    ^             ^                             |    approved",
    "    |             |                             |        |", "    +-------------+------------------+----------+--------+",
    "                  |                  |          |", "                  |                  |          |",
    "                  |          +--------------+   |  +-----------+", "                  |          |              |   |  |           |",
    "                  +--------->|  feature/ui  |  fail|   Tests?  |", "                  |          |              |   |  |           |",
    "                  |          +--------------+   |  +-----------+", "                  |                             |        ^",
    "                  |                             |        |", "                  |                  +----------+        |",
    "                  |                  |                   |", "                  |                  v                   |",
    "                  |          +--------------+            |", "                  |          |              |            |",
    "                  +--------->| release/1.0  |------------+", "                             |              |",
    "                             +--------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn git_branching_workflow_expected_unicode() -> String {
  [
    "┌──────┐     ┌─────────┐     ┌──────────────┐      ┌───────────┐",
    "│      │     │         │     │              │      │           │",
    "│ main ├────►│ develop ├────►│ feature/auth ├───┬─►│ PR Review │",
    "│      │     │         │     │              │   │  │           │",
    "└──────┘     └────┬────┘     └──────────────┘   │  └─────┬─────┘",
    "    ▲             ▲                             │    approved", "    │             │                             │        │",
    "    └─────────────┼──────────────────┬──────────┼────────┘",
    "                  │                  │          │", "                  │                  │          │",
    "                  │          ┌───────┴──────┐   │  ┌───────────┐",
    "                  │          │              │   │  │           │",
    "                  ├─────────►│  feature/ui  │  fail┤   Tests?  │",
    "                  │          │              │   │  │           │",
    "                  │          └──────────────┘   │  └───────────┘",
    "                  │                             │        ▲", "                  │                             │        │",
    "                  │                  ┌──────────┘        │",
    "                  │                  │                   │", "                  │                  ▼                   │",
    "                  │          ┌──────────────┐            │",
    "                  │          │              │            │", "                  └─────────►│ release/1.0  ├────────────┘",
    "                             │              │", "                             └──────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn subgraph_direction_override_source() -> String {
  "graph TD\n  subgraph pipeline [Processing Pipeline]\n    direction LR\n    A[Input] --> B[Parse] --> C[Transform] --> D[Output]\n  end\n  E[Source] --> A\n  D --> F[Sink]"
}

///|
fn subgraph_direction_override_expected_ascii() -> String {
  [
    "+---------------+             ",
    "|Processing Pipe|             ",
    "|               |             ",
    "|               |             ",
    "| +-----------+ |   +--------+",
    "| |           | |   |        |",
    "| |   Input   |<----| Source |",
    "| |           | |   |        |",
    "| +-----------+ |   +--------+",
    "|       |       |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       v       |             ",
    "| +-----------+ |             ",
    "| |           | |             ",
    "| |   Parse   | |             ",
    "| |           | |             ",
    "| +-----------+ |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       v       |             ",
    "| +-----------+ |             ",
    "| |           | |             ",
    "| | Transform | |             ",
    "| |           | |             ",
    "| +-----------+ |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       |       |             ",
    "|       v       |             ",
    "| +-----------+ |             ",
    "| |           | |             ",
    "| |   Output  | |             ",
    "| |           | |             ",
    "| +-----------+ |             ",
    "|       |       |             ",
    "+-------|-------+             ",
    "        |                     ",
    "        |                     ",
    "        v                     ",
    "  +-----------+               ",
    "  |           |               ",
    "  |    Sink   |               ",
    "  |           |               ",
    "  +-----------+               ",
  ]
  .iter()
  .join("\n")
}

///|
fn subgraph_direction_override_expected_unicode() -> String {
  [
    "┌───────────────┐             ",
    "│Processing Pipe│             ",
    "│               │             ",
    "│               │             ",
    "│ ┌───────────┐ │   ┌────────┐",
    "│ │           │ │   │        │",
    "│ │   Input   │◄┼───┤ Source │",
    "│ │           │ │   │        │",
    "│ └─────┬─────┘ │   └────────┘",
    "│       │       │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       ▼       │             ",
    "│ ┌───────────┐ │             ",
    "│ │           │ │             ",
    "│ │   Parse   │ │             ",
    "│ │           │ │             ",
    "│ └─────┬─────┘ │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       ▼       │             ",
    "│ ┌───────────┐ │             ",
    "│ │           │ │             ",
    "│ │ Transform │ │             ",
    "│ │           │ │             ",
    "│ └─────┬─────┘ │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       │       │             ",
    "│       ▼       │             ",
    "│ ┌───────────┐ │             ",
    "│ │           │ │             ",
    "│ │   Output  │ │             ",
    "│ │           │ │             ",
    "│ └─────┬─────┘ │             ",
    "│       │       │             ",
    "└───────┼───────┘             ",
    "        │                     ",
    "        │                     ",
    "        ▼                     ",
    "  ┌───────────┐               ",
    "  │           │               ",
    "  │    Sink   │               ",
    "  │           │               ",
    "  └───────────┘               ",
  ]
  .iter()
  .join("\n")
}

///|
fn state_connection_lifecycle_source() -> String {
  "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
}

///|
fn state_connection_lifecycle_expected_ascii() -> String {
  [
    "+---------------+                            ",
    "|               |                            ",
    "|               |                            ",
    "|               |                            ",
    "+---------------+                            ",
    "        |                                    ",
    "        |                                    ",
    "        |                                    ",
    "        |                                    ",
    "        v                                    ",
    "+---------------+                            ",
    "|               |                            ",
    "|     Closed    |   <----+-----------+       ",
    "|               |        |           |       ",
    "+---------------+        |           |       ",
    "        ^                |           |       ",
    "        |                |           |       ",
    "     timeout             |           |       ",
    "        |                |           |       ",
    "        v                |           v       ",
    "+---------------+        |   +--------------+",
    "|               |        |   |              |",
    "|   Connecting  |        |   |              |",
    "|               |        |   |              |",
    "+---------------+        |   +--------------+",
    "        |                |                   ",
    "        |                |                   ",
    "     success             |                   ",
    "        |                |                   ",
    "        v                |                   ",
    "+---------------+        +---+               ",
    "|               |        |   |               ",
    "|   Connected   |   <----|error------+       ",
    "|               |        |   |       |       ",
    "+---------------+        |   |       |       ",
    "        |                |   |       |       ",
    "        |                |   |    success    ",
    "      close              |   +-------+       ",
    "        |                |      max_retries  ",
    "        v                |           v       ",
    "+---------------+        |   +--------------+",
    "|               |        |   |              |",
    "| Disconnecting |   done-+   | Reconnecting |",
    "|               |            |              |",
    "+---------------+            +--------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn state_connection_lifecycle_expected_unicode() -> String {
  [
    "┌───────────────┐                            ",
    "│               │                            ",
    "│               │                            ",
    "│               │                            ",
    "└───────┬───────┘                            ",
    "        │                                    ",
    "        │                                    ",
    "        │                                    ",
    "        │                                    ",
    "        ▼                                    ",
    "┌───────────────┐                            ",
    "│               │                            ",
    "│     Closed    │  ├◄────┬───────────┐       ",
    "│               │        │           │       ",
    "└───────┬───────┘        │           │       ",
    "        ▲                │           │       ",
    "        │                │           │       ",
    "     timeout             │           │       ",
    "        │                │           │       ",
    "        ▼                │           ▼       ",
    "┌───────┴───────┐        │   ┌──────────────┐",
    "│               │        │   │              │",
    "│   Connecting  │        │   │              │",
    "│               │        │   │              │",
    "└───────┬───────┘        │   └──────────────┘",
    "        │                │                   ",
    "        │                │                   ",
    "     success             │                   ",
    "        │                │                   ",
    "        ▼                │                   ",
    "┌───────────────┐        ├───┐               ",
    "│               │        │   │               ",
    "│   Connected   │  ├◄────┼error──────┐       ",
    "│               │        │   │       │       ",
    "└───────┬───────┘        │   │       │       ",
    "        │                │   │       │       ",
    "        │                │   │    success    ",
    "      close              │   └───────┤       ",
    "        │                │      max_retries  ",
    "        ▼                │           ▼       ",
    "┌───────────────┐        │   ┌───────┴──────┐",
    "│               │        │   │              │",
    "│ Disconnecting │  ├done─┘   │ Reconnecting │",
    "│               │            │              │",
    "└───────────────┘            └──────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_activation_boxes_source() -> String {
  "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>+S: Request\n  S->>+S: Process\n  S->>-S: Done\n  S-->>-C: Response"
}

///|
fn sequence_activation_boxes_expected_ascii() -> String {
  [
    "+--------+    +--------+            ",
    "| Client |    | Server |            ",
    "+--------+    +--------+            ",
    "     |             |                ",
    "     |   Request   |                ",
    "     |------------->                ",
    "     |             |                ",
    "     |             +---+            ",
    "     |             |   | Process    ",
    "     |             <---+            ",
    "     |             |                ",
    "     |             +---+            ",
    "     |             |   | Done       ",
    "     |             <---+            ",
    "     |             |                ",
    "     |  Response   |                ",
    "     <.............|                ",
    "     |             |                ",
    "+--------+    +--------+            ",
    "| Client |    | Server |            ",
    "+--------+    +--------+            ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_activation_boxes_expected_unicode() -> String {
  [
    "┌────────┐    ┌────────┐            ",
    "│ Client │    │ Server │            ",
    "└────┬───┘    └────┬───┘            ",
    "     │             │                ",
    "     │   Request   │                ",
    "     │─────────────▶                ",
    "     │             │                ",
    "     │             ├───┐            ",
    "     │             │   │ Process    ",
    "     │             ◀───┘            ",
    "     │             │                ",
    "     │             ├───┐            ",
    "     │             │   │ Done       ",
    "     │             ◀───┘            ",
    "     │             │                ",
    "     │  Response   │                ",
    "     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌│                ",
    "     │             │                ",
    "┌────┴───┐    ┌────┴───┐            ",
    "│ Client │    │ Server │            ",
    "└────────┘    └────────┘            ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_all_relationship_types_source() -> String {
  "classDiagram\n  A <|-- B : inheritance\n  C *-- D : composition\n  E o-- F : aggregation\n  G --> H : association\n  I ..> J : dependency\n  K ..|> L : realization"
}

///|
fn class_all_relationship_types_expected_ascii() -> String {
  [
    "+---+    +---+    +---+    +---+    +---+    +---+",
    "| A |    | C |    | E |    | G |    | I |    | L |",
    "+---+    +---+    +---+    +---+    +---+    +---+",
    "  ^        *        o        |        :        ^",
    "erita composit aggregat associat dependen realization",
    "  |        |        |        v        v        :",
    "+---+    +---+    +---+    +---+    +---+    +---+",
    "| B |    | D |    | F |    | H |    | J |    | K |",
    "+---+    +---+    +---+    +---+    +---+    +---+",
  ]
  .iter()
  .join("\n")
}

///|
fn class_all_relationship_types_expected_unicode() -> String {
  [
    "┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐",
    "│ A │    │ C │    │ E │    │ G │    │ I │    │ L │",
    "└───┘    └───┘    └───┘    └───┘    └───┘    └───┘",
    "  △        ◆        ◇        │        ┊        △",
    "erita composit aggregat associat dependen realization",
    "  │        │        │        ▼        ▼        ┊",
    "┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐",
    "│ B │    │ D │    │ F │    │ H │    │ J │    │ K │",
    "└───┘    └───┘    └───┘    └───┘    └───┘    └───┘",
  ]
  .iter()
  .join("\n")
}

///|
fn er_ecommerce_schema_source() -> String {
  "erDiagram\n  CUSTOMER {\n    int id PK\n    string name\n    string email UK\n  }\n  ORDER {\n    int id PK\n    date created\n    int customer_id FK\n  }\n  PRODUCT {\n    int id PK\n    string name\n    float price\n  }\n  LINE_ITEM {\n    int id PK\n    int order_id FK\n    int product_id FK\n    int quantity\n  }\n  CUSTOMER ||--o{ ORDER : places\n  ORDER ||--|{ LINE_ITEM : contains\n  PRODUCT ||--o{ LINE_ITEM : includes"
}

///|
fn er_ecommerce_schema_expected_ascii() -> String {
  [
    "+-----------------+      +--------------------+",
    "| CUSTOMER        |      | ORDER              |",
    "+-----------------+places+--------------------+",
    "| PK int id       |||--o{| PK int id          |",
    "|    string name  |      |    date created    |",
    "| UK string email |      | FK int customer_id |",
    "+-----------------+      +--------------------+",
    "                                   ||",
    "                                  --- contains",
    "                                  | |",
    "                                 }| |",
    "+----------------+      +-------------------+",
    "| PRODUCT        |      | LINE_ITEM         |",
    "+----------------+includ+-------------------+",
    "| PK int id      |||--o{| PK int id         |",
    "|    string name |      | FK int order_id   |",
    "|    float price |      | FK int product_id |",
    "+----------------+      |    int quantity   |",
    "                        +-------------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn er_ecommerce_schema_expected_unicode() -> String {
  [
    "┌─────────────────┐      ┌────────────────────┐",
    "│ CUSTOMER        │      │ ORDER              │",
    "├─────────────────┤places├────────────────────┤",
    "│ PK int id       │║───o╟│ PK int id          │",
    "│    string name  │      │    date created    │",
    "│ UK string email │      │ FK int customer_id │",
    "└─────────────────┘      └────────────────────┘",
    "                                    ║",
    "                                  ─── contains",
    "                                  │ │",
    "                                  ╟ │",
    "┌────────────────┐      ┌───────────────────┐",
    "│ PRODUCT        │      │ LINE_ITEM         │",
    "├────────────────┤includ├───────────────────┤",
    "│ PK int id      │║───o╟│ PK int id         │",
    "│    string name │      │ FK int order_id   │",
    "│    float price │      │ FK int product_id │",
    "└────────────────┘      │    int quantity   │",
    "                        └───────────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn ci_cd_pipeline_source() -> String {
  "graph TD\n  subgraph ci [CI Pipeline]\n    A[Push Code] --> B{Tests Pass?}\n    B -->|Yes| C[Build Image]\n    B -->|No| D[Fix & Retry]\n    D -.-> A\n  end\n  C --> E([Deploy Staging])\n  E --> F{QA Approved?}\n  F -->|Yes| G((Production))\n  F -->|No| D"
}

///|
fn ci_cd_pipeline_expected_ascii() -> String {
  [
    "+----------------------------------------+",
    "|              CI Pipeline               |",
    "|                                        |",
    "|                                        |",
    "| +----------------+                     |",
    "| |                |                     |",
    "| |   Push Code    |<-----------+        |",
    "| |                |            |        |",
    "| +----------------+            |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          v                    |        |",
    "| +----------------+            |        |",
    "| |                |            |        |",
    "| |  Tests Pass?   |----No------+        |",
    "| |                |            |        |",
    "| +----------------+            |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|         Yes                   |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          |                    |        |",
    "|          v                    v        |",
    "| +----------------+     +-------------+ |",
    "| |                |     |             | |",
    "| |  Build Image   |     | Fix & Retry | |",
    "| |                |     |             | |",
    "| +----------------+     +-------------+ |",
    "|          |                    ^        |",
    "+----------|--------------------|--------+",
    "           |                    |",
    "           |                    |",
    "           v                    |",
    "  +----------------+            |",
    "  |                |            |",
    "  | Deploy Staging |            |",
    "  |                |            |",
    "  +----------------+            |",
    "           |                    |",
    "           |                    |",
    "           |                    |",
    "           |                    |",
    "           v                    |",
    "  +----------------+            |",
    "  |                |            |",
    "  |  QA Approved?  |----No------+",
    "  |                |",
    "  +----------------+",
    "           |",
    "           |",
    "          Yes",
    "           |",
    "           v",
    "  +----------------+",
    "  |                |",
    "  |   Production   |",
    "  |                |",
    "  +----------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn ci_cd_pipeline_expected_unicode() -> String {
  [
    "┌────────────────────────────────────────┐",
    "│              CI Pipeline               │",
    "│                                        │",
    "│                                        │",
    "│ ┌────────────────┐                     │",
    "│ │                │                     │",
    "│ │   Push Code    │◄───────────┐        │",
    "│ │                │            │        │",
    "│ └────────┬───────┘            │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          ▼                    │        │",
    "│ ┌────────────────┐            │        │",
    "│ │                │            │        │",
    "│ │  Tests Pass?   ├────No──────┤        │",
    "│ │                │            │        │",
    "│ └────────┬───────┘            │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│         Yes                   │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          │                    │        │",
    "│          ▼                    ▼        │",
    "│ ┌────────────────┐     ┌──────┴──────┐ │",
    "│ │                │     │             │ │",
    "│ │  Build Image   │     │ Fix & Retry │ │",
    "│ │                │     │             │ │",
    "│ └────────┬───────┘     └─────────────┘ │",
    "│          │                    ▲        │",
    "└──────────┼────────────────────┼────────┘",
    "           │                    │",
    "           │                    │",
    "           ▼                    │",
    "  ┌────────────────┐            │",
    "  │                │            │",
    "  │ Deploy Staging │            │",
    "  │                │            │",
    "  └────────┬───────┘            │",
    "           │                    │",
    "           │                    │",
    "           │                    │",
    "           │                    │",
    "           ▼                    │",
    "  ┌────────────────┐            │",
    "  │                │            │",
    "  │  QA Approved?  ├────No──────┘",
    "  │                │",
    "  └────────┬───────┘",
    "           │",
    "           │",
    "          Yes",
    "           │",
    "           ▼",
    "  ┌────────────────┐",
    "  │                │",
    "  │   Production   │",
    "  │                │",
    "  └────────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn decision_tree_source() -> String {
  "graph TD\n  A{Is it raining?} -->|Yes| B{Have umbrella?}\n  A -->|No| C([Go outside])\n  B -->|Yes| D([Go with umbrella])\n  B -->|No| E{Is it heavy?}\n  E -->|Yes| F([Stay inside])\n  E -->|No| G([Run for it])"
}

///|
fn decision_tree_expected_ascii() -> String {
  [
    "+------------------+",
    "|                  |",
    "|  Is it raining?  |  -----No-------+",
    "|                  |                |",
    "+------------------+                |",
    "          |                         |",
    "          |                         |",
    "         Yes                        |",
    "          |                         |",
    "          v                         v",
    "+------------------+        +--------------+",
    "|                  |        |              |",
    "|  Have umbrella?  |  No-+  |  Go outside  |",
    "|                  |     |  |              |",
    "+------------------+     |  +--------------+",
    "          |              |",
    "          |              |",
    "         Yes             +----------+",
    "          |                         |",
    "          v                         v",
    "+------------------+        +--------------+",
    "|                  |        |              |",
    "| Go with umbrella |     Yes| Is it heavy? |",
    "|                  |     |  |              |",
    "+------------------+     |  +--------------+",
    "                         |          |",
    "                         |          |",
    "          +--------------+         No",
    "          |                         |",
    "          v                         v",
    "+------------------+        +--------------+",
    "|                  |        |              |",
    "|   Stay inside    |        |  Run for it  |",
    "|                  |        |              |",
    "+------------------+        +--------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn decision_tree_expected_unicode() -> String {
  [
    "┌──────────────────┐",
    "│                  │",
    "│  Is it raining?  │ ├─────No───────┐",
    "│                  │                │",
    "└─────────┬────────┘                │",
    "          │                         │",
    "          │                         │",
    "         Yes                        │",
    "          │                         │",
    "          ▼                         ▼",
    "┌──────────────────┐        ┌──────────────┐",
    "│                  │        │              │",
    "│  Have umbrella?  │ ├No─┐  │  Go outside  │",
    "│                  │     │  │              │",
    "└─────────┬────────┘     │  └──────────────┘",
    "          │              │",
    "          │              │",
    "         Yes             └──────────┐",
    "          │                         │",
    "          ▼                         ▼",
    "┌──────────────────┐        ┌──────────────┐",
    "│                  │        │              │",
    "│ Go with umbrella │     Yes┤ Is it heavy? │",
    "│                  │     │  │              │",
    "└──────────────────┘     │  └───────┬──────┘",
    "                         │          │",
    "                         │          │",
    "          ┌──────────────┘         No",
    "          │                         │",
    "          ▼                         ▼",
    "┌──────────────────┐        ┌──────────────┐",
    "│                  │        │              │",
    "│   Stay inside    │        │  Run for it  │",
    "│                  │        │              │",
    "└──────────────────┘        └──────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_left_right_source() -> String {
  "graph LR\n  A[Input] --> B[Transform] --> C[Output]"
}

///|
fn direction_left_right_expected_ascii() -> String {
  [
    "+-------+     +-----------+     +--------+",
    "|       |     |           |     |        |",
    "| Input |---->| Transform |---->| Output |",
    "|       |     |           |     |        |",
    "+-------+     +-----------+     +--------+",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_left_right_expected_unicode() -> String {
  [
    "┌───────┐     ┌───────────┐     ┌────────┐",
    "│       │     │           │     │        │",
    "│ Input ├────►│ Transform ├────►│ Output │",
    "│       │     │           │     │        │",
    "└───────┘     └───────────┘     └────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_bottom_top_source() -> String {
  "graph BT\n  A[Foundation] --> B[Layer 2] --> C[Top]"
}

///|
fn direction_bottom_top_expected_ascii() -> String {
  [
    "+------------+",
    "|            |",
    "|    Top     |",
    "|            |",
    "+------------+",
    "       ^",
    "       |",
    "       |",
    "       |",
    "       |",
    "+------------+",
    "|            |",
    "|  Layer 2   |",
    "|            |",
    "+------------+",
    "       ^",
    "       |",
    "       |",
    "       |",
    "       |",
    "+------------+",
    "|            |",
    "| Foundation |",
    "|            |",
    "+------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_bottom_top_expected_unicode() -> String {
  [
    "┌────────────┐",
    "│            │",
    "│    Top     │",
    "│            │",
    "└────────────┘",
    "       ▲",
    "       │",
    "       │",
    "       │",
    "       │",
    "┌──────┴─────┐",
    "│            │",
    "│  Layer 2   │",
    "│            │",
    "└────────────┘",
    "       ▲",
    "       │",
    "       │",
    "       │",
    "       │",
    "┌──────┴─────┐",
    "│            │",
    "│ Foundation │",
    "│            │",
    "└────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn system_architecture_source() -> String {
  "graph LR\n  subgraph clients [Client Layer]\n    A([Web App]) --> B[API Gateway]\n    C([Mobile App]) --> B\n  end\n  subgraph services [Service Layer]\n    B --> D[Auth Service]\n    B --> E[User Service]\n    B --> F[Order Service]\n  end\n  subgraph data [Data Layer]\n    D --> G[(Auth DB)]\n    E --> H[(User DB)]\n    F --> I[(Order DB)]\n    F --> J([Message Queue])\n  end"
}

///|
fn system_architecture_expected_ascii() -> String {
  [
    "+------------------------------------+ +-------------------+ +-------------------+",
    "|           Client Layer             | |   Service Layer   | |    Data Layer     |",
    "|                                    | |                   | |                   |",
    "|                                    | |                   | |                   |",
    "| +------------+     +-------------+ | | +---------------+ | | +---------------+ |",
    "| |            |     |             | | | |               | | | |               | |",
    "| |  Web App   |---->| API Gateway |---->|  Auth Service |---->|    Auth DB    | |",
    "| |            |     |             | | | |               | | | |               | |",
    "| +------------+     +-------------+ | | +---------------+ | | +---------------+ |",
    "|                           ^        | |                   | |                   |",
    "|                           |        | |                   | |                   |",
    "|                           |        | |                   | |                   |",
    "|                           |        | |                   | |                   |",
    "|                           |        | |                   | |                   |",
    "| +------------+            |        | | +---------------+ | | +---------------+ |",
    "| |            |            |        | | |               | | | |               | |",
    "| | Mobile App |------------+----------->|  User Service |---->|    User DB    | |",
    "| |            |            |        | | |               | | | |               | |",
    "| +------------+            |        | | +---------------+ | | +---------------+ |",
    "|                           |        | |                   | |                   |",
    "+---------------------------|--------+ |                   | |                   |",
    "                            |          |                   | |                   |",
    "                            |          |                   | |                   |",
    "                            |          |                   | |                   |",
    "                            |          | +---------------+ | | +---------------+ |",
    "                            |          | |               | | | |               | |",
    "                            +----------->| Order Service |---->|    Order DB   | |",
    "                                       | |               | | | |               | |",
    "                                       | +---------------+ | | +---------------+ |",
    "                                       |         |         | |                   |",
    "                                       +---------|---------+ |                   |",
    "                                                 |           |                   |",
    "                                                 |           |                   |",
    "                                                 |           |                   |",
    "                                                 |           | +---------------+ |",
    "                                                 |           | |               | |",
    "                                                 +------------>| Message Queue | |",
    "                                                             | |               | |",
    "                                                             | +---------------+ |",
    "                                                             |                   |",
    "                                                             +-------------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn system_architecture_expected_unicode() -> String {
  [
    "┌────────────────────────────────────┐ ┌───────────────────┐ ┌───────────────────┐",
    "│           Client Layer             │ │   Service Layer   │ │    Data Layer     │",
    "│                                    │ │                   │ │                   │",
    "│                                    │ │                   │ │                   │",
    "│ ┌────────────┐     ┌─────────────┐ │ │ ┌───────────────┐ │ │ ┌───────────────┐ │",
    "│ │            │     │             │ │ │ │               │ │ │ │               │ │",
    "│ │  Web App   ├────►│ API Gateway ├─┼─┼►│  Auth Service ├─┼─┼►│    Auth DB    │ │",
    "│ │            │     │             │ │ │ │               │ │ │ │               │ │",
    "│ └────────────┘     └──────┬──────┘ │ │ └───────────────┘ │ │ └───────────────┘ │",
    "│                           ▲        │ │                   │ │                   │",
    "│                           │        │ │                   │ │                   │",
    "│                           │        │ │                   │ │                   │",
    "│                           │        │ │                   │ │                   │",
    "│                           │        │ │                   │ │                   │",
    "│ ┌────────────┐            │        │ │ ┌───────────────┐ │ │ ┌───────────────┐ │",
    "│ │            │            │        │ │ │               │ │ │ │               │ │",
    "│ │ Mobile App ├────────────┼────────┼─┼►│  User Service ├─┼─┼►│    User DB    │ │",
    "│ │            │            │        │ │ │               │ │ │ │               │ │",
    "│ └────────────┘            │        │ │ └───────────────┘ │ │ └───────────────┘ │",
    "│                           │        │ │                   │ │                   │",
    "└───────────────────────────┼────────┘ │                   │ │                   │",
    "                            │          │                   │ │                   │",
    "                            │          │                   │ │                   │",
    "                            │          │                   │ │                   │",
    "                            │          │ ┌───────────────┐ │ │ ┌───────────────┐ │",
    "                            │          │ │               │ │ │ │               │ │",
    "                            └──────────┼►│ Order Service ├─┼─┼►│    Order DB   │ │",
    "                                       │ │               │ │ │ │               │ │",
    "                                       │ └───────┬───────┘ │ │ └───────────────┘ │",
    "                                       │         │         │ │                   │",
    "                                       └─────────┼─────────┘ │                   │",
    "                                                 │           │                   │",
    "                                                 │           │                   │",
    "                                                 │           │                   │",
    "                                                 │           │ ┌───────────────┐ │",
    "                                                 │           │ │               │ │",
    "                                                 └───────────┼►│ Message Queue │ │",
    "                                                             │ │               │ │",
    "                                                             │ └───────────────┘ │",
    "                                                             │                   │",
    "                                                             └───────────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn subgraphs_source() -> String {
  "graph TD\n  subgraph Frontend\n    A[React App] --> B[State Manager]\n  end\n  subgraph Backend\n    C[API Server] --> D[Database]\n  end\n  B --> C"
}

///|
fn subgraphs_expected_ascii() -> String {
  [
    "+-------------------+",
    "|     Frontend      |",
    "|                   |",
    "|                   |",
    "| +---------------+ |",
    "| |               | |",
    "| |   React App   | |",
    "| |               | |",
    "| +---------------+ |",
    "|         |         |",
    "|         |         |",
    "|         |         |",
    "|         |         |",
    "|         v         |",
    "| +---------------+ |",
    "| |               | |",
    "| | State Manager | |",
    "| |               | |",
    "| +---------------+ |",
    "|         |         |",
    "+---------|---------+",
    "          |",
    "          |",
    "          |",
    "+---------|---------+",
    "|      Backend      |",
    "|         |         |",
    "|         v         |",
    "| +---------------+ |",
    "| |               | |",
    "| |   API Server  | |",
    "| |               | |",
    "| +---------------+ |",
    "|         |         |",
    "|         |         |",
    "|         |         |",
    "|         |         |",
    "|         v         |",
    "| +---------------+ |",
    "| |               | |",
    "| |    Database   | |",
    "| |               | |",
    "| +---------------+ |",
    "|                   |",
    "+-------------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn subgraphs_expected_unicode() -> String {
  [
    "┌───────────────────┐",
    "│     Frontend      │",
    "│                   │",
    "│                   │",
    "│ ┌───────────────┐ │",
    "│ │               │ │",
    "│ │   React App   │ │",
    "│ │               │ │",
    "│ └───────┬───────┘ │",
    "│         │         │",
    "│         │         │",
    "│         │         │",
    "│         │         │",
    "│         ▼         │",
    "│ ┌───────────────┐ │",
    "│ │               │ │",
    "│ │ State Manager │ │",
    "│ │               │ │",
    "│ └───────┬───────┘ │",
    "│         │         │",
    "└─────────┼─────────┘",
    "          │",
    "          │",
    "          │",
    "┌─────────┼─────────┐",
    "│      Backend      │",
    "│         │         │",
    "│         ▼         │",
    "│ ┌───────────────┐ │",
    "│ │               │ │",
    "│ │   API Server  │ │",
    "│ │               │ │",
    "│ └───────┬───────┘ │",
    "│         │         │",
    "│         │         │",
    "│         │         │",
    "│         │         │",
    "│         ▼         │",
    "│ ┌───────────────┐ │",
    "│ │               │ │",
    "│ │    Database   │ │",
    "│ │               │ │",
    "│ └───────────────┘ │",
    "│                   │",
    "└───────────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn nested_subgraphs_source() -> String {
  "graph TD\n  subgraph Cloud\n    subgraph us-east [US East Region]\n      A[Web Server] --> B[App Server]\n    end\n    subgraph us-west [US West Region]\n      C[Web Server] --> D[App Server]\n    end\n  end\n  E[Load Balancer] --> A\n  E --> C"
}

///|
fn nested_subgraphs_expected_ascii() -> String {
  [
    "+---------------------------------------+",
    "|                 Cloud                 |",
    "|                                       |",
    "|                                       |",
    "| +----------------+ +----------------+ |",
    "| |US East Region  | |US West Region  | |",
    "| |                | |                | |",
    "| |                | |                | |",
    "| | +------------+ | | +------------+ | | +---------------+",
    "| | |            | | | |            | | | |               |",
    "| | | Web Server |<-+| | Web Server |<-+--| Load Balancer |",
    "| | |            | ||| |            | ||| |               |",
    "| | +------------+ ||| +------------+ ||| +---------------+",
    "| |        |       |||        |       |||",
    "| |        |       |||        |       |||",
    "| |        |       |+------------------+|",
    "| |        |       | |        |       | |",
    "| |        v       | |        v       | |",
    "| | +------------+ | | +------------+ | |",
    "| | |            | | | |            | | |",
    "| | | App Server | | | | App Server | | |",
    "| | |            | | | |            | | |",
    "| | +------------+ | | +------------+ | |",
    "| |                | |                | |",
    "| +----------------+ +----------------+ |",
    "|                                       |",
    "+---------------------------------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn nested_subgraphs_expected_unicode() -> String {
  [
    "┌───────────────────────────────────────┐",
    "│                 Cloud                 │",
    "│                                       │",
    "│                                       │",
    "│ ┌────────────────┐ ┌────────────────┐ │",
    "│ │US East Region  │ │US West Region  │ │",
    "│ │                │ │                │ │",
    "│ │                │ │                │ │",
    "│ │ ┌────────────┐ │ │ ┌────────────┐ │ │ ┌───────────────┐",
    "│ │ │            │ │ │ │            │ │ │ │               │",
    "│ │ │ Web Server │◄┼┐│ │ Web Server │◄┼┬┼─┤ Load Balancer │",
    "│ │ │            │ │││ │            │ │││ │               │",
    "│ │ └──────┬─────┘ │││ └──────┬─────┘ │││ └───────────────┘",
    "│ │        │       │││        │       │││",
    "│ │        │       │││        │       │││",
    "│ │        │       │└┼────────┼───────┼┘│",
    "│ │        │       │ │        │       │ │",
    "│ │        ▼       │ │        ▼       │ │",
    "│ │ ┌────────────┐ │ │ ┌────────────┐ │ │",
    "│ │ │            │ │ │ │            │ │ │",
    "│ │ │ App Server │ │ │ │ App Server │ │ │",
    "│ │ │            │ │ │ │            │ │ │",
    "│ │ └────────────┘ │ │ └────────────┘ │ │",
    "│ │                │ │                │ │",
    "│ └────────────────┘ └────────────────┘ │",
    "│                                       │",
    "└───────────────────────────────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn simple_flow_source() -> String {
  "graph TD\n  A[Start] --> B[Process] --> C[End]"
}

///|
fn simple_flow_expected_ascii() -> String {
  [
    "+---------+",
    "|         |",
    "|  Start  |",
    "|         |",
    "+---------+",
    "     |",
    "     |",
    "     |",
    "     |",
    "     v",
    "+---------+",
    "|         |",
    "| Process |",
    "|         |",
    "+---------+",
    "     |",
    "     |",
    "     |",
    "     |",
    "     v",
    "+---------+",
    "|         |",
    "|   End   |",
    "|         |",
    "+---------+",
  ]
  .iter()
  .join("\n")
}

///|
fn simple_flow_expected_unicode() -> String {
  [
    "┌─────────┐",
    "│         │",
    "│  Start  │",
    "│         │",
    "└────┬────┘",
    "     │",
    "     │",
    "     │",
    "     │",
    "     ▼",
    "┌─────────┐",
    "│         │",
    "│ Process │",
    "│         │",
    "└────┬────┘",
    "     │",
    "     │",
    "     │",
    "     │",
    "     ▼",
    "┌─────────┐",
    "│         │",
    "│   End   │",
    "│         │",
    "└─────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn original_node_shapes_source() -> String {
  "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))"
}

///|
fn original_node_shapes_expected_ascii() -> String {
  [
    "+-----------+     +---------+     +---------+     +---------+     +--------+",
    "|           |     |         |     |         |     |         |     |        |",
    "| Rectangle |---->| Rounded |---->| Diamond |---->| Stadium |---->| Circle |",
    "|           |     |         |     |         |     |         |     |        |",
    "+-----------+     +---------+     +---------+     +---------+     +--------+",
  ]
  .iter()
  .join("\n")
}

///|
fn original_node_shapes_expected_unicode() -> String {
  [
    "┌───────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌────────┐",
    "│           │     │         │     │         │     │         │     │        │",
    "│ Rectangle ├────►│ Rounded ├────►│ Diamond ├────►│ Stadium ├────►│ Circle │",
    "│           │     │         │     │         │     │         │     │        │",
    "└───────────┘     └─────────┘     └─────────┘     └─────────┘     └────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn batch_1_shapes_source() -> String {
  "graph LR\n  A[[Subroutine]] --> B(((Double Circle)))\n  B --> C{{Hexagon}}"
}

///|
fn batch_1_shapes_expected_ascii() -> String {
  [
    "+------------+     +---------------+     +---------+",
    "|            |     |               |     |         |",
    "| Subroutine |---->| Double Circle |---->| Hexagon |",
    "|            |     |               |     |         |",
    "+------------+     +---------------+     +---------+",
  ]
  .iter()
  .join("\n")
}

///|
fn batch_1_shapes_expected_unicode() -> String {
  [
    "┌────────────┐     ┌───────────────┐     ┌─────────┐",
    "│            │     │               │     │         │",
    "│ Subroutine ├────►│ Double Circle ├────►│ Hexagon │",
    "│            │     │               │     │         │",
    "└────────────┘     └───────────────┘     └─────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn batch_2_shapes_source() -> String {
  "graph LR\n  A[(Database)] --> B>Flag Shape]\n  B --> C[/Wider Bottom\\]\n  C --> D[\\Wider Top/]"
}

///|
fn batch_2_shapes_expected_ascii() -> String {
  [
    "+----------+     +------------+     +--------------+     +-----------+",
    "|          |     |            |     |              |     |           |",
    "| Database |---->| Flag Shape |---->| Wider Bottom |---->| Wider Top |",
    "|          |     |            |     |              |     |           |",
    "+----------+     +------------+     +--------------+     +-----------+",
  ]
  .iter()
  .join("\n")
}

///|
fn batch_2_shapes_expected_unicode() -> String {
  [
    "┌──────────┐     ┌────────────┐     ┌──────────────┐     ┌───────────┐",
    "│          │     │            │     │              │     │           │",
    "│ Database ├────►│ Flag Shape ├────►│ Wider Bottom ├────►│ Wider Top │",
    "│          │     │            │     │              │     │           │",
    "└──────────┘     └────────────┘     └──────────────┘     └───────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn all_edge_styles_source() -> String {
  "graph TD\n  A[Source] -->|solid| B[Target 1]\n  A -.->|dotted| C[Target 2]\n  A ==>|thick| D[Target 3]"
}

///|
fn all_edge_styles_expected_ascii() -> String {
  [
    "+----------+",
    "|          |",
    "|  Source  |-thickted-----+",
    "|          |        |     |",
    "+----------+        +----------------------+",
    "      |                   |                |",
    "      |                   |                |",
    "    solid                 |                |",
    "      |                   |                |",
    "      v                   v                v",
    "+----------+        +----------+     +----------+",
    "|          |        |          |     |          |",
    "| Target 1 |        | Target 2 |     | Target 3 |",
    "|          |        |          |     |          |",
    "+----------+        +----------+     +----------+",
  ]
  .iter()
  .join("\n")
}

///|
fn all_edge_styles_expected_unicode() -> String {
  [
    "┌──────────┐",
    "│          │",
    "│  Source  ├─thickted─────┐",
    "│          │        │     │",
    "└─────┬────┘        └─────┼────────────────┐",
    "      │                   │                │",
    "      │                   │                │",
    "    solid                 │                │",
    "      │                   │                │",
    "      ▼                   ▼                ▼",
    "┌──────────┐        ┌──────────┐     ┌──────────┐",
    "│          │        │          │     │          │",
    "│ Target 1 │        │ Target 2 │     │ Target 3 │",
    "│          │        │          │     │          │",
    "└──────────┘        └──────────┘     └──────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn no_arrow_edges_source() -> String {
  "graph TD\n  A[Node 1] ---|related| B[Node 2]\n  B -.- C[Node 3]\n  C === D[Node 4]"
}

///|
fn no_arrow_edges_expected_ascii() -> String {
  [
    "+---------+",
    "|         |",
    "|  Node 1 |",
    "|         |",
    "+---------+",
    "     |",
    "     |",
    "  related",
    "     |",
    "     v",
    "+---------+",
    "|         |",
    "|  Node 2 |",
    "|         |",
    "+---------+",
    "     |",
    "     |",
    "     |",
    "     |",
    "     v",
    "+---------+",
    "|         |",
    "|  Node 3 |",
    "|         |",
    "+---------+",
    "     |",
    "     |",
    "     |",
    "     |",
    "     v",
    "+---------+",
    "|         |",
    "|  Node 4 |",
    "|         |",
    "+---------+",
  ]
  .iter()
  .join("\n")
}

///|
fn no_arrow_edges_expected_unicode() -> String {
  [
    "┌─────────┐",
    "│         │",
    "│  Node 1 │",
    "│         │",
    "└────┬────┘",
    "     │",
    "     │",
    "  related",
    "     │",
    "     ▼",
    "┌─────────┐",
    "│         │",
    "│  Node 2 │",
    "│         │",
    "└────┬────┘",
    "     │",
    "     │",
    "     │",
    "     │",
    "     ▼",
    "┌─────────┐",
    "│         │",
    "│  Node 3 │",
    "│         │",
    "└────┬────┘",
    "     │",
    "     │",
    "     │",
    "     │",
    "     ▼",
    "┌─────────┐",
    "│         │",
    "│  Node 4 │",
    "│         │",
    "└─────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn bidirectional_arrows_source() -> String {
  "graph LR\n  A[Client] <-->|sync| B[Server]\n  B <-.->|heartbeat| C[Monitor]\n  C <==>|data| D[Storage]"
}

///|
fn bidirectional_arrows_expected_ascii() -> String {
  [
    "+--------+      +--------+           +---------+      +---------+",
    "|        |      |        |           |         |      |         |",
    "| Client |sync->| Server |-heartbeat>| Monitor |data->| Storage |",
    "|        |      |        |           |         |      |         |",
    "+--------+      +--------+           +---------+      +---------+",
  ]
  .iter()
  .join("\n")
}

///|
fn bidirectional_arrows_expected_unicode() -> String {
  [
    "┌────────┐      ┌────────┐           ┌─────────┐      ┌─────────┐",
    "│        │      │        │           │         │      │         │",
    "│ Client ├sync─►│ Server ├─heartbeat►│ Monitor ├data─►│ Storage │",
    "│        │      │        │           │         │      │         │",
    "└────────┘      └────────┘           └─────────┘      └─────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn parallel_links_and_source() -> String {
  "graph TD\n  A[Input] & B[Config] --> C[Processor]\n  C --> D[Output] & E[Log]"
}

///|
fn parallel_links_and_expected_ascii() -> String {
  [
    "+-----------+     +--------+",
    "|           |     |        |",
    "|   Input   |     | Config |",
    "|           |     |        |",
    "+-----------+     +--------+",
    "      |                |    ",
    "      |                |    ",
    "      |                |    ",
    "      |                |    ",
    "      v                |    ",
    "+-----------+          |    ",
    "|           |          |    ",
    "| Processor |<---------+    ",
    "|           |          |    ",
    "+-----------+          |    ",
    "      |                |    ",
    "      |                |    ",
    "      |                |    ",
    "      |                |    ",
    "      v                v    ",
    "+-----------+     +--------+",
    "|           |     |        |",
    "|   Output  |     |  Log   |",
    "|           |     |        |",
    "+-----------+     +--------+",
  ]
  .iter()
  .join("\n")
}

///|
fn parallel_links_and_expected_unicode() -> String {
  [
    "┌───────────┐     ┌────────┐",
    "│           │     │        │",
    "│   Input   │     │ Config │",
    "│           │     │        │",
    "└─────┬─────┘     └────┬───┘",
    "      │                │    ",
    "      │                │    ",
    "      │                │    ",
    "      │                │    ",
    "      ▼                │    ",
    "┌───────────┐          │    ",
    "│           │          │    ",
    "│ Processor ├◄─────────┤    ",
    "│           │          │    ",
    "└─────┬─────┘          │    ",
    "      │                │    ",
    "      │                │    ",
    "      │                │    ",
    "      │                │    ",
    "      ▼                ▼    ",
    "┌───────────┐     ┌────────┐",
    "│           │     │        │",
    "│   Output  │     │  Log   │",
    "│           │     │        │",
    "└───────────┘     └────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn chained_edges_source() -> String {
  "graph LR\n  A[Step 1] --> B[Step 2] --> C[Step 3] --> D[Step 4] --> E[Step 5]"
}

///|
fn chained_edges_expected_ascii() -> String {
  [
    "+--------+     +--------+     +--------+     +--------+     +--------+",
    "|        |     |        |     |        |     |        |     |        |",
    "| Step 1 |---->| Step 2 |---->| Step 3 |---->| Step 4 |---->| Step 5 |",
    "|        |     |        |     |        |     |        |     |        |",
    "+--------+     +--------+     +--------+     +--------+     +--------+",
  ]
  .iter()
  .join("\n")
}

///|
fn chained_edges_expected_unicode() -> String {
  [
    "┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐",
    "│        │     │        │     │        │     │        │     │        │",
    "│ Step 1 ├────►│ Step 2 ├────►│ Step 3 ├────►│ Step 4 ├────►│ Step 5 │",
    "│        │     │        │     │        │     │        │     │        │",
    "└────────┘     └────────┘     └────────┘     └────────┘     └────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_left_right_lr_source() -> String {
  "graph LR\n  A[Input] --> B[Transform] --> C[Output]"
}

///|
fn direction_left_right_lr_expected_ascii() -> String {
  [
    "+-------+     +-----------+     +--------+",
    "|       |     |           |     |        |",
    "| Input |---->| Transform |---->| Output |",
    "|       |     |           |     |        |",
    "+-------+     +-----------+     +--------+",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_left_right_lr_expected_unicode() -> String {
  [
    "┌───────┐     ┌───────────┐     ┌────────┐",
    "│       │     │           │     │        │",
    "│ Input ├────►│ Transform ├────►│ Output │",
    "│       │     │           │     │        │",
    "└───────┘     └───────────┘     └────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_bottom_top_bt_source() -> String {
  "graph BT\n  A[Foundation] --> B[Layer 2] --> C[Top]"
}

///|
fn direction_bottom_top_bt_expected_ascii() -> String {
  [
    "+------------+",
    "|            |",
    "|    Top     |",
    "|            |",
    "+------------+",
    "       ^      ",
    "       |      ",
    "       |      ",
    "       |      ",
    "       |      ",
    "+------------+",
    "|            |",
    "|  Layer 2   |",
    "|            |",
    "+------------+",
    "       ^      ",
    "       |      ",
    "       |      ",
    "       |      ",
    "       |      ",
    "+------------+",
    "|            |",
    "| Foundation |",
    "|            |",
    "+------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn direction_bottom_top_bt_expected_unicode() -> String {
  [
    "┌────────────┐",
    "│            │",
    "│    Top     │",
    "│            │",
    "└────────────┘",
    "       ▲      ",
    "       │      ",
    "       │      ",
    "       │      ",
    "       │      ",
    "┌──────┴─────┐",
    "│            │",
    "│  Layer 2   │",
    "│            │",
    "└────────────┘",
    "       ▲      ",
    "       │      ",
    "       │      ",
    "       │      ",
    "       │      ",
    "┌──────┴─────┐",
    "│            │",
    "│ Foundation │",
    "│            │",
    "└────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn all_12_flowchart_shapes_source() -> String {
  "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))\n  E --> F[[Subroutine]]\n  F --> G(((Double Circle)))\n  G --> H{{Hexagon}}\n  H --> I[(Database)]\n  I --> J>Flag]\n  J --> K[/Trapezoid\\]\n  K --> L[\\Inverse Trap/]"
}

///|
fn all_12_flowchart_shapes_expected_ascii() -> String {
  [
    "+-----------+     +---------+     +---------+     +---------+     +--------+     +------------+     +---------------+     +---------+     +----------+     +------+     +-----------+     +--------------+",
    "|           |     |         |     |         |     |         |     |        |     |            |     |               |     |         |     |          |     |      |     |           |     |              |",
    "| Rectangle |---->| Rounded |---->| Diamond |---->| Stadium |---->| Circle |---->| Subroutine |---->| Double Circle |---->| Hexagon |---->| Database |---->| Flag |---->| Trapezoid |---->| Inverse Trap |",
    "|           |     |         |     |         |     |         |     |        |     |            |     |               |     |         |     |          |     |      |     |           |     |              |",
    "+-----------+     +---------+     +---------+     +---------+     +--------+     +------------+     +---------------+     +---------+     +----------+     +------+     +-----------+     +--------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn all_12_flowchart_shapes_expected_unicode() -> String {
  [
    "┌───────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐     ┌────────┐     ┌────────────┐     ┌───────────────┐     ┌─────────┐     ┌──────────┐     ┌──────┐     ┌───────────┐     ┌──────────────┐",
    "│           │     │         │     │         │     │         │     │        │     │            │     │               │     │         │     │          │     │      │     │           │     │              │",
    "│ Rectangle ├────►│ Rounded ├────►│ Diamond ├────►│ Stadium ├────►│ Circle ├────►│ Subroutine ├────►│ Double Circle ├────►│ Hexagon ├────►│ Database ├────►│ Flag ├────►│ Trapezoid ├────►│ Inverse Trap │",
    "│           │     │         │     │         │     │         │     │        │     │            │     │               │     │         │     │          │     │      │     │           │     │              │",
    "└───────────┘     └─────────┘     └─────────┘     └─────────┘     └────────┘     └────────────┘     └───────────────┘     └─────────┘     └──────────┘     └──────┘     └───────────┘     └──────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn class_shorthand_source() -> String {
  "graph TD\n  A[Normal]:::default --> B[Highlighted]:::highlight --> C[Error]:::error\n  classDef default fill:#f4f4f5,stroke:#a1a1aa\n  classDef highlight fill:#fbbf24,stroke:#d97706\n  classDef error fill:#ef4444,stroke:#dc2626"
}

///|
fn class_shorthand_expected_ascii() -> String {
  [
    "+-------------+",
    "|             |",
    "|    Normal   |",
    "|             |",
    "+-------------+",
    "       |       ",
    "       |       ",
    "       |       ",
    "       |       ",
    "       v       ",
    "+-------------+",
    "|             |",
    "| Highlighted |",
    "|             |",
    "+-------------+",
    "       |       ",
    "       |       ",
    "       |       ",
    "       |       ",
    "       v       ",
    "+-------------+",
    "|             |",
    "|    Error    |",
    "|             |",
    "+-------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn class_shorthand_expected_unicode() -> String {
  [
    "┌─────────────┐",
    "│             │",
    "│    Normal   │",
    "│             │",
    "└──────┬──────┘",
    "       │       ",
    "       │       ",
    "       │       ",
    "       │       ",
    "       ▼       ",
    "┌─────────────┐",
    "│             │",
    "│ Highlighted │",
    "│             │",
    "└──────┬──────┘",
    "       │       ",
    "       │       ",
    "       │       ",
    "       │       ",
    "       ▼       ",
    "┌─────────────┐",
    "│             │",
    "│    Error    │",
    "│             │",
    "└─────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn inline_style_overrides_source() -> String {
  "graph TD\n  A[Default] --> B[Custom Colors] --> C[Another Custom]\n  style B fill:#3b82f6,stroke:#1d4ed8,color:#ffffff\n  style C fill:#10b981,stroke:#059669"
}

///|
fn inline_style_overrides_expected_ascii() -> String {
  [
    "+----------------+",
    "|                |",
    "|    Default     |",
    "|                |",
    "+----------------+",
    "         |        ",
    "         |        ",
    "         |        ",
    "         |        ",
    "         v        ",
    "+----------------+",
    "|                |",
    "| Custom Colors  |",
    "|                |",
    "+----------------+",
    "         |        ",
    "         |        ",
    "         |        ",
    "         |        ",
    "         v        ",
    "+----------------+",
    "|                |",
    "| Another Custom |",
    "|                |",
    "+----------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn inline_style_overrides_expected_unicode() -> String {
  [
    "┌────────────────┐",
    "│                │",
    "│    Default     │",
    "│                │",
    "└────────┬───────┘",
    "         │        ",
    "         │        ",
    "         │        ",
    "         │        ",
    "         ▼        ",
    "┌────────────────┐",
    "│                │",
    "│ Custom Colors  │",
    "│                │",
    "└────────┬───────┘",
    "         │        ",
    "         │        ",
    "         │        ",
    "         │        ",
    "         ▼        ",
    "┌────────────────┐",
    "│                │",
    "│ Another Custom │",
    "│                │",
    "└────────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn basic_state_diagram_source() -> String {
  "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Active : start\n  Active --> Idle : cancel\n  Active --> Done : complete\n  Done --> [*]"
}

///|
fn basic_state_diagram_expected_ascii() -> String {
  [
    "+----------+",
    "|          |",
    "|          |",
    "|          |",
    "+----------+",
    "      |     ",
    "      |     ",
    "      |     ",
    "      |     ",
    "      v     ",
    "+----------+",
    "|          |",
    "|   Idle   |",
    "|          |",
    "+----------+",
    "      ^     ",
    "      |     ",
    "   cancel   ",
    "      |     ",
    "      v     ",
    "+----------+",
    "|          |",
    "|  Active  |",
    "|          |",
    "+----------+",
    "      |     ",
    "      |     ",
    "  complete  ",
    "      |     ",
    "      v     ",
    "+----------+",
    "|          |",
    "|   Done   |",
    "|          |",
    "+----------+",
    "      |     ",
    "      |     ",
    "      |     ",
    "      |     ",
    "      v     ",
    "+----------+",
    "|          |",
    "|          |",
    "|          |",
    "+----------+",
  ]
  .iter()
  .join("\n")
}

///|
fn basic_state_diagram_expected_unicode() -> String {
  [
    "┌──────────┐",
    "│          │",
    "│          │",
    "│          │",
    "└─────┬────┘",
    "      │     ",
    "      │     ",
    "      │     ",
    "      │     ",
    "      ▼     ",
    "┌──────────┐",
    "│          │",
    "│   Idle   │",
    "│          │",
    "└─────┬────┘",
    "      ▲     ",
    "      │     ",
    "   cancel   ",
    "      │     ",
    "      ▼     ",
    "┌─────┴────┐",
    "│          │",
    "│  Active  │",
    "│          │",
    "└─────┬────┘",
    "      │     ",
    "      │     ",
    "  complete  ",
    "      │     ",
    "      ▼     ",
    "┌──────────┐",
    "│          │",
    "│   Done   │",
    "│          │",
    "└─────┬────┘",
    "      │     ",
    "      │     ",
    "      │     ",
    "      │     ",
    "      ▼     ",
    "┌──────────┐",
    "│          │",
    "│          │",
    "│          │",
    "└──────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn state_composite_states_source() -> String {
  "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]"
}

///|
fn state_composite_states_expected_ascii() -> String {
  [
    "                      +--------------+",
    "                      | Processing   |",
    "                      |              |",
    "                      |              |",
    "+------------+        | +----------+ |",
    "|            |        | |          | |",
    "|            |        | |  parse   | |",
    "|            |        | |          | |",
    "+------------+        | +----------+ |",
    "       |              |       |      |",
    "       |              |       |      |",
    "       |              |       |      |",
    "       |              |       |      |",
    "       v              |       v      |",
    "+------------+        | +----------+ |",
    "|            |        | |          | |",
    "|    Idle    |   <---+| | validate | |",
    "|            |       || |          | |",
    "+------------+       || +----------+ |",
    "       |             ||       |      |",
    "       |             ||       |      |",
    "    submit           ||       |      |",
    "       |             ||       |      |",
    "       v             ||       v      |",
    "+------------+       || +----------+ |",
    "|            |       || |          | |",
    "| Processing |  fail-+| | execute  | |",
    "|            |       || |          | |",
    "+------------+       || +----------+ |",
    "       |             ||              |",
    "       |             |+--------------+",
    "     done            +--------+       ",
    "       |                    retry     ",
    "       v                      v       ",
    "+------------+          +----------+  ",
    "|            |          |          |  ",
    "|  Complete  |          |  Error   |  ",
    "|            |          |          |  ",
    "+------------+          +----------+  ",
    "       |                              ",
    "       |                              ",
    "       |                              ",
    "       |                              ",
    "       v                              ",
    "+------------+                        ",
    "|            |                        ",
    "|            |                        ",
    "|            |                        ",
    "+------------+                        ",
  ]
  .iter()
  .join("\n")
}

///|
fn state_composite_states_expected_unicode() -> String {
  [
    "                      ┌──────────────┐",
    "                      │ Processing   │",
    "                      │              │",
    "                      │              │",
    "┌────────────┐        │ ┌──────────┐ │",
    "│            │        │ │          │ │",
    "│            │        │ │  parse   │ │",
    "│            │        │ │          │ │",
    "└──────┬─────┘        │ └─────┬────┘ │",
    "       │              │       │      │",
    "       │              │       │      │",
    "       │              │       │      │",
    "       │              │       │      │",
    "       ▼              │       ▼      │",
    "┌────────────┐        │ ┌──────────┐ │",
    "│            │        │ │          │ │",
    "│    Idle    │   ◄───┐│ │ validate │ │",
    "│            │       ││ │          │ │",
    "└──────┬─────┘       ││ └─────┬────┘ │",
    "       │             ││       │      │",
    "       │             ││       │      │",
    "    submit           ││       │      │",
    "       │             ││       │      │",
    "       ▼             ││       ▼      │",
    "┌────────────┐       ││ ┌──────────┐ │",
    "│            │       ││ │          │ │",
    "│ Processing │  fail─┤│ │ execute  │ │",
    "│            │       ││ │          │ │",
    "└──────┬─────┘       ││ └──────────┘ │",
    "       │             ││              │",
    "       │             │└──────────────┘",
    "     done            └────────┐       ",
    "       │                    retry     ",
    "       ▼                      ▼       ",
    "┌────────────┐          ┌─────┴────┐  ",
    "│            │          │          │  ",
    "│  Complete  │          │  Error   │  ",
    "│            │          │          │  ",
    "└──────┬─────┘          └──────────┘  ",
    "       │                              ",
    "       │                              ",
    "       │                              ",
    "       │                              ",
    "       ▼                              ",
    "┌────────────┐                        ",
    "│            │                        ",
    "│            │                        ",
    "│            │                        ",
    "└────────────┘                        ",
  ]
  .iter()
  .join("\n")
}

///|
fn state_connection_lifecycle_sample_source() -> String {
  "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]"
}

///|
fn state_connection_lifecycle_sample_expected_ascii() -> String {
  [
    "+---------------+                            ",
    "|               |                            ",
    "|               |                            ",
    "|               |                            ",
    "+---------------+                            ",
    "        |                                    ",
    "        |                                    ",
    "        |                                    ",
    "        |                                    ",
    "        v                                    ",
    "+---------------+                            ",
    "|               |                            ",
    "|     Closed    |   <----+-----------+       ",
    "|               |        |           |       ",
    "+---------------+        |           |       ",
    "        ^                |           |       ",
    "        |                |           |       ",
    "     timeout             |           |       ",
    "        |                |           |       ",
    "        v                |           v       ",
    "+---------------+        |   +--------------+",
    "|               |        |   |              |",
    "|   Connecting  |        |   |              |",
    "|               |        |   |              |",
    "+---------------+        |   +--------------+",
    "        |                |                   ",
    "        |                |                   ",
    "     success             |                   ",
    "        |                |                   ",
    "        v                |                   ",
    "+---------------+        +---+               ",
    "|               |        |   |               ",
    "|   Connected   |   <----|error------+       ",
    "|               |        |   |       |       ",
    "+---------------+        |   |       |       ",
    "        |                |   |       |       ",
    "        |                |   |    success    ",
    "      close              |   +-------+       ",
    "        |                |      max_retries  ",
    "        v                |           v       ",
    "+---------------+        |   +--------------+",
    "|               |        |   |              |",
    "| Disconnecting |   done-+   | Reconnecting |",
    "|               |            |              |",
    "+---------------+            +--------------+",
  ]
  .iter()
  .join("\n")
}

///|
fn state_connection_lifecycle_sample_expected_unicode() -> String {
  [
    "┌───────────────┐                            ",
    "│               │                            ",
    "│               │                            ",
    "│               │                            ",
    "└───────┬───────┘                            ",
    "        │                                    ",
    "        │                                    ",
    "        │                                    ",
    "        │                                    ",
    "        ▼                                    ",
    "┌───────────────┐                            ",
    "│               │                            ",
    "│     Closed    │  ├◄────┬───────────┐       ",
    "│               │        │           │       ",
    "└───────┬───────┘        │           │       ",
    "        ▲                │           │       ",
    "        │                │           │       ",
    "     timeout             │           │       ",
    "        │                │           │       ",
    "        ▼                │           ▼       ",
    "┌───────┴───────┐        │   ┌──────────────┐",
    "│               │        │   │              │",
    "│   Connecting  │        │   │              │",
    "│               │        │   │              │",
    "└───────┬───────┘        │   └──────────────┘",
    "        │                │                   ",
    "        │                │                   ",
    "     success             │                   ",
    "        │                │                   ",
    "        ▼                │                   ",
    "┌───────────────┐        ├───┐               ",
    "│               │        │   │               ",
    "│   Connected   │  ├◄────┼error──────┐       ",
    "│               │        │   │       │       ",
    "└───────┬───────┘        │   │       │       ",
    "        │                │   │       │       ",
    "        │                │   │    success    ",
    "      close              │   └───────┤       ",
    "        │                │      max_retries  ",
    "        ▼                │           ▼       ",
    "┌───────────────┐        │   ┌───────┴──────┐",
    "│               │        │   │              │",
    "│ Disconnecting │  ├done─┘   │ Reconnecting │",
    "│               │            │              │",
    "└───────────────┘            └──────────────┘",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_basic_messages_source() -> String {
  "sequenceDiagram\n  Alice->>Bob: Hello Bob!\n  Bob-->>Alice: Hi Alice!"
}

///|
fn sequence_basic_messages_expected_ascii() -> String {
  [
    " +-------+        +-----+   ",
    " | Alice |        | Bob |   ",
    " +-------+        +-----+   ",
    "     |               |      ",
    "     |  Hello Bob!   |      ",
    "     |--------------->      ",
    "     |               |      ",
    "     |   Hi Alice!   |      ",
    "     <...............|      ",
    "     |               |      ",
    " +-------+        +-----+   ",
    " | Alice |        | Bob |   ",
    " +-------+        +-----+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_basic_messages_expected_unicode() -> String {
  [
    " ┌───────┐        ┌─────┐   ",
    " │ Alice │        │ Bob │   ",
    " └───┬───┘        └──┬──┘   ",
    "     │               │      ",
    "     │  Hello Bob!   │      ",
    "     │───────────────▶      ",
    "     │               │      ",
    "     │   Hi Alice!   │      ",
    "     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│      ",
    "     │               │      ",
    " ┌───┴───┐        ┌──┴──┐   ",
    " │ Alice │        │ Bob │   ",
    " └───────┘        └─────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_participant_aliases_source() -> String {
  "sequenceDiagram\n  participant A as Alice\n  participant B as Bob\n  participant C as Charlie\n  A->>B: Hello\n  B->>C: Forward\n  C-->>A: Reply"
}

///|
fn sequence_participant_aliases_expected_ascii() -> String {
  [
    " +-------+   +-----+    +---------+   ",
    " | Alice |   | Bob |    | Charlie |   ",
    " +-------+   +-----+    +---------+   ",
    "     |          |            |        ",
    "     |  Hello   |            |        ",
    "     |---------->            |        ",
    "     |          |            |        ",
    "     |          |  Forward   |        ",
    "     |          |------------>        ",
    "     |          |            |        ",
    "     |         Reply         |        ",
    "     <.......................|        ",
    "     |          |            |        ",
    " +-------+   +-----+    +---------+   ",
    " | Alice |   | Bob |    | Charlie |   ",
    " +-------+   +-----+    +---------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_participant_aliases_expected_unicode() -> String {
  [
    " ┌───────┐   ┌─────┐    ┌─────────┐   ",
    " │ Alice │   │ Bob │    │ Charlie │   ",
    " └───┬───┘   └──┬──┘    └────┬────┘   ",
    "     │          │            │        ",
    "     │  Hello   │            │        ",
    "     │──────────▶            │        ",
    "     │          │            │        ",
    "     │          │  Forward   │        ",
    "     │          │────────────▶        ",
    "     │          │            │        ",
    "     │         Reply         │        ",
    "     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│        ",
    "     │          │            │        ",
    " ┌───┴───┐   ┌──┴──┐    ┌────┴────┐   ",
    " │ Alice │   │ Bob │    │ Charlie │   ",
    " └───────┘   └─────┘    └─────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_actor_stick_figures_source() -> String {
  "sequenceDiagram\n  actor U as User\n  participant S as System\n  participant DB as Database\n  U->>S: Click button\n  S->>DB: Query\n  DB-->>S: Results\n  S-->>U: Display"
}

///|
fn sequence_actor_stick_figures_expected_ascii() -> String {
  [
    "+------+         +--------+  +----------+   ",
    "| User |         | System |  | Database |   ",
    "+------+         +--------+  +----------+   ",
    "    |                 |            |        ",
    "    |  Click button   |            |        ",
    "    |----------------->            |        ",
    "    |                 |            |        ",
    "    |                 |   Query    |        ",
    "    |                 |------------>        ",
    "    |                 |            |        ",
    "    |                 |  Results   |        ",
    "    |                 <............|        ",
    "    |                 |            |        ",
    "    |     Display     |            |        ",
    "    <.................|            |        ",
    "    |                 |            |        ",
    "+------+         +--------+  +----------+   ",
    "| User |         | System |  | Database |   ",
    "+------+         +--------+  +----------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_actor_stick_figures_expected_unicode() -> String {
  [
    "┌──────┐         ┌────────┐  ┌──────────┐   ",
    "│ User │         │ System │  │ Database │   ",
    "└───┬──┘         └────┬───┘  └─────┬────┘   ",
    "    │                 │            │        ",
    "    │  Click button   │            │        ",
    "    │─────────────────▶            │        ",
    "    │                 │            │        ",
    "    │                 │   Query    │        ",
    "    │                 │────────────▶        ",
    "    │                 │            │        ",
    "    │                 │  Results   │        ",
    "    │                 ◀╌╌╌╌╌╌╌╌╌╌╌╌│        ",
    "    │                 │            │        ",
    "    │     Display     │            │        ",
    "    ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│            │        ",
    "    │                 │            │        ",
    "┌───┴──┐         ┌────┴───┐  ┌─────┴────┐   ",
    "│ User │         │ System │  │ Database │   ",
    "└──────┘         └────────┘  └──────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_arrow_types_source() -> String {
  "sequenceDiagram\n  A->>B: Solid arrow (sync)\n  B-->>A: Dashed arrow (return)\n  A-)B: Open arrow (async)\n  B--)A: Open dashed arrow"
}

///|
fn sequence_arrow_types_expected_ascii() -> String {
  [
    " +---+                      +---+   ",
    " | A |                      | B |   ",
    " +---+                      +---+   ",
    "   |                          |     ",
    "   |   Solid arrow (sync)     |     ",
    "   |-------------------------->     ",
    "   |                          |     ",
    "   |  Dashed arrow (return)   |     ",
    "   <..........................|     ",
    "   |                          |     ",
    "   |   Open arrow (async)     |     ",
    "   |-------------------------->     ",
    "   |                          |     ",
    "   |    Open dashed arrow     |     ",
    "   <..........................|     ",
    "   |                          |     ",
    " +---+                      +---+   ",
    " | A |                      | B |   ",
    " +---+                      +---+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_arrow_types_expected_unicode() -> String {
  [
    " ┌───┐                      ┌───┐   ",
    " │ A │                      │ B │   ",
    " └─┬─┘                      └─┬─┘   ",
    "   │                          │     ",
    "   │   Solid arrow (sync)     │     ",
    "   │──────────────────────────▶     ",
    "   │                          │     ",
    "   │  Dashed arrow (return)   │     ",
    "   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│     ",
    "   │                          │     ",
    "   │   Open arrow (async)     │     ",
    "   │──────────────────────────▷     ",
    "   │                          │     ",
    "   │    Open dashed arrow     │     ",
    "   ◁╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│     ",
    "   │                          │     ",
    " ┌─┴─┐                      ┌─┴─┐   ",
    " │ A │                      │ B │   ",
    " └───┘                      └───┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_activation_boxes_sample_source() -> String {
  "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>+S: Request\n  S->>+S: Process\n  S->>-S: Done\n  S-->>-C: Response"
}

///|
fn sequence_activation_boxes_sample_expected_ascii() -> String {
  [
    "+--------+    +--------+            ",
    "| Client |    | Server |            ",
    "+--------+    +--------+            ",
    "     |             |                ",
    "     |   Request   |                ",
    "     |------------->                ",
    "     |             |                ",
    "     |             +---+            ",
    "     |             |   | Process    ",
    "     |             <---+            ",
    "     |             |                ",
    "     |             +---+            ",
    "     |             |   | Done       ",
    "     |             <---+            ",
    "     |             |                ",
    "     |  Response   |                ",
    "     <.............|                ",
    "     |             |                ",
    "+--------+    +--------+            ",
    "| Client |    | Server |            ",
    "+--------+    +--------+            ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_activation_boxes_sample_expected_unicode() -> String {
  [
    "┌────────┐    ┌────────┐            ",
    "│ Client │    │ Server │            ",
    "└────┬───┘    └────┬───┘            ",
    "     │             │                ",
    "     │   Request   │                ",
    "     │─────────────▶                ",
    "     │             │                ",
    "     │             ├───┐            ",
    "     │             │   │ Process    ",
    "     │             ◀───┘            ",
    "     │             │                ",
    "     │             ├───┐            ",
    "     │             │   │ Done       ",
    "     │             ◀───┘            ",
    "     │             │                ",
    "     │  Response   │                ",
    "     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌│                ",
    "     │             │                ",
    "┌────┴───┐    ┌────┴───┐            ",
    "│ Client │    │ Server │            ",
    "└────────┘    └────────┘            ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_self_messages_source() -> String {
  "sequenceDiagram\n  participant S as Server\n  S->>S: Internal process\n  S->>S: Validate\n  S-->>S: Log"
}

///|
fn sequence_self_messages_expected_ascii() -> String {
  [
    "+--------+                     ",
    "| Server |                     ",
    "+--------+                     ",
    "     |                         ",
    "     +---+                     ",
    "     |   | Internal process    ",
    "     <---+                     ",
    "     |                         ",
    "     +---+                     ",
    "     |   | Validate            ",
    "     <---+                     ",
    "     |                         ",
    "     +...+                     ",
    "     |   | Log                 ",
    "     <...+                     ",
    "     |                         ",
    "+--------+                     ",
    "| Server |                     ",
    "+--------+                     ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_self_messages_expected_unicode() -> String {
  [
    "┌────────┐                     ",
    "│ Server │                     ",
    "└────┬───┘                     ",
    "     │                         ",
    "     ├───┐                     ",
    "     │   │ Internal process    ",
    "     ◀───┘                     ",
    "     │                         ",
    "     ├───┐                     ",
    "     │   │ Validate            ",
    "     ◀───┘                     ",
    "     │                         ",
    "     ├╌╌╌┐                     ",
    "     │   │ Log                 ",
    "     ◀╌╌╌┘                     ",
    "     │                         ",
    "┌────┴───┐                     ",
    "│ Server │                     ",
    "└────────┘                     ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_loop_block_source() -> String {
  "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Connect\n  loop Every 30s\n    C->>S: Heartbeat\n    S-->>C: Ack\n  end\n  C->>S: Disconnect"
}

///|
fn sequence_loop_block_expected_ascii() -> String {
  [
    "+--------+      +--------+   ",
    "| Client |      | Server |   ",
    "+--------+      +--------+   ",
    "     |               |       ",
    "     |    Connect    |       ",
    "     |--------------->       ",
    "     |               |       ",
    " +loop [Every 30s]-------+   ",
    " |   |               |   |   ",
    " |   |   Heartbeat   |   |   ",
    " |   |--------------->   |   ",
    " |   |               |   |   ",
    " |   |      Ack      |   |   ",
    " |   <...............|   |   ",
    " |   |               |   |   ",
    " +-----------------------+   ",
    "     |               |       ",
    "     |  Disconnect   |       ",
    "     |--------------->       ",
    "     |               |       ",
    "+--------+      +--------+   ",
    "| Client |      | Server |   ",
    "+--------+      +--------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_loop_block_expected_unicode() -> String {
  [
    "┌────────┐      ┌────────┐   ",
    "│ Client │      │ Server │   ",
    "└────┬───┘      └────┬───┘   ",
    "     │               │       ",
    "     │    Connect    │       ",
    "     │───────────────▶       ",
    "     │               │       ",
    " ┌loop [Every 30s]───────┐   ",
    " │   │               │   │   ",
    " │   │   Heartbeat   │   │   ",
    " │   │───────────────▶   │   ",
    " │   │               │   │   ",
    " │   │      Ack      │   │   ",
    " │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│   │   ",
    " │   │               │   │   ",
    " └───────────────────────┘   ",
    "     │               │       ",
    "     │  Disconnect   │       ",
    "     │───────────────▶       ",
    "     │               │       ",
    "┌────┴───┐      ┌────┴───┐   ",
    "│ Client │      │ Server │   ",
    "└────────┘      └────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_alt_else_block_source() -> String {
  "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Login\n  alt Valid credentials\n    S-->>C: 200 OK\n  else Invalid\n    S-->>C: 401 Unauthorized\n  else Account locked\n    S-->>C: 403 Forbidden\n  end"
}

///|
fn sequence_alt_else_block_expected_ascii() -> String {
  [
    "+--------+            +--------+   ",
    "| Client |            | Server |   ",
    "+--------+            +--------+   ",
    "     |                     |       ",
    "     |        Login        |       ",
    "     |--------------------->       ",
    "     |                     |       ",
    " +alt [Valid credentials]------+   ",
    " |   |                     |   |   ",
    " |   |       200 OK        |   |   ",
    " |   <.....................|   |   ",
    " |   |                     |   |   ",
    " +[Invalid]--------------------+   ",
    " |   |                     |   |   ",
    " |   |  401 Unauthorized   |   |   ",
    " |   <.....................|   |   ",
    " |   |                     |   |   ",
    " +[Account locked]-------------+   ",
    " |   |                     |   |   ",
    " |   |    403 Forbidden    |   |   ",
    " |   <.....................|   |   ",
    " |   |                     |   |   ",
    " +-----------------------------+   ",
    "     |                     |       ",
    "+--------+            +--------+   ",
    "| Client |            | Server |   ",
    "+--------+            +--------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_alt_else_block_expected_unicode() -> String {
  [
    "┌────────┐            ┌────────┐   ",
    "│ Client │            │ Server │   ",
    "└────┬───┘            └────┬───┘   ",
    "     │                     │       ",
    "     │        Login        │       ",
    "     │─────────────────────▶       ",
    "     │                     │       ",
    " ┌alt [Valid credentials]──────┐   ",
    " │   │                     │   │   ",
    " │   │       200 OK        │   │   ",
    " │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│   │   ",
    " │   │                     │   │   ",
    " ├[Invalid]╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤   ",
    " │   │                     │   │   ",
    " │   │  401 Unauthorized   │   │   ",
    " │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│   │   ",
    " │   │                     │   │   ",
    " ├[Account locked]╌╌╌╌╌╌╌╌╌╌╌╌╌┤   ",
    " │   │                     │   │   ",
    " │   │    403 Forbidden    │   │   ",
    " │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│   │   ",
    " │   │                     │   │   ",
    " └─────────────────────────────┘   ",
    "     │                     │       ",
    "┌────┴───┐            ┌────┴───┐   ",
    "│ Client │            │ Server │   ",
    "└────────┘            └────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_opt_block_source() -> String {
  "sequenceDiagram\n  participant A as App\n  participant C as Cache\n  participant DB as Database\n  A->>C: Get data\n  C-->>A: Cache miss\n  opt Cache miss\n    A->>DB: Query\n    DB-->>A: Results\n    A->>C: Store in cache\n  end"
}

///|
fn sequence_opt_block_expected_ascii() -> String {
  [
    " +-----+            +-------+  +----------+   ",
    " | App |            | Cache |  | Database |   ",
    " +-----+            +-------+  +----------+   ",
    "    |                   |            |        ",
    "    |     Get data      |            |        ",
    "    |------------------->            |        ",
    "    |                   |            |        ",
    "    |    Cache miss     |            |        ",
    "    <...................|            |        ",
    "    |                   |            |        ",
    "+opt [Cache miss]------------------------+    ",
    "|   |                   |            |   |    ",
    "|   |             Query |            |   |    ",
    "|   |-------------------------------->   |    ",
    "|   |                   |            |   |    ",
    "|   |            Results|            |   |    ",
    "|   <................................|   |    ",
    "|   |                   |            |   |    ",
    "|   |  Store in cache   |            |   |    ",
    "|   |------------------->            |   |    ",
    "|   |                   |            |   |    ",
    "+----------------------------------------+    ",
    "    |                   |            |        ",
    " +-----+            +-------+  +----------+   ",
    " | App |            | Cache |  | Database |   ",
    " +-----+            +-------+  +----------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_opt_block_expected_unicode() -> String {
  [
    " ┌─────┐            ┌───────┐  ┌──────────┐   ",
    " │ App │            │ Cache │  │ Database │   ",
    " └──┬──┘            └───┬───┘  └─────┬────┘   ",
    "    │                   │            │        ",
    "    │     Get data      │            │        ",
    "    │───────────────────▶            │        ",
    "    │                   │            │        ",
    "    │    Cache miss     │            │        ",
    "    ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│            │        ",
    "    │                   │            │        ",
    "┌opt [Cache miss]────────────────────────┐    ",
    "│   │                   │            │   │    ",
    "│   │             Query │            │   │    ",
    "│   │────────────────────────────────▶   │    ",
    "│   │                   │            │   │    ",
    "│   │            Results│            │   │    ",
    "│   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│   │    ",
    "│   │                   │            │   │    ",
    "│   │  Store in cache   │            │   │    ",
    "│   │───────────────────▶            │   │    ",
    "│   │                   │            │   │    ",
    "└────────────────────────────────────────┘    ",
    "    │                   │            │        ",
    " ┌──┴──┐            ┌───┴───┐  ┌─────┴────┐   ",
    " │ App │            │ Cache │  │ Database │   ",
    " └─────┘            └───────┘  └──────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_par_block_source() -> String {
  "sequenceDiagram\n  participant C as Client\n  participant A as AuthService\n  participant U as UserService\n  participant O as OrderService\n  C->>A: Authenticate\n  par Fetch user data\n    A->>U: Get profile\n  and Fetch orders\n    A->>O: Get orders\n  end\n  A-->>C: Combined response"
}

///|
fn sequence_par_block_expected_ascii() -> String {
  [
    "+--------+           +-------------+   +-------------+  +--------------+   ",
    "| Client |           | AuthService |   | UserService |  | OrderService |   ",
    "+--------+           +-------------+   +-------------+  +--------------+   ",
    "     |                      |                 |                 |          ",
    "     |    Authenticate      |                 |                 |          ",
    "     |---------------------->                 |                 |          ",
    "     |                      |                 |                 |          ",
    "     |                  +par [Fetch user data]----------------------+      ",
    "     |                  |   |                 |                 |   |      ",
    "     |                  |   |   Get profile   |                 |   |      ",
    "     |                  |   |----------------->                 |   |      ",
    "     |                  |   |                 |                 |   |      ",
    "     |                  +[Fetch orders]-----------------------------+      ",
    "     |                  |   |                 |                 |   |      ",
    "     |                  |   |            Get orders             |   |      ",
    "     |                  |   |----------------------------------->   |      ",
    "     |                  |   |                 |                 |   |      ",
    "     |                  +-------------------------------------------+      ",
    "     |                      |                 |                 |          ",
    "     |  Combined response   |                 |                 |          ",
    "     <......................|                 |                 |          ",
    "     |                      |                 |                 |          ",
    "+--------+           +-------------+   +-------------+  +--------------+   ",
    "| Client |           | AuthService |   | UserService |  | OrderService |   ",
    "+--------+           +-------------+   +-------------+  +--------------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_par_block_expected_unicode() -> String {
  [
    "┌────────┐           ┌─────────────┐   ┌─────────────┐  ┌──────────────┐   ",
    "│ Client │           │ AuthService │   │ UserService │  │ OrderService │   ",
    "└────┬───┘           └──────┬──────┘   └──────┬──────┘  └───────┬──────┘   ",
    "     │                      │                 │                 │          ",
    "     │    Authenticate      │                 │                 │          ",
    "     │──────────────────────▶                 │                 │          ",
    "     │                      │                 │                 │          ",
    "     │                  ┌par [Fetch user data]──────────────────────┐      ",
    "     │                  │   │                 │                 │   │      ",
    "     │                  │   │   Get profile   │                 │   │      ",
    "     │                  │   │─────────────────▶                 │   │      ",
    "     │                  │   │                 │                 │   │      ",
    "     │                  ├[Fetch orders]╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤      ",
    "     │                  │   │                 │                 │   │      ",
    "     │                  │   │            Get orders             │   │      ",
    "     │                  │   │───────────────────────────────────▶   │      ",
    "     │                  │   │                 │                 │   │      ",
    "     │                  └───────────────────────────────────────────┘      ",
    "     │                      │                 │                 │          ",
    "     │  Combined response   │                 │                 │          ",
    "     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                 │                 │          ",
    "     │                      │                 │                 │          ",
    "┌────┴───┐           ┌──────┴──────┐   ┌──────┴──────┐  ┌───────┴──────┐   ",
    "│ Client │           │ AuthService │   │ UserService │  │ OrderService │   ",
    "└────────┘           └─────────────┘   └─────────────┘  └──────────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_critical_block_source() -> String {
  "sequenceDiagram\n  participant A as App\n  participant DB as Database\n  A->>DB: BEGIN\n  critical Transaction\n    A->>DB: UPDATE accounts\n    A->>DB: INSERT log\n  end\n  A->>DB: COMMIT"
}

///|
fn sequence_critical_block_expected_ascii() -> String {
  [
    " +-----+           +----------+   ",
    " | App |           | Database |   ",
    " +-----+           +----------+   ",
    "    |                    |        ",
    "    |       BEGIN        |        ",
    "    |-------------------->        ",
    "    |                    |        ",
    "+critical [Transaction]------+    ",
    "|   |                    |   |    ",
    "|   |  UPDATE accounts   |   |    ",
    "|   |-------------------->   |    ",
    "|   |                    |   |    ",
    "|   |    INSERT log      |   |    ",
    "|   |-------------------->   |    ",
    "|   |                    |   |    ",
    "+----------------------------+    ",
    "    |                    |        ",
    "    |      COMMIT        |        ",
    "    |-------------------->        ",
    "    |                    |        ",
    " +-----+           +----------+   ",
    " | App |           | Database |   ",
    " +-----+           +----------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_critical_block_expected_unicode() -> String {
  [
    " ┌─────┐           ┌──────────┐   ",
    " │ App │           │ Database │   ",
    " └──┬──┘           └─────┬────┘   ",
    "    │                    │        ",
    "    │       BEGIN        │        ",
    "    │────────────────────▶        ",
    "    │                    │        ",
    "┌critical [Transaction]──────┐    ",
    "│   │                    │   │    ",
    "│   │  UPDATE accounts   │   │    ",
    "│   │────────────────────▶   │    ",
    "│   │                    │   │    ",
    "│   │    INSERT log      │   │    ",
    "│   │────────────────────▶   │    ",
    "│   │                    │   │    ",
    "└────────────────────────────┘    ",
    "    │                    │        ",
    "    │      COMMIT        │        ",
    "    │────────────────────▶        ",
    "    │                    │        ",
    " ┌──┴──┐           ┌─────┴────┐   ",
    " │ App │           │ Database │   ",
    " └─────┘           └──────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_notes_right_left_over_source() -> String {
  "sequenceDiagram\n  participant A as Alice\n  participant B as Bob\n  Note left of A: Alice prepares\n  A->>B: Hello\n  Note right of B: Bob thinks\n  B-->>A: Reply\n  Note over A,B: Conversation complete"
}

///|
fn sequence_notes_right_left_over_expected_ascii() -> String {
  [
    " +-------+   +-----+              ",
    " | Alice |   | Bob |              ",
    " +-------+   +-----+              ",
    "     |          |                 ",
    "     |  Hello   |                 ",
    "     |---------->                 ",
    "     |          |                 ",
    "     |          | +------------+  ",
    "     |          | | Bob thinks |  ",
    "     |          | +------------+  ",
    "     |          |                 ",
    "     |  Reply   |                 ",
    "     <..........|                 ",
    "     |          |                 ",
    "+-----------------------+         ",
    "| Conversation complete |         ",
    "+-----------------------+         ",
    "     |          |                 ",
    " +-------+   +-----+              ",
    " | Alice |   | Bob |              ",
    " +-------+   +-----+              ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_notes_right_left_over_expected_unicode() -> String {
  [
    " ┌───────┐   ┌─────┐              ",
    " │ Alice │   │ Bob │              ",
    " └───┬───┘   └──┬──┘              ",
    "     │          │                 ",
    "     │  Hello   │                 ",
    "     │──────────▶                 ",
    "     │          │                 ",
    "     │          │ ┌────────────┐  ",
    "     │          │ │ Bob thinks │  ",
    "     │          │ └────────────┘  ",
    "     │          │                 ",
    "     │  Reply   │                 ",
    "     ◀╌╌╌╌╌╌╌╌╌╌│                 ",
    "     │          │                 ",
    "┌───────────────────────┐         ",
    "│ Conversation complete │         ",
    "└───────────────────────┘         ",
    "     │          │                 ",
    " ┌───┴───┐   ┌──┴──┐              ",
    " │ Alice │   │ Bob │              ",
    " └───────┘   └─────┘              ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_oauth_2_0_flow_source() -> String {
  "sequenceDiagram\n  actor U as User\n  participant App as Client App\n  participant Auth as Auth Server\n  participant API as Resource API\n  U->>App: Click Login\n  App->>Auth: Authorization request\n  Auth->>U: Login page\n  U->>Auth: Credentials\n  Auth-->>App: Authorization code\n  App->>Auth: Exchange code for token\n  Auth-->>App: Access token\n  App->>API: Request + token\n  API-->>App: Protected resource\n  App-->>U: Display data"
}

///|
fn sequence_oauth_2_0_flow_expected_ascii() -> String {
  [
    "+------+       +------------+               +-------------+  +--------------+   ",
    "| User |       | Client App |               | Auth Server |  | Resource API |   ",
    "+------+       +------------+               +-------------+  +--------------+   ",
    "    |                 |                            |                 |          ",
    "    |   Click Login   |                            |                 |          ",
    "    |----------------->                            |                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 |   Authorization request    |                 |          ",
    "    |                 |---------------------------->                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 Login page                   |                 |          ",
    "    <----------------------------------------------|                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 Credentials                  |                 |          ",
    "    |---------------------------------------------->                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 |    Authorization code      |                 |          ",
    "    |                 <............................|                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 |  Exchange code for token   |                 |          ",
    "    |                 |---------------------------->                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 |       Access token         |                 |          ",
    "    |                 <............................|                 |          ",
    "    |                 |                            |                 |          ",
    "    |                 |               Request + token                |          ",
    "    |                 |---------------------------------------------->          ",
    "    |                 |                            |                 |          ",
    "    |                 |             Protected resource               |          ",
    "    |                 <..............................................|          ",
    "    |                 |                            |                 |          ",
    "    |  Display data   |                            |                 |          ",
    "    <.................|                            |                 |          ",
    "    |                 |                            |                 |          ",
    "+------+       +------------+               +-------------+  +--------------+   ",
    "| User |       | Client App |               | Auth Server |  | Resource API |   ",
    "+------+       +------------+               +-------------+  +--------------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_oauth_2_0_flow_expected_unicode() -> String {
  [
    "┌──────┐       ┌────────────┐               ┌─────────────┐  ┌──────────────┐   ",
    "│ User │       │ Client App │               │ Auth Server │  │ Resource API │   ",
    "└───┬──┘       └──────┬─────┘               └──────┬──────┘  └───────┬──────┘   ",
    "    │                 │                            │                 │          ",
    "    │   Click Login   │                            │                 │          ",
    "    │─────────────────▶                            │                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 │   Authorization request    │                 │          ",
    "    │                 │────────────────────────────▶                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 Login page                   │                 │          ",
    "    ◀──────────────────────────────────────────────│                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 Credentials                  │                 │          ",
    "    │──────────────────────────────────────────────▶                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 │    Authorization code      │                 │          ",
    "    │                 ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 │  Exchange code for token   │                 │          ",
    "    │                 │────────────────────────────▶                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 │       Access token         │                 │          ",
    "    │                 ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                 │          ",
    "    │                 │                            │                 │          ",
    "    │                 │               Request + token                │          ",
    "    │                 │──────────────────────────────────────────────▶          ",
    "    │                 │                            │                 │          ",
    "    │                 │             Protected resource               │          ",
    "    │                 ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│          ",
    "    │                 │                            │                 │          ",
    "    │  Display data   │                            │                 │          ",
    "    ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                            │                 │          ",
    "    │                 │                            │                 │          ",
    "┌───┴──┐       ┌──────┴─────┐               ┌──────┴──────┐  ┌───────┴──────┐   ",
    "│ User │       │ Client App │               │ Auth Server │  │ Resource API │   ",
    "└──────┘       └────────────┘               └─────────────┘  └──────────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_database_transaction_source() -> String {
  "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  participant DB as Database\n  C->>S: POST /transfer\n  S->>DB: BEGIN\n  S->>DB: Debit account A\n  alt Success\n    S->>DB: Credit account B\n    S->>DB: INSERT audit_log\n    S->>DB: COMMIT\n    S-->>C: 200 OK\n  else Insufficient funds\n    S->>DB: ROLLBACK\n    S-->>C: 400 Bad Request\n  end"
}

///|
fn sequence_database_transaction_expected_ascii() -> String {
  [
    "+--------+           +--------+           +----------+   ",
    "| Client |           | Server |           | Database |   ",
    "+--------+           +--------+           +----------+   ",
    "     |                    |                     |        ",
    "     |  POST /transfer    |                     |        ",
    "     |-------------------->                     |        ",
    "     |                    |                     |        ",
    "     |                    |        BEGIN        |        ",
    "     |                    |--------------------->        ",
    "     |                    |                     |        ",
    "     |                    |   Debit account A   |        ",
    "     |                    |--------------------->        ",
    "     |                    |                     |        ",
    " +alt [Success]-------------------------------------+    ",
    " |   |                    |                     |   |    ",
    " |   |                    |  Credit account B   |   |    ",
    " |   |                    |--------------------->   |    ",
    " |   |                    |                     |   |    ",
    " |   |                    |  INSERT audit_log   |   |    ",
    " |   |                    |--------------------->   |    ",
    " |   |                    |                     |   |    ",
    " |   |                    |       COMMIT        |   |    ",
    " |   |                    |--------------------->   |    ",
    " |   |                    |                     |   |    ",
    " |   |      200 OK        |                     |   |    ",
    " |   <....................|                     |   |    ",
    " |   |                    |                     |   |    ",
    " +[Insufficient funds]------------------------------+    ",
    " |   |                    |                     |   |    ",
    " |   |                    |      ROLLBACK       |   |    ",
    " |   |                    |--------------------->   |    ",
    " |   |                    |                     |   |    ",
    " |   |  400 Bad Request   |                     |   |    ",
    " |   <....................|                     |   |    ",
    " |   |                    |                     |   |    ",
    " +--------------------------------------------------+    ",
    "     |                    |                     |        ",
    "+--------+           +--------+           +----------+   ",
    "| Client |           | Server |           | Database |   ",
    "+--------+           +--------+           +----------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_database_transaction_expected_unicode() -> String {
  [
    "┌────────┐           ┌────────┐           ┌──────────┐   ",
    "│ Client │           │ Server │           │ Database │   ",
    "└────┬───┘           └────┬───┘           └─────┬────┘   ",
    "     │                    │                     │        ",
    "     │  POST /transfer    │                     │        ",
    "     │────────────────────▶                     │        ",
    "     │                    │                     │        ",
    "     │                    │        BEGIN        │        ",
    "     │                    │─────────────────────▶        ",
    "     │                    │                     │        ",
    "     │                    │   Debit account A   │        ",
    "     │                    │─────────────────────▶        ",
    "     │                    │                     │        ",
    " ┌alt [Success]─────────────────────────────────────┐    ",
    " │   │                    │                     │   │    ",
    " │   │                    │  Credit account B   │   │    ",
    " │   │                    │─────────────────────▶   │    ",
    " │   │                    │                     │   │    ",
    " │   │                    │  INSERT audit_log   │   │    ",
    " │   │                    │─────────────────────▶   │    ",
    " │   │                    │                     │   │    ",
    " │   │                    │       COMMIT        │   │    ",
    " │   │                    │─────────────────────▶   │    ",
    " │   │                    │                     │   │    ",
    " │   │      200 OK        │                     │   │    ",
    " │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                     │   │    ",
    " │   │                    │                     │   │    ",
    " ├[Insufficient funds]╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤    ",
    " │   │                    │                     │   │    ",
    " │   │                    │      ROLLBACK       │   │    ",
    " │   │                    │─────────────────────▶   │    ",
    " │   │                    │                     │   │    ",
    " │   │  400 Bad Request   │                     │   │    ",
    " │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│                     │   │    ",
    " │   │                    │                     │   │    ",
    " └──────────────────────────────────────────────────┘    ",
    "     │                    │                     │        ",
    "┌────┴───┐           ┌────┴───┐           ┌─────┴────┐   ",
    "│ Client │           │ Server │           │ Database │   ",
    "└────────┘           └────────┘           └──────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_microservice_orchestration_source() -> String {
  "sequenceDiagram\n  participant G as Gateway\n  participant A as Auth\n  participant U as Users\n  participant O as Orders\n  participant N as Notify\n  G->>A: Validate token\n  A-->>G: Valid\n  par Fetch data\n    G->>U: Get user\n    U-->>G: User data\n  and\n    G->>O: Get orders\n    O-->>G: Order list\n  end\n  G->>N: Send notification\n  N-->>G: Queued\n  Note over G: Aggregate response"
}

///|
fn sequence_microservice_orchestration_expected_ascii() -> String {
  [
    " +---------+          +------+   +-------+  +--------+  +--------+   ",
    " | Gateway |          | Auth |   | Users |  | Orders |  | Notify |   ",
    " +---------+          +------+   +-------+  +--------+  +--------+   ",
    "      |                   |          |           |           |       ",
    "      |  Validate token   |          |           |           |       ",
    "      |------------------->          |           |           |       ",
    "      |                   |          |           |           |       ",
    "      |       Valid       |          |           |           |       ",
    "      <...................|          |           |           |       ",
    "      |                   |          |           |           |       ",
    "  +par [Fetch data]----------------------------------+       |       ",
    "  |   |                   |          |           |   |       |       ",
    "  |   |          Get user |          |           |   |       |       ",
    "  |   |------------------------------>           |   |       |       ",
    "  |   |                   |          |           |   |       |       ",
    "  |   |          User data|          |           |   |       |       ",
    "  |   <..............................|           |   |       |       ",
    "  |   |                   |          |           |   |       |       ",
    "  +--------------------------------------------------+       |       ",
    "  |   |                   |          |           |   |       |       ",
    "  |   |               Get orders     |           |   |       |       ",
    "  |   |------------------------------------------>   |       |       ",
    "  |   |                   |          |           |   |       |       ",
    "  |   |               Order list     |           |   |       |       ",
    "  |   <..........................................|   |       |       ",
    "  |   |                   |          |           |   |       |       ",
    "  +--------------------------------------------------+       |       ",
    "      |                   |          |           |           |       ",
    "      |                  Send notification       |           |       ",
    "      |------------------------------------------------------>       ",
    "      |                   |          |           |           |       ",
    "      |                   |   Queued |           |           |       ",
    "      <......................................................|       ",
    "      |                   |          |           |           |       ",
    "+--------------------+    |          |           |           |       ",
    "| Aggregate response |    |          |           |           |       ",
    "+--------------------+    |          |           |           |       ",
    "      |                   |          |           |           |       ",
    " +---------+          +------+   +-------+  +--------+  +--------+   ",
    " | Gateway |          | Auth |   | Users |  | Orders |  | Notify |   ",
    " +---------+          +------+   +-------+  +--------+  +--------+   ",
  ]
  .iter()
  .join("\n")
}

///|
fn sequence_microservice_orchestration_expected_unicode() -> String {
  [
    " ┌─────────┐          ┌──────┐   ┌───────┐  ┌────────┐  ┌────────┐   ",
    " │ Gateway │          │ Auth │   │ Users │  │ Orders │  │ Notify │   ",
    " └────┬────┘          └───┬──┘   └───┬───┘  └────┬───┘  └────┬───┘   ",
    "      │                   │          │           │           │       ",
    "      │  Validate token   │          │           │           │       ",
    "      │───────────────────▶          │           │           │       ",
    "      │                   │          │           │           │       ",
    "      │       Valid       │          │           │           │       ",
    "      ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│          │           │           │       ",
    "      │                   │          │           │           │       ",
    "  ┌par [Fetch data]──────────────────────────────────┐       │       ",
    "  │   │                   │          │           │   │       │       ",
    "  │   │          Get user │          │           │   │       │       ",
    "  │   │──────────────────────────────▶           │   │       │       ",
    "  │   │                   │          │           │   │       │       ",
    "  │   │          User data│          │           │   │       │       ",
    "  │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│           │   │       │       ",
    "  │   │                   │          │           │   │       │       ",
    "  ├╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┤       │       ",
    "  │   │                   │          │           │   │       │       ",
    "  │   │               Get orders     │           │   │       │       ",
    "  │   │──────────────────────────────────────────▶   │       │       ",
    "  │   │                   │          │           │   │       │       ",
    "  │   │               Order list     │           │   │       │       ",
    "  │   ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│   │       │       ",
    "  │   │                   │          │           │   │       │       ",
    "  └──────────────────────────────────────────────────┘       │       ",
    "      │                   │          │           │           │       ",
    "      │                  Send notification       │           │       ",
    "      │──────────────────────────────────────────────────────▶       ",
    "      │                   │          │           │           │       ",
    "      │                   │   Queued │           │           │       ",
    "      ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌│       ",
    "      │                   │          │           │           │       ",
    "┌────────────────────┐    │          │           │           │       ",
    "│ Aggregate response │    │          │           │           │       ",
    "└────────────────────┘    │          │           │           │       ",
    "      │                   │          │           │           │       ",
    " ┌────┴────┐          ┌───┴──┐   ┌───┴───┐  ┌────┴───┐  ┌────┴───┐   ",
    " │ Gateway │          │ Auth │   │ Users │  │ Orders │  │ Notify │   ",
    " └─────────┘          └──────┘   └───────┘  └────────┘  └────────┘   ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_basic_class_sample_source() -> String {
  "classDiagram\n  class Animal {\n    +String name\n    +int age\n    +eat() void\n    +sleep() void\n  }"
}

///|
fn class_basic_class_sample_expected_ascii() -> String {
  [
    "+---------------+    ",
    "| Animal        |    ",
    "+---------------+    ",
    "| +name: String |    ",
    "| +age: int     |    ",
    "+---------------+    ",
    "| +eat: void    |    ",
    "| +sleep: void  |    ",
    "+---------------+    ",
    "                     ",
    "                     ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_basic_class_sample_expected_unicode() -> String {
  [
    "┌───────────────┐    ",
    "│ Animal        │    ",
    "├───────────────┤    ",
    "│ +name: String │    ",
    "│ +age: int     │    ",
    "├───────────────┤    ",
    "│ +eat: void    │    ",
    "│ +sleep: void  │    ",
    "└───────────────┘    ",
    "                     ",
    "                     ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Beautiful Mermaid sample" {
  assert_text_parity(
    beautiful_mermaid_source(),
    beautiful_mermaid_expected_ascii(),
    beautiful_mermaid_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Git Branching Workflow sample" {
  assert_text_parity(
    git_branching_workflow_source(),
    git_branching_workflow_expected_ascii(),
    git_branching_workflow_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Subgraph Direction Override sample" {
  assert_text_parity(
    subgraph_direction_override_source(),
    subgraph_direction_override_expected_ascii(),
    subgraph_direction_override_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: State Connection Lifecycle sample" {
  assert_text_parity(
    state_connection_lifecycle_source(),
    state_connection_lifecycle_expected_ascii(),
    state_connection_lifecycle_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence Activation Boxes sample" {
  assert_text_parity(
    sequence_activation_boxes_source(),
    sequence_activation_boxes_expected_ascii(),
    sequence_activation_boxes_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Class All 6 Relationship Types sample" {
  assert_text_parity(
    class_all_relationship_types_source(),
    class_all_relationship_types_expected_ascii(),
    class_all_relationship_types_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: ER E-Commerce Schema sample" {
  assert_text_parity(
    er_ecommerce_schema_source(),
    er_ecommerce_schema_expected_ascii(),
    er_ecommerce_schema_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: CI/CD Pipeline sample" {
  assert_text_parity(
    ci_cd_pipeline_source(),
    ci_cd_pipeline_expected_ascii(),
    ci_cd_pipeline_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Decision Tree sample" {
  assert_text_parity(
    decision_tree_source(),
    decision_tree_expected_ascii(),
    decision_tree_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Direction Left-Right sample" {
  assert_text_parity(
    direction_left_right_source(),
    direction_left_right_expected_ascii(),
    direction_left_right_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Direction Bottom-Top sample" {
  assert_text_parity(
    direction_bottom_top_source(),
    direction_bottom_top_expected_ascii(),
    direction_bottom_top_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: System Architecture sample" {
  assert_text_parity(
    system_architecture_source(),
    system_architecture_expected_ascii(),
    system_architecture_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Subgraphs sample" {
  assert_text_parity(
    subgraphs_source(),
    subgraphs_expected_ascii(),
    subgraphs_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Nested Subgraphs sample" {
  assert_text_parity(
    nested_subgraphs_source(),
    nested_subgraphs_expected_ascii(),
    nested_subgraphs_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Simple Flow sample" {
  assert_text_parity(
    simple_flow_source(),
    simple_flow_expected_ascii(),
    simple_flow_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Original Node Shapes sample" {
  assert_text_parity(
    original_node_shapes_source(),
    original_node_shapes_expected_ascii(),
    original_node_shapes_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Batch 1 Shapes sample" {
  assert_text_parity(
    batch_1_shapes_source(),
    batch_1_shapes_expected_ascii(),
    batch_1_shapes_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Batch 2 Shapes sample" {
  assert_text_parity(
    batch_2_shapes_source(),
    batch_2_shapes_expected_ascii(),
    batch_2_shapes_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: All Edge Styles sample" {
  assert_text_parity(
    all_edge_styles_source(),
    all_edge_styles_expected_ascii(),
    all_edge_styles_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: No-Arrow Edges sample" {
  assert_text_parity(
    no_arrow_edges_source(),
    no_arrow_edges_expected_ascii(),
    no_arrow_edges_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Bidirectional Arrows sample" {
  assert_text_parity(
    bidirectional_arrows_source(),
    bidirectional_arrows_expected_ascii(),
    bidirectional_arrows_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Parallel Links (&) sample" {
  assert_text_parity(
    parallel_links_and_source(),
    parallel_links_and_expected_ascii(),
    parallel_links_and_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Chained Edges sample" {
  assert_text_parity(
    chained_edges_source(),
    chained_edges_expected_ascii(),
    chained_edges_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Direction: Left-Right (LR) sample" {
  assert_text_parity(
    direction_left_right_lr_source(),
    direction_left_right_lr_expected_ascii(),
    direction_left_right_lr_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Direction: Bottom-Top (BT) sample" {
  assert_text_parity(
    direction_bottom_top_bt_source(),
    direction_bottom_top_bt_expected_ascii(),
    direction_bottom_top_bt_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: All 12 Flowchart Shapes sample" {
  assert_text_parity(
    all_12_flowchart_shapes_source(),
    all_12_flowchart_shapes_expected_ascii(),
    all_12_flowchart_shapes_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: ::: Class Shorthand sample" {
  assert_text_parity(
    class_shorthand_source(),
    class_shorthand_expected_ascii(),
    class_shorthand_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Inline Style Overrides sample" {
  assert_text_parity(
    inline_style_overrides_source(),
    inline_style_overrides_expected_ascii(),
    inline_style_overrides_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Basic State Diagram sample" {
  assert_text_parity(
    basic_state_diagram_source(),
    basic_state_diagram_expected_ascii(),
    basic_state_diagram_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: State: Composite States sample" {
  assert_text_parity(
    state_composite_states_source(),
    state_composite_states_expected_ascii(),
    state_composite_states_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: State: Connection Lifecycle sample" {
  assert_text_parity(
    state_connection_lifecycle_sample_source(),
    state_connection_lifecycle_sample_expected_ascii(),
    state_connection_lifecycle_sample_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Basic Messages sample" {
  assert_text_parity(
    sequence_basic_messages_source(),
    sequence_basic_messages_expected_ascii(),
    sequence_basic_messages_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Participant Aliases sample" {
  assert_text_parity(
    sequence_participant_aliases_source(),
    sequence_participant_aliases_expected_ascii(),
    sequence_participant_aliases_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Actor Stick Figures sample" {
  assert_text_parity(
    sequence_actor_stick_figures_source(),
    sequence_actor_stick_figures_expected_ascii(),
    sequence_actor_stick_figures_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Arrow Types sample" {
  assert_text_parity(
    sequence_arrow_types_source(),
    sequence_arrow_types_expected_ascii(),
    sequence_arrow_types_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Activation Boxes sample" {
  assert_text_parity(
    sequence_activation_boxes_sample_source(),
    sequence_activation_boxes_sample_expected_ascii(),
    sequence_activation_boxes_sample_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Self-Messages sample" {
  assert_text_parity(
    sequence_self_messages_source(),
    sequence_self_messages_expected_ascii(),
    sequence_self_messages_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Loop Block sample" {
  assert_text_parity(
    sequence_loop_block_source(),
    sequence_loop_block_expected_ascii(),
    sequence_loop_block_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Alt/Else Block sample" {
  assert_text_parity(
    sequence_alt_else_block_source(),
    sequence_alt_else_block_expected_ascii(),
    sequence_alt_else_block_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Opt Block sample" {
  assert_text_parity(
    sequence_opt_block_source(),
    sequence_opt_block_expected_ascii(),
    sequence_opt_block_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Par Block sample" {
  assert_text_parity(
    sequence_par_block_source(),
    sequence_par_block_expected_ascii(),
    sequence_par_block_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Critical Block sample" {
  assert_text_parity(
    sequence_critical_block_source(),
    sequence_critical_block_expected_ascii(),
    sequence_critical_block_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Notes (Right/Left/Over) sample" {
  assert_text_parity(
    sequence_notes_right_left_over_source(),
    sequence_notes_right_left_over_expected_ascii(),
    sequence_notes_right_left_over_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: OAuth 2.0 Flow sample" {
  assert_text_parity(
    sequence_oauth_2_0_flow_source(),
    sequence_oauth_2_0_flow_expected_ascii(),
    sequence_oauth_2_0_flow_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Database Transaction sample" {
  assert_text_parity(
    sequence_database_transaction_source(),
    sequence_database_transaction_expected_ascii(),
    sequence_database_transaction_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Sequence: Microservice Orchestration sample" {
  assert_text_parity(
    sequence_microservice_orchestration_source(),
    sequence_microservice_orchestration_expected_ascii(),
    sequence_microservice_orchestration_expected_unicode(),
  )
}

///|
test "ASCII/Unicode parity regression: Class: Basic Class sample" {
  assert_text_parity(
    class_basic_class_sample_source(),
    class_basic_class_sample_expected_ascii(),
    class_basic_class_sample_expected_unicode(),
  )
}

///|
fn class_visibility_markers_sample_source() -> String {
  "classDiagram\n  class User {\n    +String name\n    -String password\n    #int internalId\n    ~String packageField\n    +login() bool\n    -hashPassword() String\n    #validate() void\n    ~notify() void\n  }"
}

///|
fn class_visibility_markers_sample_expected_ascii() -> String {
  [
    "+-----------------------+    ",
    "| User                  |    ",
    "+-----------------------+    ",
    "| +name: String         |    ",
    "| -password: String     |    ",
    "| #internalId: int      |    ",
    "| ~packageField: String |    ",
    "+-----------------------+    ",
    "| +login: bool          |    ",
    "| -hashPassword: String |    ",
    "| #validate: void       |    ",
    "| ~notify: void         |    ",
    "+-----------------------+    ",
    "                             ",
    "                             ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_visibility_markers_sample_expected_unicode() -> String {
  [
    "┌───────────────────────┐    ",
    "│ User                  │    ",
    "├───────────────────────┤    ",
    "│ +name: String         │    ",
    "│ -password: String     │    ",
    "│ #internalId: int      │    ",
    "│ ~packageField: String │    ",
    "├───────────────────────┤    ",
    "│ +login: bool          │    ",
    "│ -hashPassword: String │    ",
    "│ #validate: void       │    ",
    "│ ~notify: void         │    ",
    "└───────────────────────┘    ",
    "                             ",
    "                             ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Visibility Markers sample" {
  assert_text_parity(
    class_visibility_markers_sample_source(),
    class_visibility_markers_sample_expected_ascii(),
    class_visibility_markers_sample_expected_unicode(),
  )
}

///|
fn class_interface_annotation_sample_source() -> String {
  "classDiagram\n  class Serializable {\n    <<interface>>\n    +serialize() String\n    +deserialize(data) void\n  }"
}

///|
fn class_interface_annotation_sample_expected_ascii() -> String {
  [
    "+--------------------+    ",
    "| <<interface>>      |    ",
    "| Serializable       |    ",
    "+--------------------+    ",
    "|                    |    ",
    "+--------------------+    ",
    "| +serialize: String |    ",
    "| +deserialize: void |    ",
    "+--------------------+    ",
    "                          ",
    "                          ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_interface_annotation_sample_expected_unicode() -> String {
  [
    "┌────────────────────┐    ",
    "│ <<interface>>      │    ",
    "│ Serializable       │    ",
    "├────────────────────┤    ",
    "│                    │    ",
    "├────────────────────┤    ",
    "│ +serialize: String │    ",
    "│ +deserialize: void │    ",
    "└────────────────────┘    ",
    "                          ",
    "                          ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Interface Annotation sample" {
  assert_text_parity(
    class_interface_annotation_sample_source(),
    class_interface_annotation_sample_expected_ascii(),
    class_interface_annotation_sample_expected_unicode(),
  )
}

///|
fn class_abstract_annotation_sample_source() -> String {
  "classDiagram\n  class Shape {\n    <<abstract>>\n    +String color\n    +area() double\n    +draw() void\n  }"
}

///|
fn class_abstract_annotation_sample_expected_ascii() -> String {
  [
    "+----------------+    ",
    "| <<abstract>>   |    ",
    "| Shape          |    ",
    "+----------------+    ",
    "| +color: String |    ",
    "+----------------+    ",
    "| +area: double  |    ",
    "| +draw: void    |    ",
    "+----------------+    ",
    "                      ",
    "                      ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_abstract_annotation_sample_expected_unicode() -> String {
  [
    "┌────────────────┐    ",
    "│ <<abstract>>   │    ",
    "│ Shape          │    ",
    "├────────────────┤    ",
    "│ +color: String │    ",
    "├────────────────┤    ",
    "│ +area: double  │    ",
    "│ +draw: void    │    ",
    "└────────────────┘    ",
    "                      ",
    "                      ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Abstract Annotation sample" {
  assert_text_parity(
    class_abstract_annotation_sample_source(),
    class_abstract_annotation_sample_expected_ascii(),
    class_abstract_annotation_sample_expected_unicode(),
  )
}

///|
fn class_enum_annotation_sample_source() -> String {
  "classDiagram\n  class Status {\n    <<enumeration>>\n    ACTIVE\n    INACTIVE\n    PENDING\n    DELETED\n  }"
}

///|
fn class_enum_annotation_sample_expected_ascii() -> String {
  [
    "+-----------------+    ",
    "| <<enumeration>> |    ",
    "| Status          |    ",
    "+-----------------+    ",
    "| ACTIVE          |    ",
    "| INACTIVE        |    ",
    "| PENDING         |    ",
    "| DELETED         |    ",
    "+-----------------+    ",
    "                       ",
    "                       ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_enum_annotation_sample_expected_unicode() -> String {
  [
    "┌─────────────────┐    ",
    "│ <<enumeration>> │    ",
    "│ Status          │    ",
    "├─────────────────┤    ",
    "│ ACTIVE          │    ",
    "│ INACTIVE        │    ",
    "│ PENDING         │    ",
    "│ DELETED         │    ",
    "└─────────────────┘    ",
    "                       ",
    "                       ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Enum Annotation sample" {
  assert_text_parity(
    class_enum_annotation_sample_source(),
    class_enum_annotation_sample_expected_ascii(),
    class_enum_annotation_sample_expected_unicode(),
  )
}

///|
fn class_inheritance_sample_source() -> String {
  "classDiagram\n  class Animal {\n    +String name\n    +eat() void\n  }\n  class Dog {\n    +String breed\n    +bark() void\n  }\n  class Cat {\n    +bool isIndoor\n    +meow() void\n  }\n  Animal <|-- Dog\n  Animal <|-- Cat"
}

///|
fn class_inheritance_sample_expected_ascii() -> String {
  [
    "+---------------+                            ",
    "| Animal        |                            ",
    "+---------------+                            ",
    "| +name: String |                            ",
    "+---------------+                            ",
    "| +eat: void    |                            ",
    "+---------------+                            ",
    "        ^                                    ",
    "        ------------------------             ",
    "         |                     |             ",
    "+----------------+    +-----------------+    ",
    "| Dog            |    | Cat             |    ",
    "+----------------+    +-----------------+    ",
    "| +breed: String |    | +isIndoor: bool |    ",
    "+----------------+    +-----------------+    ",
    "| +bark: void    |    | +meow: void     |    ",
    "+----------------+    +-----------------+    ",
    "                                             ",
    "                                             ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_inheritance_sample_expected_unicode() -> String {
  [
    "┌───────────────┐                            ",
    "│ Animal        │                            ",
    "├───────────────┤                            ",
    "│ +name: String │                            ",
    "├───────────────┤                            ",
    "│ +eat: void    │                            ",
    "└───────────────┘                            ",
    "        △                                    ",
    "        └──────────────────────┐             ",
    "         │                     │             ",
    "┌────────────────┐    ┌─────────────────┐    ",
    "│ Dog            │    │ Cat             │    ",
    "├────────────────┤    ├─────────────────┤    ",
    "│ +breed: String │    │ +isIndoor: bool │    ",
    "├────────────────┤    ├─────────────────┤    ",
    "│ +bark: void    │    │ +meow: void     │    ",
    "└────────────────┘    └─────────────────┘    ",
    "                                             ",
    "                                             ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Inheritance (<|--) sample" {
  assert_text_parity(
    class_inheritance_sample_source(),
    class_inheritance_sample_expected_ascii(),
    class_inheritance_sample_expected_unicode(),
  )
}


///|
fn class_composition_sample_source() -> String {
  "classDiagram\n  class Car {\n    +String model\n    +start() void\n  }\n  class Engine {\n    +int horsepower\n    +rev() void\n  }\n  Car *-- Engine"
}

///|
fn class_composition_sample_expected_ascii() -> String {
  [
    "+----------------+      ",
    "| Car            |      ",
    "+----------------+      ",
    "| +model: String |      ",
    "+----------------+      ",
    "| +start: void   |      ",
    "+----------------+      ",
    "         *              ",
    "         --             ",
    "          |             ",
    "+------------------+    ",
    "| Engine           |    ",
    "+------------------+    ",
    "| +horsepower: int |    ",
    "+------------------+    ",
    "| +rev: void       |    ",
    "+------------------+    ",
    "                        ",
    "                        ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_composition_sample_expected_unicode() -> String {
  [
    "┌────────────────┐      ",
    "│ Car            │      ",
    "├────────────────┤      ",
    "│ +model: String │      ",
    "├────────────────┤      ",
    "│ +start: void   │      ",
    "└────────────────┘      ",
    "         ◆              ",
    "         └┐             ",
    "          │             ",
    "┌──────────────────┐    ",
    "│ Engine           │    ",
    "├──────────────────┤    ",
    "│ +horsepower: int │    ",
    "├──────────────────┤    ",
    "│ +rev: void       │    ",
    "└──────────────────┘    ",
    "                        ",
    "                        ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Composition (*--) sample" {
  assert_text_parity(
    class_composition_sample_source(),
    class_composition_sample_expected_ascii(),
    class_composition_sample_expected_unicode(),
  )
}


///|
fn class_aggregation_o_sample_source() -> String {
  "classDiagram\n  class University {\n    +String name\n  }\n  class Department {\n    +String faculty\n  }\n  University o-- Department"
}

///|
fn class_aggregation_o_sample_expected_ascii() -> String {
  [
    "+---------------+       ",
    "| University    |       ",
    "+---------------+       ",
    "| +name: String |       ",
    "+---------------+       ",
    "        o               ",
    "        ---             ",
    "          |             ",
    "+------------------+    ",
    "| Department       |    ",
    "+------------------+    ",
    "| +faculty: String |    ",
    "+------------------+    ",
    "                        ",
    "                        ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_aggregation_o_sample_expected_unicode() -> String {
  [
    "┌───────────────┐       ",
    "│ University    │       ",
    "├───────────────┤       ",
    "│ +name: String │       ",
    "└───────────────┘       ",
    "        ◇               ",
    "        └─┐             ",
    "          │             ",
    "┌──────────────────┐    ",
    "│ Department       │    ",
    "├──────────────────┤    ",
    "│ +faculty: String │    ",
    "└──────────────────┘    ",
    "                        ",
    "                        ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Aggregation (o--) sample" {
  assert_text_parity(
    class_aggregation_o_sample_source(),
    class_aggregation_o_sample_expected_ascii(),
    class_aggregation_o_sample_expected_unicode(),
  )
}


///|
fn class_association_sample_source() -> String {
  "classDiagram\n  class Customer {\n    +String name\n  }\n  class Order {\n    +int orderId\n  }\n  Customer --> Order"
}

///|
fn class_association_sample_expected_ascii() -> String {
  [
    "+---------------+    ",
    "| Customer      |    ",
    "+---------------+    ",
    "| +name: String |    ",
    "+---------------+    ",
    "        |            ",
    "        |            ",
    "        v            ",
    "+---------------+    ",
    "| Order         |    ",
    "+---------------+    ",
    "| +orderId: int |    ",
    "+---------------+    ",
    "                     ",
    "                     ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_association_sample_expected_unicode() -> String {
  [
    "┌───────────────┐    ",
    "│ Customer      │    ",
    "├───────────────┤    ",
    "│ +name: String │    ",
    "└───────────────┘    ",
    "        │            ",
    "        │            ",
    "        ▼            ",
    "┌───────────────┐    ",
    "│ Order         │    ",
    "├───────────────┤    ",
    "│ +orderId: int │    ",
    "└───────────────┘    ",
    "                     ",
    "                     ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Association (-->) sample" {
  assert_text_parity(
    class_association_sample_source(),
    class_association_sample_expected_ascii(),
    class_association_sample_expected_unicode(),
  )
}



///|
fn class_dependency_sample_source() -> String {
  "classDiagram\n  class Service {\n    +process() void\n  }\n  class Repository {\n    +find() Object\n  }\n  Service ..> Repository"
}

///|
fn class_dependency_sample_expected_ascii() -> String {
  [
    "+----------------+    ",
    "| Service        |    ",
    "+----------------+    ",
    "|                |    ",
    "+----------------+    ",
    "| +process: void |    ",
    "+----------------+    ",
    "         :            ",
    "        ..            ",
    "        v             ",
    "+---------------+     ",
    "| Repository    |     ",
    "+---------------+     ",
    "|               |     ",
    "+---------------+     ",
    "| +find: Object |     ",
    "+---------------+     ",
    "                      ",
    "                      ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_dependency_sample_expected_unicode() -> String {
  [
    "┌────────────────┐    ",
    "│ Service        │    ",
    "├────────────────┤    ",
    "│                │    ",
    "├────────────────┤    ",
    "│ +process: void │    ",
    "└────────────────┘    ",
    "         ┊            ",
    "        ┌┘            ",
    "        ▼             ",
    "┌───────────────┐     ",
    "│ Repository    │     ",
    "├───────────────┤     ",
    "│               │     ",
    "├───────────────┤     ",
    "│ +find: Object │     ",
    "└───────────────┘     ",
    "                      ",
    "                      ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Dependency (..>) sample" {
  assert_text_parity(
    class_dependency_sample_source(),
    class_dependency_sample_expected_ascii(),
    class_dependency_sample_expected_unicode(),
  )
}


///|
fn class_realization_sample_source() -> String {
  "classDiagram\n  class Flyable {\n    <<interface>>\n    +fly() void\n  }\n  class Bird {\n    +fly() void\n    +sing() void\n  }\n  Bird ..|> Flyable"
}

///|
fn class_realization_sample_expected_ascii() -> String {
  [
    "+---------------+    ",
    "| <<interface>> |    ",
    "| Flyable       |    ",
    "+---------------+    ",
    "|               |    ",
    "+---------------+    ",
    "| +fly: void    |    ",
    "+---------------+    ",
    "        ^            ",
    "       ..            ",
    "       :             ",
    "+-------------+      ",
    "| Bird        |      ",
    "+-------------+      ",
    "|             |      ",
    "+-------------+      ",
    "| +fly: void  |      ",
    "| +sing: void |      ",
    "+-------------+      ",
    "                     ",
    "                     ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_realization_sample_expected_unicode() -> String {
  [
    "┌───────────────┐    ",
    "│ <<interface>> │    ",
    "│ Flyable       │    ",
    "├───────────────┤    ",
    "│               │    ",
    "├───────────────┤    ",
    "│ +fly: void    │    ",
    "└───────────────┘    ",
    "        △            ",
    "       ┌┘            ",
    "       ┊             ",
    "┌─────────────┐      ",
    "│ Bird        │      ",
    "├─────────────┤      ",
    "│             │      ",
    "├─────────────┤      ",
    "│ +fly: void  │      ",
    "│ +sing: void │      ",
    "└─────────────┘      ",
    "                     ",
    "                     ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Realization (..|>) sample" {
  assert_text_parity(
    class_realization_sample_source(),
    class_realization_sample_expected_ascii(),
    class_realization_sample_expected_unicode(),
  )
}


///|
fn class_all_6_relationship_types_sample_source() -> String {
  "classDiagram\n  A <|-- B : inheritance\n  C *-- D : composition\n  E o-- F : aggregation\n  G --> H : association\n  I ..> J : dependency\n  K ..|> L : realization"
}

///|
fn class_all_6_relationship_types_sample_expected_ascii() -> String {
  [
    "+---+    +---+    +---+    +---+    +---+    +---+    ",
    "| A |    | C |    | E |    | G |    | I |    | L |    ",
    "+---+    +---+    +---+    +---+    +---+    +---+    ",
    "  ^        *        o        |        :        ^      ",
    "erita composit aggregat associat dependen realization ",
    "  |        |        |        v        v        :      ",
    "+---+    +---+    +---+    +---+    +---+    +---+    ",
    "| B |    | D |    | F |    | H |    | J |    | K |    ",
    "+---+    +---+    +---+    +---+    +---+    +---+    ",
    "                                                      ",
    "                                                      ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_all_6_relationship_types_sample_expected_unicode() -> String {
  [
    "┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ",
    "│ A │    │ C │    │ E │    │ G │    │ I │    │ L │    ",
    "└───┘    └───┘    └───┘    └───┘    └───┘    └───┘    ",
    "  △        ◆        ◇        │        ┊        △      ",
    "erita composit aggregat associat dependen realization ",
    "  │        │        │        ▼        ▼        ┊      ",
    "┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ",
    "│ B │    │ D │    │ F │    │ H │    │ J │    │ K │    ",
    "└───┘    └───┘    └───┘    └───┘    └───┘    └───┘    ",
    "                                                      ",
    "                                                      ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: All 6 Relationship Types sample" {
  assert_text_parity(
    class_all_6_relationship_types_sample_source(),
    class_all_6_relationship_types_sample_expected_ascii(),
    class_all_6_relationship_types_sample_expected_unicode(),
  )
}


///|
fn class_relationship_labels_sample_source() -> String {
  "classDiagram\n  class Teacher {\n    +String name\n  }\n  class Student {\n    +String name\n  }\n  class Course {\n    +String title\n  }\n  Teacher --> Course : teaches\n  Student --> Course : enrolled in"
}

///|
fn class_relationship_labels_sample_expected_ascii() -> String {
  [
    "+---------------+    +---------------+    ",
    "| Teacher       |    | Student       |    ",
    "+---------------+    +---------------+    ",
    "| +name: String |    | +name: String |    ",
    "+---------------+    +---------------+    ",
    "        |                    |            ",
    "     teac---- enrolled in ----            ",
    "         v                                ",
    "+----------------+                        ",
    "| Course         |                        ",
    "+----------------+                        ",
    "| +title: String |                        ",
    "+----------------+                        ",
    "                                          ",
    "                                          ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_relationship_labels_sample_expected_unicode() -> String {
  [
    "┌───────────────┐    ┌───────────────┐    ",
    "│ Teacher       │    │ Student       │    ",
    "├───────────────┤    ├───────────────┤    ",
    "│ +name: String │    │ +name: String │    ",
    "└───────────────┘    └───────────────┘    ",
    "        │                    │            ",
    "     teac┌─── enrolled in ───┘            ",
    "         ▼                                ",
    "┌────────────────┐                        ",
    "│ Course         │                        ",
    "├────────────────┤                        ",
    "│ +title: String │                        ",
    "└────────────────┘                        ",
    "                                          ",
    "                                          ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Relationship Labels sample" {
  assert_text_parity(
    class_relationship_labels_sample_source(),
    class_relationship_labels_sample_expected_ascii(),
    class_relationship_labels_sample_expected_unicode(),
  )
}


///|
fn class_design_pattern_observer_sample_source() -> String {
  "classDiagram\n  class Subject {\n    <<interface>>\n    +attach(Observer) void\n    +detach(Observer) void\n    +notify() void\n  }\n  class Observer {\n    <<interface>>\n    +update() void\n  }\n  class EventEmitter {\n    -List~Observer~ observers\n    +attach(Observer) void\n    +detach(Observer) void\n    +notify() void\n  }\n  class Logger {\n    +update() void\n  }\n  class Alerter {\n    +update() void\n  }\n  Subject <|.. EventEmitter\n  Observer <|.. Logger\n  Observer <|.. Alerter\n  EventEmitter --> Observer"
}

///|
fn class_design_pattern_observer_sample_expected_ascii() -> String {
  [
    "+---------------+                         ",
    "| <<interface>> |                         ",
    "| Subject       |                         ",
    "+---------------+                         ",
    "|               |                         ",
    "+---------------+                         ",
    "| +attach: void |                         ",
    "| +detach: void |                         ",
    "| +notify: void |                         ",
    "+---------------+                         ",
    "        ^                                 ",
    "        ........                          ",
    "               :                          ",
    "+----------------------------+            ",
    "| EventEmitter               |            ",
    "+----------------------------+            ",
    "| -observers: List~Observer~ |            ",
    "+----------------------------+            ",
    "| +attach: void              |            ",
    "| +detach: void              |            ",
    "| +notify: void              |            ",
    "+----------------------------+            ",
    "               |                          ",
    "        --------                          ",
    "        v                                 ",
    "+---------------+                         ",
    "| <<interface>> |                         ",
    "| Observer      |                         ",
    "+---------------+                         ",
    "|               |                         ",
    "+---------------+                         ",
    "| +update: void |                         ",
    "+---------------+                         ",
    "        ^                                 ",
    "        ......................            ",
    "        :                    :            ",
    "+---------------+    +---------------+    ",
    "| Logger        |    | Alerter       |    ",
    "+---------------+    +---------------+    ",
    "|               |    |               |    ",
    "+---------------+    +---------------+    ",
    "| +update: void |    | +update: void |    ",
    "+---------------+    +---------------+    ",
    "                                          ",
    "                                          ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_design_pattern_observer_sample_expected_unicode() -> String {
  [
    "┌───────────────┐                         ",
    "│ <<interface>> │                         ",
    "│ Subject       │                         ",
    "├───────────────┤                         ",
    "│               │                         ",
    "├───────────────┤                         ",
    "│ +attach: void │                         ",
    "│ +detach: void │                         ",
    "│ +notify: void │                         ",
    "└───────────────┘                         ",
    "        △                                 ",
    "        └╌╌╌╌╌╌┐                          ",
    "               ┊                          ",
    "┌────────────────────────────┐            ",
    "│ EventEmitter               │            ",
    "├────────────────────────────┤            ",
    "│ -observers: List~Observer~ │            ",
    "├────────────────────────────┤            ",
    "│ +attach: void              │            ",
    "│ +detach: void              │            ",
    "│ +notify: void              │            ",
    "└────────────────────────────┘            ",
    "               │                          ",
    "        ┌──────┘                          ",
    "        ▼                                 ",
    "┌───────────────┐                         ",
    "│ <<interface>> │                         ",
    "│ Observer      │                         ",
    "├───────────────┤                         ",
    "│               │                         ",
    "├───────────────┤                         ",
    "│ +update: void │                         ",
    "└───────────────┘                         ",
    "        △                                 ",
    "        └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐            ",
    "        ┊                    ┊            ",
    "┌───────────────┐    ┌───────────────┐    ",
    "│ Logger        │    │ Alerter       │    ",
    "├───────────────┤    ├───────────────┤    ",
    "│               │    │               │    ",
    "├───────────────┤    ├───────────────┤    ",
    "│ +update: void │    │ +update: void │    ",
    "└───────────────┘    └───────────────┘    ",
    "                                          ",
    "                                          ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Design Pattern — Observer sample" {
  assert_text_parity(
    class_design_pattern_observer_sample_source(),
    class_design_pattern_observer_sample_expected_ascii(),
    class_design_pattern_observer_sample_expected_unicode(),
  )
}


///|
fn class_mvc_architecture_sample_source() -> String {
  "classDiagram\n  class Model {\n    -data Map\n    +getData() Map\n    +setData(key, val) void\n    +notify() void\n  }\n  class View {\n    -model Model\n    +render() void\n    +update() void\n  }\n  class Controller {\n    -model Model\n    -view View\n    +handleInput(event) void\n    +updateModel(data) void\n  }\n  Controller --> Model : updates\n  Controller --> View : refreshes\n  View --> Model : reads\n  Model ..> View : notifies"
}

///|
fn class_mvc_architecture_sample_expected_ascii() -> String {
  [
    "+--------------------+    ",
    "| Controller         |    ",
    "+--------------------+    ",
    "| -Model: model      |    ",
    "| -View: view        |    ",
    "+--------------------+    ",
    "| +handleInput: void |    ",
    "| +updateModel: void |    ",
    "+--------------------+    ",
    "           |              ",
    "       upda|es            ",
    "         v |              ",
    "+----------|-----+        ",
    "| Model    |     |        ",
    "+----------|-----+        ",
    "| -Map: dat|     |        ",
    "+--- refreshes --+        ",
    "| +getDa|a: Map  |        ",
    "| +setDa|a: void |        ",
    "| +notif|: void  |        ",
    "+-------|--------+        ",
    "        |:                ",
    "    notifies              ",
    "        v                 ",
    "+---------------+         ",
    "| View          |         ",
    "+---------------+         ",
    "| -Model: model |         ",
    "+---------------+         ",
    "| +render: void |         ",
    "| +update: void |         ",
    "+---------------+         ",
    "                          ",
    "                          ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_mvc_architecture_sample_expected_unicode() -> String {
  [
    "┌────────────────────┐    ",
    "│ Controller         │    ",
    "├────────────────────┤    ",
    "│ -Model: model      │    ",
    "│ -View: view        │    ",
    "├────────────────────┤    ",
    "│ +handleInput: void │    ",
    "│ +updateModel: void │    ",
    "└────────────────────┘    ",
    "           │              ",
    "       upda│es            ",
    "         ▼ │              ",
    "┌──────────│─────┐        ",
    "│ Model    │     │        ",
    "├──────────│─────┤        ",
    "│ -Map: dat│     │        ",
    "├─── refreshes ──┤        ",
    "│ +getDa│a: Map  │        ",
    "│ +setDa│a: void │        ",
    "│ +notif│: void  │        ",
    "└───────│────────┘        ",
    "        │┊                ",
    "    notifies              ",
    "        ▼                 ",
    "┌───────────────┐         ",
    "│ View          │         ",
    "├───────────────┤         ",
    "│ -Model: model │         ",
    "├───────────────┤         ",
    "│ +render: void │         ",
    "│ +update: void │         ",
    "└───────────────┘         ",
    "                          ",
    "                          ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: MVC Architecture sample" {
  assert_text_parity(
    class_mvc_architecture_sample_source(),
    class_mvc_architecture_sample_expected_ascii(),
    class_mvc_architecture_sample_expected_unicode(),
  )
}


///|
fn class_full_hierarchy_sample_source() -> String {
  "classDiagram\n  class Animal {\n    <<abstract>>\n    +String name\n    +int age\n    +eat() void\n    +sleep() void\n  }\n  class Mammal {\n    +bool warmBlooded\n    +nurse() void\n  }\n  class Bird {\n    +bool canFly\n    +layEggs() void\n  }\n  class Dog {\n    +String breed\n    +bark() void\n  }\n  class Cat {\n    +bool isIndoor\n    +purr() void\n  }\n  class Parrot {\n    +String vocabulary\n    +speak() void\n  }\n  Animal <|-- Mammal\n  Animal <|-- Bird\n  Mammal <|-- Dog\n  Mammal <|-- Cat\n  Bird <|-- Parrot"
}

///|
fn class_full_hierarchy_sample_expected_ascii() -> String {
  [
    "+---------------+                                                       ",
    "| <<abstract>>  |                                                       ",
    "| Animal        |                                                       ",
    "+---------------+                                                       ",
    "| +name: String |                                                       ",
    "| +age: int     |                                                       ",
    "+---------------+                                                       ",
    "| +eat: void    |                                                       ",
    "| +sleep: void  |                                                       ",
    "+---------------+                                                       ",
    "        ^                                                               ",
    "        ----------------------------                                    ",
    "           |                       |                                    ",
    "+--------------------+    +----------------+                            ",
    "| Mammal             |    | Bird           |                            ",
    "+--------------------+    +----------------+                            ",
    "| +warmBlooded: bool |    | +canFly: bool  |                            ",
    "+--------------------+    +----------------+                            ",
    "| +nurse: void       |    | +layEggs: void |                            ",
    "+--------------------+    +----------------+                            ",
    "           ^                       ^                                    ",
    "         -----------------------   ----------------------               ",
    "         |                     |                        |               ",
    "+----------------+    +-----------------+    +---------------------+    ",
    "| Dog            |    | Cat             |    | Parrot              |    ",
    "+----------------+    +-----------------+    +---------------------+    ",
    "| +breed: String |    | +isIndoor: bool |    | +vocabulary: String |    ",
    "+----------------+    +-----------------+    +---------------------+    ",
    "| +bark: void    |    | +purr: void     |    | +speak: void        |    ",
    "+----------------+    +-----------------+    +---------------------+    ",
    "                                                                        ",
    "                                                                        ",
  ]
  .iter()
  .join("\n")
}

///|
fn class_full_hierarchy_sample_expected_unicode() -> String {
  [
    "┌───────────────┐                                                       ",
    "│ <<abstract>>  │                                                       ",
    "│ Animal        │                                                       ",
    "├───────────────┤                                                       ",
    "│ +name: String │                                                       ",
    "│ +age: int     │                                                       ",
    "├───────────────┤                                                       ",
    "│ +eat: void    │                                                       ",
    "│ +sleep: void  │                                                       ",
    "└───────────────┘                                                       ",
    "        △                                                               ",
    "        └──────────────────────────┐                                    ",
    "           │                       │                                    ",
    "┌────────────────────┐    ┌────────────────┐                            ",
    "│ Mammal             │    │ Bird           │                            ",
    "├────────────────────┤    ├────────────────┤                            ",
    "│ +warmBlooded: bool │    │ +canFly: bool  │                            ",
    "├────────────────────┤    ├────────────────┤                            ",
    "│ +nurse: void       │    │ +layEggs: void │                            ",
    "└────────────────────┘    └────────────────┘                            ",
    "           △                       △                                    ",
    "         ┌─└───────────────────┐   └────────────────────┐               ",
    "         │                     │                        │               ",
    "┌────────────────┐    ┌─────────────────┐    ┌─────────────────────┐    ",
    "│ Dog            │    │ Cat             │    │ Parrot              │    ",
    "├────────────────┤    ├─────────────────┤    ├─────────────────────┤    ",
    "│ +breed: String │    │ +isIndoor: bool │    │ +vocabulary: String │    ",
    "├────────────────┤    ├─────────────────┤    ├─────────────────────┤    ",
    "│ +bark: void    │    │ +purr: void     │    │ +speak: void        │    ",
    "└────────────────┘    └─────────────────┘    └─────────────────────┘    ",
    "                                                                        ",
    "                                                                        ",
  ]
  .iter()
  .join("\n")
}

///|
test "ASCII/Unicode parity regression: Class: Full Hierarchy sample" {
  assert_text_parity(
    class_full_hierarchy_sample_source(),
    class_full_hierarchy_sample_expected_ascii(),
    class_full_hierarchy_sample_expected_unicode(),
  )
}
