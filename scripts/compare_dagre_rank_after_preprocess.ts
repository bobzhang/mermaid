/**
 * Compare local rank assignment against upstream dagre rank assignment after
 * dagre preprocess rank normalization steps.
 *
 * Usage:
 *   bun run scripts/compare_dagre_rank_after_preprocess.ts
 *   bun run scripts/compare_dagre_rank_after_preprocess.ts --case case1
 *   bun run scripts/compare_dagre_rank_after_preprocess.ts --case case2
 *   bun run scripts/compare_dagre_rank_after_preprocess.ts --case case3
 */

import { spawnSync } from 'node:child_process'

const dagre = require('../.repos/dagre')
const acyclic = require('../.repos/dagre/lib/acyclic')
const rank = require('../.repos/dagre/lib/rank')
const nestingGraph = require('../.repos/dagre/lib/nesting-graph')
const util = require('../.repos/dagre/lib/util')

const Graph = dagre.graphlib.Graph

type Direction = 'TD' | 'TB' | 'LR' | 'BT' | 'RL'

type KernelTrace = {
  caseName: string
  direction: Direction
  nodeOrder: string[]
  edges: Array<[string, string]>
  nodeSizes: Map<string, { width: number; height: number }>
  ranks: Map<string, number>
}

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(cmd: string, args: string[]): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  })
  if (result.status !== 0) {
    const stderr = (result.stderr ?? '').toString().trim()
    const stdout = (result.stdout ?? '').toString().trim()
    fail(
      [
        `command failed: ${cmd} ${args.join(' ')}`,
        stderr ? `stderr: ${stderr}` : '',
        stdout ? `stdout: ${stdout}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
    )
  }
  return (result.stdout ?? '').toString()
}

function parseCaseArg(args: string[]): string {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--case') {
      const value = args[i + 1]
      if (!value) fail('missing value for --case')
      return value
    }
    if (arg.startsWith('--case=')) {
      return arg.slice('--case='.length)
    }
  }
  return 'all'
}

function parseIntStrict(raw: string): number {
  const value = Number.parseInt(raw, 10)
  if (!Number.isFinite(value)) {
    fail(`invalid integer literal: ${raw}`)
  }
  return value
}

function parseLocalTrace(stdout: string): Record<string, KernelTrace> {
  const byCase: Record<string, KernelTrace> = {}
  let current: KernelTrace | null = null

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    const kind = parts[0]

    if (kind === 'CASE') {
      const caseName = parts[1]
      if (!caseName) fail(`invalid CASE line: ${line}`)
      current = {
        caseName,
        direction: 'LR',
        nodeOrder: [],
        edges: [],
        nodeSizes: new Map<string, { width: number; height: number }>(),
        ranks: new Map<string, number>(),
      }
      byCase[caseName] = current
      continue
    }

    if (!current) {
      fail(`trace line before CASE header: ${line}`)
    }

    if (kind === 'DIRECTION') {
      const dir = parts[1] as Direction | undefined
      if (!dir) fail(`invalid DIRECTION line: ${line}`)
      current.direction = dir
      continue
    }

    if (kind === 'EDGE') {
      const source = parts[1]
      const target = parts[2]
      if (!source || !target) fail(`invalid EDGE line: ${line}`)
      current.edges.push([source, target])
      continue
    }

    if (kind === 'NODE_ORDER') {
      const nodeId = parts[1]
      if (!nodeId) fail(`invalid NODE_ORDER line: ${line}`)
      current.nodeOrder.push(nodeId)
      continue
    }

    if (kind === 'NODE_SIZE') {
      const nodeId = parts[1]
      const width = parts[2]
      const height = parts[3]
      if (!nodeId || !width || !height) fail(`invalid NODE_SIZE line: ${line}`)
      current.nodeSizes.set(nodeId, {
        width: parseIntStrict(width),
        height: parseIntStrict(height),
      })
      continue
    }

    if (kind === 'RANK') {
      const nodeId = parts[1]
      const rank = parts[2]
      if (!nodeId || !rank) fail(`invalid RANK line: ${line}`)
      current.ranks.set(nodeId, parseIntStrict(rank))
      continue
    }
  }

  return byCase
}

function canonicalize(attrs: Record<string, unknown> | undefined): Record<string, unknown> {
  const next: Record<string, unknown> = {}
  if (!attrs) return next
  Object.entries(attrs).forEach(([key, value]) => {
    next[key.toLowerCase()] = value
  })
  return next
}

function selectNumberAttrs(obj: Record<string, unknown>, attrs: string[]): Record<string, number> {
  const next: Record<string, number> = {}
  attrs.forEach(key => {
    const value = obj[key]
    if (value !== undefined) {
      next[key] = Number(value)
    }
  })
  return next
}

function buildLayoutGraph(inputGraph: any): any {
  const graphNumAttrs = ['nodesep', 'edgesep', 'ranksep', 'marginx', 'marginy']
  const graphDefaults = {
    ranksep: 50,
    edgesep: 20,
    nodesep: 50,
    rankdir: 'tb',
    rankalign: 'center',
  }
  const graphAttrs = ['acyclicer', 'ranker', 'rankdir', 'align', 'rankalign']
  const nodeNumAttrs = ['width', 'height', 'rank']
  const nodeDefaults = { width: 0, height: 0 }
  const edgeNumAttrs = ['minlen', 'weight', 'width', 'height', 'labeloffset']
  const edgeDefaults = {
    minlen: 1,
    weight: 1,
    width: 0,
    height: 0,
    labeloffset: 10,
    labelpos: 'r',
  }
  const edgeAttrs = ['labelpos']

  const g = new Graph({ multigraph: true, compound: true })
  const graph = canonicalize(inputGraph.graph())

  const graphAttrsObj: Record<string, unknown> = {}
  graphNumAttrs.forEach(key => {
    const value = graph[key]
    if (value !== undefined) graphAttrsObj[key] = Number(value)
  })
  graphAttrs.forEach(key => {
    if (graph[key] !== undefined) graphAttrsObj[key] = graph[key]
  })
  g.setGraph({ ...graphDefaults, ...graphAttrsObj })

  inputGraph.nodes().forEach((v: string) => {
    const node = canonicalize(inputGraph.node(v))
    const nextNode: Record<string, unknown> = {
      ...selectNumberAttrs(node, nodeNumAttrs),
      ...nodeDefaults,
    }
    g.setNode(v, nextNode)
    g.setParent(v, inputGraph.parent(v))
  })

  inputGraph.edges().forEach((e: { v: string; w: string; name?: string }) => {
    const edge = canonicalize(inputGraph.edge(e))
    const nextEdge: Record<string, unknown> = {
      ...edgeDefaults,
      ...selectNumberAttrs(edge, edgeNumAttrs),
    }
    edgeAttrs.forEach(key => {
      if (edge[key] !== undefined) nextEdge[key] = edge[key]
    })
    g.setEdge(e, nextEdge)
  })

  return g
}

function makeSpaceForEdgeLabels(g: any): void {
  const graph = g.graph()
  graph.ranksep /= 2
  g.edges().forEach((e: any) => {
    const edge = g.edge(e)
    edge.minlen *= 2
    if (edge.labelpos.toLowerCase() !== 'c') {
      if (graph.rankdir === 'TB' || graph.rankdir === 'BT') {
        edge.width += edge.labeloffset
      } else {
        edge.height += edge.labeloffset
      }
    }
  })
}

function removeSelfEdges(g: any): void {
  g.edges().forEach((e: any) => {
    if (e.v === e.w) {
      const node = g.node(e.v)
      if (!node.selfEdges) {
        node.selfEdges = []
      }
      node.selfEdges.push({ e, label: g.edge(e) })
      g.removeEdge(e)
    }
  })
}

function injectEdgeLabelProxies(g: any): void {
  g.edges().forEach((e: any) => {
    const edge = g.edge(e)
    if (edge.width && edge.height) {
      const v = g.node(e.v)
      const w = g.node(e.w)
      const label = { rank: (w.rank - v.rank) / 2 + v.rank, e }
      util.addDummyNode(g, 'edge-proxy', label, '_ep')
    }
  })
}

function removeEdgeLabelProxies(g: any): void {
  g.nodes().forEach((v: string) => {
    const node = g.node(v)
    if (node.dummy === 'edge-proxy') {
      g.edge(node.e).labelRank = node.rank
      g.removeNode(v)
    }
  })
}

function upstreamRanksAfterRankPreprocess(local: KernelTrace): Map<string, number> {
  const input = new Graph({ directed: true, multigraph: true, compound: true })
  input.setGraph({
    rankdir: local.direction,
    ranker: 'network-simplex',
    nodesep: 130,
    ranksep: 90,
    marginx: 40,
    marginy: 40,
  })

  const addedNodes = new Set<string>()
  for (const id of local.nodeOrder) {
    const size = local.nodeSizes.get(id)
    if (!size) continue
    input.setNode(id, { width: size.width, height: size.height })
    addedNodes.add(id)
  }
  for (const [id, size] of local.nodeSizes.entries()) {
    if (addedNodes.has(id)) continue
    input.setNode(id, { width: size.width, height: size.height })
  }
  local.edges.forEach(([source, target], index) => {
    input.setEdge(source, target, { weight: 1, minlen: 1 }, `e${index}`)
  })

  const g = buildLayoutGraph(input)
  makeSpaceForEdgeLabels(g)
  removeSelfEdges(g)
  acyclic.run(g)
  nestingGraph.run(g)
  rank(util.asNonCompoundGraph(g))
  injectEdgeLabelProxies(g)
  util.removeEmptyRanks(g)
  nestingGraph.cleanup(g)
  util.normalizeRanks(g)
  removeEdgeLabelProxies(g)

  const ranks = new Map<string, number>()
  for (const nodeId of input.nodes()) {
    const node = g.node(nodeId) as { rank?: number }
    ranks.set(nodeId, Number.isFinite(node.rank) ? Number(node.rank) : 0)
  }
  return ranks
}

function main(): void {
  const caseArg = parseCaseArg(process.argv.slice(2)).toLowerCase()
  const stdout = runOrThrow('moon', [
    'run',
    'cmd/dagre_pipeline_trace',
    '--target',
    'native',
    '--',
    '--case',
    caseArg,
  ])
  const localByCase = parseLocalTrace(stdout)
  const caseNames = Object.keys(localByCase).sort()
  if (caseNames.length === 0) {
    fail('no cases selected')
  }

  let mismatchCount = 0
  for (const caseName of caseNames) {
    const local = localByCase[caseName]!
    const upstreamRanks = upstreamRanksAfterRankPreprocess(local)

    const nodeIds = [...local.nodeSizes.keys()].sort((a, b) => a.localeCompare(b))
    const mismatches: string[] = []
    nodeIds.forEach(nodeId => {
      const localRank = local.ranks.get(nodeId) ?? 0
      const upstreamRank = upstreamRanks.get(nodeId) ?? 0
      if (localRank !== upstreamRank) {
        mismatches.push(`${nodeId}: local=${localRank} upstream=${upstreamRank}`)
      }
    })

    if (mismatches.length === 0) {
      console.log(`PASS ${caseName}`)
      continue
    }

    mismatchCount += 1
    console.log(`FAIL ${caseName}`)
    mismatches.forEach(item => console.log(`  - ${item}`))
  }

  if (mismatchCount > 0) {
    process.exit(1)
  }
}

main()
