///|
struct UpstreamSample {
  title : String
  source : String
  transparent : Bool
}

///|
fn upstream_samples() -> Array[UpstreamSample] {
  [
    {
      title: "Beautiful Mermaid",
      source: (
        #|stateDiagram-v2
        #|    direction LR
        #|    [*] --> Input
        #|    Input --> Parse: DSL
        #|    Parse --> Layout: AST
        #|    Layout --> SVG: Vector
        #|    Layout --> ASCII: Text
        #|    SVG --> Theme
        #|    ASCII --> Theme
        #|    Theme --> Output
        #|    Output --> [*]
      ),
      transparent: true,
    },
    {
      title: "Simple Flow",
      source: (
        #|graph TD
        #|  A[Start] --> B[Process] --> C[End]
      ),
      transparent: false,
    },
    {
      title: "Original Node Shapes",
      source: (
        #|graph LR
        #|  A[Rectangle] --> B(Rounded)
        #|  B --> C{Diamond}
        #|  C --> D([Stadium])
        #|  D --> E((Circle))
      ),
      transparent: false,
    },
    {
      title: "Batch 1 Shapes",
      source: (
        #|graph LR
        #|  A[[Subroutine]] --> B(((Double Circle)))
        #|  B --> C{{Hexagon}}
      ),
      transparent: false,
    },
    {
      title: "Batch 2 Shapes",
      source: "graph LR\n  A[(Database)] --> B>Flag Shape]\n  B --> C[/Wider Bottom\\]\n  C --> D[\\Wider Top/]",
      transparent: false,
    },
    {
      title: "All 12 Flowchart Shapes",
      source: "graph LR\n  A[Rectangle] --> B(Rounded)\n  B --> C{Diamond}\n  C --> D([Stadium])\n  D --> E((Circle))\n  E --> F[[Subroutine]]\n  F --> G(((Double Circle)))\n  G --> H{{Hexagon}}\n  H --> I[(Database)]\n  I --> J>Flag]\n  J --> K[/Trapezoid\\]\n  K --> L[\\Inverse Trap/]",
      transparent: false,
    },
    {
      title: "All Edge Styles",
      source: (
        #|graph TD
        #|  A[Source] -->|solid| B[Target 1]
        #|  A -.->|dotted| C[Target 2]
        #|  A ==>|thick| D[Target 3]
      ),
      transparent: false,
    },
    {
      title: "No-Arrow Edges",
      source: (
        #|graph TD
        #|  A[Node 1] ---|related| B[Node 2]
        #|  B -.- C[Node 3]
        #|  C === D[Node 4]
      ),
      transparent: false,
    },
    {
      title: "Bidirectional Arrows",
      source: (
        #|graph LR
        #|  A[Client] <-->|sync| B[Server]
        #|  B <-.->|heartbeat| C[Monitor]
        #|  C <==>|data| D[Storage]
      ),
      transparent: false,
    },
    {
      title: "Parallel Links (&)",
      source: (
        #|graph TD
        #|  A[Input] & B[Config] --> C[Processor]
        #|  C --> D[Output] & E[Log]
      ),
      transparent: false,
    },
    {
      title: "Chained Edges",
      source: "graph LR\n  A[Step 1] --> B[Step 2] --> C[Step 3] --> D[Step 4] --> E[Step 5]",
      transparent: false,
    },
    {
      title: "Direction: Left-Right (LR)",
      source: "graph LR\n  A[Input] --> B[Transform] --> C[Output]",
      transparent: false,
    },
    {
      title: "Direction: Bottom-Top (BT)",
      source: "graph BT\n  A[Foundation] --> B[Layer 2] --> C[Top]",
      transparent: false,
    },
    {
      title: "Subgraphs",
      source: "graph TD\n  subgraph Frontend\n    A[React App] --> B[State Manager]\n  end\n  subgraph Backend\n    C[API Server] --> D[Database]\n  end\n  B --> C",
      transparent: false,
    },
    {
      title: "Nested Subgraphs",
      source: "graph TD\n  subgraph Cloud\n    subgraph us-east [US East Region]\n      A[Web Server] --> B[App Server]\n    end\n    subgraph us-west [US West Region]\n      C[Web Server] --> D[App Server]\n    end\n  end\n  E[Load Balancer] --> A\n  E --> C",
      transparent: false,
    },
    {
      title: "Subgraph Direction Override",
      source: "graph TD\n  subgraph pipeline [Processing Pipeline]\n    direction LR\n    A[Input] --> B[Parse] --> C[Transform] --> D[Output]\n  end\n  E[Source] --> A\n  D --> F[Sink]",
      transparent: false,
    },
    {
      title: "::: Class Shorthand",
      source: "graph TD\n  A[Normal]:::default --> B[Highlighted]:::highlight --> C[Error]:::error\n  classDef default fill:#f4f4f5,stroke:#a1a1aa\n  classDef highlight fill:#fbbf24,stroke:#d97706\n  classDef error fill:#ef4444,stroke:#dc2626",
      transparent: false,
    },
    {
      title: "Inline Style Overrides",
      source: "graph TD\n  A[Default] --> B[Custom Colors] --> C[Another Custom]\n  style B fill:#3b82f6,stroke:#1d4ed8,color:#ffffff\n  style C fill:#10b981,stroke:#059669",
      transparent: false,
    },
    {
      title: "CI/CD Pipeline",
      source: "graph TD\n  subgraph ci [CI Pipeline]\n    A[Push Code] --> B{Tests Pass?}\n    B -->|Yes| C[Build Image]\n    B -->|No| D[Fix & Retry]\n    D -.-> A\n  end\n  C --> E([Deploy Staging])\n  E --> F{QA Approved?}\n  F -->|Yes| G((Production))\n  F -->|No| D",
      transparent: false,
    },
    {
      title: "System Architecture",
      source: "graph LR\n  subgraph clients [Client Layer]\n    A([Web App]) --> B[API Gateway]\n    C([Mobile App]) --> B\n  end\n  subgraph services [Service Layer]\n    B --> D[Auth Service]\n    B --> E[User Service]\n    B --> F[Order Service]\n  end\n  subgraph data [Data Layer]\n    D --> G[(Auth DB)]\n    E --> H[(User DB)]\n    F --> I[(Order DB)]\n    F --> J([Message Queue])\n  end",
      transparent: false,
    },
    {
      title: "Decision Tree",
      source: "graph TD\n  A{Is it raining?} -->|Yes| B{Have umbrella?}\n  A -->|No| C([Go outside])\n  B -->|Yes| D([Go with umbrella])\n  B -->|No| E{Is it heavy?}\n  E -->|Yes| F([Stay inside])\n  E -->|No| G([Run for it])",
      transparent: false,
    },
    {
      title: "Git Branching Workflow",
      source: "graph LR\n  A[main] --> B[develop]\n  B --> C[feature/auth]\n  B --> D[feature/ui]\n  C --> E{PR Review}\n  D --> E\n  E -->|approved| B\n  B --> F[release/1.0]\n  F --> G{Tests?}\n  G -->|pass| A\n  G -->|fail| F",
      transparent: false,
    },
    {
      title: "Basic State Diagram",
      source: "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Active : start\n  Active --> Idle : cancel\n  Active --> Done : complete\n  Done --> [*]",
      transparent: false,
    },
    {
      title: "State: Composite States",
      source: "stateDiagram-v2\n  [*] --> Idle\n  Idle --> Processing : submit\n  state Processing {\n    parse --> validate\n    validate --> execute\n  }\n  Processing --> Complete : done\n  Processing --> Error : fail\n  Error --> Idle : retry\n  Complete --> [*]",
      transparent: false,
    },
    {
      title: "State: Connection Lifecycle",
      source: "stateDiagram-v2\n  [*] --> Closed\n  Closed --> Connecting : connect\n  Connecting --> Connected : success\n  Connecting --> Closed : timeout\n  Connected --> Disconnecting : close\n  Connected --> Reconnecting : error\n  Reconnecting --> Connected : success\n  Reconnecting --> Closed : max_retries\n  Disconnecting --> Closed : done\n  Closed --> [*]",
      transparent: false,
    },
    {
      title: "Sequence: Basic Messages",
      source: "sequenceDiagram\n  Alice->>Bob: Hello Bob!\n  Bob-->>Alice: Hi Alice!",
      transparent: false,
    },
    {
      title: "Sequence: Participant Aliases",
      source: "sequenceDiagram\n  participant A as Alice\n  participant B as Bob\n  participant C as Charlie\n  A->>B: Hello\n  B->>C: Forward\n  C-->>A: Reply",
      transparent: false,
    },
    {
      title: "Sequence: Actor Stick Figures",
      source: "sequenceDiagram\n  actor U as User\n  participant S as System\n  participant DB as Database\n  U->>S: Click button\n  S->>DB: Query\n  DB-->>S: Results\n  S-->>U: Display",
      transparent: false,
    },
    {
      title: "Sequence: Arrow Types",
      source: "sequenceDiagram\n  A->>B: Solid arrow (sync)\n  B-->>A: Dashed arrow (return)\n  A-)B: Open arrow (async)\n  B--)A: Open dashed arrow",
      transparent: false,
    },
    {
      title: "Sequence: Activation Boxes",
      source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>+S: Request\n  S->>+S: Process\n  S->>-S: Done\n  S-->>-C: Response",
      transparent: false,
    },
    {
      title: "Sequence: Self-Messages",
      source: "sequenceDiagram\n  participant S as Server\n  S->>S: Internal process\n  S->>S: Validate\n  S-->>S: Log",
      transparent: false,
    },
    {
      title: "Sequence: Loop Block",
      source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Connect\n  loop Every 30s\n    C->>S: Heartbeat\n    S-->>C: Ack\n  end\n  C->>S: Disconnect",
      transparent: false,
    },
    {
      title: "Sequence: Alt/Else Block",
      source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  C->>S: Login\n  alt Valid credentials\n    S-->>C: 200 OK\n  else Invalid\n    S-->>C: 401 Unauthorized\n  else Account locked\n    S-->>C: 403 Forbidden\n  end",
      transparent: false,
    },
    {
      title: "Sequence: Opt Block",
      source: "sequenceDiagram\n  participant A as App\n  participant C as Cache\n  participant DB as Database\n  A->>C: Get data\n  C-->>A: Cache miss\n  opt Cache miss\n    A->>DB: Query\n    DB-->>A: Results\n    A->>C: Store in cache\n  end",
      transparent: false,
    },
    {
      title: "Sequence: Par Block",
      source: "sequenceDiagram\n  participant C as Client\n  participant A as AuthService\n  participant U as UserService\n  participant O as OrderService\n  C->>A: Authenticate\n  par Fetch user data\n    A->>U: Get profile\n  and Fetch orders\n    A->>O: Get orders\n  end\n  A-->>C: Combined response",
      transparent: false,
    },
    {
      title: "Sequence: Critical Block",
      source: "sequenceDiagram\n  participant A as App\n  participant DB as Database\n  A->>DB: BEGIN\n  critical Transaction\n    A->>DB: UPDATE accounts\n    A->>DB: INSERT log\n  end\n  A->>DB: COMMIT",
      transparent: false,
    },
    {
      title: "Sequence: Notes (Right/Left/Over)",
      source: "sequenceDiagram\n  participant A as Alice\n  participant B as Bob\n  Note left of A: Alice prepares\n  A->>B: Hello\n  Note right of B: Bob thinks\n  B-->>A: Reply\n  Note over A,B: Conversation complete",
      transparent: false,
    },
    {
      title: "Sequence: OAuth 2.0 Flow",
      source: "sequenceDiagram\n  actor U as User\n  participant App as Client App\n  participant Auth as Auth Server\n  participant API as Resource API\n  U->>App: Click Login\n  App->>Auth: Authorization request\n  Auth->>U: Login page\n  U->>Auth: Credentials\n  Auth-->>App: Authorization code\n  App->>Auth: Exchange code for token\n  Auth-->>App: Access token\n  App->>API: Request + token\n  API-->>App: Protected resource\n  App-->>U: Display data",
      transparent: false,
    },
    {
      title: "Sequence: Database Transaction",
      source: "sequenceDiagram\n  participant C as Client\n  participant S as Server\n  participant DB as Database\n  C->>S: POST /transfer\n  S->>DB: BEGIN\n  S->>DB: Debit account A\n  alt Success\n    S->>DB: Credit account B\n    S->>DB: INSERT audit_log\n    S->>DB: COMMIT\n    S-->>C: 200 OK\n  else Insufficient funds\n    S->>DB: ROLLBACK\n    S-->>C: 400 Bad Request\n  end",
      transparent: false,
    },
    {
      title: "Sequence: Microservice Orchestration",
      source: "sequenceDiagram\n  participant G as Gateway\n  participant A as Auth\n  participant U as Users\n  participant O as Orders\n  participant N as Notify\n  G->>A: Validate token\n  A-->>G: Valid\n  par Fetch data\n    G->>U: Get user\n    U-->>G: User data\n  and\n    G->>O: Get orders\n    O-->>G: Order list\n  end\n  G->>N: Send notification\n  N-->>G: Queued\n  Note over G: Aggregate response",
      transparent: false,
    },
    {
      title: "Class: Basic Class",
      source: "classDiagram\n  class Animal {\n    +String name\n    +int age\n    +eat() void\n    +sleep() void\n  }",
      transparent: false,
    },
    {
      title: "Class: Visibility Markers",
      source: "classDiagram\n  class User {\n    +String name\n    -String password\n    #int internalId\n    ~String packageField\n    +login() bool\n    -hashPassword() String\n    #validate() void\n    ~notify() void\n  }",
      transparent: false,
    },
    {
      title: "Class: Interface Annotation",
      source: "classDiagram\n  class Serializable {\n    <<interface>>\n    +serialize() String\n    +deserialize(data) void\n  }",
      transparent: false,
    },
    {
      title: "Class: Abstract Annotation",
      source: "classDiagram\n  class Shape {\n    <<abstract>>\n    +String color\n    +area() double\n    +draw() void\n  }",
      transparent: false,
    },
    {
      title: "Class: Enum Annotation",
      source: "classDiagram\n  class Status {\n    <<enumeration>>\n    ACTIVE\n    INACTIVE\n    PENDING\n    DELETED\n  }",
      transparent: false,
    },
    {
      title: "Class: Inheritance (<|--)",
      source: "classDiagram\n  class Animal {\n    +String name\n    +eat() void\n  }\n  class Dog {\n    +String breed\n    +bark() void\n  }\n  class Cat {\n    +bool isIndoor\n    +meow() void\n  }\n  Animal <|-- Dog\n  Animal <|-- Cat",
      transparent: false,
    },
    {
      title: "Class: Composition (*--)",
      source: "classDiagram\n  class Car {\n    +String model\n    +start() void\n  }\n  class Engine {\n    +int horsepower\n    +rev() void\n  }\n  Car *-- Engine",
      transparent: false,
    },
    {
      title: "Class: Aggregation (o--)",
      source: "classDiagram\n  class University {\n    +String name\n  }\n  class Department {\n    +String faculty\n  }\n  University o-- Department",
      transparent: false,
    },
    {
      title: "Class: Association (-->)",
      source: "classDiagram\n  class Customer {\n    +String name\n  }\n  class Order {\n    +int orderId\n  }\n  Customer --> Order",
      transparent: false,
    },
    {
      title: "Class: Dependency (..>)",
      source: "classDiagram\n  class Service {\n    +process() void\n  }\n  class Repository {\n    +find() Object\n  }\n  Service ..> Repository",
      transparent: false,
    },
    {
      title: "Class: Realization (..|>)",
      source: "classDiagram\n  class Flyable {\n    <<interface>>\n    +fly() void\n  }\n  class Bird {\n    +fly() void\n    +sing() void\n  }\n  Bird ..|> Flyable",
      transparent: false,
    },
    {
      title: "Class: All 6 Relationship Types",
      source: "classDiagram\n  A <|-- B : inheritance\n  C *-- D : composition\n  E o-- F : aggregation\n  G --> H : association\n  I ..> J : dependency\n  K ..|> L : realization",
      transparent: false,
    },
    {
      title: "Class: Relationship Labels",
      source: "classDiagram\n  class Teacher {\n    +String name\n  }\n  class Student {\n    +String name\n  }\n  class Course {\n    +String title\n  }\n  Teacher --> Course : teaches\n  Student --> Course : enrolled in",
      transparent: false,
    },
    {
      title: "Class: Design Pattern - Observer",
      source: "classDiagram\n  class Subject {\n    <<interface>>\n    +attach(Observer) void\n    +detach(Observer) void\n    +notify() void\n  }\n  class Observer {\n    <<interface>>\n    +update() void\n  }\n  class EventEmitter {\n    -List~Observer~ observers\n    +attach(Observer) void\n    +detach(Observer) void\n    +notify() void\n  }\n  class Logger {\n    +update() void\n  }\n  class Alerter {\n    +update() void\n  }\n  Subject <|.. EventEmitter\n  Observer <|.. Logger\n  Observer <|.. Alerter\n  EventEmitter --> Observer",
      transparent: false,
    },
    {
      title: "Class: MVC Architecture",
      source: "classDiagram\n  class Model {\n    -data Map\n    +getData() Map\n    +setData(key, val) void\n    +notify() void\n  }\n  class View {\n    -model Model\n    +render() void\n    +update() void\n  }\n  class Controller {\n    -model Model\n    -view View\n    +handleInput(event) void\n    +updateModel(data) void\n  }\n  Controller --> Model : updates\n  Controller --> View : refreshes\n  View --> Model : reads\n  Model ..> View : notifies",
      transparent: false,
    },
    {
      title: "Class: Full Hierarchy",
      source: "classDiagram\n  class Animal {\n    <<abstract>>\n    +String name\n    +int age\n    +eat() void\n    +sleep() void\n  }\n  class Mammal {\n    +bool warmBlooded\n    +nurse() void\n  }\n  class Bird {\n    +bool canFly\n    +layEggs() void\n  }\n  class Dog {\n    +String breed\n    +bark() void\n  }\n  class Cat {\n    +bool isIndoor\n    +purr() void\n  }\n  class Parrot {\n    +String vocabulary\n    +speak() void\n  }\n  Animal <|-- Mammal\n  Animal <|-- Bird\n  Mammal <|-- Dog\n  Mammal <|-- Cat\n  Bird <|-- Parrot",
      transparent: false,
    },
    {
      title: "ER: Basic Relationship",
      source: "erDiagram\n  CUSTOMER ||--o{ ORDER : places",
      transparent: false,
    },
    {
      title: "ER: Entity with Attributes",
      source: "erDiagram\n  CUSTOMER {\n    int id PK\n    string name\n    string email UK\n    date created_at\n  }",
      transparent: false,
    },
    {
      title: "ER: Attribute Keys (PK, FK, UK)",
      source: "erDiagram\n  ORDER {\n    int id PK\n    int customer_id FK\n    string invoice_number UK\n    decimal total\n    date order_date\n    string status\n  }",
      transparent: false,
    },
    {
      title: "ER: Exactly One to Exactly One (||--||)",
      source: "erDiagram\n  PERSON ||--|| PASSPORT : has",
      transparent: false,
    },
    {
      title: "ER: Exactly One to Zero-or-Many (||--o{)",
      source: "erDiagram\n  CUSTOMER ||--o{ ORDER : places",
      transparent: false,
    },
    {
      title: "ER: Zero-or-One to One-or-Many (|o--|{)",
      source: "erDiagram\n  SUPERVISOR |o--|{ EMPLOYEE : manages",
      transparent: false,
    },
    {
      title: "ER: One-or-More to Zero-or-Many (}|--o{)",
      source: "erDiagram\n  TEACHER }|--o{ COURSE : teaches",
      transparent: false,
    },
    {
      title: "ER: All Cardinality Types",
      source: "erDiagram\n  A ||--|| B : one-to-one\n  C ||--o{ D : one-to-many\n  E |o--|{ F : opt-to-many\n  G }|--o{ H : many-to-many",
      transparent: false,
    },
    {
      title: "ER: Identifying (Solid) Relationship",
      source: "erDiagram\n  ORDER ||--|{ LINE_ITEM : contains",
      transparent: false,
    },
    {
      title: "ER: Non-Identifying (Dashed) Relationship",
      source: "erDiagram\n  USER ||..o{ LOG_ENTRY : generates\n  USER ||..o{ SESSION : opens",
      transparent: false,
    },
    {
      title: "ER: Mixed Identifying & Non-Identifying",
      source: "erDiagram\n  ORDER ||--|{ LINE_ITEM : contains\n  ORDER ||..o{ SHIPMENT : ships-via\n  PRODUCT ||--o{ LINE_ITEM : includes\n  PRODUCT ||..o{ REVIEW : receives",
      transparent: false,
    },
    {
      title: "ER: E-Commerce Schema",
      source: "erDiagram\n  CUSTOMER {\n    int id PK\n    string name\n    string email UK\n  }\n  ORDER {\n    int id PK\n    date created\n    int customer_id FK\n  }\n  PRODUCT {\n    int id PK\n    string name\n    float price\n  }\n  LINE_ITEM {\n    int id PK\n    int order_id FK\n    int product_id FK\n    int quantity\n  }\n  CUSTOMER ||--o{ ORDER : places\n  ORDER ||--|{ LINE_ITEM : contains\n  PRODUCT ||--o{ LINE_ITEM : includes",
      transparent: false,
    },
    {
      title: "ER: Blog Platform Schema",
      source: "erDiagram\n  USER {\n    int id PK\n    string username UK\n    string email UK\n    date joined\n  }\n  POST {\n    int id PK\n    string title\n    text content\n    int author_id FK\n    date published\n  }\n  COMMENT {\n    int id PK\n    text body\n    int post_id FK\n    int user_id FK\n    date created\n  }\n  TAG {\n    int id PK\n    string name UK\n  }\n  USER ||--o{ POST : writes\n  USER ||--o{ COMMENT : authors\n  POST ||--o{ COMMENT : has\n  POST }|--o{ TAG : tagged-with",
      transparent: false,
    },
    {
      title: "ER: School Management Schema",
      source: "erDiagram\n  STUDENT {\n    int id PK\n    string name\n    date dob\n    string grade\n  }\n  TEACHER {\n    int id PK\n    string name\n    string department\n  }\n  COURSE {\n    int id PK\n    string title\n    int teacher_id FK\n    int credits\n  }\n  ENROLLMENT {\n    int id PK\n    int student_id FK\n    int course_id FK\n    string semester\n    float grade\n  }\n  TEACHER ||--o{ COURSE : teaches\n  STUDENT ||--o{ ENROLLMENT : enrolled\n  COURSE ||--o{ ENROLLMENT : has",
      transparent: false,
    },
  ]
}

///|
fn non_empty_output(value : String) -> Bool {
  @test_support.normalize_whitespace(value) != ""
}

///|
test "Render smoke for upstream samples-data corpus" (it : @test.Test) {
  let svg_sections : Array[String] = []
  for sample in upstream_samples() {
    let svg_options = @beautiful_mermaid.RenderOptions::{
      bg: None,
      fg: None,
      line: None,
      accent: None,
      muted: None,
      surface: None,
      border: None,
      font: None,
      padding: None,
      node_spacing: None,
      layer_spacing: None,
      transparent: Some(sample.transparent),
    }
    let svg = try! @beautiful_mermaid.render_mermaid(
      sample.source,
      options=svg_options,
    )
    if !svg.has_prefix("<svg ") || !svg.has_suffix("</svg>") {
      fail("invalid svg envelope for sample: \{sample.title}")
    }
    let section = (
        $|<section><h2>\{sample.title}</h2>
        $|\{svg}
        $|</section>
        $|
      )
      .trim_end()
      .to_string()
    svg_sections.push(section)
    if sample.transparent {
      assert_true(!svg.contains("background:var(--bg)"))
    }

    let ascii = try! @beautiful_mermaid.render_mermaid_ascii(sample.source, options={
      use_ascii: true,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    })
    if !non_empty_output(ascii) {
      fail("empty ascii output for sample: \{sample.title}")
    }

    let unicode = try! @beautiful_mermaid.render_mermaid_ascii(sample.source, options={
      use_ascii: false,
      padding_x: 5,
      padding_y: 5,
      box_border_padding: 1,
    })
    if !non_empty_output(unicode) {
      fail("empty unicode output for sample: \{sample.title}")
    }
  }

  let gallery_body = svg_sections.join("\n<hr/>\n")
  let gallery = (
      $|<!doctype html><html><head><meta charset="utf-8" /><title>Upstream Samples SVG Gallery</title></head><body>
      $|\{gallery_body}
      $|</body></html>
      $|
    )
    .trim_end()
    .to_string()
  it.write(gallery)
  it.snapshot(filename="upstream_samples_smoke_gallery.html")
}
