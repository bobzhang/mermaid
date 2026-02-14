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
}

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
        (
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
      ),
      expected_unicode: Some(
        (
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |--+->| C |
          #||   |  |  |   |
          #|+---+  |  +---+
          #|  |    |
          #|  |    |
          #|  +----+
          #|  |    |
          #|  |    |
          #|+---+  |  +---+
          #||   |  |  |   |
          #|| B |--+->| D |
          #||   |     |   |
          #|+---+     +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├──┬─►│ C │
          #|│   │  │  │   │
          #|└─┬─┘  │  └───┘
          #|  │    │
          #|  │    │
          #|  ├────┤
          #|  │    │
          #|  │    │
          #|┌─┴─┐  │  ┌───┐
          #|│   │  │  │   │
          #|│ B ├──┴─►│ D │
          #|│   │     │   │
          #|└───┘     └───┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |---->| C |
          #||   |     |   |
          #|+---+     +---+
          #|            ^
          #|            |
          #|            |
          #|            |
          #|            |
          #|+---+       |
          #||   |       |
          #|| B |-------+
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├────►│ C │
          #|│   │     │   │
          #|└───┘     └───┘
          #|            ▲
          #|            │
          #|            │
          #|            │
          #|            │
          #|┌───┐       │
          #|│   │       │
          #|│ B ├───────┘
          #|│   │
          #|└───┘
        ),
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
        (
          #|+---+
          #||   |
          #|| A |
          #||   |
          #|+---+
          #|
          #|
          #|
          #|
          #|
          #|+---+
          #||   |
          #|| B |
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐
          #|│   │
          #|│ A │
          #|│   │
          #|└───┘
          #|
          #|
          #|
          #|
          #|
          #|┌───┐
          #|│   │
          #|│ B │
          #|│   │
          #|└───┘
        ),
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
        (
          #|+---+     +---+     +---+
          #||   |     |   |     |   |
          #|| A |---->| B |---->| C |
          #||   |     |   |     |   |
          #|+---+     +---+     +---+
          #|  ^                   |
          #|  +-------------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐     ┌───┐
          #|│   │     │   │     │   │
          #|│ A ├────►│ B ├────►│ C │
          #|│   │     │   │     │   │
          #|└───┘     └───┘     └─┬─┘
          #|  ▲                   │
          #|  └───────────────────┘
        ),
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
        (
          #|+---+     +---+     +---+
          #||   |     |   |     |   |
          #|| A |---->| B |---->| D |
          #||   |     |   |     |   |
          #|+---+     +---+     +---+
          #|  |         |         ^
          #|  |         |         |
          #|  |         |         |
          #|  |         |         |
          #|  |         v         |
          #|  |       +---+       |
          #|  |       |   |       |
          #|  +------>| C |-------+
          #|          |   |
          #|          +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐     ┌───┐
          #|│   │     │   │     │   │
          #|│ A ├────►│ B ├────►│ D │
          #|│   │     │   │     │   │
          #|└─┬─┘     └─┬─┘     └───┘
          #|  │         │         ▲
          #|  │         │         │
          #|  │         │         │
          #|  │         │         │
          #|  │         ▼         │
          #|  │       ┌───┐       │
          #|  │       │   │       │
          #|  └──────►│ C ├───────┘
          #|          │   │
          #|          └───┘
        ),
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
        (
          #|+---+     +---+     +---+
          #||   |     |   |     |   |
          #|| A |---->| B |--+->| D |
          #||   |     |   |  |  |   |
          #|+---+     +---+  |  +---+
          #|  |         |    |
          #|  |         |    |
          #|  |         +----+
          #|  |         |
          #|  |         v
          #|  |       +---+
          #|  |       |   |
          #|  +------>| C |
          #|          |   |
          #|          +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐     ┌───┐
          #|│   │     │   │     │   │
          #|│ A ├────►│ B ├──┬─►┤ D │
          #|│   │     │   │  │  │   │
          #|└─┬─┘     └─┬─┘  │  └───┘
          #|  │         │    │
          #|  │         │    │
          #|  │         ├────┘
          #|  │         │
          #|  │         ▼
          #|  │       ┌───┐
          #|  │       │   │
          #|  └──────►│ C │
          #|          │   │
          #|          └───┘
        ),
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
        (
          #|+---+     +---+     +---+
          #||   |     |   |     |   |
          #|| A |---->| B |--+->| D |
          #||   |     |   |  |  |   |
          #|+---+     +---+  |  +---+
          #|  |         |    |
          #|  |         +----+
          #|  |         v
          #|  |       +---+
          #|  |       |   |
          #|  +------>| C |
          #|          |   |
          #|          +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐     ┌───┐
          #|│   │     │   │     │   │
          #|│ A ├────►│ B ├──┬─►┤ D │
          #|│   │     │   │  │  │   │
          #|└─┬─┘     └─┬─┘  │  └───┘
          #|  │         │    │
          #|  │         ├────┘
          #|  │         ▼
          #|  │       ┌───┐
          #|  │       │   │
          #|  └──────►│ C │
          #|          │   │
          #|          └───┘
        ),
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
        (
          #|+---+    +---+    +---+    +---+    +---+    +---+
          #|| A |    | C |    | E |    | G |    | I |    | L |
          #|+---+    +---+    +---+    +---+    +---+    +---+
          #|  ^        *        o        |        :        ^
          #|herits   owns      has     uses    depend implements
          #|  |        |        |        v        v        :
          #|+---+    +---+    +---+    +---+    +---+    +---+
          #|| B |    | D |    | F |    | H |    | J |    | K |
          #|+---+    +---+    +---+    +---+    +---+    +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
          #|│ A │    │ C │    │ E │    │ G │    │ I │    │ L │
          #|└───┘    └───┘    └───┘    └───┘    └───┘    └───┘
          #|  △        ◆        ◇        │        ┊        △
          #|herits   owns      has     uses    depend implements
          #|  │        │        │        ▼        ▼        ┊
          #|┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
          #|│ B │    │ D │    │ F │    │ H │    │ J │    │ K │
          #|└───┘    └───┘    └───┘    └───┘    └───┘    └───┘
        ),
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
        (
          #|+--------------+
          #|| <<abstract>> |
          #|| Shape        |
          #|+--------------+
          #||              |
          #|+--------------+
          #|| +draw: void  |
          #|+--------------+
          #|        ^
          #|        |
          #|        |
          #|+--------------+
          #|| Circle       |
          #|+--------------+
          #|| +int: radius |
          #|+--------------+
          #|| +draw: void  |
          #|+--------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌──────────────┐
          #|│ <<abstract>> │
          #|│ Shape        │
          #|├──────────────┤
          #|│              │
          #|├──────────────┤
          #|│ +draw: void  │
          #|└──────────────┘
          #|        △
          #|        │
          #|        │
          #|┌──────────────┐
          #|│ Circle       │
          #|├──────────────┤
          #|│ +int: radius │
          #|├──────────────┤
          #|│ +draw: void  │
          #|└──────────────┘
        ),
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
        (
          #|+---------+
          #|| Student |
          #|+---------+
          #|     |
          #|  enrolls
          #|     v
          #|+--------+
          #|| Course |
          #|+--------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────┐
          #|│ Student │
          #|└─────────┘
          #|     │
          #|  enrolls
          #|     ▼
          #|┌────────┐
          #|│ Course │
          #|└────────┘
        ),
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
        (
          #|+---------------+
          #|| Animal        |
          #|+---------------+
          #|| +name: String |
          #|+---------------+
          #|| +eat: void    |
          #|+---------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────────────┐
          #|│ Animal        │
          #|├───────────────┤
          #|│ +name: String │
          #|├───────────────┤
          #|│ +eat: void    │
          #|└───────────────┘
        ),
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
        (
          #|+--------+
          #|| Client |
          #|+--------+
          #|     :
          #|   uses
          #|     v
          #|+--------+
          #|| Server |
          #|+--------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌────────┐
          #|│ Client │
          #|└────────┘
          #|     ┊
          #|   uses
          #|     ▼
          #|┌────────┐
          #|│ Server │
          #|└────────┘
        ),
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
        (
          #|+---------------+
          #|| Animal        |
          #|+---------------+
          #|| +name: String |
          #|+---------------+
          #|        ^
          #|       --
          #|       |
          #|+-------------+
          #|| Dog         |
          #|+-------------+
          #||             |
          #|+-------------+
          #|| +bark: void |
          #|+-------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────────────┐
          #|│ Animal        │
          #|├───────────────┤
          #|│ +name: String │
          #|└───────────────┘
          #|        △
          #|       ┌┘
          #|       │
          #|┌─────────────┐
          #|│ Dog         │
          #|├─────────────┤
          #|│             │
          #|├─────────────┤
          #|│ +bark: void │
          #|└─────────────┘
        ),
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
        (
          #|+-----------------+
          #|| BankAccount     |
          #|+-----------------+
          #|| +owner: String  |
          #|| -balance: int   |
          #|+-----------------+
          #|| +deposit: void  |
          #|| +withdraw: bool |
          #|| -validate: bool |
          #|+-----------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────────────┐
          #|│ BankAccount     │
          #|├─────────────────┤
          #|│ +owner: String  │
          #|│ -balance: int   │
          #|├─────────────────┤
          #|│ +deposit: void  │
          #|│ +withdraw: bool │
          #|│ -validate: bool │
          #|└─────────────────┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |---->| B |
          #||   |     |   |
          #|+---+     +---+
          #|  |         |
          #|  |         |
          #|  |         |
          #|  |         |
          #|  |         v
          #|  |       +---+
          #|  |       |   |
          #|  +------>| C |
          #|          |   |
          #|          +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├────►│ B │
          #|│   │     │   │
          #|└─┬─┘     └─┬─┘
          #|  │         │
          #|  │         │
          #|  │         │
          #|  │         │
          #|  │         ▼
          #|  │       ┌───┐
          #|  │       │   │
          #|  └──────►│ C │
          #|          │   │
          #|          └───┘
        ),
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
        (
          #|+---+  +---+
          #||   |  |   |
          #|| A |->| B |
          #||   |  |   |
          #|+---+  +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐  ┌───┐
          #|│   │  │   │
          #|│ A ├─►│ B │
          #|│   │  │   │
          #|└───┘  └───┘
        ),
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
        (
          #|+--------+     +--------+
          #||        |     |        |
          #|| Server |     | Server |
          #||        |     |        |
          #|+--------+     +--------+
          #|     |              |
          #|     |              |
          #|     |              |
          #|     |              |
          #|     v              v
          #|+--------+     +--------+
          #||        |     |        |
          #|| Client |     | Client |
          #||        |     |        |
          #|+--------+     +--------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌────────┐     ┌────────┐
          #|│        │     │        │
          #|│ Server │     │ Server │
          #|│        │     │        │
          #|└────┬───┘     └────┬───┘
          #|     │              │
          #|     │              │
          #|     │              │
          #|     │              │
          #|     ▼              ▼
          #|┌────────┐     ┌────────┐
          #|│        │     │        │
          #|│ Client │     │ Client │
          #|│        │     │        │
          #|└────────┘     └────────┘
        ),
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
        (
          #|+-----------------+      +------------------+
          #|| CUSTOMER        |      | ORDER            |
          #|+-----------------+places+------------------+
          #|| PK string name  |||--o{| PK int id        |
          #|| UK string email |      |    string status |
          #||    int age      |      +------------------+
          #|+-----------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────────────┐      ┌──────────────────┐
          #|│ CUSTOMER        │      │ ORDER            │
          #|├─────────────────┤places├──────────────────┤
          #|│ PK string name  │║───o╟│ PK int id        │
          #|│ UK string email │      │    string status │
          #|│    int age      │      └──────────────────┘
          #|└─────────────────┘
        ),
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
        (
          #|+----------+places+-------+
          #|| CUSTOMER |||--o{| ORDER |
          #|+----------+      +-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌──────────┐places┌───────┐
          #|│ CUSTOMER │║───o╟│ ORDER │
          #|└──────────┘      └───────┘
        ),
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
        (
          #|+----------------+      +------------------+
          #|| PERSON         |lives_| ADDRESS          |
          #|+----------------+||--o{+------------------+
          #|| PK string name |      |    string street |
          #|+----------------+      |    string city   |
          #|                        +------------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌────────────────┐      ┌──────────────────┐
          #|│ PERSON         │lives_│ ADDRESS          │
          #|├────────────────┤║───o╟├──────────────────┤
          #|│ PK string name │      │    string street │
          #|└────────────────┘      │    string city   │
          #|                        └──────────────────┘
        ),
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
        (
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
          #|  |
          #|  |
          #|  |
          #|  |
          #|  v
          #|+---+
          #||   |
          #|| C |
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
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
          #|└─┬─┘
          #|  │
          #|  │
          #|  │
          #|  │
          #|  ▼
          #|┌───┐
          #|│   │
          #|│ C │
          #|│   │
          #|└───┘
        ),
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
        (
          #|+---+
          #||   |
          #|| C |
          #||   |
          #|+---+
          #|  ^
          #|  |
          #|  |
          #|  |
          #|  |
          #|+---+
          #||   |
          #|| B |
          #||   |
          #|+---+
          #|  ^
          #|  |
          #|  |
          #|  |
          #|  |
          #|+---+
          #||   |
          #|| A |
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐
          #|│   │
          #|│ C │
          #|│   │
          #|└───┘
          #|  ▲
          #|  │
          #|  │
          #|  │
          #|  │
          #|┌─┴─┐
          #|│   │
          #|│ B │
          #|│   │
          #|└───┘
          #|  ▲
          #|  │
          #|  │
          #|  │
          #|  │
          #|┌─┴─┐
          #|│   │
          #|│ A │
          #|│   │
          #|└───┘
        ),
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
        (
          #|+-------+
          #||  one  |
          #||       |
          #||       |
          #|| +---+ |
          #|| |   | |
          #|| | A | |
          #|| |   | |
          #|| +---+ |
          #||   |   |
          #||   |   |
          #||   |   |
          #||   |   |
          #||   v   |
          #|| +---+ |
          #|| |   | |
          #|| | B | |
          #|| |   | |
          #|| +---+ |
          #||       |
          #|+-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────┐
          #|│  one  │
          #|│       │
          #|│       │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ A │ │
          #|│ │   │ │
          #|│ └─┬─┘ │
          #|│   │   │
          #|│   │   │
          #|│   │   │
          #|│   │   │
          #|│   ▼   │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ B │ │
          #|│ │   │ │
          #|│ └───┘ │
          #|│       │
          #|└───────┘
        ),
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
        (
          #|+-----------------+
          #||    Frontend     |
          #||                 |
          #||                 |
          #|| +-------------+ |
          #|| |             | |
          #|| |  Web Server | |
          #|| |             | |
          #|| +-------------+ |
          #||        |        |
          #|+--------|--------+
          #|         |
          #|         |
          #|         |
          #|+--------|--------+
          #||     Backend     |
          #||        |        |
          #||        v        |
          #|| +-------------+ |
          #|| |             | |
          #|| | API Gateway | |
          #|| |             | |
          #|| +-------------+ |
          #||        |        |
          #||        |        |
          #||        |        |
          #||        |        |
          #||        v        |
          #|| +-------------+ |
          #|| |             | |
          #|| |  Web Server | |
          #|| |             | |
          #|| +-------------+ |
          #||                 |
          #|+-----------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────────────┐
          #|│    Frontend     │
          #|│                 │
          #|│                 │
          #|│ ┌─────────────┐ │
          #|│ │             │ │
          #|│ │  Web Server │ │
          #|│ │             │ │
          #|│ └──────┬──────┘ │
          #|│        │        │
          #|└────────┼────────┘
          #|         │
          #|         │
          #|         │
          #|┌────────┼────────┐
          #|│     Backend     │
          #|│        │        │
          #|│        ▼        │
          #|│ ┌─────────────┐ │
          #|│ │             │ │
          #|│ │ API Gateway │ │
          #|│ │             │ │
          #|│ └──────┬──────┘ │
          #|│        │        │
          #|│        │        │
          #|│        │        │
          #|│        │        │
          #|│        ▼        │
          #|│ ┌─────────────┐ │
          #|│ │             │ │
          #|│ │  Web Server │ │
          #|│ │             │ │
          #|│ └─────────────┘ │
          #|│                 │
          #|└─────────────────┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |<-+--| C |
          #||   |  |  |   |
          #|+---+  |  +---+
          #|  ^    |    ^
          #|  |    |    |
          #|  +----+    |
          #|  |         |
          #|  |         |
          #|+---+       |
          #||   |       |
          #|| B |-------+
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├◄─┬──┤ C │
          #|│   │  │  │   │
          #|└───┘  │  └───┘
          #|  ▲    │    ▲
          #|  │    │    │
          #|  ├────┘    │
          #|  │         │
          #|  │         │
          #|┌─┴─┐       │
          #|│   │       │
          #|│ B ├───────┘
          #|│   │
          #|└───┘
        ),
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
        (
          #|+---+
          #||   |
          #|| A |-+
          #||   | |
          #|+---+ |
          #|  ^   |
          #|  +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐
          #|│   │
          #|│ A ├─┐
          #|│   │ │
          #|└───┘ │
          #|  ▲   │
          #|  └───┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |--+->| B |
          #||   |  |  |   |
          #|+---+  |  +---+
          #|  ^    |
          #|  +----+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├──┬─►│ B │
          #|│   │  │  │   │
          #|└───┘  │  └───┘
          #|  ▲    │
          #|  └────┘
        ),
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
        (
          #| +-------+       +-----+
          #| | Alice |       | Bob |
          #| +-------+       +-----+
          #|     |              |
          #|     |  Hello Bob   |
          #|     |-------------->
          #|     |              |
          #|     |  Hi Alice    |
          #|     <..............|
          #|     |              |
          #| +-------+       +-----+
          #| | Alice |       | Bob |
          #| +-------+       +-----+
        ),
      ),
      expected_unicode: Some(
        (
          #| ┌───────┐       ┌─────┐
          #| │ Alice │       │ Bob │
          #| └───┬───┘       └──┬──┘
          #|     │              │
          #|     │  Hello Bob   │
          #|     │──────────────▶
          #|     │              │
          #|     │  Hi Alice    │
          #|     ◀╌╌╌╌╌╌╌╌╌╌╌╌╌╌│
          #|     │              │
          #| ┌───┴───┐       ┌──┴──┐
          #| │ Alice │       │ Bob │
          #| └───────┘       └─────┘
        ),
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
        (
          #| +-------+   +-----+    +---------+
          #| | Alice |   | Bob |    | Charlie |
          #| +-------+   +-----+    +---------+
          #|     |          |            |
          #|     |  Hello   |            |
          #|     |---------->            |
          #|     |          |            |
          #|     |          |  Forward   |
          #|     |          |------------>
          #|     |          |            |
          #|     |          |   Reply    |
          #|     |          <............|
          #|     |          |            |
          #|     |  Done    |            |
          #|     <..........|            |
          #|     |          |            |
          #| +-------+   +-----+    +---------+
          #| | Alice |   | Bob |    | Charlie |
          #| +-------+   +-----+    +---------+
        ),
      ),
      expected_unicode: Some(
        (
          #| ┌───────┐   ┌─────┐    ┌─────────┐
          #| │ Alice │   │ Bob │    │ Charlie │
          #| └───┬───┘   └──┬──┘    └────┬────┘
          #|     │          │            │
          #|     │  Hello   │            │
          #|     │──────────▶            │
          #|     │          │            │
          #|     │          │  Forward   │
          #|     │          │────────────▶
          #|     │          │            │
          #|     │          │   Reply    │
          #|     │          ◀╌╌╌╌╌╌╌╌╌╌╌╌│
          #|     │          │            │
          #|     │  Done    │            │
          #|     ◀╌╌╌╌╌╌╌╌╌╌│            │
          #|     │          │            │
          #| ┌───┴───┐   ┌──┴──┐    ┌────┴────┐
          #| │ Alice │   │ Bob │    │ Charlie │
          #| └───────┘   └─────┘    └─────────┘
        ),
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
        (
          #| +-------+    +-----+
          #| | Alice |    | Bob |
          #| +-------+    +-----+
          #|     |           |
          #|     +---+       |
          #|     |   | Think |
          #|     <---+       |
          #|     |           |
          #|     |  Result   |
          #|     |----------->
          #|     |           |
          #| +-------+    +-----+
          #| | Alice |    | Bob |
          #| +-------+    +-----+
        ),
      ),
      expected_unicode: Some(
        (
          #| ┌───────┐    ┌─────┐
          #| │ Alice │    │ Bob │
          #| └───┬───┘    └──┬──┘
          #|     │           │
          #|     ├───┐       │
          #|     │   │ Think │
          #|     ◀───┘       │
          #|     │           │
          #|     │  Result   │
          #|     │───────────▶
          #|     │           │
          #| ┌───┴───┐    ┌──┴──┐
          #| │ Alice │    │ Bob │
          #| └───────┘    └─────┘
        ),
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
      expected_ascii: Some(
        (
          #|+---+
          #||   |
          #|| A |
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐
          #|│   │
          #|│ A │
          #|│   │
          #|└───┘
        ),
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
        (
          #|+------------+
          #||            |
          #|| LongerName |
          #||            |
          #|+------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌────────────┐
          #|│            │
          #|│ LongerName │
          #|│            │
          #|└────────────┘
        ),
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
        (
          #|            +---------------------------+ +-------+
          #|            |        Processing         | |Storage|
          #|            |                           | |       |
          #|            |                           | |       |
          #|+-------+   | +---+     +---+     +---+ | | +---+ |   +-----+
          #||       |   | |   |     |   |     |   | | | |   | |   |     |
          #|| Start |---->| A |---->| B |---->| C |---->| D |---->| End |
          #||       |   | |   |     |   |     |   | | | |   | |   |     |
          #|+-------+   | +---+     +---+     +---+ | | +---+ |   +-----+
          #|            |                       |   | |       |      ^
          #|            +-----------------------|---+ |       |      |
          #|                                    |     |       |      |
          #|                                    |     |       |      |
          #|                                    |     |       |      |
          #|                                    |     | +---+ |      |
          #|                                    |     | |   | |      |
          #|                                    +------>| E |--------+
          #|                                          | |   | |
          #|                                          | +---+ |
          #|                                          |       |
          #|                                          +-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|            ┌───────────────────────────┐ ┌───────┐
          #|            │        Processing         │ │Storage│
          #|            │                           │ │       │
          #|            │                           │ │       │
          #|┌───────┐   │ ┌───┐     ┌───┐     ┌───┐ │ │ ┌───┐ │   ┌─────┐
          #|│       │   │ │   │     │   │     │   │ │ │ │   │ │   │     │
          #|│ Start ├───┼►│ A ├────►│ B ├────►│ C ├─┼─┼►│ D ├─┼──►│ End │
          #|│       │   │ │   │     │   │     │   │ │ │ │   │ │   │     │
          #|└───────┘   │ └───┘     └───┘     └─┬─┘ │ │ └───┘ │   └─────┘
          #|            │                       │   │ │       │      ▲
          #|            └───────────────────────┼───┘ │       │      │
          #|                                    │     │       │      │
          #|                                    │     │       │      │
          #|                                    │     │       │      │
          #|                                    │     │ ┌───┐ │      │
          #|                                    │     │ │   │ │      │
          #|                                    └─────┼►│ E ├─┼──────┘
          #|                                          │ │   │ │
          #|                                          │ └───┘ │
          #|                                          │       │
          #|                                          └───────┘
        ),
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
        (
          #|+-----------+
          #||   outer   |
          #||           |
          #||           |
          #||   +---+   |
          #||   |   |   |
          #||   | A |   |
          #||   |   |   |
          #||   +---+   |
          #||           |
          #|| +-------+ |
          #|| | inner | |
          #|| |       | |
          #|| |       | |
          #|| | +---+ | |
          #|| | |   | | |
          #|| | | B | | |
          #|| | |   | | |
          #|| | +---+ | |
          #|| |       | |
          #|| +-------+ |
          #||           |
          #||           |
          #||           |
          #||   +---+   |
          #||   |   |   |
          #||   | C |   |
          #||   |   |   |
          #||   +---+   |
          #||           |
          #|+-----------+
          #|
          #|
          #|
          #|    +---+
          #|    |   |
          #|    | D |
          #|    |   |
          #|    +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────────┐
          #|│   outer   │
          #|│           │
          #|│           │
          #|│   ┌───┐   │
          #|│   │   │   │
          #|│   │ A │   │
          #|│   │   │   │
          #|│   └───┘   │
          #|│           │
          #|│ ┌───────┐ │
          #|│ │ inner │ │
          #|│ │       │ │
          #|│ │       │ │
          #|│ │ ┌───┐ │ │
          #|│ │ │   │ │ │
          #|│ │ │ B │ │ │
          #|│ │ │   │ │ │
          #|│ │ └───┘ │ │
          #|│ │       │ │
          #|│ └───────┘ │
          #|│           │
          #|│           │
          #|│           │
          #|│   ┌───┐   │
          #|│   │   │   │
          #|│   │ C │   │
          #|│   │   │   │
          #|│   └───┘   │
          #|│           │
          #|└───────────┘
          #|
          #|
          #|
          #|    ┌───┐
          #|    │   │
          #|    │ D │
          #|    │   │
          #|    └───┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |---->| B |
          #||   |     |   |
          #|+---+     +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├────►│ B │
          #|│   │     │   │
          #|└───┘     └───┘
        ),
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
        (
          #|        +-----------------+
          #|        |       one       |
          #|        |                 |
          #|        |                 |
          #|+---+   | +---+     +---+ |   +---+
          #||   |   | |   |     |   | |   |   |
          #|| X |---->| A |---->| B |---->| Y |
          #||   |   | |   |     |   | |   |   |
          #|+---+   | +---+     +---+ |   +---+
          #|        |                 |
          #|        +-----------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|        ┌─────────────────┐
          #|        │       one       │
          #|        │                 │
          #|        │                 │
          #|┌───┐   │ ┌───┐     ┌───┐ │   ┌───┐
          #|│   │   │ │   │     │   │ │   │   │
          #|│ X ├───┼►│ A ├────►│ B ├─┼──►│ Y │
          #|│   │   │ │   │     │   │ │   │   │
          #|└───┘   │ └───┘     └───┘ │   └───┘
          #|        │                 │
          #|        └─────────────────┘
        ),
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
        (
          #|  +---+
          #|  |   |
          #|  | X |
          #|  |   |
          #|  +---+
          #|    |
          #|    |
          #|    |
          #|    |
          #|    |
          #|+---|---+
          #||  one  |
          #||   |   |
          #||   v   |
          #|| +---+ |
          #|| |   | |
          #|| | A | |
          #|| |   | |
          #|| +---+ |
          #||   |   |
          #||   |   |
          #||   |   |
          #||   |   |
          #||   v   |
          #|| +---+ |
          #|| |   | |
          #|| | B | |
          #|| |   | |
          #|| +---+ |
          #||   |   |
          #|+---|---+
          #|    |
          #|    |
          #|    v
          #|  +---+
          #|  |   |
          #|  | Y |
          #|  |   |
          #|  +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|  ┌───┐
          #|  │   │
          #|  │ X │
          #|  │   │
          #|  └─┬─┘
          #|    │
          #|    │
          #|    │
          #|    │
          #|    │
          #|┌───┼───┐
          #|│  one  │
          #|│   │   │
          #|│   ▼   │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ A │ │
          #|│ │   │ │
          #|│ └─┬─┘ │
          #|│   │   │
          #|│   │   │
          #|│   │   │
          #|│   │   │
          #|│   ▼   │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ B │ │
          #|│ │   │ │
          #|│ └─┬─┘ │
          #|│   │   │
          #|└───┼───┘
          #|    │
          #|    │
          #|    ▼
          #|  ┌───┐
          #|  │   │
          #|  │ Y │
          #|  │   │
          #|  └───┘
        ),
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
        (
          #|+-----------------+ +-------+
          #||       one       | |  two  |
          #||                 | |       |
          #||                 | |       |
          #|| +---+     +---+ | | +---+ |
          #|| |   |     |   | | | |   | |
          #|| | A |---->| B |---->| D | |
          #|| |   |     |   | | | |   | |
          #|| +---+     +---+ | | +---+ |
          #||   |             | |   |   |
          #||   |             | |   |   |
          #||   |             | |   |   |
          #||   |             | |   |   |
          #||   |             | |   v   |
          #||   |       +---+ | | +---+ |
          #||   |       |   | | | |   | |
          #||   +------>| C |---->| E | |
          #||           |   | | | |   | |
          #||           +---+ | | +---+ |
          #||                 | |       |
          #|+-----------------+ +-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────────────┐ ┌───────┐
          #|│       one       │ │  two  │
          #|│                 │ │       │
          #|│                 │ │       │
          #|│ ┌───┐     ┌───┐ │ │ ┌───┐ │
          #|│ │   │     │   │ │ │ │   │ │
          #|│ │ A ├────►│ B ├─┼─┼►│ D │ │
          #|│ │   │     │   │ │ │ │   │ │
          #|│ └─┬─┘     └───┘ │ │ └─┬─┘ │
          #|│   │             │ │   │   │
          #|│   │             │ │   │   │
          #|│   │             │ │   │   │
          #|│   │             │ │   │   │
          #|│   │             │ │   ▼   │
          #|│   │       ┌───┐ │ │ ┌───┐ │
          #|│   │       │   │ │ │ │   │ │
          #|│   └──────►│ C ├─┼─┼►│ E │ │
          #|│           │   │ │ │ │   │ │
          #|│           └───┘ │ │ └───┘ │
          #|│                 │ │       │
          #|└─────────────────┘ └───────┘
        ),
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
        (
          #|+-----------------+
          #||       one       |
          #||                 |
          #||                 |
          #|| +---+     +---+ |
          #|| |   |     |   | |
          #|| | A |---->| B | |
          #|| |   |     |   | |
          #|| +---+     +---+ |
          #||                 |
          #|+-----------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────────────┐
          #|│       one       │
          #|│                 │
          #|│                 │
          #|│ ┌───┐     ┌───┐ │
          #|│ │   │     │   │ │
          #|│ │ A ├────►│ B │ │
          #|│ │   │     │   │ │
          #|│ └───┘     └───┘ │
          #|│                 │
          #|└─────────────────┘
        ),
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
        (
          #|+-----------+
          #||   outer   |
          #||           |
          #||           |
          #|| +-------+ |
          #|| | inner | |
          #|| |       | |
          #|| |       | |
          #|| | +---+ | |
          #|| | |   | | |
          #|| | | A | | |
          #|| | |   | | |
          #|| | +---+ | |
          #|| |       | |
          #|| +-------+ |
          #||           |
          #|+-----------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────────┐
          #|│   outer   │
          #|│           │
          #|│           │
          #|│ ┌───────┐ │
          #|│ │ inner │ │
          #|│ │       │ │
          #|│ │       │ │
          #|│ │ ┌───┐ │ │
          #|│ │ │   │ │ │
          #|│ │ │ A │ │ │
          #|│ │ │   │ │ │
          #|│ │ └───┘ │ │
          #|│ │       │ │
          #|│ └───────┘ │
          #|│           │
          #|└───────────┘
        ),
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
        (
          #|        +-----------------------------+
          #|        |            outer            |
          #|        |                             |
          #|        |                             |
          #|        |         +-----------------+ |
          #|        |         |      inner      | |
          #|        |         |                 | |
          #|        |         |                 | |
          #|+---+   | +---+   | +---+     +---+ | | +---+
          #||   |   | |   |   | |   |     |   | | | |   |
          #|| X |---->| A |---->| B |---->| C |---->| Y |
          #||   |   | |   |   | |   |     |   | | | |   |
          #|+---+   | +---+   | +---+     +---+ | | +---+
          #|        |         |                 | |
          #|        |         +-----------------+ |
          #|        |                             |
          #|        +-----------------------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|        ┌─────────────────────────────┐
          #|        │            outer            │
          #|        │                             │
          #|        │                             │
          #|        │         ┌─────────────────┐ │
          #|        │         │      inner      │ │
          #|        │         │                 │ │
          #|        │         │                 │ │
          #|┌───┐   │ ┌───┐   │ ┌───┐     ┌───┐ │ │ ┌───┐
          #|│   │   │ │   │   │ │   │     │   │ │ │ │   │
          #|│ X ├───┼►│ A ├───┼►│ B ├────►│ C ├─┼─┼►│ Y │
          #|│   │   │ │   │   │ │   │     │   │ │ │ │   │
          #|└───┘   │ └───┘   │ └───┘     └───┘ │ │ └───┘
          #|        │         │                 │ │
          #|        │         └─────────────────┘ │
          #|        │                             │
          #|        └─────────────────────────────┘
        ),
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
        (
          #|        +-----------------+
          #|        |       one       |
          #|        |                 |
          #|        |                 |
          #|+---+   | +---+     +---+ |
          #||   |   | |   |     |   | |
          #|| X |   | | A |---->| B | |
          #||   |   | |   |     |   | |
          #|+---+   | +---+     +---+ |
          #|        |                 |
          #|        +-----------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|        ┌─────────────────┐
          #|        │       one       │
          #|        │                 │
          #|        │                 │
          #|┌───┐   │ ┌───┐     ┌───┐ │
          #|│   │   │ │   │     │   │ │
          #|│ X │   │ │ A ├────►│ B │ │
          #|│   │   │ │   │     │   │ │
          #|└───┘   │ └───┘     └───┘ │
          #|        │                 │
          #|        └─────────────────┘
        ),
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
        (
          #|+-------+
          #||  one  |
          #||       |
          #||       |
          #|| +---+ |
          #|| |   | |
          #|| | A | |
          #|| |   | |
          #|| +---+ |
          #||       |
          #|+-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────┐
          #|│  one  │
          #|│       │
          #|│       │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ A │ │
          #|│ │   │ │
          #|│ └───┘ │
          #|│       │
          #|└───────┘
        ),
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
        (
          #|+-------+
          #||  one  |
          #||       |
          #||       |
          #|| +---+ |
          #|| |   | |
          #|| | A | |
          #|| |   | |
          #|| +---+ |
          #||   |   |
          #||   |   |
          #||   |   |
          #||   |   |
          #||   v   |
          #|| +---+ |
          #|| |   | |
          #|| | B | |
          #|| |   | |
          #|| +---+ |
          #||       |
          #|+-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────┐
          #|│  one  │
          #|│       │
          #|│       │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ A │ │
          #|│ │   │ │
          #|│ └─┬─┘ │
          #|│   │   │
          #|│   │   │
          #|│   │   │
          #|│   │   │
          #|│   ▼   │
          #|│ ┌───┐ │
          #|│ │   │ │
          #|│ │ B │ │
          #|│ │   │ │
          #|│ └───┘ │
          #|│       │
          #|└───────┘
        ),
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
        (
          #|+--------------+
          #||  Frontend    |
          #||              |
          #||              |
          #|| +----------+ |
          #|| |          | |
          #|| |    UI    | |
          #|| |          | |
          #|| +----------+ |
          #||       |      |
          #||       |      |
          #||       |      |
          #||       |      |
          #||       v      |
          #|| +----------+ |
          #|| |          | |
          #|| |   API    |---------+
          #|| |          | |       |
          #|| +----------+ |       |
          #||       |      |       |
          #|+-------|------+       |
          #|        |              |
          #|        |              |
          #|        |              |
          #|+-------|--------------|-----+
          #||       |  Backend     |     |
          #||       |              |     |
          #||       v              v     |
          #|| +----------+     +-------+ |
          #|| |          |     |       | |
          #|| | Database |     | Cache | |
          #|| |          |     |       | |
          #|| +----------+     +-------+ |
          #||                            |
          #|+----------------------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌──────────────┐
          #|│  Frontend    │
          #|│              │
          #|│              │
          #|│ ┌──────────┐ │
          #|│ │          │ │
          #|│ │    UI    │ │
          #|│ │          │ │
          #|│ └─────┬────┘ │
          #|│       │      │
          #|│       │      │
          #|│       │      │
          #|│       │      │
          #|│       ▼      │
          #|│ ┌──────────┐ │
          #|│ │          │ │
          #|│ │   API    ├─┼───────┐
          #|│ │          │ │       │
          #|│ └─────┬────┘ │       │
          #|│       │      │       │
          #|└───────┼──────┘       │
          #|        │              │
          #|        │              │
          #|        │              │
          #|┌───────┼──────────────┼─────┐
          #|│       │  Backend     │     │
          #|│       │              │     │
          #|│       ▼              ▼     │
          #|│ ┌──────────┐     ┌───────┐ │
          #|│ │          │     │       │ │
          #|│ │ Database │     │ Cache │ │
          #|│ │          │     │       │ │
          #|│ └──────────┘     └───────┘ │
          #|│                            │
          #|└────────────────────────────┘
        ),
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
        (
          #|+--------------+
          #||  Frontend    |
          #||              |
          #||              |
          #|| +----------+ |
          #|| |          | |
          #|| |    UI    | |
          #|| |          | |
          #|| +----------+ |
          #||       |      |
          #||       |      |
          #||       v      |
          #|| +----------+ |
          #|| |          | |
          #|| |   API    |-------+
          #|| |          | |     |
          #|| +----------+ |     |
          #||       |      |     |
          #|+-------|------+     |
          #|        |            |
          #|+-------|------------|-----+
          #||       | Backend    |     |
          #||       |            |     |
          #||       v            v     |
          #|| +----------+   +-------+ |
          #|| |          |   |       | |
          #|| | Database |   | Cache | |
          #|| |          |   |       | |
          #|| +----------+   +-------+ |
          #||                          |
          #|+--------------------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌──────────────┐
          #|│  Frontend    │
          #|│              │
          #|│              │
          #|│ ┌──────────┐ │
          #|│ │          │ │
          #|│ │    UI    │ │
          #|│ │          │ │
          #|│ └─────┬────┘ │
          #|│       │      │
          #|│       │      │
          #|│       ▼      │
          #|│ ┌──────────┐ │
          #|│ │          │ │
          #|│ │   API    ├─┼─────┐
          #|│ │          │ │     │
          #|│ └─────┬────┘ │     │
          #|│       │      │     │
          #|└───────┼──────┘     │
          #|        │            │
          #|┌───────┼────────────┼─────┐
          #|│       │ Backend    │     │
          #|│       │            │     │
          #|│       ▼            ▼     │
          #|│ ┌──────────┐   ┌───────┐ │
          #|│ │          │   │       │ │
          #|│ │ Database │   │ Cache │ │
          #|│ │          │   │       │ │
          #|│ └──────────┘   └───────┘ │
          #|│                          │
          #|└──────────────────────────┘
        ),
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
        (
          #|+---------------+
          #||    level1     |
          #||               |
          #||               |
          #|| +-----------+ |
          #|| |  level2   | |
          #|| |           | |
          #|| |           | |
          #|| | +-------+ | |
          #|| | |level3 | | |
          #|| | |       | | |
          #|| | |       | | |
          #|| | | +---+ | | |
          #|| | | |   | | | |
          #|| | | | A | | | |
          #|| | | |   | | | |
          #|| | | +---+ | | |
          #|| | |       | | |
          #|| | +-------+ | |
          #|| |           | |
          #|| +-----------+ |
          #||               |
          #|+---------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────────────┐
          #|│    level1     │
          #|│               │
          #|│               │
          #|│ ┌───────────┐ │
          #|│ │  level2   │ │
          #|│ │           │ │
          #|│ │           │ │
          #|│ │ ┌───────┐ │ │
          #|│ │ │level3 │ │ │
          #|│ │ │       │ │ │
          #|│ │ │       │ │ │
          #|│ │ │ ┌───┐ │ │ │
          #|│ │ │ │   │ │ │ │
          #|│ │ │ │ A │ │ │ │
          #|│ │ │ │   │ │ │ │
          #|│ │ │ └───┘ │ │ │
          #|│ │ │       │ │ │
          #|│ │ └───────┘ │ │
          #|│ │           │ │
          #|│ └───────────┘ │
          #|│               │
          #|└───────────────┘
        ),
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
        (
          #|+--------+ +---------+ +--------+
          #||Frontend| | Backend | |Database|
          #||        | |         | |        |
          #||        | |         | |        |
          #|| +----+ | | +-----+ | | +----+ |
          #|| |    | | | |     | | | |    | |
          #|| | UI |---->| API |---->| DB | |
          #|| |    | | | |     | | | |    | |
          #|| +----+ | | +-----+ | | +----+ |
          #||        | |         | |        |
          #|+--------+ +---------+ +--------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌────────┐ ┌─────────┐ ┌────────┐
          #|│Frontend│ │ Backend │ │Database│
          #|│        │ │         │ │        │
          #|│        │ │         │ │        │
          #|│ ┌────┐ │ │ ┌─────┐ │ │ ┌────┐ │
          #|│ │    │ │ │ │     │ │ │ │    │ │
          #|│ │ UI ├─┼─┼►│ API ├─┼─┼►│ DB │ │
          #|│ │    │ │ │ │     │ │ │ │    │ │
          #|│ └────┘ │ │ └─────┘ │ │ └────┘ │
          #|│        │ │         │ │        │
          #|└────────┘ └─────────┘ └────────┘
        ),
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
        (
          #|+-------+ +-------+
          #||  one  | |  two  |
          #||       | |       |
          #||       | |       |
          #|| +---+ | | +---+ |
          #|| |   | | | |   | |
          #|| | A |---->| B | |
          #|| |   | | | |   | |
          #|| +---+ | | +---+ |
          #||       | |       |
          #|+-------+ +-------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────┐ ┌───────┐
          #|│  one  │ │  two  │
          #|│       │ │       │
          #|│       │ │       │
          #|│ ┌───┐ │ │ ┌───┐ │
          #|│ │   │ │ │ │   │ │
          #|│ │ A ├─┼─┼►│ B │ │
          #|│ │   │ │ │ │   │ │
          #|│ └───┘ │ │ └───┘ │
          #|│       │ │       │
          #|└───────┘ └───────┘
        ),
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
        (
          #|+-------------------+  +----------------------+
          #||        one        |  |         two          |
          #||                   |  |                      |
          #||                   |  |                      |
          #|| +---+       +---+ |  | +---+          +---+ |
          #|| |   |       |   | |  | |   |          |   | |
          #|| | A |-sends>| B |data->| C |receives->| D | |
          #|| |   |       |   | |  | |   |          |   | |
          #|| +---+       +---+ |  | +---+          +---+ |
          #||                   |  |                      |
          #|+-------------------+  +----------------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───────────────────┐  ┌──────────────────────┐
          #|│        one        │  │         two          │
          #|│                   │  │                      │
          #|│                   │  │                      │
          #|│ ┌───┐       ┌───┐ │  │ ┌───┐          ┌───┐ │
          #|│ │   │       │   │ │  │ │   │          │   │ │
          #|│ │ A ├─sends►│ B ├data┼►│ C ├receives─►│ D │ │
          #|│ │   │       │   │ │  │ │   │          │   │ │
          #|│ └───┘       └───┘ │  │ └───┘          └───┘ │
          #|│                   │  │                      │
          #|└───────────────────┘  └──────────────────────┘
        ),
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
        (
          #|+---+     +---+     +---+
          #||   |     |   |     |   |
          #|| A |---->| B |---->| C |
          #||   |     |   |     |   |
          #|+---+     +---+     +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐     ┌───┐
          #|│   │     │   │     │   │
          #|│ A ├────►│ B ├────►│ C │
          #|│   │     │   │     │   │
          #|└───┘     └───┘     └───┘
        ),
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
        (
          #|+---+     +---+     +---+
          #||   |     |   |     |   |
          #|| A |---->| B |---->| C |
          #||   |     |   |     |   |
          #|+---+     +---+     +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐     ┌───┐
          #|│   │     │   │     │   │
          #|│ A ├────►│ B ├────►│ C │
          #|│   │     │   │     │   │
          #|└───┘     └───┘     └───┘
        ),
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
        (
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
      ),
      expected_unicode: Some(
        (
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
        (
          #|+-----+     +---------+
          #||     |     |         |
          #|| ABC |---->|  BCDEFG |
          #||     |     |         |
          #|+-----+     +---------+
          #|   |
          #|   |
          #|   |
          #|   |
          #|   |
          #|   |        +---------+
          #|   |        |         |
          #|   +------->| CDEFGHI |
          #|            |         |
          #|            +---------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────┐     ┌─────────┐
          #|│     │     │         │
          #|│ ABC ├────►│  BCDEFG │
          #|│     │     │         │
          #|└──┬──┘     └─────────┘
          #|   │
          #|   │
          #|   │
          #|   │
          #|   │
          #|   │        ┌─────────┐
          #|   │        │         │
          #|   └───────►│ CDEFGHI │
          #|            │         │
          #|            └─────────┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |---->| B |
          #||   |     |   |
          #|+---+     +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├────►│ B │
          #|│   │     │   │
          #|└───┘     └───┘
        ),
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
        (
          #|+-------------+     +-------------+
          #||             |     |             |
          #|| LongerName1 |---->| LongerName2 |
          #||             |     |             |
          #|+-------------+     +-------------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌─────────────┐     ┌─────────────┐
          #|│             │     │             │
          #|│ LongerName1 ├────►│ LongerName2 │
          #|│             │     │             │
          #|└─────────────┘     └─────────────┘
        ),
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
        (
          #|+---+     +---+
          #||   |     |   |
          #|| A |---->| B |
          #||   |     |   |
          #|+---+     +---+
          #|
          #|
          #|
          #|
          #|
          #|+---+     +---+
          #||   |     |   |
          #|| C |---->| D |
          #||   |     |   |
          #|+---+     +---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ A ├────►│ B │
          #|│   │     │   │
          #|└───┘     └───┘
          #|
          #|
          #|
          #|
          #|
          #|┌───┐     ┌───┐
          #|│   │     │   │
          #|│ C ├────►│ D │
          #|│   │     │   │
          #|└───┘     └───┘
        ),
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
        (
          #|+--------+     +--------+
          #||        |     |        |
          #||  ABC   |---->| BCDEFG |
          #||        |     |        |
          #|+--------+     +--------+
          #|
          #|
          #|
          #|
          #|
          #|+--------+     +--------+
          #||        |     |        |
          #|| CDEFGH |---->|  DEF   |
          #||        |     |        |
          #|+--------+     +--------+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌────────┐     ┌────────┐
          #|│        │     │        │
          #|│  ABC   ├────►│ BCDEFG │
          #|│        │     │        │
          #|└────────┘     └────────┘
          #|
          #|
          #|
          #|
          #|
          #|┌────────┐     ┌────────┐
          #|│        │     │        │
          #|│ CDEFGH ├────►│  DEF   │
          #|│        │     │        │
          #|└────────┘     └────────┘
        ),
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
        (
          #|+---+
          #||   |
          #|| A |
          #||   |
          #|+---+
          #|
          #|
          #|
          #|
          #|
          #|+---+
          #||   |
          #|| B |
          #||   |
          #|+---+
        ),
      ),
      expected_unicode: Some(
        (
          #|┌───┐
          #|│   │
          #|│ A │
          #|│   │
          #|└───┘
          #|
          #|
          #|
          #|
          #|
          #|┌───┐
          #|│   │
          #|│ B │
          #|│   │
          #|└───┘
        ),
      ),
      expected_svg_fragments: ["<svg", "</svg>", "<defs>"],
    },
  ]
}
