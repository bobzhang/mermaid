/**
 * Compare local ELK crossing-phase intermediate outputs against upstream elkjs.
 *
 * Phase mapping:
 * - local post-sweep: selected candidate `ORDER_LAYER_*_POST_SWEEP`
 * - upstream post-barycenter: layout with greedy switch disabled
 * - local final: `RANK_LAYER`
 * - upstream final: default layered layout
 *
 * Usage:
 *   bun run scripts/compare_elk_crossing_phase_trace.ts fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts fixtures/layout_stress_001_dense_dag.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --trial-count 5 fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --sweep-kernel neighbor-median --trial-count 5 fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --sweep-kernel edge-slot --trial-count 5 fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --sweep-kernel port-rank --trial-count 5 fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --trial-continuation-policy objective-improves fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --local-refinement-profile none fixtures/layout_stress_006_nested_bridge_loops.mmd
 *   bun run scripts/compare_elk_crossing_phase_trace.ts --model-order-inversion-influence 0.25 fixtures/layout_stress_006_nested_bridge_loops.mmd
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
  selectedSource: string
  selectedPostSweepLayers: Layering
  finalLayers: Layering
}

type UpstreamPlacement = {
  majorByNodeId: Map<string, number>
  minorByNodeId: Map<string, number>
}

type LayerParity = {
  layerSlots: number
  orderMismatchLayers: number
  compositionMismatchLayers: number
  exactMatchRate: number
  avgDisplacement: number
  sameRankSharedNodes: number
  exactOrderMatchRate: number
  avgOrderDisplacement: number
}

type CaseMetrics = {
  fixture: string
  selectedSource: string
  postSweep: LayerParity
  final: LayerParity
}

type CliOptions = {
  fixtures: string[]
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

function parseRankLayersByPrefix(lines: string[], prefix: string): Map<number, string[]> {
  const layersByRank = new Map<number, string[]>()
  for (const line of lines) {
    const parts = line.split('\t')
    if (parts[0] !== prefix) continue
    const rank = Number.parseInt(parts[1] ?? '', 10)
    if (!Number.isFinite(rank)) fail(`invalid ${prefix} rank line: ${line}`)
    const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
    layersByRank.set(rank, nodes)
  }
  return layersByRank
}

function layersFromRankMap(layersByRank: Map<number, string[]>): Layering {
  if (layersByRank.size === 0) return []
  const maxRank = Math.max(...layersByRank.keys())
  const layers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    const layer = layersByRank.get(rank) ?? []
    if (layer.length > 0) layers.push(layer)
  }
  return layers
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
  const lines = stdout
    .split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line !== '')

  const inputNodeIdsByIndex = new Map<number, string>()
  const inputEdges: Edge[] = []
  let selectedSource = ''

  for (const line of lines) {
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
    if (parts[0] === 'ORDER_SELECTED_SOURCE') {
      selectedSource = parts[1] ?? ''
      continue
    }
  }

  if (inputNodeIdsByIndex.size === 0) fail('local trace missing INPUT_NODE output')
  if (inputEdges.length === 0) fail('local trace missing INPUT_EDGE output')
  if (selectedSource === '') fail('local trace missing ORDER_SELECTED_SOURCE output')

  const seedPostSweep = parseRankLayersByPrefix(
    lines,
    'ORDER_LAYER_OPTIMIZED_SEED_POST_SWEEP',
  )
  const reversedPostSweep = parseRankLayersByPrefix(
    lines,
    'ORDER_LAYER_OPTIMIZED_REVERSED_SEED_POST_SWEEP',
  )
  const virtualPostSweep = parseRankLayersByPrefix(
    lines,
    'ORDER_LAYER_VIRTUAL_CANDIDATE_POST_SWEEP',
  )
  const finalRankLayers = parseRankLayersByPrefix(lines, 'RANK_LAYER')

  const selectedPostSweepRankMap =
    selectedSource === 'optimized-reversed-seed'
      ? reversedPostSweep
      : selectedSource === 'virtual'
        ? virtualPostSweep
        : seedPostSweep

  if (selectedPostSweepRankMap.size === 0) {
    fail(
      `local trace missing selected post-sweep layers for source: ${selectedSource}`,
    )
  }
  if (finalRankLayers.size === 0) fail('local trace missing RANK_LAYER output')

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)

  return {
    inputNodeIds,
    inputEdges,
    selectedSource,
    selectedPostSweepLayers: layersFromRankMap(selectedPostSweepRankMap),
    finalLayers: layersFromRankMap(finalRankLayers),
  }
}

function parseJsonPlacement(raw: string): Array<{ id: string; x: number; y: number }> {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream placement payload: ${String(error)}`)
  }
  if (!Array.isArray(parsed)) {
    fail('invalid upstream placement payload: root is not an array')
  }
  const rows: Array<{ id: string; x: number; y: number }> = []
  for (const row of parsed) {
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
  return rows
}

function runUpstreamPlacement(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
  disableGreedySwitch: boolean,
): UpstreamPlacement {
  const payload = {
    inputNodeIds,
    inputEdges,
    elkDirection: elkDirection(direction),
    disableGreedySwitch,
  }
  const script = [
    "const ELK = require('./.repos/elkjs_pkg/package/lib/main.js');",
    'const payload = JSON.parse(process.argv[1]);',
    'const layoutOptions = {',
    "  'elk.algorithm': 'layered',",
    "  'org.eclipse.elk.randomSeed': '1',",
    "  'elk.direction': payload.elkDirection,",
    "  'org.eclipse.elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES',",
    "  'spacing.baseValue': '40',",
    "  'spacing.nodeNode': '130',",
    "  'spacing.nodeNodeBetweenLayers': '90',",
    "  'elk.edgeRouting': 'POLYLINE',",
    "  'org.eclipse.elk.layered.unnecessaryBendpoints': 'true',",
    '};',
    'if (payload.disableGreedySwitch) {',
    "  layoutOptions['org.eclipse.elk.layered.crossingMinimization.greedySwitch.type'] = 'OFF';",
    '}',
    'const graph = {',
    "  id: 'g',",
    '  layoutOptions,',
    '  children: payload.inputNodeIds.map(id => ({ id, width: 80, height: 40 })),',
    '  edges: payload.inputEdges.map((edge, index) => ({',
    "    id: `e${index}`,",
    '    sources: [edge.source],',
    '    targets: [edge.target],',
    '  })),',
    '};',
    'new ELK().layout(graph).then(out => {',
    '  const rows = (out.children ?? []).map(child => ({ id: child.id, x: child.x, y: child.y }));',
    '  process.stdout.write(JSON.stringify(rows));',
    '}).catch(err => {',
    '  console.error(String(err));',
    '  process.exit(1);',
    '});',
  ].join('\n')
  const stdout = runOrThrow('node', ['-e', script, JSON.stringify(payload)])
  const rows = parseJsonPlacement(stdout)
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
  return { majorByNodeId, minorByNodeId }
}

function buildLayersByMajor(
  labels: string[],
  majorByNodeId: Map<string, number>,
  minorByNodeId: Map<string, number>,
): Layering {
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
  const layers: Layering = []
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
  if (layer.length > 0) layers.push(layer)
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

function compareLayers(localLayers: Layering, upstreamLayers: Layering): LayerParity {
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
    layerSlots: maxLayerCount,
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
): { selectedLayers: Layering; parity: LayerParity } {
  const directParity = compareLayers(localLayers, upstreamLayers)
  const reversedUpstreamLayers = upstreamLayers.slice().reverse()
  const reversedParity = compareLayers(localLayers, reversedUpstreamLayers)
  const useReversed =
    reversedParity.compositionMismatchLayers < directParity.compositionMismatchLayers ||
    (
      reversedParity.compositionMismatchLayers ===
        directParity.compositionMismatchLayers &&
      reversedParity.orderMismatchLayers < directParity.orderMismatchLayers
    ) ||
    (
      reversedParity.compositionMismatchLayers ===
        directParity.compositionMismatchLayers &&
      reversedParity.orderMismatchLayers === directParity.orderMismatchLayers &&
      reversedParity.avgDisplacement < directParity.avgDisplacement
    )
  return {
    selectedLayers: useReversed ? reversedUpstreamLayers : upstreamLayers,
    parity: useReversed ? reversedParity : directParity,
  }
}

function compareFixture(fixturePath: string, options: CliOptions): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const local = parseLocalTrace(source, options)
  const upstreamPostBarycenter = runUpstreamPlacement(
    local.inputNodeIds,
    local.inputEdges,
    direction,
    true,
  )
  const upstreamFinal = runUpstreamPlacement(
    local.inputNodeIds,
    local.inputEdges,
    direction,
    false,
  )
  const upstreamPostBarycenterLayers = buildLayersByMajor(
    local.inputNodeIds,
    upstreamPostBarycenter.majorByNodeId,
    upstreamPostBarycenter.minorByNodeId,
  )
  const upstreamFinalLayers = buildLayersByMajor(
    local.inputNodeIds,
    upstreamFinal.majorByNodeId,
    upstreamFinal.minorByNodeId,
  )
  const postSweep = selectCloserUpstreamLayering(
    local.selectedPostSweepLayers,
    upstreamPostBarycenterLayers,
  ).parity
  const final = selectCloserUpstreamLayering(
    local.finalLayers,
    upstreamFinalLayers,
  ).parity
  return { fixture: fixturePath, selectedSource: local.selectedSource, postSweep, final }
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
  const fixtures: string[] = []
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
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
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
    if (arg.startsWith('--')) {
      fail(`unknown argument: ${arg}`)
    }
    fixtures.push(arg)
  }
  if (fixtures.length === 0) {
    fail(
      'usage: bun run scripts/compare_elk_crossing_phase_trace.ts [--trial-count N] [--sweep-pass-count N] [--sweep-kernel default|neighbor-mean|neighbor-median|edge-slot|port-rank] [--trial-continuation-policy default|pass-changes|objective-improves] [--local-refinement-profile default|none|adjacent-swap|rank-permutation|adjacent-swap-then-rank-permutation] [--model-order-inversion-influence N] <fixture.mmd> [more...]',
    )
  }
  return {
    fixtures,
    trialCount,
    sweepPassCount,
    sweepKernel,
    trialContinuationPolicy,
    localRefinementProfile,
    modelOrderInversionInfluence,
  }
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const rows = options.fixtures.map(fixture => compareFixture(fixture, options))
  let totalPostSweepOrderMismatch = 0
  let totalFinalOrderMismatch = 0
  let totalPostSweepCompositionMismatch = 0
  let totalFinalCompositionMismatch = 0
  let totalPostSweepLayerSlots = 0
  let totalFinalLayerSlots = 0
  let postSweepExactOrderRateSum = 0
  let finalExactOrderRateSum = 0
  let postSweepAvgOrderDisplacementSum = 0
  let finalAvgOrderDisplacementSum = 0

  for (const row of rows) {
    totalPostSweepOrderMismatch += row.postSweep.orderMismatchLayers
    totalFinalOrderMismatch += row.final.orderMismatchLayers
    totalPostSweepCompositionMismatch += row.postSweep.compositionMismatchLayers
    totalFinalCompositionMismatch += row.final.compositionMismatchLayers
    totalPostSweepLayerSlots += row.postSweep.layerSlots
    totalFinalLayerSlots += row.final.layerSlots
    postSweepExactOrderRateSum += row.postSweep.exactOrderMatchRate
    finalExactOrderRateSum += row.final.exactOrderMatchRate
    postSweepAvgOrderDisplacementSum += row.postSweep.avgOrderDisplacement
    finalAvgOrderDisplacementSum += row.final.avgOrderDisplacement

    console.log(`\n=== ${row.fixture} ===`)
    console.log(`selected_source=${row.selectedSource}`)
    console.log(
      `post_sweep order_mismatch=${row.postSweep.orderMismatchLayers} composition_mismatch=${row.postSweep.compositionMismatchLayers} exact_order_match_rate=${round(row.postSweep.exactOrderMatchRate)} avg_order_displacement=${round(row.postSweep.avgOrderDisplacement)}`,
    )
    console.log(
      `final      order_mismatch=${row.final.orderMismatchLayers} composition_mismatch=${row.final.compositionMismatchLayers} exact_order_match_rate=${round(row.final.exactOrderMatchRate)} avg_order_displacement=${round(row.final.avgOrderDisplacement)}`,
    )
  }

  const caseCount = rows.length
  console.log('\n=== summary ===')
  console.log(`fixtures=${caseCount}`)
  console.log(
    `post_sweep_total_order_mismatch=${totalPostSweepOrderMismatch}/${totalPostSweepLayerSlots}`,
  )
  console.log(
    `final_total_order_mismatch=${totalFinalOrderMismatch}/${totalFinalLayerSlots}`,
  )
  console.log(
    `post_sweep_total_composition_mismatch=${totalPostSweepCompositionMismatch}/${totalPostSweepLayerSlots}`,
  )
  console.log(
    `final_total_composition_mismatch=${totalFinalCompositionMismatch}/${totalFinalLayerSlots}`,
  )
  console.log(
    `post_sweep_avg_exact_order_match_rate=${round(postSweepExactOrderRateSum / caseCount)}`,
  )
  console.log(
    `final_avg_exact_order_match_rate=${round(finalExactOrderRateSum / caseCount)}`,
  )
  console.log(
    `post_sweep_avg_order_displacement=${round(postSweepAvgOrderDisplacementSum / caseCount)}`,
  )
  console.log(
    `final_avg_order_displacement=${round(finalAvgOrderDisplacementSum / caseCount)}`,
  )
}

main()
