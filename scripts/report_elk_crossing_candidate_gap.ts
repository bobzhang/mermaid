/**
 * Report ELK crossing-rank candidate gap versus upstream layered order.
 *
 * This script compares local rank-order candidates from `cmd/elk_trace`:
 * - optimized seed
 * - optimized reversed seed
 * - virtual candidate
 * - selected candidate
 *
 * against upstream elkjs layered output and reports:
 * - per-candidate layer-order mismatch totals
 * - oracle-best mismatch among local candidates
 * - selection gap (selected - oracle-best)
 *
 * Usage:
 *   bun run scripts/report_elk_crossing_candidate_gap.ts
 *   bun run scripts/report_elk_crossing_candidate_gap.ts --json /tmp/candidate_gap.json
 *   bun run scripts/report_elk_crossing_candidate_gap.ts --upstream-layer-source layer-logs
 */

import { spawnSync } from 'node:child_process'
import { readFileSync, writeFileSync } from 'node:fs'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Layering = string[][]
type CandidateName = 'seed' | 'reversed' | 'virtual' | 'selected'

type CandidateMismatch = {
  seed: number
  reversed: number
  virtual: number
  selected: number
  oracleBest: number
  selectionGap: number
}

type CaseReport = {
  fixture: string
  candidates: CandidateMismatch
}

type SummaryReport = {
  fixtures: number
  perCandidateOrderMismatch: CandidateMismatch
  selectedEqualsOracleCount: number
}

type FullReport = {
  cases: CaseReport[]
  summary: SummaryReport
}

type CliOptions = {
  jsonPath?: string
  upstreamLayerSource: 'final-coordinates' | 'layer-logs'
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

function runOrThrow(
  cmd: string,
  args: string[],
  env?: NodeJS.ProcessEnv,
): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 64 * 1024 * 1024,
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

function parseCliOptions(args: string[]): CliOptions {
  let jsonPath: string | undefined
  let upstreamLayerSource: 'final-coordinates' | 'layer-logs' =
    'final-coordinates'
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--json') {
      const next = args[i + 1]
      if (!next) fail('missing path after --json')
      jsonPath = next
      i += 1
      continue
    }
    if (arg.startsWith('--json=')) {
      const value = arg.slice('--json='.length)
      if (value === '') fail('missing path after --json=')
      jsonPath = value
      continue
    }
    if (arg === '--upstream-layer-source') {
      const next = args[i + 1]
      if (!next) fail('missing value after --upstream-layer-source')
      const normalized = next.trim().toLowerCase()
      if (
        normalized !== 'final-coordinates' &&
        normalized !== 'layer-logs'
      ) {
        fail(
          "invalid --upstream-layer-source value, expected 'final-coordinates' or 'layer-logs'",
        )
      }
      upstreamLayerSource = normalized
      i += 1
      continue
    }
    if (arg.startsWith('--upstream-layer-source=')) {
      const normalized = arg
        .slice('--upstream-layer-source='.length)
        .trim()
        .toLowerCase()
      if (
        normalized !== 'final-coordinates' &&
        normalized !== 'layer-logs'
      ) {
        fail(
          "invalid --upstream-layer-source value, expected 'final-coordinates' or 'layer-logs'",
        )
      }
      upstreamLayerSource = normalized
      continue
    }
    fail(`unknown argument: ${arg}`)
  }
  return { jsonPath, upstreamLayerSource }
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

function majorAxisByDirection(direction: Direction): 'x' | 'y' {
  return direction === 'LR' || direction === 'RL' ? 'x' : 'y'
}

function elkDirection(direction: Direction): 'RIGHT' | 'LEFT' | 'DOWN' | 'UP' {
  if (direction === 'RL') return 'LEFT'
  if (direction === 'BT') return 'UP'
  if (direction === 'TB' || direction === 'TD') return 'DOWN'
  return 'RIGHT'
}

type ParsedTrace = {
  inputNodeIds: string[]
  inputEdges: Array<{ source: string; target: string }>
  layersByCandidate: Record<CandidateName, Layering>
}

type UpstreamLayoutPayload = {
  rows: Array<{ id: string; x: number; y: number }>
  layers: Layering
}

function parseRankLayersByPrefix(
  lines: string[],
  prefix: string,
): Layering {
  const byRank = new Map<number, string[]>()
  for (const rawLine of lines) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    if (parts[0] !== prefix) continue
    const rank = Number.parseInt(parts[1] ?? '', 10)
    if (!Number.isFinite(rank)) continue
    const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
    byRank.set(rank, nodes)
  }
  if (byRank.size === 0) return []
  const maxRank = Math.max(...byRank.keys())
  const layers: string[][] = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    const layer = byRank.get(rank) ?? []
    if (layer.length > 0) layers.push(layer)
  }
  return layers
}

function parseLocalTrace(source: string): ParsedTrace {
  const stdout = runOrThrow('moon', [
    'run',
    'cmd/elk_trace',
    '--target',
    'native',
    '--',
    '--source',
    source,
  ])
  const lines = stdout.split(/\r?\n/)
  const inputNodeIdsByIndex = new Map<number, string>()
  const inputEdges: Array<{ source: string; target: string }> = []
  for (const rawLine of lines) {
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
    }
  }
  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)
  if (inputNodeIds.length === 0 || inputEdges.length === 0) {
    fail('trace did not contain INPUT_NODE/INPUT_EDGE lines')
  }
  return {
    inputNodeIds,
    inputEdges,
    layersByCandidate: {
      seed: parseRankLayersByPrefix(lines, 'ORDER_LAYER_OPTIMIZED_SEED'),
      reversed: parseRankLayersByPrefix(lines, 'ORDER_LAYER_OPTIMIZED_REVERSED_SEED'),
      virtual: parseRankLayersByPrefix(lines, 'ORDER_LAYER_VIRTUAL_CANDIDATE'),
      selected: parseRankLayersByPrefix(lines, 'ORDER_LAYER_SELECTED'),
    },
  }
}

function parseJsonUpstreamLayout(raw: string): UpstreamLayoutPayload {
  const parsed = JSON.parse(raw) as unknown
  if (!parsed || typeof parsed !== 'object') {
    fail('invalid upstream payload: not an object')
  }
  const maybeRows = (parsed as { rows?: unknown }).rows
  const maybeLayers = (parsed as { layers?: unknown }).layers
  if (!Array.isArray(maybeRows)) fail('invalid upstream payload: rows is not an array')
  if (!Array.isArray(maybeLayers)) {
    fail('invalid upstream payload: layers is not an array')
  }
  const rows: Array<{ id: string; x: number; y: number }> = []
  for (const row of maybeRows) {
    if (!row || typeof row !== 'object') fail('invalid upstream payload row')
    const maybeId = (row as { id?: unknown }).id
    const maybeX = (row as { x?: unknown }).x
    const maybeY = (row as { y?: unknown }).y
    if (typeof maybeId !== 'string' || typeof maybeX !== 'number' || typeof maybeY !== 'number') {
      fail('invalid upstream payload row shape')
    }
    rows.push({ id: maybeId, x: maybeX, y: maybeY })
  }
  const layers: Layering = []
  for (const layer of maybeLayers) {
    if (!Array.isArray(layer)) fail('invalid upstream payload layer')
    const normalizedLayer: string[] = []
    for (const nodeId of layer) {
      if (typeof nodeId !== 'string') {
        fail('invalid upstream payload layer node id')
      }
      normalizedLayer.push(nodeId)
    }
    if (normalizedLayer.length > 0) layers.push(normalizedLayer)
  }
  return { rows, layers }
}

function runUpstreamLayers(
  inputNodeIds: string[],
  inputEdges: Array<{ source: string; target: string }>,
  direction: Direction,
  upstreamLayerSource: 'final-coordinates' | 'layer-logs',
): Layering {
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
  if (upstreamLayerSource === 'layer-logs' && parsed.layers.length > 0) {
    return parsed.layers
  }
  const rows = parsed.rows
  const majorAxis = majorAxisByDirection(direction)
  const entries = rows
    .map(row => ({
      id: row.id,
      major: majorAxis === 'x' ? row.x : row.y,
      minor: majorAxis === 'x' ? row.y : row.x,
    }))
    .sort((left, right) => {
      if (left.major !== right.major) return left.major - right.major
      if (left.minor !== right.minor) return left.minor - right.minor
      return left.id.localeCompare(right.id)
    })
  if (entries.length === 0) return []
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
    layer.push(entry.id)
  }
  if (layer.length > 0) layers.push(layer)
  return layers
}

function orderMismatchLayers(localLayers: Layering, upstreamLayers: Layering): number {
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  let mismatch = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const local = localLayers[rank] ?? []
    const upstream = upstreamLayers[rank] ?? []
    const localSet = [...local].sort().join(',')
    const upstreamSet = [...upstream].sort().join(',')
    if (localSet !== upstreamSet) continue
    if (local.join(',') !== upstream.join(',')) mismatch += 1
  }
  return mismatch
}

function compareFixture(
  fixture: string,
  upstreamLayerSource: 'final-coordinates' | 'layer-logs',
): CaseReport {
  const source = readFileSync(fixture, 'utf8')
  const local = parseLocalTrace(source)
  const upstream = runUpstreamLayers(
    local.inputNodeIds,
    local.inputEdges,
    parseGraphDirection(source),
    upstreamLayerSource,
  )
  const seed = orderMismatchLayers(local.layersByCandidate.seed, upstream)
  const reversed = orderMismatchLayers(local.layersByCandidate.reversed, upstream)
  const virtual = orderMismatchLayers(local.layersByCandidate.virtual, upstream)
  const selected = orderMismatchLayers(local.layersByCandidate.selected, upstream)
  const oracleBest = Math.min(seed, reversed, virtual)
  return {
    fixture,
    candidates: {
      seed,
      reversed,
      virtual,
      selected,
      oracleBest,
      selectionGap: selected - oracleBest,
    },
  }
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const cases = STRESS_FIXTURES.map(fixture =>
    compareFixture(fixture, options.upstreamLayerSource),
  )
  const summary: SummaryReport = {
    fixtures: cases.length,
    perCandidateOrderMismatch: {
      seed: 0,
      reversed: 0,
      virtual: 0,
      selected: 0,
      oracleBest: 0,
      selectionGap: 0,
    },
    selectedEqualsOracleCount: 0,
  }
  for (const row of cases) {
    summary.perCandidateOrderMismatch.seed += row.candidates.seed
    summary.perCandidateOrderMismatch.reversed += row.candidates.reversed
    summary.perCandidateOrderMismatch.virtual += row.candidates.virtual
    summary.perCandidateOrderMismatch.selected += row.candidates.selected
    summary.perCandidateOrderMismatch.oracleBest += row.candidates.oracleBest
    summary.perCandidateOrderMismatch.selectionGap += row.candidates.selectionGap
    if (row.candidates.selectionGap === 0) summary.selectedEqualsOracleCount += 1
    console.log(
      `${row.fixture} seed=${row.candidates.seed} reversed=${row.candidates.reversed} virtual=${row.candidates.virtual} selected=${row.candidates.selected} oracle=${row.candidates.oracleBest} gap=${row.candidates.selectionGap}`,
    )
  }
  console.log('\n=== summary ===')
  console.log(`fixtures=${summary.fixtures}`)
  console.log(`upstream_layer_source=${options.upstreamLayerSource}`)
  console.log(
    `candidate_order_mismatch seed=${summary.perCandidateOrderMismatch.seed} reversed=${summary.perCandidateOrderMismatch.reversed} virtual=${summary.perCandidateOrderMismatch.virtual} selected=${summary.perCandidateOrderMismatch.selected} oracle=${summary.perCandidateOrderMismatch.oracleBest}`,
  )
  console.log(`selection_gap_total=${summary.perCandidateOrderMismatch.selectionGap}`)
  console.log(
    `selected_equals_oracle=${summary.selectedEqualsOracleCount}/${summary.fixtures}`,
  )
  const report: FullReport = { cases, summary }
  if (options.jsonPath) {
    writeFileSync(options.jsonPath, JSON.stringify(report, null, 2))
    console.log(`wrote_json=${options.jsonPath}`)
  }
}

main()
