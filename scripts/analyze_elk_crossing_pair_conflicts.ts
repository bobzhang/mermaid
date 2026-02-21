/**
 * Analyze ELK crossing-rank mismatches by pairwise neighbor-mean conflicts.
 *
 * For each rank and each node pair in that rank, this script compares:
 * - upstream order (from elkjs final layer order)
 * - local predecessor-/successor-neighbor mean order (from local trace graph)
 *
 * This helps separate:
 * - strict conflicts (heuristic predicts opposite order)
 * - ties/ambiguous cases (equal means)
 *
 * Usage:
 *   bun run scripts/analyze_elk_crossing_pair_conflicts.ts
 *   bun run scripts/analyze_elk_crossing_pair_conflicts.ts fixtures/layout_stress_004_fanin_fanout.mmd
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

type RankPos = { rank: number; pos: number }

type ConflictCounters = {
  comparablePrevPairs: number
  strictPrevConflicts: number
  tiedPrevPairs: number
  comparableNextPairs: number
  strictNextConflicts: number
  tiedNextPairs: number
}

type CliOptions = {
  fixtures: string[]
  trialCount?: number
  sweepPassCount?: number
  sweepKernel?: 'default' | 'neighbor-mean' | 'neighbor-median' | 'edge-slot'
  trialContinuationPolicy?: 'default' | 'pass-changes' | 'objective-improves'
  localRefinementProfile?:
    | 'default'
    | 'none'
    | 'adjacent-swap'
    | 'rank-permutation'
    | 'adjacent-swap-then-rank-permutation'
  modelOrderInversionInfluence?: number
}

const STRESS_FIXTURES = [
  'fixtures/layout_stress_001_dense_dag.mmd',
  'fixtures/layout_stress_002_feedback_mesh.mmd',
  'fixtures/layout_stress_003_subgraph_bridges.mmd',
  'fixtures/layout_stress_004_fanin_fanout.mmd',
  'fixtures/layout_stress_005_long_span_backjumps.mmd',
  'fixtures/layout_stress_006_nested_bridge_loops.mmd',
  'fixtures/layout_stress_007_dependency_weave.mmd',
  'fixtures/layout_stress_008_hyper_weave_pipeline.mmd',
  'fixtures/layout_stress_009_nested_ring_bridges.mmd',
  'fixtures/layout_stress_010_bipartite_crossfire.mmd',
  'fixtures/layout_stress_011_feedback_lattice.mmd',
  'fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd',
  'fixtures/layout_stress_013_rl_dual_scc_weave.mmd',
]

function fail(message: string): never {
  throw new Error(message)
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
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail(`invalid --trial-count value: ${next}`)
      }
      trialCount = parsed
      i += 1
      continue
    }
    if (arg === '--sweep-pass-count') {
      const next = args[i + 1]
      if (!next) fail('missing value after --sweep-pass-count')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail(`invalid --sweep-pass-count value: ${next}`)
      }
      sweepPassCount = parsed
      i += 1
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
        normalized !== 'edge-slot'
      ) {
        fail(
          "invalid --sweep-kernel value, expected 'default', 'neighbor-mean', 'neighbor-median', or 'edge-slot'",
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
    if (arg === '--model-order-inversion-influence') {
      const next = args[i + 1]
      if (!next) fail('missing value after --model-order-inversion-influence')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed < 0) {
        fail(`invalid --model-order-inversion-influence value: ${next}`)
      }
      modelOrderInversionInfluence = parsed
      i += 1
      continue
    }
    if (arg.startsWith('-')) {
      fail(`unknown argument: ${arg}`)
    }
    fixtures.push(arg)
  }

  return {
    fixtures: fixtures.length > 0 ? fixtures : STRESS_FIXTURES,
    trialCount,
    sweepPassCount,
    sweepKernel,
    trialContinuationPolicy,
    localRefinementProfile,
    modelOrderInversionInfluence,
  }
}

function runOrThrow(cmd: string, args: string[], env?: NodeJS.ProcessEnv): string {
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
      if (Number.isFinite(index) && nodeId !== '') inputNodeIdsByIndex.set(index, nodeId)
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
      if (!Number.isFinite(rank)) fail(`invalid RANK_LAYER rank line: ${line}`)
      rankLayersByRank.set(rank, (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(','))
      continue
    }
  }

  if (inputNodeIdsByIndex.size === 0) fail('local trace missing INPUT_NODE output')
  if (rankLayersByRank.size === 0) fail('local trace missing RANK_LAYER output')

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)

  const maxRank = Math.max(...rankLayersByRank.keys())
  const rankLayers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    const layer = rankLayersByRank.get(rank) ?? []
    if (layer.length > 0) rankLayers.push(layer)
  }
  return { inputNodeIds, inputEdges, rankLayers }
}

function parseJsonPlacement(raw: string): Array<{ id: string; x: number; y: number }> {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream placement payload: ${String(error)}`)
  }
  if (!Array.isArray(parsed)) fail('invalid upstream placement payload: root is not an array')
  const rows: Array<{ id: string; x: number; y: number }> = []
  for (const row of parsed) {
    if (!row || typeof row !== 'object') fail('invalid upstream placement payload: row is not object')
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
): UpstreamPlacement {
  const payload = { inputNodeIds, inputEdges, elkDirection: elkDirection(direction) }
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

function layeringToRankPosMap(layers: Layering): Map<string, RankPos> {
  const rankPosByNodeId = new Map<string, RankPos>()
  layers.forEach((layer, rank) => {
    layer.forEach((nodeId, pos) => rankPosByNodeId.set(nodeId, { rank, pos }))
  })
  return rankPosByNodeId
}

function compareOrderMismatchCount(localLayers: Layering, upstreamLayers: Layering): number {
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  let mismatch = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const local = localLayers[rank] ?? []
    const upstream = upstreamLayers[rank] ?? []
    if (JSON.stringify(local) !== JSON.stringify(upstream)) mismatch += 1
  }
  return mismatch
}

function selectCloserUpstreamLayering(localLayers: Layering, upstreamLayers: Layering): Layering {
  const directMismatch = compareOrderMismatchCount(localLayers, upstreamLayers)
  const reversed = upstreamLayers.slice().reverse()
  const reversedMismatch = compareOrderMismatchCount(localLayers, reversed)
  return reversedMismatch < directMismatch ? reversed : upstreamLayers
}

function buildAdjacency(edges: Edge[]): {
  predecessorsByNodeId: Map<string, string[]>
  successorsByNodeId: Map<string, string[]>
} {
  const predecessorsByNodeId = new Map<string, string[]>()
  const successorsByNodeId = new Map<string, string[]>()
  for (const edge of edges) {
    const succ = successorsByNodeId.get(edge.source) ?? []
    succ.push(edge.target)
    successorsByNodeId.set(edge.source, succ)
    const pred = predecessorsByNodeId.get(edge.target) ?? []
    pred.push(edge.source)
    predecessorsByNodeId.set(edge.target, pred)
  }
  return { predecessorsByNodeId, successorsByNodeId }
}

function neighborMeanAtRank(
  nodeId: string,
  neighborsByNodeId: Map<string, string[]>,
  localRankPosByNodeId: Map<string, RankPos>,
  expectedNeighborRank: number,
): number | null {
  const neighbors = neighborsByNodeId.get(nodeId) ?? []
  let count = 0
  let sum = 0
  for (const neighborId of neighbors) {
    const pos = localRankPosByNodeId.get(neighborId)
    if (!pos || pos.rank !== expectedNeighborRank) continue
    count += 1
    sum += pos.pos
  }
  if (count === 0) return null
  return sum / count
}

function sign(value: number): -1 | 0 | 1 {
  if (value < 0) return -1
  if (value > 0) return 1
  return 0
}

function countPairConflicts(
  localLayers: Layering,
  upstreamLayers: Layering,
  predecessorsByNodeId: Map<string, string[]>,
  successorsByNodeId: Map<string, string[]>,
): ConflictCounters {
  const localRankPosByNodeId = layeringToRankPosMap(localLayers)
  const upstreamRankPosByNodeId = layeringToRankPosMap(upstreamLayers)
  const counters: ConflictCounters = {
    comparablePrevPairs: 0,
    strictPrevConflicts: 0,
    tiedPrevPairs: 0,
    comparableNextPairs: 0,
    strictNextConflicts: 0,
    tiedNextPairs: 0,
  }

  for (let rank = 0; rank < localLayers.length; rank += 1) {
    const localLayer = localLayers[rank] ?? []
    const nodes = localLayer.filter(nodeId => upstreamRankPosByNodeId.get(nodeId)?.rank === rank)
    if (nodes.length <= 1) continue
    for (let i = 0; i < nodes.length; i += 1) {
      const left = nodes[i]!
      const upstreamLeftPos = upstreamRankPosByNodeId.get(left)?.pos
      if (upstreamLeftPos === undefined) continue
      for (let j = i + 1; j < nodes.length; j += 1) {
        const right = nodes[j]!
        const upstreamRightPos = upstreamRankPosByNodeId.get(right)?.pos
        if (upstreamRightPos === undefined) continue
        const upstreamSign = sign(upstreamLeftPos - upstreamRightPos)

        const prevLeft = neighborMeanAtRank(
          left,
          predecessorsByNodeId,
          localRankPosByNodeId,
          rank - 1,
        )
        const prevRight = neighborMeanAtRank(
          right,
          predecessorsByNodeId,
          localRankPosByNodeId,
          rank - 1,
        )
        if (prevLeft !== null && prevRight !== null) {
          counters.comparablePrevPairs += 1
          const prevSign = sign(prevLeft - prevRight)
          if (prevSign === 0) {
            counters.tiedPrevPairs += 1
          } else if (prevSign !== upstreamSign) {
            counters.strictPrevConflicts += 1
          }
        }

        const nextLeft = neighborMeanAtRank(
          left,
          successorsByNodeId,
          localRankPosByNodeId,
          rank + 1,
        )
        const nextRight = neighborMeanAtRank(
          right,
          successorsByNodeId,
          localRankPosByNodeId,
          rank + 1,
        )
        if (nextLeft !== null && nextRight !== null) {
          counters.comparableNextPairs += 1
          const nextSign = sign(nextLeft - nextRight)
          if (nextSign === 0) {
            counters.tiedNextPairs += 1
          } else if (nextSign !== upstreamSign) {
            counters.strictNextConflicts += 1
          }
        }
      }
    }
  }
  return counters
}

function formatRatio(numerator: number, denominator: number): string {
  if (denominator <= 0) return 'n/a'
  return `${((numerator / denominator) * 100).toFixed(1)}%`
}

function analyzeFixture(fixturePath: string, options: CliOptions): ConflictCounters {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const local = parseLocalTrace(source, options)
  const upstream = runUpstreamPlacement(local.inputNodeIds, local.inputEdges, direction)
  const upstreamLayersRaw = buildLayersByMajor(
    local.inputNodeIds,
    upstream.majorByNodeId,
    upstream.minorByNodeId,
  )
  const upstreamLayers = selectCloserUpstreamLayering(local.rankLayers, upstreamLayersRaw)
  const { predecessorsByNodeId, successorsByNodeId } = buildAdjacency(local.inputEdges)
  return countPairConflicts(
    local.rankLayers,
    upstreamLayers,
    predecessorsByNodeId,
    successorsByNodeId,
  )
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const targets = options.fixtures
  const total: ConflictCounters = {
    comparablePrevPairs: 0,
    strictPrevConflicts: 0,
    tiedPrevPairs: 0,
    comparableNextPairs: 0,
    strictNextConflicts: 0,
    tiedNextPairs: 0,
  }
  for (const fixture of targets) {
    const counters = analyzeFixture(fixture, options)
    total.comparablePrevPairs += counters.comparablePrevPairs
    total.strictPrevConflicts += counters.strictPrevConflicts
    total.tiedPrevPairs += counters.tiedPrevPairs
    total.comparableNextPairs += counters.comparableNextPairs
    total.strictNextConflicts += counters.strictNextConflicts
    total.tiedNextPairs += counters.tiedNextPairs
    console.log(
      `${fixture}\tprev_strict=${counters.strictPrevConflicts}/${counters.comparablePrevPairs}\tprev_tied=${counters.tiedPrevPairs}/${counters.comparablePrevPairs}\tnext_strict=${counters.strictNextConflicts}/${counters.comparableNextPairs}\tnext_tied=${counters.tiedNextPairs}/${counters.comparableNextPairs}`,
    )
  }
  console.log('')
  console.log('=== summary ===')
  console.log(
    `prev_strict_conflict=${total.strictPrevConflicts}/${total.comparablePrevPairs} (${formatRatio(total.strictPrevConflicts, total.comparablePrevPairs)})`,
  )
  console.log(
    `prev_tied_pairs=${total.tiedPrevPairs}/${total.comparablePrevPairs} (${formatRatio(total.tiedPrevPairs, total.comparablePrevPairs)})`,
  )
  console.log(
    `next_strict_conflict=${total.strictNextConflicts}/${total.comparableNextPairs} (${formatRatio(total.strictNextConflicts, total.comparableNextPairs)})`,
  )
  console.log(
    `next_tied_pairs=${total.tiedNextPairs}/${total.comparableNextPairs} (${formatRatio(total.tiedNextPairs, total.comparableNextPairs)})`,
  )
}

main()
