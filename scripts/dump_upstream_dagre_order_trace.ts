/**
 * Dump upstream dagre ordering traces for focused parity kernels.
 *
 * Usage:
 *   bun run scripts/dump_upstream_dagre_order_trace.ts
 *   bun run scripts/dump_upstream_dagre_order_trace.ts --case case1
 *   bun run scripts/dump_upstream_dagre_order_trace.ts --case case2
 *   bun run scripts/dump_upstream_dagre_order_trace.ts --case case3
 */

const { Graph } = require('../.repos/dagre/node_modules/@dagrejs/graphlib')
const initOrder = require('../.repos/dagre/lib/order/init-order')
const crossCount = require('../.repos/dagre/lib/order/cross-count')
const sortSubgraph = require('../.repos/dagre/lib/order/sort-subgraph')
const buildLayerGraph = require('../.repos/dagre/lib/order/build-layer-graph')
const addSubgraphConstraints = require('../.repos/dagre/lib/order/add-subgraph-constraints')
const util = require('../.repos/dagre/lib/util')

type DagreGraph = any

type Layering = string[][]
type PassStep = {
  pass: number
  incomingFromNeighbor: boolean
  biasRight: boolean
  crossings: number
  layering: Layering
}

type TraceResult = {
  trace: Layering[]
  passTrace: PassStep[]
}

function buildLayerGraphs(g: DagreGraph, ranks: number[], relationship: 'inEdges' | 'outEdges'): DagreGraph[] {
  const nodesByRank = new Map<number, string[]>()
  const addNodeToRank = (rank: number, node: string): void => {
    if (!nodesByRank.has(rank)) {
      nodesByRank.set(rank, [])
    }
    nodesByRank.get(rank)!.push(node)
  }

  for (const v of g.nodes()) {
    const node = g.node(v) as { rank?: number; minRank?: number; maxRank?: number }
    if (typeof node.rank === 'number') {
      addNodeToRank(node.rank, v)
    }
    if (typeof node.minRank === 'number' && typeof node.maxRank === 'number') {
      for (let r = node.minRank; r <= node.maxRank; r += 1) {
        if (r !== node.rank) {
          addNodeToRank(r, v)
        }
      }
    }
  }

  return ranks.map(rank => buildLayerGraph(g, rank, relationship, nodesByRank.get(rank) ?? []))
}

function assignOrder(g: DagreGraph, layering: Layering): void {
  Object.values(layering).forEach(layer => {
    layer.forEach((v, i) => {
      ;(g.node(v) as { order?: number }).order = i
    })
  })
}

function cloneLayering(layers: Layering): Layering {
  return layers.map(layer => layer.slice())
}

function currentLayering(g: DagreGraph): Layering {
  return cloneLayering(util.buildLayerMatrix(g) as Layering)
}

function sweepLayerGraphs(
  layerGraphs: DagreGraph[],
  biasRight: boolean,
  constraints: Array<{ left: string; right: string }>,
): void {
  const cg = new Graph()
  layerGraphs.forEach(lg => {
    constraints.forEach(con => cg.setEdge(con.left, con.right))
    const root = (lg.graph() as { root: string }).root
    const sorted = sortSubgraph(lg, root, cg, biasRight) as { vs: string[] }
    sorted.vs.forEach((v, i) => {
      ;(lg.node(v) as { order?: number }).order = i
    })
    addSubgraphConstraints(lg, cg, sorted.vs)
  })
}

function traceOrder(g: DagreGraph): TraceResult {
  const maxRank = util.maxRank(g) as number
  const downLayerGraphs = buildLayerGraphs(g, util.range(1, maxRank + 1) as number[], 'inEdges')
  const upLayerGraphs = buildLayerGraphs(g, util.range(maxRank - 1, -1, -1) as number[], 'outEdges')
  const constraints: Array<{ left: string; right: string }> = []

  let layering = initOrder(g) as Layering
  assignOrder(g, layering)

  const trace: Layering[] = [currentLayering(g)]
  const passTrace: PassStep[] = []

  let bestCC = Number.POSITIVE_INFINITY
  let best: Layering | undefined

  for (let i = 0, lastBest = 0; lastBest < 4; i += 1, lastBest += 1) {
    const incomingFromNeighbor = i % 2 === 1
    const biasRight = i % 4 >= 2
    sweepLayerGraphs(incomingFromNeighbor ? downLayerGraphs : upLayerGraphs, biasRight, constraints)

    layering = util.buildLayerMatrix(g) as Layering
    const cc = crossCount(g, layering) as number
    passTrace.push({
      pass: i,
      incomingFromNeighbor,
      biasRight,
      crossings: cc,
      layering: cloneLayering(layering),
    })

    if (cc < bestCC) {
      lastBest = 0
      bestCC = cc
      best = cloneLayering(layering)
    } else if (cc === bestCC) {
      best = cloneLayering(layering)
    }
    trace.push(cloneLayering(layering))
  }

  if (!best) {
    throw new Error('failed to compute best layering')
  }
  assignOrder(g, best)
  trace.push(currentLayering(g))
  return { trace, passTrace }
}

function newGraph(): DagreGraph {
  const g = new Graph({ directed: true, multigraph: true, compound: true })
  g.setGraph({})
  return g
}

function addNode(g: DagreGraph, id: string, rank: number): void {
  g.setNode(id, { rank })
}

function addEdges(g: DagreGraph, edges: Array<[string, string]>): void {
  edges.forEach(([v, w], i) => {
    g.setEdge(v, w, { weight: 1, minlen: 1 }, `e${i}`)
  })
}

function buildCase1(): DagreGraph {
  const g = newGraph()
  const ranks: Record<string, number> = {
    A: 0,
    B: 0,
    M: 1,
    X: 2,
    Y: 2,
    __lane_dummy_f_4_1: 1,
    __lane_dummy_f_5_1: 1,
  }
  Object.entries(ranks).forEach(([id, rank]) => addNode(g, id, rank))
  addEdges(g, [
    ['A', 'M'],
    ['B', 'M'],
    ['M', 'X'],
    ['M', 'Y'],
    ['A', '__lane_dummy_f_4_1'],
    ['__lane_dummy_f_4_1', 'Y'],
    ['B', '__lane_dummy_f_5_1'],
    ['__lane_dummy_f_5_1', 'X'],
  ])
  return g
}

function buildCase2(): DagreGraph {
  const g = newGraph()
  const r0 = ['A', 'B']
  const r1 = ['D', '__lane_dummy_f_2_1', '__lane_dummy_f_6_1', 'C', '__lane_dummy_f_3_1', '__lane_dummy_f_7_1']
  const r2 = ['E', 'F']

  r0.forEach(id => addNode(g, id, 0))
  r1.forEach(id => addNode(g, id, 1))
  r2.forEach(id => addNode(g, id, 2))

  addEdges(g, [
    ['A', 'D'],
    ['B', 'C'],
    ['A', '__lane_dummy_f_2_1'],
    ['__lane_dummy_f_2_1', 'E'],
    ['B', '__lane_dummy_f_3_1'],
    ['__lane_dummy_f_3_1', 'F'],
    ['C', 'F'],
    ['D', 'E'],
    ['A', '__lane_dummy_f_6_1'],
    ['__lane_dummy_f_6_1', 'F'],
    ['B', '__lane_dummy_f_7_1'],
    ['__lane_dummy_f_7_1', 'E'],
  ])
  return g
}

function buildCase3(): DagreGraph {
  const g = newGraph()
  const ranks: Record<string, number> = {
    A: 0,
    B: 0,
    C: 1,
    D: 1,
    E: 2,
    F: 2,
    G: 3,
    H: 3,
  }
  Object.entries(ranks).forEach(([id, rank]) => addNode(g, id, rank))
  addEdges(g, [
    ['A', 'C'],
    ['A', 'D'],
    ['B', 'C'],
    ['B', 'D'],
    ['C', 'E'],
    ['D', 'F'],
    ['C', 'F'],
    ['D', 'E'],
    ['E', 'G'],
    ['F', 'H'],
    ['E', 'H'],
    ['F', 'G'],
  ])
  return g
}

function parseCaseArg(args: string[]): string {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--case') {
      const value = args[i + 1]
      if (!value) {
        throw new Error('missing value for --case')
      }
      return value
    }
    if (arg.startsWith('--case=')) {
      return arg.slice('--case='.length)
    }
  }
  return 'all'
}

function main(): void {
  const caseArg = parseCaseArg(process.argv.slice(2)).toLowerCase()
  const builders: Record<string, () => DagreGraph> = {
    case1: buildCase1,
    case2: buildCase2,
    case3: buildCase3,
  }

  const selected =
    caseArg === 'all'
      ? Object.entries(builders)
      : Object.entries(builders).filter(([name]) => name === caseArg)

  if (selected.length === 0) {
    throw new Error("invalid --case value, expected 'case1', 'case2', 'case3', or 'all'")
  }

  const output: Record<string, TraceResult> = {}
  selected.forEach(([name, build]) => {
    output[name] = traceOrder(build())
  })

  console.log(JSON.stringify(output, null, 2))
}

main()
