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
