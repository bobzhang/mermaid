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
      source: (
        #|graph LR
        #|  A[(Database)] --> B>Flag Shape]
        #|  B --> C[/Wider Bottom\]
        #|  C --> D[\Wider Top/]
      ),
      transparent: false,
    },
    {
      title: "All 12 Flowchart Shapes",
      source: (
        #|graph LR
        #|  A[Rectangle] --> B(Rounded)
        #|  B --> C{Diamond}
        #|  C --> D([Stadium])
        #|  D --> E((Circle))
        #|  E --> F[[Subroutine]]
        #|  F --> G(((Double Circle)))
        #|  G --> H{{Hexagon}}
        #|  H --> I[(Database)]
        #|  I --> J>Flag]
        #|  J --> K[/Trapezoid\]
        #|  K --> L[\Inverse Trap/]
      ),
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
      source: (
        #|graph LR
        #|  A[Step 1] --> B[Step 2] --> C[Step 3] --> D[Step 4] --> E[Step 5]
      ),
      transparent: false,
    },
    {
      title: "Direction: Left-Right (LR)",
      source: (
        #|graph LR
        #|  A[Input] --> B[Transform] --> C[Output]
      ),
      transparent: false,
    },
    {
      title: "Direction: Bottom-Top (BT)",
      source: (
        #|graph BT
        #|  A[Foundation] --> B[Layer 2] --> C[Top]
      ),
      transparent: false,
    },
    {
      title: "Subgraphs",
      source: (
        #|graph TD
        #|  subgraph Frontend
        #|    A[React App] --> B[State Manager]
        #|  end
        #|  subgraph Backend
        #|    C[API Server] --> D[Database]
        #|  end
        #|  B --> C
      ),
      transparent: false,
    },
    {
      title: "Nested Subgraphs",
      source: (
        #|graph TD
        #|  subgraph Cloud
        #|    subgraph us-east [US East Region]
        #|      A[Web Server] --> B[App Server]
        #|    end
        #|    subgraph us-west [US West Region]
        #|      C[Web Server] --> D[App Server]
        #|    end
        #|  end
        #|  E[Load Balancer] --> A
        #|  E --> C
      ),
      transparent: false,
    },
    {
      title: "Subgraph Direction Override",
      source: (
        #|graph TD
        #|  subgraph pipeline [Processing Pipeline]
        #|    direction LR
        #|    A[Input] --> B[Parse] --> C[Transform] --> D[Output]
        #|  end
        #|  E[Source] --> A
        #|  D --> F[Sink]
      ),
      transparent: false,
    },
    {
      title: "::: Class Shorthand",
      source: (
        #|graph TD
        #|  A[Normal]:::default --> B[Highlighted]:::highlight --> C[Error]:::error
        #|  classDef default fill:#f4f4f5,stroke:#a1a1aa
        #|  classDef highlight fill:#fbbf24,stroke:#d97706
        #|  classDef error fill:#ef4444,stroke:#dc2626
      ),
      transparent: false,
    },
    {
      title: "Inline Style Overrides",
      source: (
        #|graph TD
        #|  A[Default] --> B[Custom Colors] --> C[Another Custom]
        #|  style B fill:#3b82f6,stroke:#1d4ed8,color:#ffffff
        #|  style C fill:#10b981,stroke:#059669
      ),
      transparent: false,
    },
    {
      title: "CI/CD Pipeline",
      source: (
        #|graph TD
        #|  subgraph ci [CI Pipeline]
        #|    A[Push Code] --> B{Tests Pass?}
        #|    B -->|Yes| C[Build Image]
        #|    B -->|No| D[Fix & Retry]
        #|    D -.-> A
        #|  end
        #|  C --> E([Deploy Staging])
        #|  E --> F{QA Approved?}
        #|  F -->|Yes| G((Production))
        #|  F -->|No| D
      ),
      transparent: false,
    },
    {
      title: "System Architecture",
      source: (
        #|graph LR
        #|  subgraph clients [Client Layer]
        #|    A([Web App]) --> B[API Gateway]
        #|    C([Mobile App]) --> B
        #|  end
        #|  subgraph services [Service Layer]
        #|    B --> D[Auth Service]
        #|    B --> E[User Service]
        #|    B --> F[Order Service]
        #|  end
        #|  subgraph data [Data Layer]
        #|    D --> G[(Auth DB)]
        #|    E --> H[(User DB)]
        #|    F --> I[(Order DB)]
        #|    F --> J([Message Queue])
        #|  end
      ),
      transparent: false,
    },
    {
      title: "Decision Tree",
      source: (
        #|graph TD
        #|  A{Is it raining?} -->|Yes| B{Have umbrella?}
        #|  A -->|No| C([Go outside])
        #|  B -->|Yes| D([Go with umbrella])
        #|  B -->|No| E{Is it heavy?}
        #|  E -->|Yes| F([Stay inside])
        #|  E -->|No| G([Run for it])
      ),
      transparent: false,
    },
    {
      title: "Git Branching Workflow",
      source: (
        #|graph LR
        #|  A[main] --> B[develop]
        #|  B --> C[feature/auth]
        #|  B --> D[feature/ui]
        #|  C --> E{PR Review}
        #|  D --> E
        #|  E -->|approved| B
        #|  B --> F[release/1.0]
        #|  F --> G{Tests?}
        #|  G -->|pass| A
        #|  G -->|fail| F
      ),
      transparent: false,
    },
    {
      title: "Basic State Diagram",
      source: (
        #|stateDiagram-v2
        #|  [*] --> Idle
        #|  Idle --> Active : start
        #|  Active --> Idle : cancel
        #|  Active --> Done : complete
        #|  Done --> [*]
      ),
      transparent: false,
    },
    {
      title: "State: Composite States",
      source: (
        #|stateDiagram-v2
        #|  [*] --> Idle
        #|  Idle --> Processing : submit
        #|  state Processing {
        #|    parse --> validate
        #|    validate --> execute
        #|  }
        #|  Processing --> Complete : done
        #|  Processing --> Error : fail
        #|  Error --> Idle : retry
        #|  Complete --> [*]
      ),
      transparent: false,
    },
    {
      title: "State: Connection Lifecycle",
      source: (
        #|stateDiagram-v2
        #|  [*] --> Closed
        #|  Closed --> Connecting : connect
        #|  Connecting --> Connected : success
        #|  Connecting --> Closed : timeout
        #|  Connected --> Disconnecting : close
        #|  Connected --> Reconnecting : error
        #|  Reconnecting --> Connected : success
        #|  Reconnecting --> Closed : max_retries
        #|  Disconnecting --> Closed : done
        #|  Closed --> [*]
      ),
      transparent: false,
    },
    {
      title: "Sequence: Basic Messages",
      source: (
        #|sequenceDiagram
        #|  Alice->>Bob: Hello Bob!
        #|  Bob-->>Alice: Hi Alice!
      ),
      transparent: false,
    },
    {
      title: "Sequence: Participant Aliases",
      source: (
        #|sequenceDiagram
        #|  participant A as Alice
        #|  participant B as Bob
        #|  participant C as Charlie
        #|  A->>B: Hello
        #|  B->>C: Forward
        #|  C-->>A: Reply
      ),
      transparent: false,
    },
    {
      title: "Sequence: Actor Stick Figures",
      source: (
        #|sequenceDiagram
        #|  actor U as User
        #|  participant S as System
        #|  participant DB as Database
        #|  U->>S: Click button
        #|  S->>DB: Query
        #|  DB-->>S: Results
        #|  S-->>U: Display
      ),
      transparent: false,
    },
    {
      title: "Sequence: Arrow Types",
      source: (
        #|sequenceDiagram
        #|  A->>B: Solid arrow (sync)
        #|  B-->>A: Dashed arrow (return)
        #|  A-)B: Open arrow (async)
        #|  B--)A: Open dashed arrow
      ),
      transparent: false,
    },
    {
      title: "Sequence: Activation Boxes",
      source: (
        #|sequenceDiagram
        #|  participant C as Client
        #|  participant S as Server
        #|  C->>+S: Request
        #|  S->>+S: Process
        #|  S->>-S: Done
        #|  S-->>-C: Response
      ),
      transparent: false,
    },
    {
      title: "Sequence: Self-Messages",
      source: (
        #|sequenceDiagram
        #|  participant S as Server
        #|  S->>S: Internal process
        #|  S->>S: Validate
        #|  S-->>S: Log
      ),
      transparent: false,
    },
    {
      title: "Sequence: Loop Block",
      source: (
        #|sequenceDiagram
        #|  participant C as Client
        #|  participant S as Server
        #|  C->>S: Connect
        #|  loop Every 30s
        #|    C->>S: Heartbeat
        #|    S-->>C: Ack
        #|  end
        #|  C->>S: Disconnect
      ),
      transparent: false,
    },
    {
      title: "Sequence: Alt/Else Block",
      source: (
        #|sequenceDiagram
        #|  participant C as Client
        #|  participant S as Server
        #|  C->>S: Login
        #|  alt Valid credentials
        #|    S-->>C: 200 OK
        #|  else Invalid
        #|    S-->>C: 401 Unauthorized
        #|  else Account locked
        #|    S-->>C: 403 Forbidden
        #|  end
      ),
      transparent: false,
    },
    {
      title: "Sequence: Opt Block",
      source: (
        #|sequenceDiagram
        #|  participant A as App
        #|  participant C as Cache
        #|  participant DB as Database
        #|  A->>C: Get data
        #|  C-->>A: Cache miss
        #|  opt Cache miss
        #|    A->>DB: Query
        #|    DB-->>A: Results
        #|    A->>C: Store in cache
        #|  end
      ),
      transparent: false,
    },
    {
      title: "Sequence: Par Block",
      source: (
        #|sequenceDiagram
        #|  participant C as Client
        #|  participant A as AuthService
        #|  participant U as UserService
        #|  participant O as OrderService
        #|  C->>A: Authenticate
        #|  par Fetch user data
        #|    A->>U: Get profile
        #|  and Fetch orders
        #|    A->>O: Get orders
        #|  end
        #|  A-->>C: Combined response
      ),
      transparent: false,
    },
    {
      title: "Sequence: Critical Block",
      source: (
        #|sequenceDiagram
        #|  participant A as App
        #|  participant DB as Database
        #|  A->>DB: BEGIN
        #|  critical Transaction
        #|    A->>DB: UPDATE accounts
        #|    A->>DB: INSERT log
        #|  end
        #|  A->>DB: COMMIT
      ),
      transparent: false,
    },
    {
      title: "Sequence: Notes (Right/Left/Over)",
      source: (
        #|sequenceDiagram
        #|  participant A as Alice
        #|  participant B as Bob
        #|  Note left of A: Alice prepares
        #|  A->>B: Hello
        #|  Note right of B: Bob thinks
        #|  B-->>A: Reply
        #|  Note over A,B: Conversation complete
      ),
      transparent: false,
    },
    {
      title: "Sequence: OAuth 2.0 Flow",
      source: (
        #|sequenceDiagram
        #|  actor U as User
        #|  participant App as Client App
        #|  participant Auth as Auth Server
        #|  participant API as Resource API
        #|  U->>App: Click Login
        #|  App->>Auth: Authorization request
        #|  Auth->>U: Login page
        #|  U->>Auth: Credentials
        #|  Auth-->>App: Authorization code
        #|  App->>Auth: Exchange code for token
        #|  Auth-->>App: Access token
        #|  App->>API: Request + token
        #|  API-->>App: Protected resource
        #|  App-->>U: Display data
      ),
      transparent: false,
    },
    {
      title: "Sequence: Database Transaction",
      source: (
        #|sequenceDiagram
        #|  participant C as Client
        #|  participant S as Server
        #|  participant DB as Database
        #|  C->>S: POST /transfer
        #|  S->>DB: BEGIN
        #|  S->>DB: Debit account A
        #|  alt Success
        #|    S->>DB: Credit account B
        #|    S->>DB: INSERT audit_log
        #|    S->>DB: COMMIT
        #|    S-->>C: 200 OK
        #|  else Insufficient funds
        #|    S->>DB: ROLLBACK
        #|    S-->>C: 400 Bad Request
        #|  end
      ),
      transparent: false,
    },
    {
      title: "Sequence: Microservice Orchestration",
      source: (
        #|sequenceDiagram
        #|  participant G as Gateway
        #|  participant A as Auth
        #|  participant U as Users
        #|  participant O as Orders
        #|  participant N as Notify
        #|  G->>A: Validate token
        #|  A-->>G: Valid
        #|  par Fetch data
        #|    G->>U: Get user
        #|    U-->>G: User data
        #|  and
        #|    G->>O: Get orders
        #|    O-->>G: Order list
        #|  end
        #|  G->>N: Send notification
        #|  N-->>G: Queued
        #|  Note over G: Aggregate response
      ),
      transparent: false,
    },
    {
      title: "Class: Basic Class",
      source: (
        #|classDiagram
        #|  class Animal {
        #|    +String name
        #|    +int age
        #|    +eat() void
        #|    +sleep() void
        #|  }
      ),
      transparent: false,
    },
    {
      title: "Class: Visibility Markers",
      source: (
        #|classDiagram
        #|  class User {
        #|    +String name
        #|    -String password
        #|    #int internalId
        #|    ~String packageField
        #|    +login() bool
        #|    -hashPassword() String
        #|    #validate() void
        #|    ~notify() void
        #|  }
      ),
      transparent: false,
    },
    {
      title: "Class: Interface Annotation",
      source: (
        #|classDiagram
        #|  class Serializable {
        #|    <<interface>>
        #|    +serialize() String
        #|    +deserialize(data) void
        #|  }
      ),
      transparent: false,
    },
    {
      title: "Class: Abstract Annotation",
      source: (
        #|classDiagram
        #|  class Shape {
        #|    <<abstract>>
        #|    +String color
        #|    +area() double
        #|    +draw() void
        #|  }
      ),
      transparent: false,
    },
    {
      title: "Class: Enum Annotation",
      source: (
        #|classDiagram
        #|  class Status {
        #|    <<enumeration>>
        #|    ACTIVE
        #|    INACTIVE
        #|    PENDING
        #|    DELETED
        #|  }
      ),
      transparent: false,
    },
    {
      title: "Class: Inheritance (<|--)",
      source: (
        #|classDiagram
        #|  class Animal {
        #|    +String name
        #|    +eat() void
        #|  }
        #|  class Dog {
        #|    +String breed
        #|    +bark() void
        #|  }
        #|  class Cat {
        #|    +bool isIndoor
        #|    +meow() void
        #|  }
        #|  Animal <|-- Dog
        #|  Animal <|-- Cat
      ),
      transparent: false,
    },
    {
      title: "Class: Composition (*--)",
      source: (
        #|classDiagram
        #|  class Car {
        #|    +String model
        #|    +start() void
        #|  }
        #|  class Engine {
        #|    +int horsepower
        #|    +rev() void
        #|  }
        #|  Car *-- Engine
      ),
      transparent: false,
    },
    {
      title: "Class: Aggregation (o--)",
      source: (
        #|classDiagram
        #|  class University {
        #|    +String name
        #|  }
        #|  class Department {
        #|    +String faculty
        #|  }
        #|  University o-- Department
      ),
      transparent: false,
    },
    {
      title: "Class: Association (-->)",
      source: (
        #|classDiagram
        #|  class Customer {
        #|    +String name
        #|  }
        #|  class Order {
        #|    +int orderId
        #|  }
        #|  Customer --> Order
      ),
      transparent: false,
    },
    {
      title: "Class: Dependency (..>)",
      source: (
        #|classDiagram
        #|  class Service {
        #|    +process() void
        #|  }
        #|  class Repository {
        #|    +find() Object
        #|  }
        #|  Service ..> Repository
      ),
      transparent: false,
    },
    {
      title: "Class: Realization (..|>)",
      source: (
        #|classDiagram
        #|  class Flyable {
        #|    <<interface>>
        #|    +fly() void
        #|  }
        #|  class Bird {
        #|    +fly() void
        #|    +sing() void
        #|  }
        #|  Bird ..|> Flyable
      ),
      transparent: false,
    },
    {
      title: "Class: All 6 Relationship Types",
      source: (
        #|classDiagram
        #|  A <|-- B : inheritance
        #|  C *-- D : composition
        #|  E o-- F : aggregation
        #|  G --> H : association
        #|  I ..> J : dependency
        #|  K ..|> L : realization
      ),
      transparent: false,
    },
    {
      title: "Class: Relationship Labels",
      source: (
        #|classDiagram
        #|  class Teacher {
        #|    +String name
        #|  }
        #|  class Student {
        #|    +String name
        #|  }
        #|  class Course {
        #|    +String title
        #|  }
        #|  Teacher --> Course : teaches
        #|  Student --> Course : enrolled in
      ),
      transparent: false,
    },
    {
      title: "Class: Design Pattern - Observer",
      source: (
        #|classDiagram
        #|  class Subject {
        #|    <<interface>>
        #|    +attach(Observer) void
        #|    +detach(Observer) void
        #|    +notify() void
        #|  }
        #|  class Observer {
        #|    <<interface>>
        #|    +update() void
        #|  }
        #|  class EventEmitter {
        #|    -List~Observer~ observers
        #|    +attach(Observer) void
        #|    +detach(Observer) void
        #|    +notify() void
        #|  }
        #|  class Logger {
        #|    +update() void
        #|  }
        #|  class Alerter {
        #|    +update() void
        #|  }
        #|  Subject <|.. EventEmitter
        #|  Observer <|.. Logger
        #|  Observer <|.. Alerter
        #|  EventEmitter --> Observer
      ),
      transparent: false,
    },
    {
      title: "Class: MVC Architecture",
      source: (
        #|classDiagram
        #|  class Model {
        #|    -data Map
        #|    +getData() Map
        #|    +setData(key, val) void
        #|    +notify() void
        #|  }
        #|  class View {
        #|    -model Model
        #|    +render() void
        #|    +update() void
        #|  }
        #|  class Controller {
        #|    -model Model
        #|    -view View
        #|    +handleInput(event) void
        #|    +updateModel(data) void
        #|  }
        #|  Controller --> Model : updates
        #|  Controller --> View : refreshes
        #|  View --> Model : reads
        #|  Model ..> View : notifies
      ),
      transparent: false,
    },
    {
      title: "Class: Full Hierarchy",
      source: (
        #|classDiagram
        #|  class Animal {
        #|    <<abstract>>
        #|    +String name
        #|    +int age
        #|    +eat() void
        #|    +sleep() void
        #|  }
        #|  class Mammal {
        #|    +bool warmBlooded
        #|    +nurse() void
        #|  }
        #|  class Bird {
        #|    +bool canFly
        #|    +layEggs() void
        #|  }
        #|  class Dog {
        #|    +String breed
        #|    +bark() void
        #|  }
        #|  class Cat {
        #|    +bool isIndoor
        #|    +purr() void
        #|  }
        #|  class Parrot {
        #|    +String vocabulary
        #|    +speak() void
        #|  }
        #|  Animal <|-- Mammal
        #|  Animal <|-- Bird
        #|  Mammal <|-- Dog
        #|  Mammal <|-- Cat
        #|  Bird <|-- Parrot
      ),
      transparent: false,
    },
    {
      title: "ER: Basic Relationship",
      source: (
        #|erDiagram
        #|  CUSTOMER ||--o{ ORDER : places
      ),
      transparent: false,
    },
    {
      title: "ER: Entity with Attributes",
      source: (
        #|erDiagram
        #|  CUSTOMER {
        #|    int id PK
        #|    string name
        #|    string email UK
        #|    date created_at
        #|  }
      ),
      transparent: false,
    },
    {
      title: "ER: Attribute Keys (PK, FK, UK)",
      source: (
        #|erDiagram
        #|  ORDER {
        #|    int id PK
        #|    int customer_id FK
        #|    string invoice_number UK
        #|    decimal total
        #|    date order_date
        #|    string status
        #|  }
      ),
      transparent: false,
    },
    {
      title: "ER: Exactly One to Exactly One (||--||)",
      source: (
        #|erDiagram
        #|  PERSON ||--|| PASSPORT : has
      ),
      transparent: false,
    },
    {
      title: "ER: Exactly One to Zero-or-Many (||--o{)",
      source: (
        #|erDiagram
        #|  CUSTOMER ||--o{ ORDER : places
      ),
      transparent: false,
    },
    {
      title: "ER: Zero-or-One to One-or-Many (|o--|{)",
      source: (
        #|erDiagram
        #|  SUPERVISOR |o--|{ EMPLOYEE : manages
      ),
      transparent: false,
    },
    {
      title: "ER: One-or-More to Zero-or-Many (}|--o{)",
      source: (
        #|erDiagram
        #|  TEACHER }|--o{ COURSE : teaches
      ),
      transparent: false,
    },
    {
      title: "ER: All Cardinality Types",
      source: (
        #|erDiagram
        #|  A ||--|| B : one-to-one
        #|  C ||--o{ D : one-to-many
        #|  E |o--|{ F : opt-to-many
        #|  G }|--o{ H : many-to-many
      ),
      transparent: false,
    },
    {
      title: "ER: Identifying (Solid) Relationship",
      source: (
        #|erDiagram
        #|  ORDER ||--|{ LINE_ITEM : contains
      ),
      transparent: false,
    },
    {
      title: "ER: Non-Identifying (Dashed) Relationship",
      source: (
        #|erDiagram
        #|  USER ||..o{ LOG_ENTRY : generates
        #|  USER ||..o{ SESSION : opens
      ),
      transparent: false,
    },
    {
      title: "ER: Mixed Identifying & Non-Identifying",
      source: (
        #|erDiagram
        #|  ORDER ||--|{ LINE_ITEM : contains
        #|  ORDER ||..o{ SHIPMENT : ships-via
        #|  PRODUCT ||--o{ LINE_ITEM : includes
        #|  PRODUCT ||..o{ REVIEW : receives
      ),
      transparent: false,
    },
    {
      title: "ER: E-Commerce Schema",
      source: (
        #|erDiagram
        #|  CUSTOMER {
        #|    int id PK
        #|    string name
        #|    string email UK
        #|  }
        #|  ORDER {
        #|    int id PK
        #|    date created
        #|    int customer_id FK
        #|  }
        #|  PRODUCT {
        #|    int id PK
        #|    string name
        #|    float price
        #|  }
        #|  LINE_ITEM {
        #|    int id PK
        #|    int order_id FK
        #|    int product_id FK
        #|    int quantity
        #|  }
        #|  CUSTOMER ||--o{ ORDER : places
        #|  ORDER ||--|{ LINE_ITEM : contains
        #|  PRODUCT ||--o{ LINE_ITEM : includes
      ),
      transparent: false,
    },
    {
      title: "ER: Blog Platform Schema",
      source: (
        #|erDiagram
        #|  USER {
        #|    int id PK
        #|    string username UK
        #|    string email UK
        #|    date joined
        #|  }
        #|  POST {
        #|    int id PK
        #|    string title
        #|    text content
        #|    int author_id FK
        #|    date published
        #|  }
        #|  COMMENT {
        #|    int id PK
        #|    text body
        #|    int post_id FK
        #|    int user_id FK
        #|    date created
        #|  }
        #|  TAG {
        #|    int id PK
        #|    string name UK
        #|  }
        #|  USER ||--o{ POST : writes
        #|  USER ||--o{ COMMENT : authors
        #|  POST ||--o{ COMMENT : has
        #|  POST }|--o{ TAG : tagged-with
      ),
      transparent: false,
    },
    {
      title: "ER: School Management Schema",
      source: (
        #|erDiagram
        #|  STUDENT {
        #|    int id PK
        #|    string name
        #|    date dob
        #|    string grade
        #|  }
        #|  TEACHER {
        #|    int id PK
        #|    string name
        #|    string department
        #|  }
        #|  COURSE {
        #|    int id PK
        #|    string title
        #|    int teacher_id FK
        #|    int credits
        #|  }
        #|  ENROLLMENT {
        #|    int id PK
        #|    int student_id FK
        #|    int course_id FK
        #|    string semester
        #|    float grade
        #|  }
        #|  TEACHER ||--o{ COURSE : teaches
        #|  STUDENT ||--o{ ENROLLMENT : enrolled
        #|  COURSE ||--o{ ENROLLMENT : has
      ),
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
