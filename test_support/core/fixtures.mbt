///|
/// Public type `CorpusCase`.
pub struct CorpusCase {
  name : String
  input : String
  header : String
  supported_by_moonbit : Bool
  padding_x : Int
  padding_y : Int
  direction : String?
  expected_node_count : Int?
  expected_edge_count : Int?
  expected_ascii : String?
  expected_unicode : String?
  expected_svg_fragments : Array[String]
} derive(Eq, Show, ToJson)

///|
/// Public function `corpus_cases`.
pub fn corpus_cases() -> Array[CorpusCase] {
  [
    {
      name: "ampersand_lhs",
      input: (
        #|graph LR
        #|A --> B & C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+\n  |\n  |\n  |\n  |\n  |\n  |       +---+\n  |       |   |\n  +------>| C |\n          |   |\n          +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└─┬─┘     └───┘\n  │\n  │\n  │\n  │\n  │\n  │       ┌───┐\n  │       │   │\n  └──────►│ C │\n          │   │\n          └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "ampersand_lhs_and_rhs",
      input: (
        #|graph LR
        #|A & B --> C & D
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(4),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |--+->| C |\n|   |  |  |   |\n+---+  |  +---+\n  |    |\n  |    |\n  +----+\n  |    |\n  |    |\n+---+  |  +---+\n|   |  |  |   |\n| B |--+->| D |\n|   |     |   |\n+---+     +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├──┬─►│ C │\n│   │  │  │   │\n└─┬─┘  │  └───┘\n  │    │\n  │    │\n  ├────┤\n  │    │\n  │    │\n┌─┴─┐  │  ┌───┐\n│   │  │  │   │\n│ B ├──┴─►│ D │\n│   │     │   │\n└───┘     └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "ampersand_rhs",
      input: (
        #|graph LR
        #|A & B --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| C |\n|   |     |   |\n+---+     +---+\n            ^\n            |\n            |\n            |\n            |\n+---+       |\n|   |       |\n| B |-------+\n|   |\n+---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ C │\n│   │     │   │\n└───┘     └───┘\n            ▲\n            │\n            │\n            │\n            │\n┌───┐       │\n│   │       │\n│ B ├───────┘\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "ampersand_without_edge",
      input: (
        #|graph LR
        #|A & B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+---+\n|   |\n| A |\n|   |\n+---+\n\n\n\n\n\n+---+\n|   |\n| B |\n|   |\n+---+",
      ),
      expected_unicode: Some(
        "┌───┐\n│   │\n│ A │\n│   │\n└───┘\n\n\n\n\n\n┌───┐\n│   │\n│ B │\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "back_reference_from_child",
      input: (
        #|graph LR
        #|A --> B --> C --> A
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |---->| C |\n|   |     |   |     |   |\n+---+     +---+     +---+\n  ^                   |\n  +-------------------+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├────►│ C │\n│   │     │   │     │   │\n└───┘     └───┘     └─┬─┘\n  ▲                   │\n  └───────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "backlink_from_bottom",
      input: (
        #|graph LR
        #|A --> B
        #|B --> C
        #|A --> C
        #|B --> D
        #|C --> D
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(5),
      expected_ascii: Some(
        "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |---->| D |\n|   |     |   |     |   |\n+---+     +---+     +---+\n  |         |         ^\n  |         |         |\n  |         |         |\n  |         |         |\n  |         v         |\n  |       +---+       |\n  |       |   |       |\n  +------>| C |-------+\n          |   |\n          +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├────►│ D │\n│   │     │   │     │   │\n└─┬─┘     └─┬─┘     └───┘\n  │         │         ▲\n  │         │         │\n  │         │         │\n  │         │         │\n  │         ▼         │\n  │       ┌───┐       │\n  │       │   │       │\n  └──────►│ C ├───────┘\n          │   │\n          └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "backlink_from_top",
      input: (
        #|graph LR
        #|A --> B
        #|B --> C
        #|A --> C
        #|B --> D
        #|D --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(5),
      expected_ascii: Some(
        "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |--+->| D |\n|   |     |   |  |  |   |\n+---+     +---+  |  +---+\n  |         |    |\n  |         |    |\n  |         +----+\n  |         |\n  |         v\n  |       +---+\n  |       |   |\n  +------>| C |\n          |   |\n          +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├──┬─►┤ D │\n│   │     │   │  │  │   │\n└─┬─┘     └─┬─┘  │  └───┘\n  │         │    │\n  │         │    │\n  │         ├────┘\n  │         │\n  │         ▼\n  │       ┌───┐\n  │       │   │\n  └──────►│ C │\n          │   │\n          └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "backlink_with_short_y_padding",
      input: (
        #|graph LR
        #|A --> B & C
        #|B --> C & D
        #|D --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 3,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(5),
      expected_ascii: Some(
        "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |--+->| D |\n|   |     |   |  |  |   |\n+---+     +---+  |  +---+\n  |         |    |\n  |         +----+\n  |         v\n  |       +---+\n  |       |   |\n  +------>| C |\n          |   |\n          +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├──┬─►┤ D │\n│   │     │   │  │  │   │\n└─┬─┘     └─┬─┘  │  └───┘\n  │         │    │\n  │         ├────┘\n  │         ▼\n  │       ┌───┐\n  │       │   │\n  └──────►│ C │\n          │   │\n          └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_all_relationships",
      input: (
        #|classDiagram
        #|  A <|-- B : inherits
        #|  C *-- D : owns
        #|  E o-- F : has
        #|  G --> H : uses
        #|  I ..> J : depends
        #|  K ..|> L : implements
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(12),
      expected_edge_count: Some(6),
      expected_ascii: Some(
        "+---+    +---+    +---+    +---+    +---+    +---+\n| A |    | C |    | E |    | G |    | I |    | L |\n+---+    +---+    +---+    +---+    +---+    +---+\n  ^        *        o        |        :        ^\nherits   owns      has     uses    depend implements\n  |        |        |        v        v        :\n+---+    +---+    +---+    +---+    +---+    +---+\n| B |    | D |    | F |    | H |    | J |    | K |\n+---+    +---+    +---+    +---+    +---+    +---+",
      ),
      expected_unicode: Some(
        "┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐\n│ A │    │ C │    │ E │    │ G │    │ I │    │ L │\n└───┘    └───┘    └───┘    └───┘    └───┘    └───┘\n  △        ◆        ◇        │        ┊        △\nherits   owns      has     uses    depend implements\n  │        │        │        ▼        ▼        ┊\n┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐\n│ B │    │ D │    │ F │    │ H │    │ J │    │ K │\n└───┘    └───┘    └───┘    └───┘    └───┘    └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_annotation",
      input: (
        #|classDiagram
        #|  class Shape {
        #|    <<abstract>>
        #|    +draw() void
        #|  }
        #|  class Circle {
        #|    +radius int
        #|    +draw() void
        #|  }
        #|  Shape <|-- Circle
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+--------------+\n| <<abstract>> |\n| Shape        |\n+--------------+\n|              |\n+--------------+\n| +draw: void  |\n+--------------+\n        ^\n        |\n        |\n+--------------+\n| Circle       |\n+--------------+\n| +int: radius |\n+--------------+\n| +draw: void  |\n+--------------+",
      ),
      expected_unicode: Some(
        "┌──────────────┐\n│ <<abstract>> │\n│ Shape        │\n├──────────────┤\n│              │\n├──────────────┤\n│ +draw: void  │\n└──────────────┘\n        △\n        │\n        │\n┌──────────────┐\n│ Circle       │\n├──────────────┤\n│ +int: radius │\n├──────────────┤\n│ +draw: void  │\n└──────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_association",
      input: (
        #|classDiagram
        #|  Student --> Course : enrolls
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+---------+\n| Student |\n+---------+\n     |\n  enrolls\n     v\n+--------+\n| Course |\n+--------+",
      ),
      expected_unicode: Some(
        "┌─────────┐\n│ Student │\n└─────────┘\n     │\n  enrolls\n     ▼\n┌────────┐\n│ Course │\n└────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_basic",
      input: (
        #|classDiagram
        #|  class Animal {
        #|    +String name
        #|    +eat() void
        #|  }
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+---------------+\n| Animal        |\n+---------------+\n| +name: String |\n+---------------+\n| +eat: void    |\n+---------------+",
      ),
      expected_unicode: Some(
        "┌───────────────┐\n│ Animal        │\n├───────────────┤\n│ +name: String │\n├───────────────┤\n│ +eat: void    │\n└───────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_dependency",
      input: (
        #|classDiagram
        #|  Client ..> Server : uses
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+--------+\n| Client |\n+--------+\n     :\n   uses\n     v\n+--------+\n| Server |\n+--------+",
      ),
      expected_unicode: Some(
        "┌────────┐\n│ Client │\n└────────┘\n     ┊\n   uses\n     ▼\n┌────────┐\n│ Server │\n└────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_inheritance",
      input: (
        #|classDiagram
        #|  Animal <|-- Dog
        #|  Animal : +String name
        #|  Dog : +bark() void
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+---------------+\n| Animal        |\n+---------------+\n| +name: String |\n+---------------+\n        ^\n       --\n       |\n+-------------+\n| Dog         |\n+-------------+\n|             |\n+-------------+\n| +bark: void |\n+-------------+",
      ),
      expected_unicode: Some(
        "┌───────────────┐\n│ Animal        │\n├───────────────┤\n│ +name: String │\n└───────────────┘\n        △\n       ┌┘\n       │\n┌─────────────┐\n│ Dog         │\n├─────────────┤\n│             │\n├─────────────┤\n│ +bark: void │\n└─────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "cls_methods",
      input: (
        #|classDiagram
        #|  class BankAccount {
        #|    +String owner
        #|    -int balance
        #|    +deposit(int amount) void
        #|    +withdraw(int amount) bool
        #|    -validate() bool
        #|  }
        #|
      ),
      header: "classdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+-----------------+\n| BankAccount     |\n+-----------------+\n| +owner: String  |\n| -balance: int   |\n+-----------------+\n| +deposit: void  |\n| +withdraw: bool |\n| -validate: bool |\n+-----------------+",
      ),
      expected_unicode: Some(
        "┌─────────────────┐\n│ BankAccount     │\n├─────────────────┤\n│ +owner: String  │\n│ -balance: int   │\n├─────────────────┤\n│ +deposit: void  │\n│ +withdraw: bool │\n│ -validate: bool │\n└─────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "comments",
      input: (
        #|graph LR
        #|%% This is a comment
        #|A --> B
        #|%% Another comment
        #|B --> C
        #|A --> C
        #|%% Final comment
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+\n  |         |\n  |         |\n  |         |\n  |         |\n  |         v\n  |       +---+\n  |       |   |\n  +------>| C |\n          |   |\n          +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└─┬─┘     └─┬─┘\n  │         │\n  │         │\n  │         │\n  │         │\n  │         ▼\n  │       ┌───┐\n  │       │   │\n  └──────►│ C │\n          │   │\n          └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "custom_padding",
      input: (
        #|graph LR
        #|A --> B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 2,
      padding_y: 1,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+---+  +---+\n|   |  |   |\n| A |->| B |\n|   |  |   |\n+---+  +---+",
      ),
      expected_unicode: Some(
        "┌───┐  ┌───┐\n│   │  │   │\n│ A ├─►│ B │\n│   │  │   │\n└───┘  └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "duplicate_labels",
      input: (
        #|graph TD
        #|A[Server] --> B[Client]
        #|C[Server] --> D[Client]
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(4),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+--------+     +--------+\n|        |     |        |\n| Server |     | Server |\n|        |     |        |\n+--------+     +--------+\n     |              |\n     |              |\n     |              |\n     |              |\n     v              v\n+--------+     +--------+\n|        |     |        |\n| Client |     | Client |\n|        |     |        |\n+--------+     +--------+",
      ),
      expected_unicode: Some(
        "┌────────┐     ┌────────┐\n│        │     │        │\n│ Server │     │ Server │\n│        │     │        │\n└────┬───┘     └────┬───┘\n     │              │\n     │              │\n     │              │\n     │              │\n     ▼              ▼\n┌────────┐     ┌────────┐\n│        │     │        │\n│ Client │     │ Client │\n│        │     │        │\n└────────┘     └────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "er_attributes",
      input: (
        #|erDiagram
        #|  CUSTOMER {
        #|    string name PK
        #|    string email UK
        #|    int age
        #|  }
        #|  ORDER {
        #|    int id PK
        #|    string status
        #|  }
        #|  CUSTOMER ||--o{ ORDER : places
        #|
      ),
      header: "erdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+-----------------+      +------------------+\n| CUSTOMER        |      | ORDER            |\n+-----------------+places+------------------+\n| PK string name  |||--o{| PK int id        |\n| UK string email |      |    string status |\n|    int age      |      +------------------+\n+-----------------+",
      ),
      expected_unicode: Some(
        "┌─────────────────┐      ┌──────────────────┐\n│ CUSTOMER        │      │ ORDER            │\n├─────────────────┤places├──────────────────┤\n│ PK string name  │║───o╟│ PK int id        │\n│ UK string email │      │    string status │\n│    int age      │      └──────────────────┘\n└─────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "er_basic",
      input: (
        #|erDiagram
        #|  CUSTOMER ||--o{ ORDER : places
        #|
      ),
      header: "erdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+----------+places+-------+\n| CUSTOMER |||--o{| ORDER |\n+----------+      +-------+",
      ),
      expected_unicode: Some(
        "┌──────────┐places┌───────┐\n│ CUSTOMER │║───o╟│ ORDER │\n└──────────┘      └───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "er_identifying",
      input: (
        #|erDiagram
        #|  PERSON ||--o{ ADDRESS : lives_at
        #|  PERSON {
        #|    string name PK
        #|  }
        #|  ADDRESS {
        #|    string street
        #|    string city
        #|  }
        #|
      ),
      header: "erdiagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+----------------+      +------------------+\n| PERSON         |lives_| ADDRESS          |\n+----------------+||--o{+------------------+\n| PK string name |      |    string street |\n+----------------+      |    string city   |\n                        +------------------+",
      ),
      expected_unicode: Some(
        "┌────────────────┐      ┌──────────────────┐\n│ PERSON         │lives_│ ADDRESS          │\n├────────────────┤║───o╟├──────────────────┤\n│ PK string name │      │    string street │\n└────────────────┘      │    string city   │\n                        └──────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "flowchart_tb_simple",
      input: (
        #|flowchart TB
        #|    A --> B
        #|    B --> C
        #|
      ),
      header: "flowchart",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TB"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+\n|   |\n| A |\n|   |\n+---+\n  |\n  |\n  |\n  |\n  v\n+---+\n|   |\n| B |\n|   |\n+---+\n  |\n  |\n  |\n  |\n  v\n+---+\n|   |\n| C |\n|   |\n+---+",
      ),
      expected_unicode: Some(
        "┌───┐\n│   │\n│ A │\n│   │\n└─┬─┘\n  │\n  │\n  │\n  │\n  ▼\n┌───┐\n│   │\n│ B │\n│   │\n└─┬─┘\n  │\n  │\n  │\n  │\n  ▼\n┌───┐\n│   │\n│ C │\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "graph_bt_direction",
      input: (
        #|graph BT
        #|  A --> B --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("BT"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+\n|   |\n| C |\n|   |\n+---+\n  ^\n  |\n  |\n  |\n  |\n+---+\n|   |\n| B |\n|   |\n+---+\n  ^\n  |\n  |\n  |\n  |\n+---+\n|   |\n| A |\n|   |\n+---+",
      ),
      expected_unicode: Some(
        "┌───┐\n│   │\n│ C │\n│   │\n└───┘\n  ▲\n  │\n  │\n  │\n  │\n┌─┴─┐\n│   │\n│ B │\n│   │\n└───┘\n  ▲\n  │\n  │\n  │\n  │\n┌─┴─┐\n│   │\n│ A │\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "graph_tb_direction",
      input: (
        #|graph TB
        #|subgraph one
        #|    A --> B
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TB"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+-------+\n|  one  |\n|       |\n|       |\n| +---+ |\n| |   | |\n| | A | |\n| |   | |\n| +---+ |\n|   |   |\n|   |   |\n|   |   |\n|   |   |\n|   v   |\n| +---+ |\n| |   | |\n| | B | |\n| |   | |\n| +---+ |\n|       |\n+-------+",
      ),
      expected_unicode: Some(
        "┌───────┐\n│  one  │\n│       │\n│       │\n│ ┌───┐ │\n│ │   │ │\n│ │ A │ │\n│ │   │ │\n│ └─┬─┘ │\n│   │   │\n│   │   │\n│   │   │\n│   │   │\n│   ▼   │\n│ ┌───┐ │\n│ │   │ │\n│ │ B │ │\n│ │   │ │\n│ └───┘ │\n│       │\n└───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "nested_subgraphs_with_labels",
      input: (
        #|graph TD
        #|A[Web Server] --> B[API Gateway]
        #|B --> C[Web Server]
        #|subgraph Frontend
        #|A
        #|end
        #|subgraph Backend
        #|B
        #|C
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+-----------------+\n|    Frontend     |\n|                 |\n|                 |\n| +-------------+ |\n| |             | |\n| |  Web Server | |\n| |             | |\n| +-------------+ |\n|        |        |\n+--------|--------+\n         |\n         |\n         |\n+--------|--------+\n|     Backend     |\n|        |        |\n|        v        |\n| +-------------+ |\n| |             | |\n| | API Gateway | |\n| |             | |\n| +-------------+ |\n|        |        |\n|        |        |\n|        |        |\n|        |        |\n|        v        |\n| +-------------+ |\n| |             | |\n| |  Web Server | |\n| |             | |\n| +-------------+ |\n|                 |\n+-----------------+",
      ),
      expected_unicode: Some(
        "┌─────────────────┐\n│    Frontend     │\n│                 │\n│                 │\n│ ┌─────────────┐ │\n│ │             │ │\n│ │  Web Server │ │\n│ │             │ │\n│ └──────┬──────┘ │\n│        │        │\n└────────┼────────┘\n         │\n         │\n         │\n┌────────┼────────┐\n│     Backend     │\n│        │        │\n│        ▼        │\n│ ┌─────────────┐ │\n│ │             │ │\n│ │ API Gateway │ │\n│ │             │ │\n│ └──────┬──────┘ │\n│        │        │\n│        │        │\n│        │        │\n│        │        │\n│        ▼        │\n│ ┌─────────────┐ │\n│ │             │ │\n│ │  Web Server │ │\n│ │             │ │\n│ └─────────────┘ │\n│                 │\n└─────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "preserve_order_of_definition",
      input: (
        #|graph LR
        #|A
        #|B
        #|B --> A
        #|A --> A
        #|B --> C
        #|C --> A
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(4),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |<-+--| C |\n|   |  |  |   |\n+---+  |  +---+\n  ^    |    ^\n  |    |    |\n  +----+    |\n  |         |\n  |         |\n+---+       |\n|   |       |\n| B |-------+\n|   |\n+---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├◄─┬──┤ C │\n│   │  │  │   │\n└───┘  │  └───┘\n  ▲    │    ▲\n  │    │    │\n  ├────┘    │\n  │         │\n  │         │\n┌─┴─┐       │\n│   │       │\n│ B ├───────┘\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "self_reference",
      input: (
        #|graph LR
        #|A --> A
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(1),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+---+\n|   |\n| A |-+\n|   | |\n+---+ |\n  ^   |\n  +---+",
      ),
      expected_unicode: Some(
        "┌───┐\n│   │\n│ A ├─┐\n│   │ │\n└───┘ │\n  ▲   │\n  └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "self_reference_with_edge",
      input: (
        #|graph LR
        #|A --> A & B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |--+->| B |\n|   |  |  |   |\n+---+  |  +---+\n  ^    |\n  +----+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├──┬─►│ B │\n│   │  │  │   │\n└───┘  │  └───┘\n  ▲    │\n  └────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "seq_basic",
      input: (
        #|sequenceDiagram
        #|  Alice->>Bob: Hello Bob
        #|  Bob-->>Alice: Hi Alice
        #|
      ),
      header: "sequencediagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        " +-------+       +-----+\n | Alice |       | Bob |\n +-------+       +-----+\n     |              |\n     |  Hello Bob   |\n     |-------------->\n     |              |\n     |  Hi Alice    |\n     <..............|\n     |              |\n +-------+       +-----+\n | Alice |       | Bob |\n +-------+       +-----+",
      ),
      expected_unicode: Some(
        " ┌───────┐       ┌─────┐\n │ Alice │       │ Bob │\n └───┬───┘       └──┬──┘\n     │              │\n     │  Hello Bob   │\n     │──────────────▶\n     │              │\n     │  Hi Alice    │\n     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌│\n     │              │\n ┌───┴───┐       ┌──┴──┐\n │ Alice │       │ Bob │\n └───────┘       └─────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "seq_multiple_messages",
      input: (
        #|sequenceDiagram
        #|  Alice->>Bob: Hello
        #|  Bob->>Charlie: Forward
        #|  Charlie-->>Bob: Reply
        #|  Bob-->>Alice: Done
        #|
      ),
      header: "sequencediagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(4),
      expected_ascii: Some(
        " +-------+   +-----+    +---------+\n | Alice |   | Bob |    | Charlie |\n +-------+   +-----+    +---------+\n     |          |            |\n     |  Hello   |            |\n     |---------->            |\n     |          |            |\n     |          |  Forward   |\n     |          |------------>\n     |          |            |\n     |          |   Reply    |\n     |          <............|\n     |          |            |\n     |  Done    |            |\n     <..........|            |\n     |          |            |\n +-------+   +-----+    +---------+\n | Alice |   | Bob |    | Charlie |\n +-------+   +-----+    +---------+",
      ),
      expected_unicode: Some(
        " ┌───────┐   ┌─────┐    ┌─────────┐\n │ Alice │   │ Bob │    │ Charlie │\n └───┬───┘   └──┬──┘    └────┬────┘\n     │          │            │\n     │  Hello   │            │\n     │──────────▶            │\n     │          │            │\n     │          │  Forward   │\n     │          │────────────▶\n     │          │            │\n     │          │   Reply    │\n     │          ◀╌╌╌╌╌╌╌╌╌╌╌╌│\n     │          │            │\n     │  Done    │            │\n     ◀╌╌╌╌╌╌╌╌╌╌│            │\n     │          │            │\n ┌───┴───┐   ┌──┴──┐    ┌────┴────┐\n │ Alice │   │ Bob │    │ Charlie │\n └───────┘   └─────┘    └─────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "seq_self_message",
      input: (
        #|sequenceDiagram
        #|  Alice->>Alice: Think
        #|  Alice->>Bob: Result
        #|
      ),
      header: "sequencediagram",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        " +-------+    +-----+\n | Alice |    | Bob |\n +-------+    +-----+\n     |           |\n     +---+       |\n     |   | Think |\n     <---+       |\n     |           |\n     |  Result   |\n     |----------->\n     |           |\n +-------+    +-----+\n | Alice |    | Bob |\n +-------+    +-----+",
      ),
      expected_unicode: Some(
        " ┌───────┐    ┌─────┐\n │ Alice │    │ Bob │\n └───┬───┘    └──┬──┘\n     │           │\n     ├───┐       │\n     │   │ Think │\n     ◀───┘       │\n     │           │\n     │  Result   │\n     │───────────▶\n     │           │\n ┌───┴───┐    ┌──┴──┐\n │ Alice │    │ Bob │\n └───────┘    └─────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "single_node",
      input: (
        #|graph LR
        #|A
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some("+---+\n|   |\n| A |\n|   |\n+---+"),
      expected_unicode: Some(
        "┌───┐\n│   │\n│ A │\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "single_node_longer_name",
      input: (
        #|graph LR
        #|LongerName
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+------------+\n|            |\n| LongerName |\n|            |\n+------------+",
      ),
      expected_unicode: Some(
        "┌────────────┐\n│            │\n│ LongerName │\n│            │\n└────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_complex_mixed",
      input: (
        #|graph LR
        #|Start
        #|subgraph Processing
        #|    A --> B
        #|    B --> C
        #|end
        #|subgraph Storage
        #|    D
        #|    E
        #|end
        #|Start --> A
        #|C --> D
        #|C --> E
        #|D --> End
        #|E --> End
        #|End
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(7),
      expected_edge_count: Some(7),
      expected_ascii: Some(
        "            +---------------------------+ +-------+\n            |        Processing         | |Storage|\n            |                           | |       |\n            |                           | |       |\n+-------+   | +---+     +---+     +---+ | | +---+ |   +-----+\n|       |   | |   |     |   |     |   | | | |   | |   |     |\n| Start |---->| A |---->| B |---->| C |---->| D |---->| End |\n|       |   | |   |     |   |     |   | | | |   | |   |     |\n+-------+   | +---+     +---+     +---+ | | +---+ |   +-----+\n            |                       |   | |       |      ^\n            +-----------------------|---+ |       |      |\n                                    |     |       |      |\n                                    |     |       |      |\n                                    |     |       |      |\n                                    |     | +---+ |      |\n                                    |     | |   | |      |\n                                    +------>| E |--------+\n                                          | |   | |\n                                          | +---+ |\n                                          |       |\n                                          +-------+",
      ),
      expected_unicode: Some(
        "            ┌───────────────────────────┐ ┌───────┐\n            │        Processing         │ │Storage│\n            │                           │ │       │\n            │                           │ │       │\n┌───────┐   │ ┌───┐     ┌───┐     ┌───┐ │ │ ┌───┐ │   ┌─────┐\n│       │   │ │   │     │   │     │   │ │ │ │   │ │   │     │\n│ Start ├───┼►│ A ├────►│ B ├────►│ C ├─┼─┼►│ D ├─┼──►│ End │\n│       │   │ │   │     │   │     │   │ │ │ │   │ │   │     │\n└───────┘   │ └───┘     └───┘     └─┬─┘ │ │ └───┘ │   └─────┘\n            │                       │   │ │       │      ▲\n            └───────────────────────┼───┘ │       │      │\n                                    │     │       │      │\n                                    │     │       │      │\n                                    │     │       │      │\n                                    │     │ ┌───┐ │      │\n                                    │     │ │   │ │      │\n                                    └─────┼►│ E ├─┼──────┘\n                                          │ │   │ │\n                                          │ └───┘ │\n                                          │       │\n                                          └───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_complex_nested",
      input: (
        #|graph LR
        #|subgraph outer
        #|    A
        #|    subgraph inner
        #|        B
        #|    end
        #|    C
        #|end
        #|D
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+-----------+\n|   outer   |\n|           |\n|           |\n|   +---+   |\n|   |   |   |\n|   | A |   |\n|   |   |   |\n|   +---+   |\n|           |\n| +-------+ |\n| | inner | |\n| |       | |\n| |       | |\n| | +---+ | |\n| | |   | | |\n| | | B | | |\n| | |   | | |\n| | +---+ | |\n| |       | |\n| +-------+ |\n|           |\n|           |\n|           |\n|   +---+   |\n|   |   |   |\n|   | C |   |\n|   |   |   |\n|   +---+   |\n|           |\n+-----------+\n\n\n\n    +---+\n    |   |\n    | D |\n    |   |\n    +---+",
      ),
      expected_unicode: Some(
        "┌───────────┐\n│   outer   │\n│           │\n│           │\n│   ┌───┐   │\n│   │   │   │\n│   │ A │   │\n│   │   │   │\n│   └───┘   │\n│           │\n│ ┌───────┐ │\n│ │ inner │ │\n│ │       │ │\n│ │       │ │\n│ │ ┌───┐ │ │\n│ │ │   │ │ │\n│ │ │ B │ │ │\n│ │ │   │ │ │\n│ │ └───┘ │ │\n│ │       │ │\n│ └───────┘ │\n│           │\n│           │\n│           │\n│   ┌───┐   │\n│   │   │   │\n│   │ C │   │\n│   │   │   │\n│   └───┘   │\n│           │\n└───────────┘\n\n\n\n    ┌───┐\n    │   │\n    │ D │\n    │   │\n    └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_empty",
      input: (
        #|graph LR
        #|subgraph one
        #|end
        #|A --> B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└───┘     └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_mixed_nodes",
      input: (
        #|graph LR
        #|X
        #|subgraph one
        #|    A --> B
        #|end
        #|Y
        #|X --> A
        #|B --> Y
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "        +-----------------+\n        |       one       |\n        |                 |\n        |                 |\n+---+   | +---+     +---+ |   +---+\n|   |   | |   |     |   | |   |   |\n| X |---->| A |---->| B |---->| Y |\n|   |   | |   |     |   | |   |   |\n+---+   | +---+     +---+ |   +---+\n        |                 |\n        +-----------------+",
      ),
      expected_unicode: Some(
        "        ┌─────────────────┐\n        │       one       │\n        │                 │\n        │                 │\n┌───┐   │ ┌───┐     ┌───┐ │   ┌───┐\n│   │   │ │   │     │   │ │   │   │\n│ X ├───┼►│ A ├────►│ B ├─┼──►│ Y │\n│   │   │ │   │     │   │ │   │   │\n└───┘   │ └───┘     └───┘ │   └───┘\n        │                 │\n        └─────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_mixed_nodes_td",
      input: (
        #|graph TD
        #|X
        #|subgraph one
        #|    A --> B
        #|end
        #|Y
        #|X --> A
        #|B --> Y
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(4),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "  +---+\n  |   |\n  | X |\n  |   |\n  +---+\n    |\n    |\n    |\n    |\n    |\n+---|---+\n|  one  |\n|   |   |\n|   v   |\n| +---+ |\n| |   | |\n| | A | |\n| |   | |\n| +---+ |\n|   |   |\n|   |   |\n|   |   |\n|   |   |\n|   v   |\n| +---+ |\n| |   | |\n| | B | |\n| |   | |\n| +---+ |\n|   |   |\n+---|---+\n    |\n    |\n    v\n  +---+\n  |   |\n  | Y |\n  |   |\n  +---+",
      ),
      expected_unicode: Some(
        "  ┌───┐\n  │   │\n  │ X │\n  │   │\n  └─┬─┘\n    │\n    │\n    │\n    │\n    │\n┌───┼───┐\n│  one  │\n│   │   │\n│   ▼   │\n│ ┌───┐ │\n│ │   │ │\n│ │ A │ │\n│ │   │ │\n│ └─┬─┘ │\n│   │   │\n│   │   │\n│   │   │\n│   │   │\n│   ▼   │\n│ ┌───┐ │\n│ │   │ │\n│ │ B │ │\n│ │   │ │\n│ └─┬─┘ │\n│   │   │\n└───┼───┘\n    │\n    │\n    ▼\n  ┌───┐\n  │   │\n  │ Y │\n  │   │\n  └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_multiple_edges",
      input: (
        #|graph LR
        #|subgraph one
        #|    A --> B
        #|    A --> C
        #|end
        #|subgraph two
        #|    D --> E
        #|end
        #|B --> D
        #|C --> E
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(5),
      expected_edge_count: Some(5),
      expected_ascii: Some(
        "+-----------------+ +-------+\n|       one       | |  two  |\n|                 | |       |\n|                 | |       |\n| +---+     +---+ | | +---+ |\n| |   |     |   | | | |   | |\n| | A |---->| B |---->| D | |\n| |   |     |   | | | |   | |\n| +---+     +---+ | | +---+ |\n|   |             | |   |   |\n|   |             | |   |   |\n|   |             | |   |   |\n|   |             | |   |   |\n|   |             | |   v   |\n|   |       +---+ | | +---+ |\n|   |       |   | | | |   | |\n|   +------>| C |---->| E | |\n|           |   | | | |   | |\n|           +---+ | | +---+ |\n|                 | |       |\n+-----------------+ +-------+",
      ),
      expected_unicode: Some(
        "┌─────────────────┐ ┌───────┐\n│       one       │ │  two  │\n│                 │ │       │\n│                 │ │       │\n│ ┌───┐     ┌───┐ │ │ ┌───┐ │\n│ │   │     │   │ │ │ │   │ │\n│ │ A ├────►│ B ├─┼─┼►│ D │ │\n│ │   │     │   │ │ │ │   │ │\n│ └─┬─┘     └───┘ │ │ └─┬─┘ │\n│   │             │ │   │   │\n│   │             │ │   │   │\n│   │             │ │   │   │\n│   │             │ │   │   │\n│   │             │ │   ▼   │\n│   │       ┌───┐ │ │ ┌───┐ │\n│   │       │   │ │ │ │   │ │\n│   └──────►│ C ├─┼─┼►│ E │ │\n│           │   │ │ │ │   │ │\n│           └───┘ │ │ └───┘ │\n│                 │ │       │\n└─────────────────┘ └───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_multiple_nodes",
      input: (
        #|graph LR
        #|subgraph one
        #|    A --> B
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+-----------------+\n|       one       |\n|                 |\n|                 |\n| +---+     +---+ |\n| |   |     |   | |\n| | A |---->| B | |\n| |   |     |   | |\n| +---+     +---+ |\n|                 |\n+-----------------+",
      ),
      expected_unicode: Some(
        "┌─────────────────┐\n│       one       │\n│                 │\n│                 │\n│ ┌───┐     ┌───┐ │\n│ │   │     │   │ │\n│ │ A ├────►│ B │ │\n│ │   │     │   │ │\n│ └───┘     └───┘ │\n│                 │\n└─────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_nested",
      input: (
        #|graph LR
        #|subgraph outer
        #|    subgraph inner
        #|        A
        #|    end
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+-----------+\n|   outer   |\n|           |\n|           |\n| +-------+ |\n| | inner | |\n| |       | |\n| |       | |\n| | +---+ | |\n| | |   | | |\n| | | A | | |\n| | |   | | |\n| | +---+ | |\n| |       | |\n| +-------+ |\n|           |\n+-----------+",
      ),
      expected_unicode: Some(
        "┌───────────┐\n│   outer   │\n│           │\n│           │\n│ ┌───────┐ │\n│ │ inner │ │\n│ │       │ │\n│ │       │ │\n│ │ ┌───┐ │ │\n│ │ │   │ │ │\n│ │ │ A │ │ │\n│ │ │   │ │ │\n│ │ └───┘ │ │\n│ │       │ │\n│ └───────┘ │\n│           │\n└───────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_nested_with_external",
      input: (
        #|graph LR
        #|X
        #|subgraph outer
        #|    A
        #|    subgraph inner
        #|        B --> C
        #|    end
        #|    A --> B
        #|end
        #|X --> A
        #|C --> Y
        #|Y
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(5),
      expected_edge_count: Some(4),
      expected_ascii: Some(
        "        +-----------------------------+\n        |            outer            |\n        |                             |\n        |                             |\n        |         +-----------------+ |\n        |         |      inner      | |\n        |         |                 | |\n        |         |                 | |\n+---+   | +---+   | +---+     +---+ | | +---+\n|   |   | |   |   | |   |     |   | | | |   |\n| X |---->| A |---->| B |---->| C |---->| Y |\n|   |   | |   |   | |   |     |   | | | |   |\n+---+   | +---+   | +---+     +---+ | | +---+\n        |         |                 | |\n        |         +-----------------+ |\n        |                             |\n        +-----------------------------+",
      ),
      expected_unicode: Some(
        "        ┌─────────────────────────────┐\n        │            outer            │\n        │                             │\n        │                             │\n        │         ┌─────────────────┐ │\n        │         │      inner      │ │\n        │         │                 │ │\n        │         │                 │ │\n┌───┐   │ ┌───┐   │ ┌───┐     ┌───┐ │ │ ┌───┐\n│   │   │ │   │   │ │   │     │   │ │ │ │   │\n│ X ├───┼►│ A ├───┼►│ B ├────►│ C ├─┼─┼►│ Y │\n│   │   │ │   │   │ │   │     │   │ │ │ │   │\n└───┘   │ └───┘   │ └───┘     └───┘ │ │ └───┘\n        │         │                 │ │\n        │         └─────────────────┘ │\n        │                             │\n        └─────────────────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_node_outside_lr",
      input: (
        #|graph LR
        #|X
        #|subgraph one
        #|    A --> B
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "        +-----------------+\n        |       one       |\n        |                 |\n        |                 |\n+---+   | +---+     +---+ |\n|   |   | |   |     |   | |\n| X |   | | A |---->| B | |\n|   |   | |   |     |   | |\n+---+   | +---+     +---+ |\n        |                 |\n        +-----------------+",
      ),
      expected_unicode: Some(
        "        ┌─────────────────┐\n        │       one       │\n        │                 │\n        │                 │\n┌───┐   │ ┌───┐     ┌───┐ │\n│   │   │ │   │     │   │ │\n│ X │   │ │ A ├────►│ B │ │\n│   │   │ │   │     │   │ │\n└───┘   │ └───┘     └───┘ │\n        │                 │\n        └─────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_single_node",
      input: (
        #|graph LR
        #|subgraph one
        #|    A
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+-------+\n|  one  |\n|       |\n|       |\n| +---+ |\n| |   | |\n| | A | |\n| |   | |\n| +---+ |\n|       |\n+-------+",
      ),
      expected_unicode: Some(
        "┌───────┐\n│  one  │\n│       │\n│       │\n│ ┌───┐ │\n│ │   │ │\n│ │ A │ │\n│ │   │ │\n│ └───┘ │\n│       │\n└───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_td_direction",
      input: (
        #|graph TD
        #|subgraph one
        #|    A --> B
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+-------+\n|  one  |\n|       |\n|       |\n| +---+ |\n| |   | |\n| | A | |\n| |   | |\n| +---+ |\n|   |   |\n|   |   |\n|   |   |\n|   |   |\n|   v   |\n| +---+ |\n| |   | |\n| | B | |\n| |   | |\n| +---+ |\n|       |\n+-------+",
      ),
      expected_unicode: Some(
        "┌───────┐\n│  one  │\n│       │\n│       │\n│ ┌───┐ │\n│ │   │ │\n│ │ A │ │\n│ │   │ │\n│ └─┬─┘ │\n│   │   │\n│   │   │\n│   │   │\n│   │   │\n│   ▼   │\n│ ┌───┐ │\n│ │   │ │\n│ │ B │ │\n│ │   │ │\n│ └───┘ │\n│       │\n└───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_td_multiple",
      input: (
        #|graph TD
        #|subgraph Frontend
        #|    UI --> API
        #|end
        #|subgraph Backend
        #|    API --> Database
        #|    API --> Cache
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("TD"),
      expected_node_count: Some(4),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "+--------------+\n|  Frontend    |\n|              |\n|              |\n| +----------+ |\n| |          | |\n| |    UI    | |\n| |          | |\n| +----------+ |\n|       |      |\n|       |      |\n|       |      |\n|       |      |\n|       v      |\n| +----------+ |\n| |          | |\n| |   API    |---------+\n| |          | |       |\n| +----------+ |       |\n|       |      |       |\n+-------|------+       |\n        |              |\n        |              |\n        |              |\n+-------|--------------|-----+\n|       |  Backend     |     |\n|       |              |     |\n|       v              v     |\n| +----------+     +-------+ |\n| |          |     |       | |\n| | Database |     | Cache | |\n| |          |     |       | |\n| +----------+     +-------+ |\n|                            |\n+----------------------------+",
      ),
      expected_unicode: Some(
        "┌──────────────┐\n│  Frontend    │\n│              │\n│              │\n│ ┌──────────┐ │\n│ │          │ │\n│ │    UI    │ │\n│ │          │ │\n│ └─────┬────┘ │\n│       │      │\n│       │      │\n│       │      │\n│       │      │\n│       ▼      │\n│ ┌──────────┐ │\n│ │          │ │\n│ │   API    ├─┼───────┐\n│ │          │ │       │\n│ └─────┬────┘ │       │\n│       │      │       │\n└───────┼──────┘       │\n        │              │\n        │              │\n        │              │\n┌───────┼──────────────┼─────┐\n│       │  Backend     │     │\n│       │              │     │\n│       ▼              ▼     │\n│ ┌──────────┐     ┌───────┐ │\n│ │          │     │       │ │\n│ │ Database │     │ Cache │ │\n│ │          │     │       │ │\n│ └──────────┘     └───────┘ │\n│                            │\n└────────────────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_td_multiple_paddingy",
      input: (
        #|graph TD
        #|subgraph Frontend
        #|    UI --> API
        #|end
        #|subgraph Backend
        #|    API --> Database
        #|    API --> Cache
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 3,
      padding_y: 3,
      direction: Some("TD"),
      expected_node_count: Some(4),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "+--------------+\n|  Frontend    |\n|              |\n|              |\n| +----------+ |\n| |          | |\n| |    UI    | |\n| |          | |\n| +----------+ |\n|       |      |\n|       |      |\n|       v      |\n| +----------+ |\n| |          | |\n| |   API    |-------+\n| |          | |     |\n| +----------+ |     |\n|       |      |     |\n+-------|------+     |\n        |            |\n+-------|------------|-----+\n|       | Backend    |     |\n|       |            |     |\n|       v            v     |\n| +----------+   +-------+ |\n| |          |   |       | |\n| | Database |   | Cache | |\n| |          |   |       | |\n| +----------+   +-------+ |\n|                          |\n+--------------------------+",
      ),
      expected_unicode: Some(
        "┌──────────────┐\n│  Frontend    │\n│              │\n│              │\n│ ┌──────────┐ │\n│ │          │ │\n│ │    UI    │ │\n│ │          │ │\n│ └─────┬────┘ │\n│       │      │\n│       │      │\n│       ▼      │\n│ ┌──────────┐ │\n│ │          │ │\n│ │   API    ├─┼─────┐\n│ │          │ │     │\n│ └─────┬────┘ │     │\n│       │      │     │\n└───────┼──────┘     │\n        │            │\n┌───────┼────────────┼─────┐\n│       │ Backend    │     │\n│       │            │     │\n│       ▼            ▼     │\n│ ┌──────────┐   ┌───────┐ │\n│ │          │   │       │ │\n│ │ Database │   │ Cache │ │\n│ │          │   │       │ │\n│ └──────────┘   └───────┘ │\n│                          │\n└──────────────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_three_levels_nested",
      input: (
        #|graph LR
        #|subgraph level1
        #|    subgraph level2
        #|        subgraph level3
        #|            A
        #|        end
        #|    end
        #|end
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(1),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+---------------+\n|    level1     |\n|               |\n|               |\n| +-----------+ |\n| |  level2   | |\n| |           | |\n| |           | |\n| | +-------+ | |\n| | |level3 | | |\n| | |       | | |\n| | |       | | |\n| | | +---+ | | |\n| | | |   | | | |\n| | | | A | | | |\n| | | |   | | | |\n| | | +---+ | | |\n| | |       | | |\n| | +-------+ | |\n| |           | |\n| +-----------+ |\n|               |\n+---------------+",
      ),
      expected_unicode: Some(
        "┌───────────────┐\n│    level1     │\n│               │\n│               │\n│ ┌───────────┐ │\n│ │  level2   │ │\n│ │           │ │\n│ │           │ │\n│ │ ┌───────┐ │ │\n│ │ │level3 │ │ │\n│ │ │       │ │ │\n│ │ │       │ │ │\n│ │ │ ┌───┐ │ │ │\n│ │ │ │   │ │ │ │\n│ │ │ │ A │ │ │ │\n│ │ │ │   │ │ │ │\n│ │ │ └───┘ │ │ │\n│ │ │       │ │ │\n│ │ └───────┘ │ │\n│ │           │ │\n│ └───────────┘ │\n│               │\n└───────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_three_separate",
      input: (
        #|graph LR
        #|subgraph Frontend
        #|    UI
        #|end
        #|subgraph Backend
        #|    API
        #|end
        #|subgraph Database
        #|    DB
        #|end
        #|UI --> API
        #|API --> DB
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+--------+ +---------+ +--------+\n|Frontend| | Backend | |Database|\n|        | |         | |        |\n|        | |         | |        |\n| +----+ | | +-----+ | | +----+ |\n| |    | | | |     | | | |    | |\n| | UI |---->| API |---->| DB | |\n| |    | | | |     | | | |    | |\n| +----+ | | +-----+ | | +----+ |\n|        | |         | |        |\n+--------+ +---------+ +--------+",
      ),
      expected_unicode: Some(
        "┌────────┐ ┌─────────┐ ┌────────┐\n│Frontend│ │ Backend │ │Database│\n│        │ │         │ │        │\n│        │ │         │ │        │\n│ ┌────┐ │ │ ┌─────┐ │ │ ┌────┐ │\n│ │    │ │ │ │     │ │ │ │    │ │\n│ │ UI ├─┼─┼►│ API ├─┼─┼►│ DB │ │\n│ │    │ │ │ │     │ │ │ │    │ │\n│ └────┘ │ │ └─────┘ │ │ └────┘ │\n│        │ │         │ │        │\n└────────┘ └─────────┘ └────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_two_separate",
      input: (
        #|graph LR
        #|subgraph one
        #|    A
        #|end
        #|subgraph two
        #|    B
        #|end
        #|A --> B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+-------+ +-------+\n|  one  | |  two  |\n|       | |       |\n|       | |       |\n| +---+ | | +---+ |\n| |   | | | |   | |\n| | A |---->| B | |\n| |   | | | |   | |\n| +---+ | | +---+ |\n|       | |       |\n+-------+ +-------+",
      ),
      expected_unicode: Some(
        "┌───────┐ ┌───────┐\n│  one  │ │  two  │\n│       │ │       │\n│       │ │       │\n│ ┌───┐ │ │ ┌───┐ │\n│ │   │ │ │ │   │ │\n│ │ A ├─┼─┼►│ B │ │\n│ │   │ │ │ │   │ │\n│ └───┘ │ │ └───┘ │\n│       │ │       │\n└───────┘ └───────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "subgraph_with_labels",
      input: (
        #|graph LR
        #|subgraph one
        #|    A -->|sends| B
        #|end
        #|subgraph two
        #|    C -->|receives| D
        #|end
        #|B -->|data| C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(3),
      expected_ascii: Some(
        "+-------------------+  +----------------------+\n|        one        |  |         two          |\n|                   |  |                      |\n|                   |  |                      |\n| +---+       +---+ |  | +---+          +---+ |\n| |   |       |   | |  | |   |          |   | |\n| | A |-sends>| B |data->| C |receives->| D | |\n| |   |       |   | |  | |   |          |   | |\n| +---+       +---+ |  | +---+          +---+ |\n|                   |  |                      |\n+-------------------+  +----------------------+",
      ),
      expected_unicode: Some(
        "┌───────────────────┐  ┌──────────────────────┐\n│        one        │  │         two          │\n│                   │  │                      │\n│                   │  │                      │\n│ ┌───┐       ┌───┐ │  │ ┌───┐          ┌───┐ │\n│ │   │       │   │ │  │ │   │          │   │ │\n│ │ A ├─sends►│ B ├data┼►│ C ├receives─►│ D │ │\n│ │   │       │   │ │  │ │   │          │   │ │\n│ └───┘       └───┘ │  │ └───┘          └───┘ │\n│                   │  │                      │\n└───────────────────┘  └──────────────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "three_nodes",
      input: (
        #|graph LR
        #|A --> B
        #|B --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |---->| C |\n|   |     |   |     |   |\n+---+     +---+     +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├────►│ C │\n│   │     │   │     │   │\n└───┘     └───┘     └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "three_nodes_single_line",
      input: (
        #|graph LR
        #|A --> B --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+     +---+\n|   |     |   |     |   |\n| A |---->| B |---->| C |\n|   |     |   |     |   |\n+---+     +---+     +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐     ┌───┐\n│   │     │   │     │   │\n│ A ├────►│ B ├────►│ C │\n│   │     │   │     │   │\n└───┘     └───┘     └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_layer_single_graph",
      input: (
        #|graph LR
        #|A --> B
        #|A --> C
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+\n  |\n  |\n  |\n  |\n  |\n  |       +---+\n  |       |   |\n  +------>| C |\n          |   |\n          +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└─┬─┘     └───┘\n  │\n  │\n  │\n  │\n  │\n  │       ┌───┐\n  │       │   │\n  └──────►│ C │\n          │   │\n          └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_layer_single_graph_longer_names",
      input: (
        #|graph LR
        #|ABC --> BCDEFG
        #|ABC --> CDEFGHI
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(3),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+-----+     +---------+\n|     |     |         |\n| ABC |---->|  BCDEFG |\n|     |     |         |\n+-----+     +---------+\n   |\n   |\n   |\n   |\n   |\n   |        +---------+\n   |        |         |\n   +------->| CDEFGHI |\n            |         |\n            +---------+",
      ),
      expected_unicode: Some(
        "┌─────┐     ┌─────────┐\n│     │     │         │\n│ ABC ├────►│  BCDEFG │\n│     │     │         │\n└──┬──┘     └─────────┘\n   │\n   │\n   │\n   │\n   │\n   │        ┌─────────┐\n   │        │         │\n   └───────►│ CDEFGHI │\n            │         │\n            └─────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_nodes_linked",
      input: (
        #|graph LR
        #|A --> B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└───┘     └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_nodes_longer_names",
      input: (
        #|graph LR
        #|LongerName1 --> LongerName2
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(1),
      expected_ascii: Some(
        "+-------------+     +-------------+\n|             |     |             |\n| LongerName1 |---->| LongerName2 |\n|             |     |             |\n+-------------+     +-------------+",
      ),
      expected_unicode: Some(
        "┌─────────────┐     ┌─────────────┐\n│             │     │             │\n│ LongerName1 ├────►│ LongerName2 │\n│             │     │             │\n└─────────────┘     └─────────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_root_nodes",
      input: (
        #|graph LR
        #|A --> B
        #|C --> D
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+---+     +---+\n|   |     |   |\n| A |---->| B |\n|   |     |   |\n+---+     +---+\n\n\n\n\n\n+---+     +---+\n|   |     |   |\n| C |---->| D |\n|   |     |   |\n+---+     +---+",
      ),
      expected_unicode: Some(
        "┌───┐     ┌───┐\n│   │     │   │\n│ A ├────►│ B │\n│   │     │   │\n└───┘     └───┘\n\n\n\n\n\n┌───┐     ┌───┐\n│   │     │   │\n│ C ├────►│ D │\n│   │     │   │\n└───┘     └───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_root_nodes_longer_names",
      input: (
        #|graph LR
        #|ABC --> BCDEFG
        #|CDEFGH --> DEF
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(4),
      expected_edge_count: Some(2),
      expected_ascii: Some(
        "+--------+     +--------+\n|        |     |        |\n|  ABC   |---->| BCDEFG |\n|        |     |        |\n+--------+     +--------+\n\n\n\n\n\n+--------+     +--------+\n|        |     |        |\n| CDEFGH |---->|  DEF   |\n|        |     |        |\n+--------+     +--------+",
      ),
      expected_unicode: Some(
        "┌────────┐     ┌────────┐\n│        │     │        │\n│  ABC   ├────►│ BCDEFG │\n│        │     │        │\n└────────┘     └────────┘\n\n\n\n\n\n┌────────┐     ┌────────┐\n│        │     │        │\n│ CDEFGH ├────►│  DEF   │\n│        │     │        │\n└────────┘     └────────┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
    {
      name: "two_single_root_nodes",
      input: (
        #|graph LR
        #|A
        #|B
        #|
      ),
      header: "graph",
      supported_by_moonbit: true,
      padding_x: 5,
      padding_y: 5,
      direction: Some("LR"),
      expected_node_count: Some(2),
      expected_edge_count: Some(0),
      expected_ascii: Some(
        "+---+\n|   |\n| A |\n|   |\n+---+\n\n\n\n\n\n+---+\n|   |\n| B |\n|   |\n+---+",
      ),
      expected_unicode: Some(
        "┌───┐\n│   │\n│ A │\n│   │\n└───┘\n\n\n\n\n\n┌───┐\n│   │\n│ B │\n│   │\n└───┘",
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
  ]
}

///|
/// Public function `supported_cases`.
pub fn supported_cases() -> Array[CorpusCase] {
  corpus_cases().filter(case_data => case_data.supported_by_moonbit)
}

///|
/// Public function `supported_ascii_cases`.
pub fn supported_ascii_cases() -> Array[CorpusCase] {
  supported_cases().filter(case_data => case_data.expected_ascii is Some(_))
}

///|
/// Public function `supported_unicode_cases`.
pub fn supported_unicode_cases() -> Array[CorpusCase] {
  supported_cases().filter(case_data => case_data.expected_unicode is Some(_))
}
