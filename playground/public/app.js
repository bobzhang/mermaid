const sourceEl = document.querySelector("#source");
const previewEl = document.querySelector("#preview");
const statusEl = document.querySelector("#status");
const errorEl = document.querySelector("#error");
const exampleSelectEl = document.querySelector("#example-select");

const examples = [
  {
    id: "flowchart-basic",
    label: "Flowchart: Decision",
    diagram: [
      "flowchart LR",
      "Start([Start]) --> Check{Valid input?}",
      "Check -->|yes| Build[Build artifact]",
      "Check -->|no| Fix[Fix source]",
      "Fix --> Check",
      "Build --> Ship([Ship])",
    ].join("\n"),
  },
  {
    id: "flowchart-subgraph",
    label: "Flowchart: Subgraph",
    diagram: [
      "flowchart TD",
      "subgraph API",
      "A[Request] --> B[Validate]",
      "B --> C[Authorize]",
      "end",
      "C --> D[(Database)]",
      "D --> E[Response]",
    ].join("\n"),
  },
  {
    id: "state-fetch",
    label: "State: Fetch lifecycle",
    diagram: [
      "stateDiagram-v2",
      "[*] --> Idle",
      "Idle --> Loading : fetch",
      "Loading --> Success : resolved",
      "Loading --> Failure : rejected",
      "Failure --> Idle : retry",
      "Success --> [*]",
    ].join("\n"),
  },
  {
    id: "state-door",
    label: "State: Door lock",
    diagram: [
      "stateDiagram-v2",
      "[*] --> Locked",
      "Locked --> Unlocked : PIN ok",
      "Locked --> Alarm : 3 failures",
      "Unlocked --> Locked : timeout",
      "Alarm --> Locked : reset",
      "Locked --> [*]",
    ].join("\n"),
  },
  {
    id: "sequence-api",
    label: "Sequence: API round trip",
    diagram: [
      "sequenceDiagram",
      "Alice->>Server: POST /api/render",
      "Server-->>Alice: 200 SVG",
      "Alice->>Browser: inject SVG",
      "Browser-->>Alice: paint done",
    ].join("\n"),
  },
  {
    id: "sequence-auth",
    label: "Sequence: Login path",
    diagram: [
      "sequenceDiagram",
      "Client->>Auth: submit credentials",
      "Auth->>DB: lookup user",
      "DB-->>Auth: user + hash",
      "Auth-->>Client: token",
      "Client->>API: GET /profile",
      "API-->>Client: profile json",
    ].join("\n"),
  },
  {
    id: "class-renderer",
    label: "Class: Renderer types",
    diagram: [
      "classDiagram",
      "class Diagram {",
      "  +String source",
      "  +render() String",
      "}",
      "class Renderer {",
      "  +layout() String",
      "}",
      "class SvgRenderer {",
      "  +renderSvg() String",
      "}",
      "Diagram --> Renderer : uses",
      "Renderer <|-- SvgRenderer",
    ].join("\n"),
  },
  {
    id: "class-inventory",
    label: "Class: Inventory model",
    diagram: [
      "classDiagram",
      "class Product {",
      "  +String sku",
      "  +Int stock",
      "}",
      "class Order {",
      "  +String id",
      "  +addItem() Unit",
      "}",
      "class OrderLine {",
      "  +Int qty",
      "}",
      "Order --> OrderLine : contains",
      "OrderLine --> Product : references",
    ].join("\n"),
  },
  {
    id: "er-commerce",
    label: "ER: Commerce",
    diagram: [
      "erDiagram",
      "USER ||--o{ ORDER : places",
      "ORDER ||--|{ ORDER_ITEM : contains",
      "PRODUCT ||--o{ ORDER_ITEM : appears_in",
      "USER {",
      "  string id",
      "  string email",
      "}",
      "ORDER {",
      "  string id",
      "  date created_at",
      "}",
      "PRODUCT {",
      "  string sku",
      "}",
      "ORDER_ITEM {",
      "  int quantity",
      "}",
    ].join("\n"),
  },
  {
    id: "er-school",
    label: "ER: School",
    diagram: [
      "erDiagram",
      "STUDENT }o--o{ COURSE : enrolls",
      "TEACHER ||--o{ COURSE : teaches",
      "STUDENT {",
      "  string id",
      "  string name",
      "}",
      "COURSE {",
      "  string code",
      "  string title",
      "}",
      "TEACHER {",
      "  string id",
      "}",
    ].join("\n"),
  },
];

let debounceTimer = 0;
let activeController = null;

function populateExamples() {
  for (const example of examples) {
    const option = document.createElement("option");
    option.value = example.id;
    option.textContent = example.label;
    exampleSelectEl.append(option);
  }
}

function findExampleById(id) {
  return examples.find((example) => example.id === id);
}

function loadExample(id) {
  const chosen = findExampleById(id);
  if (chosen === undefined) {
    return;
  }
  sourceEl.value = chosen.diagram;
  queueRender();
}

function setStatus(state, text) {
  statusEl.textContent = text;
  statusEl.classList.remove("loading", "ok", "error");
  if (state !== "idle") {
    statusEl.classList.add(state);
  }
}

function showError(message) {
  errorEl.hidden = false;
  errorEl.textContent = message;
}

function clearError() {
  errorEl.hidden = true;
  errorEl.textContent = "";
}

async function renderDiagram(diagram) {
  if (activeController !== null) {
    activeController.abort();
  }
  activeController = new AbortController();
  setStatus("loading", "Rendering");

  let response;
  try {
    response = await fetch("/api/render", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ diagram }),
      signal: activeController.signal,
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      return;
    }
    setStatus("error", "Offline");
    showError(error instanceof Error ? error.message : "Network error");
    return;
  }

  let payload;
  try {
    payload = await response.json();
  } catch {
    setStatus("error", "Invalid");
    showError("Server returned a non-JSON response.");
    return;
  }

  if (!response.ok || !payload.ok) {
    setStatus("error", "Error");
    showError(payload.error ?? "Failed to render diagram.");
    return;
  }

  clearError();
  previewEl.innerHTML = payload.svg;
  setStatus("ok", "Rendered");
}

function queueRender() {
  window.clearTimeout(debounceTimer);
  debounceTimer = window.setTimeout(() => {
    const diagram = sourceEl.value.trim();
    if (diagram.length === 0) {
      previewEl.innerHTML = "";
      setStatus("idle", "Ready");
      clearError();
      return;
    }
    renderDiagram(diagram);
  }, 250);
}

sourceEl.addEventListener("input", queueRender);
exampleSelectEl.addEventListener("change", () => {
  loadExample(exampleSelectEl.value);
});
sourceEl.addEventListener("keydown", (event) => {
  if (event.key !== "Tab") {
    return;
  }
  event.preventDefault();
  const start = sourceEl.selectionStart;
  const end = sourceEl.selectionEnd;
  const value = sourceEl.value;
  sourceEl.value = `${value.slice(0, start)}  ${value.slice(end)}`;
  sourceEl.selectionStart = start + 2;
  sourceEl.selectionEnd = start + 2;
  queueRender();
});

populateExamples();
exampleSelectEl.value = examples[0].id;
loadExample(exampleSelectEl.value);
