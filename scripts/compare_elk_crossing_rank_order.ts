/**
 * Compare local ELK rank-layer order (post crossing optimization) against
 * upstream elkjs layered order inferred from final node positions.
 *
 * This is a phase-oriented diagnostic bridge:
 * - local side: `RANK_LAYER` from `cmd/elk_trace`
 * - upstream side: major-axis grouped layers from elkjs final positions
 *
 * Usage:
 *   bun run scripts/compare_elk_crossing_rank_order.ts fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts fixtures/layout_stress_001_dense_dag.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --trial-count 5 fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --sweep-kernel neighbor-median --trial-count 5 fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --sweep-kernel edge-slot --trial-count 5 fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --sweep-kernel port-rank --trial-count 5 fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --trial-continuation-policy objective-improves fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --local-refinement-profile none fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --model-order-inversion-influence 0.25 fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --upstream-layer-source layer-logs fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_crossing_rank_order.ts --details --limit 3 fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 */

import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Axis = 'x' | 'y'
type Edge = { source: string; target: string }
type Layering = string[][]

type LocalTrace = {
  inputNodeIds: string[]
  inputEdges: Edge[]
  rankLayers: Layering
}

type UpstreamPlacement = {
  majorByNodeId: Map<string, number>
  minorByNodeId: Map<string, number>
}

type UpstreamLayoutPayload = {
  rows: Array<{ id: string; x: number; y: number }>
  layers: Layering
}

type CaseMetrics = {
  fixture: string
  localLayers: number
  upstreamLayers: number
  sharedNodes: number
  orderMismatchLayers: number
  compositionMismatchLayers: number
  exactMatchRate: number
  avgDisplacement: number
  sameRankSharedNodes: number
  exactOrderMatchRate: number
  avgOrderDisplacement: number
}

type CaseResult = {
  metrics: CaseMetrics
  inputEdges: Edge[]
  localRankLayers: Layering
  upstreamRankLayers: Layering
}

type CliOptions = {
  fixtures: string[]
  details: boolean
  detailLimit: number
  trialCount?: number
  sweepPassCount?: number
  sweepKernel?:
    | 'default'
    | 'neighbor-mean'
    | 'neighbor-median'
    | 'edge-slot'
    | 'port-rank'
  trialContinuationPolicy?: 'default' | 'pass-changes' | 'objective-improves'
  localRefinementProfile?:
    | 'default'
    | 'none'
    | 'adjacent-swap'
    | 'rank-permutation'
    | 'adjacent-swap-then-rank-permutation'
  modelOrderInversionInfluence?: number
  upstreamLayerSource: 'final-coordinates' | 'layer-logs'
}

type NeighborSummary = {
  count: number
  median: number
  mean: number
}

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(
  cmd: string,
  args: string[],
  env?: NodeJS.ProcessEnv,
): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 32 * 1024 * 1024,
    env,
  })
  if (result.status !== 0) {
    const stdout = (result.stdout ?? '').toString().trim()
    const stderr = (result.stderr ?? '').toString().trim()
    const parts = [`command failed: ${cmd} ${args.join(' ')}`]
    if (stderr !== '') parts.push(`stderr:\n${stderr}`)
    if (stdout !== '') parts.push(`stdout:\n${stdout}`)
    fail(parts.join('\n'))
  }
  return (result.stdout ?? '').toString()
}

function parseGraphDirection(source: string): Direction {
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '' || line.startsWith('%')) continue
    const match = line.match(/^(?:flowchart|graph)\s+([A-Za-z]{2})\b/i)
    if (!match) continue
    const dir = match[1]!.toUpperCase()
    if (dir === 'LR' || dir === 'RL' || dir === 'TB' || dir === 'TD' || dir === 'BT') {
      return dir
    }
  }
  return 'LR'
}

function majorAxisByDirection(direction: Direction): Axis {
  if (direction === 'LR' || direction === 'RL') return 'x'
  return 'y'
}

function elkDirection(direction: Direction): 'RIGHT' | 'LEFT' | 'DOWN' | 'UP' {
  if (direction === 'RL') return 'LEFT'
  if (direction === 'BT') return 'UP'
  if (direction === 'TB' || direction === 'TD') return 'DOWN'
  return 'RIGHT'
}

function parseLocalTrace(source: string, options: CliOptions): LocalTrace {
  const args = [
    'run',
    'cmd/elk_trace',
    '--target',
    'native',
    '--',
    '--source',
    source,
  ]
  if (options.trialCount !== undefined) {
    args.push('--trial-count', String(options.trialCount))
  }
  if (options.sweepPassCount !== undefined) {
    args.push('--sweep-pass-count', String(options.sweepPassCount))
  }
  if (options.sweepKernel !== undefined) {
    args.push('--sweep-kernel', options.sweepKernel)
  }
  if (options.trialContinuationPolicy !== undefined) {
    args.push('--trial-continuation-policy', options.trialContinuationPolicy)
  }
  if (options.localRefinementProfile !== undefined) {
    args.push('--local-refinement-profile', options.localRefinementProfile)
  }
  if (options.modelOrderInversionInfluence !== undefined) {
    args.push(
      '--model-order-inversion-influence',
      String(options.modelOrderInversionInfluence),
    )
  }
  const stdout = runOrThrow('moon', args)
  const inputNodeIdsByIndex = new Map<number, string>()
  const inputEdges: Edge[] = []
  const rankLayersByRank = new Map<number, string[]>()

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    if (parts[0] === 'INPUT_NODE') {
      const index = Number.parseInt(parts[1] ?? '', 10)
      const nodeId = parts[2] ?? ''
      if (Number.isFinite(index) && nodeId !== '') {
        inputNodeIdsByIndex.set(index, nodeId)
      }
      continue
    }
    if (parts[0] === 'INPUT_EDGE') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        inputEdges.push({ source: sourceId, target: targetId })
      }
      continue
    }
    if (parts[0] === 'RANK_LAYER') {
      const rank = Number.parseInt(parts[1] ?? '', 10)
      if (!Number.isFinite(rank)) {
        fail(`invalid RANK_LAYER rank line: ${line}`)
      }
      const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
      rankLayersByRank.set(rank, nodes)
      continue
    }
  }

  if (inputNodeIdsByIndex.size === 0) {
    fail('local trace missing INPUT_NODE output')
  }
  if (inputEdges.length === 0) {
    fail('local trace missing INPUT_EDGE output')
  }
  if (rankLayersByRank.size === 0) {
    fail('local trace missing RANK_LAYER output')
  }

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)

  const maxRank = Math.max(...rankLayersByRank.keys())
  const rankLayers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    const layer = rankLayersByRank.get(rank) ?? []
    if (layer.length > 0) {
      rankLayers.push(layer)
    }
  }

  return { inputNodeIds, inputEdges, rankLayers }
}

function parseJsonUpstreamLayout(raw: string): UpstreamLayoutPayload {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream placement payload: ${String(error)}`)
  }
  if (!parsed || typeof parsed !== 'object') {
    fail('invalid upstream placement payload: root is not an object')
  }
  const maybeRows = (parsed as { rows?: unknown }).rows
  const maybeLayers = (parsed as { layers?: unknown }).layers
  if (!Array.isArray(maybeRows)) {
    fail('invalid upstream placement payload: rows is not an array')
  }
  if (!Array.isArray(maybeLayers)) {
    fail('invalid upstream placement payload: layers is not an array')
  }
  const rows: Array<{ id: string; x: number; y: number }> = []
  for (const row of maybeRows) {
    if (!row || typeof row !== 'object') {
      fail('invalid upstream placement payload: row is not object')
    }
    const maybeId = (row as { id?: unknown }).id
    const maybeX = (row as { x?: unknown }).x
    const maybeY = (row as { y?: unknown }).y
    if (typeof maybeId !== 'string' || typeof maybeX !== 'number' || typeof maybeY !== 'number') {
      fail('invalid upstream placement payload: malformed row')
    }
    rows.push({ id: maybeId, x: maybeX, y: maybeY })
  }
  const layers: Layering = []
  for (const layer of maybeLayers) {
    if (!Array.isArray(layer)) {
      fail('invalid upstream placement payload: layer is not an array')
    }
    const normalizedLayer: string[] = []
    for (const nodeId of layer) {
      if (typeof nodeId !== 'string') {
        fail('invalid upstream placement payload: layer node id is not a string')
      }
      normalizedLayer.push(nodeId)
    }
    if (normalizedLayer.length > 0) {
      layers.push(normalizedLayer)
    }
  }
  return { rows, layers }
}

function runUpstreamPlacement(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
): { placement: UpstreamPlacement; layers: Layering } {
  const payload = {
    inputNodeIds,
    inputEdges,
    elkDirection: elkDirection(direction),
  }
  const script = [
    "const ELK = require('./.repos/elkjs_pkg/package/lib/main.js');",
    'const payload = JSON.parse(process.argv[1]);',
    'const graph = {',
    "  id: 'g',",
    '  layoutOptions: {',
    "    'elk.algorithm': 'layered',",
    "    'org.eclipse.elk.randomSeed': '1',",
    "    'elk.direction': payload.elkDirection,",
    "    'org.eclipse.elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES',",
    "    'spacing.baseValue': '40',",
    "    'spacing.nodeNode': '130',",
    "    'spacing.nodeNodeBetweenLayers': '90',",
    "    'elk.edgeRouting': 'POLYLINE',",
    "    'org.eclipse.elk.layered.unnecessaryBendpoints': 'true',",
    '  },',
    '  children: payload.inputNodeIds.map(id => ({ id, width: 80, height: 40 })),',
    '  edges: payload.inputEdges.map((edge, index) => ({',
    "    id: `e${index}`,",
    '    sources: [edge.source],',
    '    targets: [edge.target],',
    '  })),',
    '};',
    'function collectLoggingLines(node, out) {',
    '  if (!node) return;',
    '  if (Array.isArray(node.logs)) {',
    '    for (const line of node.logs) out.push(String(line));',
    '  }',
    '  if (Array.isArray(node.children)) {',
    '    for (const child of node.children) collectLoggingLines(child, out);',
    '  }',
    '}',
    "new ELK().layout(graph, { logging: true }).then(out => {",
    '  const rows = (out.children ?? []).map(child => ({ id: child.id, x: child.x, y: child.y }));',
    '  const loggingLines = [];',
    '  collectLoggingLines(out.logging, loggingLines);',
    '  const layersByRank = new Map();',
    '  const realNodeIds = new Set(payload.inputNodeIds);',
    '  for (const line of loggingLines) {',
    '    const match = /^Layer\\s+(\\d+):\\s+L_\\d+\\[(.*)\\]$/.exec(line);',
    '    if (!match) continue;',
    '    const rank = Number.parseInt(match[1], 10);',
    '    if (!Number.isFinite(rank)) continue;',
    '    const rawNodeIds = match[2].trim() === "" ? [] : match[2].split(",");',
    '    const layer = [];',
    '    for (const rawNodeId of rawNodeIds) {',
    '      const token = rawNodeId.trim();',
    '      if (token === "") continue;',
    '      if (token.startsWith("n_g.")) {',
    '        const nodeId = token.slice("n_g.".length);',
    '        if (realNodeIds.has(nodeId)) layer.push(nodeId);',
    '      } else if (realNodeIds.has(token)) {',
    '        layer.push(token);',
    '      }',
    '    }',
    '    layersByRank.set(rank, layer);',
    '  }',
    '  const ranks = [...layersByRank.keys()].sort((a, b) => a - b);',
    '  const layers = [];',
    '  for (const rank of ranks) {',
    '    const layer = layersByRank.get(rank) ?? [];',
    '    if (layer.length > 0) layers.push(layer);',
    '  }',
    '  process.stdout.write(JSON.stringify({ rows, layers }));',
    '}).catch(err => {',
    '  console.error(String(err));',
    '  process.exit(1);',
    '});',
  ].join('\n')
  const stdout = runOrThrow('node', ['-e', script, JSON.stringify(payload)])
  const parsed = parseJsonUpstreamLayout(stdout)
  const rows = parsed.rows
  const majorByNodeId = new Map<string, number>()
  const minorByNodeId = new Map<string, number>()
  const majorAxis = majorAxisByDirection(direction)
  for (const row of rows) {
    if (majorAxis === 'x') {
      majorByNodeId.set(row.id, row.x)
      minorByNodeId.set(row.id, row.y)
    } else {
      majorByNodeId.set(row.id, row.y)
      minorByNodeId.set(row.id, row.x)
    }
  }
  return {
    placement: { majorByNodeId, minorByNodeId },
    layers: parsed.layers,
  }
}

function buildLayersByMajor(
  labels: string[],
  majorByNodeId: Map<string, number>,
  minorByNodeId: Map<string, number>,
): string[][] {
  if (labels.length === 0) return []
  const entries = labels
    .map(label => ({
      label,
      major: majorByNodeId.get(label) ?? 0,
      minor: minorByNodeId.get(label) ?? 0,
    }))
    .sort((left, right) => {
      if (left.major !== right.major) return left.major - right.major
      if (left.minor !== right.minor) return left.minor - right.minor
      return left.label.localeCompare(right.label)
    })
  const layers: string[][] = []
  const epsilon = 0.5
  let anchor = entries[0]!.major
  let layer: string[] = []
  for (const entry of entries) {
    if (Math.abs(entry.major - anchor) > epsilon && layer.length > 0) {
      layers.push(layer)
      layer = []
      anchor = entry.major
    }
    layer.push(entry.label)
  }
  if (layer.length > 0) {
    layers.push(layer)
  }
  return layers
}

function layeringToRankMap(layers: Layering): Map<string, number> {
  const rankByNodeId = new Map<string, number>()
  layers.forEach((layer, rank) => {
    layer.forEach(nodeId => rankByNodeId.set(nodeId, rank))
  })
  return rankByNodeId
}

function layeringToRankPosMap(
  layers: Layering,
): Map<string, { rank: number; pos: number }> {
  const rankPosByNodeId = new Map<string, { rank: number; pos: number }>()
  layers.forEach((layer, rank) => {
    layer.forEach((nodeId, pos) => rankPosByNodeId.set(nodeId, { rank, pos }))
  })
  return rankPosByNodeId
}

function compareLayers(localLayers: Layering, upstreamLayers: Layering): {
  orderMismatchLayers: number
  compositionMismatchLayers: number
  exactMatchRate: number
  avgDisplacement: number
  sameRankSharedNodes: number
  exactOrderMatchRate: number
  avgOrderDisplacement: number
} {
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  let orderMismatchLayers = 0
  let compositionMismatchLayers = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const local = localLayers[rank] ?? []
    const upstream = upstreamLayers[rank] ?? []
    if (JSON.stringify(local) !== JSON.stringify(upstream)) {
      orderMismatchLayers += 1
    }
    const sortedLocal = local.slice().sort()
    const sortedUpstream = upstream.slice().sort()
    if (JSON.stringify(sortedLocal) !== JSON.stringify(sortedUpstream)) {
      compositionMismatchLayers += 1
    }
  }

  const localRankByNodeId = layeringToRankMap(localLayers)
  const upstreamRankByNodeId = layeringToRankMap(upstreamLayers)
  const localRankPosByNodeId = layeringToRankPosMap(localLayers)
  const upstreamRankPosByNodeId = layeringToRankPosMap(upstreamLayers)
  let shared = 0
  let exact = 0
  let displacement = 0
  let sameRankShared = 0
  let exactOrder = 0
  let orderDisplacement = 0
  for (const [nodeId, upstreamRank] of upstreamRankByNodeId.entries()) {
    const localRank = localRankByNodeId.get(nodeId)
    if (localRank === undefined) continue
    shared += 1
    if (localRank === upstreamRank) exact += 1
    displacement += Math.abs(localRank - upstreamRank)
    if (localRank !== upstreamRank) continue
    const localPos = localRankPosByNodeId.get(nodeId)?.pos
    const upstreamPos = upstreamRankPosByNodeId.get(nodeId)?.pos
    if (localPos === undefined || upstreamPos === undefined) continue
    sameRankShared += 1
    if (localPos === upstreamPos) exactOrder += 1
    orderDisplacement += Math.abs(localPos - upstreamPos)
  }

  return {
    orderMismatchLayers,
    compositionMismatchLayers,
    exactMatchRate: shared === 0 ? 0 : exact / shared,
    avgDisplacement: shared === 0 ? 0 : displacement / shared,
    sameRankSharedNodes: sameRankShared,
    exactOrderMatchRate: sameRankShared === 0 ? 0 : exactOrder / sameRankShared,
    avgOrderDisplacement:
      sameRankShared === 0 ? 0 : orderDisplacement / sameRankShared,
  }
}

function selectCloserUpstreamLayering(
  localLayers: Layering,
  upstreamLayers: Layering,
): { selectedLayers: Layering; parity: ReturnType<typeof compareLayers> } {
  const directParity = compareLayers(localLayers, upstreamLayers)
  const reversedUpstreamLayers = upstreamLayers.slice().reverse()
  const reversedParity = compareLayers(localLayers, reversedUpstreamLayers)
  const useReversed =
    reversedParity.compositionMismatchLayers < directParity.compositionMismatchLayers ||
    (
      reversedParity.compositionMismatchLayers === directParity.compositionMismatchLayers &&
      reversedParity.orderMismatchLayers < directParity.orderMismatchLayers
    ) ||
    (
      reversedParity.compositionMismatchLayers === directParity.compositionMismatchLayers &&
      reversedParity.orderMismatchLayers === directParity.orderMismatchLayers &&
      reversedParity.avgDisplacement < directParity.avgDisplacement
    )
  return {
    selectedLayers: useReversed ? reversedUpstreamLayers : upstreamLayers,
    parity: useReversed ? reversedParity : directParity,
  }
}

function compareFixture(fixturePath: string, options: CliOptions): CaseResult {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const local = parseLocalTrace(source, options)
  const upstream = runUpstreamPlacement(
    local.inputNodeIds,
    local.inputEdges,
    direction,
  )
  const upstreamLayers =
    options.upstreamLayerSource === 'layer-logs' && upstream.layers.length > 0
      ? upstream.layers
      : buildLayersByMajor(
          local.inputNodeIds,
          upstream.placement.majorByNodeId,
          upstream.placement.minorByNodeId,
        )
  const { selectedLayers, parity } = selectCloserUpstreamLayering(
    local.rankLayers,
    upstreamLayers,
  )
  return {
    metrics: {
      fixture: fixturePath,
      localLayers: local.rankLayers.length,
      upstreamLayers: selectedLayers.length,
      sharedNodes: local.inputNodeIds.length,
      orderMismatchLayers: parity.orderMismatchLayers,
      compositionMismatchLayers: parity.compositionMismatchLayers,
      exactMatchRate: parity.exactMatchRate,
      avgDisplacement: parity.avgDisplacement,
      sameRankSharedNodes: parity.sameRankSharedNodes,
      exactOrderMatchRate: parity.exactOrderMatchRate,
      avgOrderDisplacement: parity.avgOrderDisplacement,
    },
    inputEdges: local.inputEdges,
    localRankLayers: local.rankLayers,
    upstreamRankLayers: selectedLayers,
  }
}

function round(value: number): string {
  return Number.isFinite(value) ? value.toFixed(4) : 'NaN'
}

function parsePositiveIntOption(raw: string, flag: string): number {
  const parsed = Number.parseInt(raw, 10)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    fail(`invalid ${flag} value: ${raw}`)
  }
  return parsed
}

function parseCliOptions(args: string[]): CliOptions {
  let details = false
  let detailLimit = Number.MAX_SAFE_INTEGER
  let trialCount: number | undefined
  let sweepPassCount: number | undefined
  let sweepKernel:
    | 'default'
    | 'neighbor-mean'
    | 'neighbor-median'
    | 'edge-slot'
    | 'port-rank'
    | undefined
  let trialContinuationPolicy:
    | 'default'
    | 'pass-changes'
    | 'objective-improves'
    | undefined
  let localRefinementProfile:
    | 'default'
    | 'none'
    | 'adjacent-swap'
    | 'rank-permutation'
    | 'adjacent-swap-then-rank-permutation'
    | undefined
  let modelOrderInversionInfluence: number | undefined
  let upstreamLayerSource: 'final-coordinates' | 'layer-logs' =
    'final-coordinates'
  const fixtures: string[] = []
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--details') {
      details = true
      continue
    }
    if (arg === '--limit') {
      const next = args[i + 1]
      if (!next) fail('missing value after --limit')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail(`invalid --limit value: ${next}`)
      }
      detailLimit = parsed
      i += 1
      continue
    }
    if (arg.startsWith('--limit=')) {
      const raw = arg.slice('--limit='.length)
      const parsed = Number.parseInt(raw, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail(`invalid --limit value: ${raw}`)
      }
      detailLimit = parsed
      continue
    }
    if (arg === '--trial-count') {
      const next = args[i + 1]
      if (!next) fail('missing value after --trial-count')
      trialCount = parsePositiveIntOption(next, '--trial-count')
      i += 1
      continue
    }
    if (arg.startsWith('--trial-count=')) {
      const raw = arg.slice('--trial-count='.length)
      trialCount = parsePositiveIntOption(raw, '--trial-count')
      continue
    }
    if (arg === '--sweep-pass-count') {
      const next = args[i + 1]
      if (!next) fail('missing value after --sweep-pass-count')
      sweepPassCount = parsePositiveIntOption(next, '--sweep-pass-count')
      i += 1
      continue
    }
    if (arg.startsWith('--sweep-pass-count=')) {
      const raw = arg.slice('--sweep-pass-count='.length)
      sweepPassCount = parsePositiveIntOption(raw, '--sweep-pass-count')
      continue
    }
    if (arg === '--sweep-kernel') {
      const next = args[i + 1]
      if (!next) fail('missing value after --sweep-kernel')
      const normalized = next.trim().toLowerCase()
      if (
        normalized !== 'default' &&
        normalized !== 'neighbor-mean' &&
        normalized !== 'neighbor-median' &&
        normalized !== 'edge-slot' &&
        normalized !== 'port-rank'
      ) {
        fail(
          "invalid --sweep-kernel value, expected 'default', 'neighbor-mean', 'neighbor-median', 'edge-slot', or 'port-rank'",
        )
      }
      sweepKernel = normalized
      i += 1
      continue
    }
    if (arg === '--trial-continuation-policy') {
      const next = args[i + 1]
      if (!next) fail('missing value after --trial-continuation-policy')
      const normalized = next.trim().toLowerCase()
      if (
        normalized !== 'default' &&
        normalized !== 'pass-changes' &&
        normalized !== 'objective-improves'
      ) {
        fail(
          "invalid --trial-continuation-policy value, expected 'default', 'pass-changes', or 'objective-improves'",
        )
      }
      trialContinuationPolicy = normalized
      i += 1
      continue
    }
    if (arg === '--local-refinement-profile') {
      const next = args[i + 1]
      if (!next) fail('missing value after --local-refinement-profile')
      const normalized = next.trim().toLowerCase()
      if (
        normalized !== 'default' &&
        normalized !== 'none' &&
        normalized !== 'adjacent-swap' &&
        normalized !== 'rank-permutation' &&
        normalized !== 'adjacent-swap-then-rank-permutation'
      ) {
        fail(
          "invalid --local-refinement-profile value, expected 'default', 'none', 'adjacent-swap', 'rank-permutation', or 'adjacent-swap-then-rank-permutation'",
        )
      }
      localRefinementProfile = normalized
      i += 1
      continue
    }
    if (arg.startsWith('--sweep-kernel=')) {
      const normalized = arg.slice('--sweep-kernel='.length).trim().toLowerCase()
      if (
        normalized !== 'default' &&
        normalized !== 'neighbor-mean' &&
        normalized !== 'neighbor-median' &&
        normalized !== 'edge-slot' &&
        normalized !== 'port-rank'
      ) {
        fail(
          "invalid --sweep-kernel value, expected 'default', 'neighbor-mean', 'neighbor-median', 'edge-slot', or 'port-rank'",
        )
      }
      sweepKernel = normalized
      continue
    }
    if (arg.startsWith('--trial-continuation-policy=')) {
      const normalized = arg
        .slice('--trial-continuation-policy='.length)
        .trim()
        .toLowerCase()
      if (
        normalized !== 'default' &&
        normalized !== 'pass-changes' &&
        normalized !== 'objective-improves'
      ) {
        fail(
          "invalid --trial-continuation-policy value, expected 'default', 'pass-changes', or 'objective-improves'",
        )
      }
      trialContinuationPolicy = normalized
      continue
    }
    if (arg.startsWith('--local-refinement-profile=')) {
      const normalized = arg
        .slice('--local-refinement-profile='.length)
        .trim()
        .toLowerCase()
      if (
        normalized !== 'default' &&
        normalized !== 'none' &&
        normalized !== 'adjacent-swap' &&
        normalized !== 'rank-permutation' &&
        normalized !== 'adjacent-swap-then-rank-permutation'
      ) {
        fail(
          "invalid --local-refinement-profile value, expected 'default', 'none', 'adjacent-swap', 'rank-permutation', or 'adjacent-swap-then-rank-permutation'",
        )
      }
      localRefinementProfile = normalized
      continue
    }
    if (arg === '--model-order-inversion-influence') {
      const next = args[i + 1]
      if (!next) fail('missing value after --model-order-inversion-influence')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed < 0) {
        fail(
          `invalid --model-order-inversion-influence value: ${next}, expected non-negative number`,
        )
      }
      modelOrderInversionInfluence = parsed
      i += 1
      continue
    }
    if (arg === '--upstream-layer-source') {
      const next = args[i + 1]
      if (!next) fail('missing value after --upstream-layer-source')
      const normalized = next.trim().toLowerCase()
      if (normalized !== 'final-coordinates' && normalized !== 'layer-logs') {
        fail(
          "invalid --upstream-layer-source value, expected 'final-coordinates' or 'layer-logs'",
        )
      }
      upstreamLayerSource = normalized
      i += 1
      continue
    }
    if (arg.startsWith('--model-order-inversion-influence=')) {
      const raw = arg.slice('--model-order-inversion-influence='.length)
      const parsed = Number.parseFloat(raw)
      if (!Number.isFinite(parsed) || parsed < 0) {
        fail(
          `invalid --model-order-inversion-influence value: ${raw}, expected non-negative number`,
        )
      }
      modelOrderInversionInfluence = parsed
      continue
    }
    if (arg.startsWith('--upstream-layer-source=')) {
      const normalized = arg
        .slice('--upstream-layer-source='.length)
        .trim()
        .toLowerCase()
      if (normalized !== 'final-coordinates' && normalized !== 'layer-logs') {
        fail(
          "invalid --upstream-layer-source value, expected 'final-coordinates' or 'layer-logs'",
        )
      }
      upstreamLayerSource = normalized
      continue
    }
    if (arg.startsWith('--')) {
      fail(`unknown argument: ${arg}`)
    }
    fixtures.push(arg)
  }
  if (fixtures.length === 0) {
    fail(
      'usage: bun run scripts/compare_elk_crossing_rank_order.ts [--details] [--limit N] [--trial-count N] [--sweep-pass-count N] [--sweep-kernel default|neighbor-mean|neighbor-median|edge-slot|port-rank] [--trial-continuation-policy default|pass-changes|objective-improves] [--local-refinement-profile default|none|adjacent-swap|rank-permutation|adjacent-swap-then-rank-permutation] [--model-order-inversion-influence N] [--upstream-layer-source final-coordinates|layer-logs] <fixture.mmd> [more...]',
    )
  }
  return {
    fixtures,
    details,
    detailLimit,
    trialCount,
    sweepPassCount,
    sweepKernel,
    trialContinuationPolicy,
    localRefinementProfile,
    modelOrderInversionInfluence,
    upstreamLayerSource,
  }
}

function rankPositionByNodeId(layers: Layering): Map<string, { rank: number; pos: number }> {
  const map = new Map<string, { rank: number; pos: number }>()
  for (let rank = 0; rank < layers.length; rank += 1) {
    const layer = layers[rank] ?? []
    for (let pos = 0; pos < layer.length; pos += 1) {
      map.set(layer[pos]!, { rank, pos })
    }
  }
  return map
}

function summarizePositions(positions: number[]): NeighborSummary | undefined {
  if (positions.length === 0) return undefined
  const sorted = positions.slice().sort((a, b) => a - b)
  const count = sorted.length
  const sum = sorted.reduce((acc, value) => acc + value, 0)
  const median =
    count % 2 === 1
      ? sorted[(count / 2) | 0]!
      : (sorted[count / 2 - 1]! + sorted[count / 2]!) / 2
  return { count, median, mean: sum / count }
}

function collectNeighborSummary(
  nodeId: string,
  rank: number,
  edges: Edge[],
  rankPosByNodeId: Map<string, { rank: number; pos: number }>,
): { prev?: NeighborSummary; next?: NeighborSummary } {
  const prevPositions: number[] = []
  const nextPositions: number[] = []
  for (const edge of edges) {
    if (edge.target === nodeId) {
      const sourceInfo = rankPosByNodeId.get(edge.source)
      if (sourceInfo && sourceInfo.rank < rank) {
        prevPositions.push(sourceInfo.pos)
      }
    }
    if (edge.source === nodeId) {
      const targetInfo = rankPosByNodeId.get(edge.target)
      if (targetInfo && targetInfo.rank > rank) {
        nextPositions.push(targetInfo.pos)
      }
    }
  }
  return {
    prev: summarizePositions(prevPositions),
    next: summarizePositions(nextPositions),
  }
}

function formatNeighborSummary(value: NeighborSummary | undefined): string {
  if (!value) return 'none'
  return `count=${value.count}, median=${round(value.median)}, mean=${round(value.mean)}`
}

function mismatchedRanks(localLayers: Layering, upstreamLayers: Layering): number[] {
  const ranks: number[] = []
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const local = localLayers[rank] ?? []
    const upstream = upstreamLayers[rank] ?? []
    if (JSON.stringify(local) !== JSON.stringify(upstream)) {
      ranks.push(rank)
    }
  }
  return ranks
}

function printCaseDetails(result: CaseResult): void {
  const metric = result.metrics
  const mismatchRanks = mismatchedRanks(
    result.localRankLayers,
    result.upstreamRankLayers,
  )
  if (mismatchRanks.length === 0) return
  const rankPosByNodeId = rankPositionByNodeId(result.localRankLayers)
  console.log(`\n--- details ${metric.fixture} ---`)
  for (const rank of mismatchRanks) {
    const localLayer = result.localRankLayers[rank] ?? []
    const upstreamLayer = result.upstreamRankLayers[rank] ?? []
    const nodes: string[] = []
    for (const nodeId of localLayer) {
      nodes.push(nodeId)
    }
    for (const nodeId of upstreamLayer) {
      if (!nodes.includes(nodeId)) {
        nodes.push(nodeId)
      }
    }
    console.log(`rank=${rank}`)
    console.log(`  local   = [${localLayer.join(', ')}]`)
    console.log(`  upstream= [${upstreamLayer.join(', ')}]`)
    for (const nodeId of nodes) {
      const summary = collectNeighborSummary(
        nodeId,
        rank,
        result.inputEdges,
        rankPosByNodeId,
      )
      console.log(
        `  node=${nodeId} prev{${formatNeighborSummary(summary.prev)}} next{${formatNeighborSummary(summary.next)}}`,
      )
    }
  }
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const results = options.fixtures.map(fixture => compareFixture(fixture, options))
  const rows = results.map(result => result.metrics)
  let totalOrderMismatch = 0
  let totalCompositionMismatch = 0
  let totalLayerSlots = 0
  let exactRateSum = 0
  let displacementSum = 0
  let exactOrderRateSum = 0
  let orderDisplacementSum = 0

  for (const row of rows) {
    const layerSlots = Math.max(row.localLayers, row.upstreamLayers)
    totalOrderMismatch += row.orderMismatchLayers
    totalCompositionMismatch += row.compositionMismatchLayers
    totalLayerSlots += layerSlots
    exactRateSum += row.exactMatchRate
    displacementSum += row.avgDisplacement
    exactOrderRateSum += row.exactOrderMatchRate
    orderDisplacementSum += row.avgOrderDisplacement

    console.log(`\n=== ${row.fixture} ===`)
    console.log(
      `layers local/upstream=${row.localLayers}/${row.upstreamLayers} shared_nodes=${row.sharedNodes}`,
    )
    console.log(
      `order_mismatch_layers=${row.orderMismatchLayers} composition_mismatch_layers=${row.compositionMismatchLayers}`,
    )
    console.log(
      `exact_match_rate=${round(row.exactMatchRate)} avg_displacement=${round(row.avgDisplacement)}`,
    )
    console.log(
      `same_rank_shared_nodes=${row.sameRankSharedNodes} exact_order_match_rate=${round(row.exactOrderMatchRate)} avg_order_displacement=${round(row.avgOrderDisplacement)}`,
    )
  }

  const avgExactRate = rows.length === 0 ? 0 : exactRateSum / rows.length
  const avgDisplacement = rows.length === 0 ? 0 : displacementSum / rows.length
  const avgExactOrderRate =
    rows.length === 0 ? 0 : exactOrderRateSum / rows.length
  const avgOrderDisplacement =
    rows.length === 0 ? 0 : orderDisplacementSum / rows.length

  console.log('\n=== summary ===')
  console.log(`fixtures=${rows.length}`)
  console.log(`total_order_mismatch=${totalOrderMismatch}/${totalLayerSlots}`)
  console.log(`total_composition_mismatch=${totalCompositionMismatch}/${totalLayerSlots}`)
  console.log(`avg_exact_match_rate=${round(avgExactRate)}`)
  console.log(`avg_displacement=${round(avgDisplacement)}`)
  console.log(`avg_exact_order_match_rate=${round(avgExactOrderRate)}`)
  console.log(`avg_order_displacement=${round(avgOrderDisplacement)}`)

  if (options.details) {
    const ranked = results
      .filter(result => result.metrics.orderMismatchLayers > 0)
      .sort((left, right) => {
        if (left.metrics.orderMismatchLayers !== right.metrics.orderMismatchLayers) {
          return right.metrics.orderMismatchLayers - left.metrics.orderMismatchLayers
        }
        return left.metrics.fixture.localeCompare(right.metrics.fixture)
      })
      .slice(0, options.detailLimit)
    if (ranked.length === 0) {
      console.log('\n=== details ===')
      console.log('no order mismatch layers')
      return
    }
    console.log('\n=== details ===')
    for (const result of ranked) {
      printCaseDetails(result)
    }
  }
}

main()
