/**
 * Compare local Dagre parity pipeline traces against upstream Dagre layout.
 *
 * Usage:
 *   bun run scripts/compare_dagre_pipeline_trace.ts
 *   bun run scripts/compare_dagre_pipeline_trace.ts --case case1
 *   bun run scripts/compare_dagre_pipeline_trace.ts --case case2
 *   bun run scripts/compare_dagre_pipeline_trace.ts --case case3
 */

import { spawnSync } from 'node:child_process'

const dagre = require('../.repos/dagre')

type Direction = 'TD' | 'TB' | 'LR' | 'BT' | 'RL'

type KernelTrace = {
  caseName: string
  direction: Direction
  edges: Array<[string, string]>
  nodeSizes: Map<string, { width: number; height: number }>
  ranks: Map<string, number>
  layers: string[][]
  positions: Map<string, { x: number; y: number }>
}

type ComparisonResult = {
  rankMismatchCount: number
  layerMismatchCount: number
  positionRmse: number
  positionMaxAbsDx: number
  positionMaxAbsDy: number
  positionMaxAbsError: number
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
      ].filter(Boolean).join('\n'),
    )
  }
  return (result.stdout ?? '').toString()
}

function parseCaseArg(args: string[]): string {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--case') {
      const value = args[i + 1]
      if (!value) {
        fail('missing value for --case')
      }
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

function parseFloatStrict(raw: string): number {
  const value = Number.parseFloat(raw)
  if (!Number.isFinite(value)) {
    fail(`invalid float literal: ${raw}`)
  }
  return value
}

function parseNodeList(raw: string): string[] {
  if (raw.trim() === '') {
    return []
  }
  return raw.split(',')
}

function normalizeLayers(layersByRank: Map<number, string[]>): string[][] {
  if (layersByRank.size === 0) {
    return []
  }
  const maxRank = Math.max(...layersByRank.keys())
  const layers: string[][] = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    layers.push([...(layersByRank.get(rank) ?? [])])
  }
  return layers
}

function parseLocalTrace(stdout: string): Record<string, KernelTrace> {
  const byCase: Record<string, KernelTrace> = {}
  let current: KernelTrace | null = null
  const localLayersByRank = new Map<number, string[]>()

  const flushLayers = (): void => {
    if (!current) return
    current.layers = normalizeLayers(localLayersByRank)
  }

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    const kind = parts[0]
    if (kind === 'CASE') {
      flushLayers()
      const caseName = parts[1]
      if (!caseName) fail(`invalid CASE line: ${line}`)
      current = {
        caseName,
        direction: 'LR',
        edges: [],
        nodeSizes: new Map<string, { width: number; height: number }>(),
        ranks: new Map<string, number>(),
        layers: [],
        positions: new Map<string, { x: number; y: number }>(),
      }
      byCase[caseName] = current
      localLayersByRank.clear()
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
    if (kind === 'LAYER') {
      const rank = parts[1]
      const nodes = parts[2] ?? ''
      if (!rank) fail(`invalid LAYER line: ${line}`)
      localLayersByRank.set(parseIntStrict(rank), parseNodeList(nodes))
      continue
    }
    if (kind === 'POS') {
      const nodeId = parts[1]
      const x = parts[2]
      const y = parts[3]
      if (!nodeId || !x || !y) fail(`invalid POS line: ${line}`)
      current.positions.set(nodeId, {
        x: parseIntStrict(x),
        y: parseIntStrict(y),
      })
      continue
    }
    fail(`unknown trace line: ${line}`)
  }
  flushLayers()
  return byCase
}

function sortLayerNodes(
  entries: Array<{ id: string; order: number }>,
): string[] {
  return entries
    .slice()
    .sort((a, b) => (a.order !== b.order ? a.order - b.order : a.id.localeCompare(b.id)))
    .map(item => item.id)
}

function upstreamTrace(local: KernelTrace): KernelTrace {
  const Graph = dagre.graphlib.Graph
  const g = new Graph({ directed: true, multigraph: true, compound: true })
  g.setGraph({
    rankdir: local.direction,
    ranker: 'network-simplex',
    nodesep: 130,
    ranksep: 90,
    marginx: 40,
    marginy: 40,
  })
  for (const [id, size] of local.nodeSizes.entries()) {
    g.setNode(id, { width: size.width, height: size.height })
  }
  local.edges.forEach(([source, target], index) => {
    g.setEdge(source, target, { weight: 1, minlen: 1 }, `e${index}`)
  })
  dagre.layout(g)

  const ranks = new Map<string, number>()
  const positions = new Map<string, { x: number; y: number }>()
  const layersByRank = new Map<number, Array<{ id: string; order: number }>>()

  for (const nodeId of g.nodes()) {
    const node = g.node(nodeId) as {
      rank?: number
      order?: number
      x?: number
      y?: number
      width?: number
      height?: number
    }
    const rank = Number.isFinite(node.rank) ? Number(node.rank) : 0
    const order = Number.isFinite(node.order) ? Number(node.order) : 0
    const x = Number.isFinite(node.x) ? Number(node.x) : 0
    const y = Number.isFinite(node.y) ? Number(node.y) : 0
    ranks.set(nodeId, rank)
    positions.set(nodeId, { x, y })
    if (!layersByRank.has(rank)) {
      layersByRank.set(rank, [])
    }
    layersByRank.get(rank)!.push({ id: nodeId, order })
  }

  const normalizedLayers = normalizeLayers(
    new Map<number, string[]>(
      [...layersByRank.entries()].map(([rank, entries]) => [rank, sortLayerNodes(entries)]),
    ),
  )

  return {
    caseName: local.caseName,
    direction: local.direction,
    edges: local.edges.slice(),
    nodeSizes: new Map(local.nodeSizes),
    ranks,
    layers: normalizedLayers,
    positions,
  }
}

function minCoord(
  positions: Map<string, { x: number; y: number }>,
  axis: 'x' | 'y',
): number {
  let minValue = Number.POSITIVE_INFINITY
  for (const pos of positions.values()) {
    const value = axis === 'x' ? pos.x : pos.y
    if (value < minValue) {
      minValue = value
    }
  }
  return Number.isFinite(minValue) ? minValue : 0
}

function compareCase(
  local: KernelTrace,
  upstream: KernelTrace,
): ComparisonResult {
  const nodeIds = [...local.ranks.keys()].sort()
  let rankMismatchCount = 0
  for (const nodeId of nodeIds) {
    const localRank = local.ranks.get(nodeId)
    const upstreamRank = upstream.ranks.get(nodeId)
    if (localRank !== upstreamRank) {
      rankMismatchCount += 1
    }
  }

  const maxLayerCount = Math.max(local.layers.length, upstream.layers.length)
  let layerMismatchCount = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const localLayer = local.layers[rank] ?? []
    const upstreamLayer = upstream.layers[rank] ?? []
    if (JSON.stringify(localLayer) !== JSON.stringify(upstreamLayer)) {
      layerMismatchCount += 1
    }
  }

  const localMinX = minCoord(local.positions, 'x')
  const localMinY = minCoord(local.positions, 'y')
  const upstreamMinX = minCoord(upstream.positions, 'x')
  const upstreamMinY = minCoord(upstream.positions, 'y')

  let sumSquaredError = 0
  let comparedCount = 0
  let positionMaxAbsDx = 0
  let positionMaxAbsDy = 0
  let positionMaxAbsError = 0
  for (const nodeId of nodeIds) {
    const localPos = local.positions.get(nodeId)
    const upstreamPos = upstream.positions.get(nodeId)
    if (!localPos || !upstreamPos) {
      continue
    }
    const dx = (localPos.x - localMinX) - (upstreamPos.x - upstreamMinX)
    const dy = (localPos.y - localMinY) - (upstreamPos.y - upstreamMinY)
    const absDx = Math.abs(dx)
    const absDy = Math.abs(dy)
    const absErr = Math.sqrt(dx * dx + dy * dy)
    if (absDx > positionMaxAbsDx) positionMaxAbsDx = absDx
    if (absDy > positionMaxAbsDy) positionMaxAbsDy = absDy
    if (absErr > positionMaxAbsError) positionMaxAbsError = absErr
    sumSquaredError += dx * dx + dy * dy
    comparedCount += 1
  }
  const positionRmse =
    comparedCount === 0 ? 0 : Math.sqrt(sumSquaredError / comparedCount)

  return {
    rankMismatchCount,
    layerMismatchCount,
    positionRmse,
    positionMaxAbsDx,
    positionMaxAbsDy,
    positionMaxAbsError,
  }
}

function main(): void {
  const caseArg = parseCaseArg(process.argv.slice(2)).toLowerCase()
  const localStdout = runOrThrow('moon', [
    'run',
    'cmd/dagre_pipeline_trace',
    '--target',
    'native',
    '--',
    '--case',
    caseArg,
  ])
  const localByCase = parseLocalTrace(localStdout)
  const selectedCaseNames = Object.keys(localByCase).sort()
  if (selectedCaseNames.length === 0) {
    fail('no local cases selected')
  }

  let mismatchCaseCount = 0
  for (const caseName of selectedCaseNames) {
    const local = localByCase[caseName]!
    const upstream = upstreamTrace(local)
    const metrics = compareCase(local, upstream)
    const hasMismatch =
      metrics.rankMismatchCount !== 0 ||
      metrics.layerMismatchCount !== 0 ||
      metrics.positionMaxAbsError !== 0
    if (hasMismatch) {
      mismatchCaseCount += 1
    }
    console.log(`\n=== ${caseName} ===`)
    console.log(
      `rank_mismatch=${metrics.rankMismatchCount} layer_mismatch=${metrics.layerMismatchCount}`,
    )
    console.log(
      `position_rmse=${metrics.positionRmse.toFixed(4)} max_abs_dx=${metrics.positionMaxAbsDx.toFixed(4)} max_abs_dy=${metrics.positionMaxAbsDy.toFixed(4)} max_abs_error=${metrics.positionMaxAbsError.toFixed(4)}`,
    )
  }

  if (mismatchCaseCount > 0) {
    process.exit(1)
  }
}

main()
