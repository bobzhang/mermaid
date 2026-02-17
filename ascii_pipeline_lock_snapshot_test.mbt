///|
fn lock_options(use_ascii : Bool) -> @model.AsciiRenderOptions {
  { use_ascii, padding_x: 5, padding_y: 5, box_border_padding: 1 }
}

///|
fn inspect_ascii_and_unicode(input : String) -> String raise {
  let ascii = @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=lock_options(true),
  )
  let unicode = @beautiful_mermaid.render_mermaid_ascii(
    input,
    options=lock_options(false),
  )
  (
    #|# ASCII
    #|
  ) +
  ascii +
  (
    #|
    #|
    #|# UNICODE
    #|
  ) +
  unicode
}

///|
test "ASCII pipeline lock flowchart subgraph snapshots" {
  let input =
    #|graph TD
    #|subgraph Build
    #|A[Checkout] --> B[Compile]
    #|B --> C[Test]
    #|end
    #|C --> D([Ship])
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|+--------------+
      #||    Build     |
      #||              |
      #||              |
      #|| +----------+ |
      #|| |          | |
      #|| | Checkout | |
      #|| |          | |
      #|| +----------+ |
      #||       |      |
      #||       |      |
      #||       |      |
      #||       |      |
      #||       v      |
      #|| +----------+ |
      #|| |          | |
      #|| | Compile  | |
      #|| |          | |
      #|| +----------+ |
      #||       |      |
      #||       |      |
      #||       |      |
      #||       |      |
      #||       v      |
      #|| +----------+ |
      #|| |          | |
      #|| |   Test   | |
      #|| |          | |
      #|| +----------+ |
      #||       |      |
      #|+-------|------+
      #|        |       
      #|        |       
      #|        v       
      #|  +----------+  
      #|  |          |  
      #|  |   Ship   |  
      #|  |          |  
      #|  +----------+  
      #|
      #|# UNICODE
      #|┌──────────────┐
      #|│    Build     │
      #|│              │
      #|│              │
      #|│ ┌──────────┐ │
      #|│ │          │ │
      #|│ │ Checkout │ │
      #|│ │          │ │
      #|│ └─────┬────┘ │
      #|│       │      │
      #|│       │      │
      #|│       │      │
      #|│       │      │
      #|│       ▼      │
      #|│ ┌──────────┐ │
      #|│ │          │ │
      #|│ │ Compile  │ │
      #|│ │          │ │
      #|│ └─────┬────┘ │
      #|│       │      │
      #|│       │      │
      #|│       │      │
      #|│       │      │
      #|│       ▼      │
      #|│ ┌──────────┐ │
      #|│ │          │ │
      #|│ │   Test   │ │
      #|│ │          │ │
      #|│ └─────┬────┘ │
      #|│       │      │
      #|└───────┼──────┘
      #|        │       
      #|        │       
      #|        ▼       
      #|  ┌──────────┐  
      #|  │          │  
      #|  │   Ship   │  
      #|  │          │  
      #|  └──────────┘  
    ),
  )
}

///|
test "ASCII pipeline lock state snapshots" {
  let input =
    #|stateDiagram-v2
    #|[*] --> Idle
    #|Idle --> Active : start
    #|state Active {
    #|  Running --> Waiting
    #|  Waiting --> Running : resume
    #|}
    #|Active --> [*] : stop
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|             +-------------+
      #|             |   Active    |
      #|             |             |
      #|             |             |
      #|+--------+   | +---------+ |
      #||        |   | |         | |
      #||        |   | | Running | |
      #||        |   | |         | |
      #|+--------+   | +---------+ |
      #|     |       |      ^      |
      #|     |       |      |      |
      #|     |       |   resume    |
      #|     |       |      |      |
      #|     v       |      v      |
      #|+--------+   | +---------+ |
      #||        |   | |         | |
      #||  Idle  |   | | Waiting | |
      #||        |   | |         | |
      #|+--------+   | +---------+ |
      #|     |       |             |
      #|     |       +-------------+
      #|   start                    
      #|     |                      
      #|     v                      
      #|+--------+                  
      #||        |                  
      #|| Active |                  
      #||        |                  
      #|+--------+                  
      #|     |                      
      #|     |                      
      #|   stop                     
      #|     |                      
      #|     v                      
      #|+--------+                  
      #||        |                  
      #||        |                  
      #||        |                  
      #|+--------+                  
      #|
      #|# UNICODE
      #|             ┌─────────────┐
      #|             │   Active    │
      #|             │             │
      #|             │             │
      #|┌────────┐   │ ┌─────────┐ │
      #|│        │   │ │         │ │
      #|│        │   │ │ Running │ │
      #|│        │   │ │         │ │
      #|└────┬───┘   │ └────┬────┘ │
      #|     │       │      ▲      │
      #|     │       │      │      │
      #|     │       │   resume    │
      #|     │       │      │      │
      #|     ▼       │      ▼      │
      #|┌────────┐   │ ┌────┴────┐ │
      #|│        │   │ │         │ │
      #|│  Idle  │   │ │ Waiting │ │
      #|│        │   │ │         │ │
      #|└────┬───┘   │ └─────────┘ │
      #|     │       │             │
      #|     │       └─────────────┘
      #|   start                    
      #|     │                      
      #|     ▼                      
      #|┌────────┐                  
      #|│        │                  
      #|│ Active │                  
      #|│        │                  
      #|└────┬───┘                  
      #|     │                      
      #|     │                      
      #|   stop                     
      #|     │                      
      #|     ▼                      
      #|┌────────┐                  
      #|│        │                  
      #|│        │                  
      #|│        │                  
      #|└────────┘                  
    ),
  )
}

///|
test "ASCII pipeline lock sequence snapshots" {
  let input =
    #|sequenceDiagram
    #|participant A
    #|participant B
    #|A->>B: Request
    #|alt Success
    #|B-->>A: 200
    #|else Failure
    #|B-->>A: 500
    #|end
    #|Note right of B: inspect
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #| +---+        +---+            
      #| | A |        | B |            
      #| +---+        +---+            
      #|   |            |              
      #|   |  Request   |              
      #|   |------------>              
      #|   |            |              
      #|+alt [Success]------+          
      #||  |            |   |          
      #||  |    200     |   |          
      #||  <............|   |          
      #||  |            |   |          
      #|+[Failure]----------+          
      #||  |            |   |          
      #||  |    500     |   |          
      #||  <............|   |          
      #||  |            |   |          
      #||  |            | +---------+  
      #||  |            | | inspect |  
      #||  |            | +---------+  
      #||  |            |   |          
      #|+-------------------+          
      #|   |            |              
      #| +---+        +---+            
      #| | A |        | B |            
      #| +---+        +---+            
      #|
      #|# UNICODE
      #| ┌───┐        ┌───┐            
      #| │ A │        │ B │            
      #| └─┬─┘        └─┬─┘            
      #|   │            │              
      #|   │  Request   │              
      #|   │────────────▶              
      #|   │            │              
      #|┌alt [Success]──────┐          
      #|│  │            │   │          
      #|│  │    200     │   │          
      #|│  ◀╌╌╌╌╌╌╌╌╌╌╌╌│   │          
      #|│  │            │   │          
      #|├[Failure]╌╌╌╌╌╌╌╌╌╌┤          
      #|│  │            │   │          
      #|│  │    500     │   │          
      #|│  ◀╌╌╌╌╌╌╌╌╌╌╌╌│   │          
      #|│  │            │   │          
      #|│  │            │ ┌─────────┐  
      #|│  │            │ │ inspect │  
      #|│  │            │ └─────────┘  
      #|│  │            │   │          
      #|└───────────────────┘          
      #|   │            │              
      #| ┌─┴─┐        ┌─┴─┐            
      #| │ A │        │ B │            
      #| └───┘        └───┘            
    ),
  )
}

///|
test "ASCII pipeline lock class snapshots" {
  let input =
    #|classDiagram
    #|Animal <|-- Duck : extends
    #|Duck o-- Feather : has
    #|Duck ..> Pond : visits
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|+--------+                 
      #|| Animal |                 
      #|+--------+                 
      #|     ^                     
      #| extends                   
      #|    |                      
      #|+------+                   
      #|| Duck |                   
      #|+------+                   
      #|    :                      
      #|   h... visits .....       
      #|     |             v       
      #|+---------+    +------+    
      #|| Feather |    | Pond |    
      #|+---------+    +------+    
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|
      #|# UNICODE
      #|┌────────┐                 
      #|│ Animal │                 
      #|└────────┘                 
      #|     △                     
      #| extends                   
      #|    │                      
      #|┌──────┐                   
      #|│ Duck │                   
      #|└──────┘                   
      #|    ┊                      
      #|   h└╌╌ visits ╌╌╌╌┐       
      #|     │             ▼       
      #|┌─────────┐    ┌──────┐    
      #|│ Feather │    │ Pond │    
      #|└─────────┘    └──────┘    
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
      #|                           
    ),
  )
}

///|
test "ASCII pipeline lock er snapshots" {
  let input =
    #|erDiagram
    #|CUSTOMER ||--o{ ORDER : places
    #|ORDER ||--|{ LINE_ITEM : contains
    #|PRODUCT ||--o{ LINE_ITEM : appears_in
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|+----------+places+-------+       
      #|| CUSTOMER |||--o{| ORDER |       
      #|+----------+      +-------+       
      #|                     ||           
      #|      ----------------- contains  
      #|      |               |           
      #|     }|               |           
      #|+-----------+appear+---------+    
      #|| LINE_ITEM |o{--||| PRODUCT |    
      #|+-----------+      +---------+    
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|
      #|# UNICODE
      #|┌──────────┐places┌───────┐       
      #|│ CUSTOMER │║───o╟│ ORDER │       
      #|└──────────┘      └───────┘       
      #|                      ║           
      #|      ───────────────── contains  
      #|      │               │           
      #|      ╟               │           
      #|┌───────────┐appear┌─────────┐    
      #|│ LINE_ITEM │o╟───║│ PRODUCT │    
      #|└───────────┘      └─────────┘    
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
      #|                                  
    ),
  )
}

///|
test "ASCII pipeline lock sequence activation snapshots" {
  let input =
    #|sequenceDiagram
    #|participant Client
    #|participant API
    #|Client->>+API: Open
    #|API-->>Client: Ack
    #|API-->>-Client: Close
    #|Note over Client,API: done
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|+--------+   +-----+   
      #|| Client |   | API |   
      #|+--------+   +-----+   
      #|     |          |      
      #|     |  Open    |      
      #|     |---------->      
      #|     |          |      
      #|     |   Ack    |      
      #|     <..........|      
      #|     |          |      
      #|     |  Close   |      
      #|     <..........|      
      #|     |          |      
      #|     |+------+  |      
      #|     || done |  |      
      #|     |+------+  |      
      #|     |          |      
      #|+--------+   +-----+   
      #|| Client |   | API |   
      #|+--------+   +-----+   
      #|
      #|# UNICODE
      #|┌────────┐   ┌─────┐   
      #|│ Client │   │ API │   
      #|└────┬───┘   └──┬──┘   
      #|     │          │      
      #|     │  Open    │      
      #|     │──────────▶      
      #|     │          │      
      #|     │   Ack    │      
      #|     ◀╌╌╌╌╌╌╌╌╌╌│      
      #|     │          │      
      #|     │  Close   │      
      #|     ◀╌╌╌╌╌╌╌╌╌╌│      
      #|     │          │      
      #|     │┌──────┐  │      
      #|     ││ done │  │      
      #|     │└──────┘  │      
      #|     │          │      
      #|┌────┴───┐   ┌──┴──┐   
      #|│ Client │   │ API │   
      #|└────────┘   └─────┘   
    ),
  )
}

///|
test "ASCII pipeline lock class section snapshots" {
  let input =
    #|classDiagram
    #|class Vehicle {
    #|  +id
    #|  +start()
    #|}
    #|class Car {
    #|  +wheelCount
    #|  +drive()
    #|}
    #|class Engine {
    #|  +serial
    #|}
    #|Vehicle <|-- Car : extends
    #|Car *-- Engine : has
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|+---------+        
      #|| Vehicle |        
      #|+---------+        
      #|| +id     |        
      #|+---------+        
      #|| +start  |        
      #|+---------+        
      #|     ^             
      #|   extends         
      #|       |           
      #|+-------------+    
      #|| Car         |    
      #|+-------------+    
      #|| +wheelCount |    
      #|+-------------+    
      #|| +drive      |    
      #|+-------------+    
      #|       *           
      #|     has           
      #|     |             
      #|+---------+        
      #|| Engine  |        
      #|+---------+        
      #|| +serial |        
      #|+---------+        
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|
      #|# UNICODE
      #|┌─────────┐        
      #|│ Vehicle │        
      #|├─────────┤        
      #|│ +id     │        
      #|├─────────┤        
      #|│ +start  │        
      #|└─────────┘        
      #|     △             
      #|   extends         
      #|       │           
      #|┌─────────────┐    
      #|│ Car         │    
      #|├─────────────┤    
      #|│ +wheelCount │    
      #|├─────────────┤    
      #|│ +drive      │    
      #|└─────────────┘    
      #|       ◆           
      #|     has           
      #|     │             
      #|┌─────────┐        
      #|│ Engine  │        
      #|├─────────┤        
      #|│ +serial │        
      #|└─────────┘        
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
      #|                   
    ),
  )
}

///|
test "ASCII pipeline lock er dense snapshots" {
  let input =
    #|erDiagram
    #|USER ||--o{ SESSION : creates
    #|SESSION ||--|| TOKEN : owns
    #|AUDIT ||--o{ SESSION : logs
    #|TOKEN ||--o{ AUDIT : traces
  inspect(
    inspect_ascii_and_unicode(input),
    content=(
      #|# ASCII
      #|+------+create+---------+    
      #|| USER |||--o{| SESSION |    
      #|+------+      +---------+    
      #|                  o{         
      #|    ---------------| logs    
      #|    |              |         
      #|   ||             ||         
      #|+-------+traces+-------+     
      #|| TOKEN |||--o{| AUDIT |     
      #|+-------+      +-------+     
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|
      #|# UNICODE
      #|┌──────┐create┌─────────┐    
      #|│ USER │║───o╟│ SESSION │    
      #|└──────┘      └─────────┘    
      #|                  o╟         
      #|    ───────────────│ logs    
      #|    │              │         
      #|    ║              ║         
      #|┌───────┐traces┌───────┐     
      #|│ TOKEN │║───o╟│ AUDIT │     
      #|└───────┘      └───────┘     
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
      #|                             
    ),
  )
}
