/**
 * Report ELK crossing pass-level parity gap for the selected trial.
 *
 * For each fixture:
 * - local source: cmd/elk_trace ORDER_TRIAL_PASS / ORDER_TRIAL_LAYER
 * - upstream target: elkjs layered order with greedy switch disabled
 *
 * Usage:
 *   bun run scripts/report_elk_crossing_selected_pass_gap.ts
 *   bun run scripts/report_elk_crossing_selected_pass_gap.ts --trial-count 2
 *   bun run scripts/report_elk_crossing_selected_pass_gap.ts fixtures/layout_stress_011_feedback_lattice.mmd
 */

import { readdirSync, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Axis = 'x' | 'y'
type Edge = { source: string; target: string }
type Layering = string[][]

type PassRow = {
  passIndex: number
  direction: 'forward' | 'backward'
  changed: boolean
  layeredCrossings: number
  globalCrossings: number
  layers: Layering
}

type SelectedTrialTrace = {
  fixture: string
  inputNodeIds: string[]
  inputEdges: Edge[]
  selectedSource: string
  selectedTrialIndex: number
  passes: PassRow[]
}

type LayerParity = {
  orderMismatchLayers: number
  compositionMismatchLayers: number
  exactOrderMatchRate: number
  avgOrderDisplacement: number
}

type PassParity = {
  pass: PassRow
  parity: LayerParity
}

type FixtureReport = {
  fixture: string
  selectedSource: string
  selectedTrialIndex: number
  passCount: number
  lastPassParity: LayerParity
  bestPassParity: LayerParity
  bestPassIndex: number
  gainOrderMismatch: number
}

type CliOptions = {
  trialCount?: number
  fixtures: string[]
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

function runOrThrow(cmd: string, args: string[]): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 64 * 1024 * 1024,
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
  const fixtures: string[] = []
  let trialCount: number | undefined
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
    if (arg.startsWith('--trial-count=')) {
      const value = arg.slice('--trial-count='.length)
      const parsed = Number.parseInt(value, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail(`invalid --trial-count value: ${value}`)
      }
      trialCount = parsed
      continue
    }
    if (arg.startsWith('-')) {
      fail(`unknown option: ${arg}`)
    }
    fixtures.push(arg)
  }
  return {
    trialCount,
    fixtures,
  }
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

function parseJsonPlacement(raw: string): Array<{ id: string; x: number; y: number }> {
  const parsed = JSON.parse(raw) as unknown
  if (!Array.isArray(parsed)) {
    fail('invalid upstream placement payload: root is not array')
  }
  const rows: Array<{ id: string; x: number; y: number }> = []
  for (const row of parsed) {
    if (!row || typeof row !== 'object') {
      fail('invalid upstream placement payload: malformed row')
    }
    const maybeId = (row as { id?: unknown }).id
    const maybeX = (row as { x?: unknown }).x
    const maybeY = (row as { y?: unknown }).y
    if (typeof maybeId !== 'string' || typeof maybeX !== 'number' || typeof maybeY !== 'number') {
      fail('invalid upstream placement payload: malformed row value')
    }
    rows.push({ id: maybeId, x: maybeX, y: maybeY })
  }
  return rows
}

function runUpstreamPostBarycenter(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
): Layering {
  const payload = {
    inputNodeIds,
    inputEdges,
    elkDirection: elkDirection(direction),
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
    "  'org.eclipse.elk.layered.crossingMinimization.greedySwitch.type': 'OFF',",
    '};',
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
    layer.push(entry.id)
  }
  if (layer.length > 0) layers.push(layer)
  return layers
}

function layerParity(localLayers: Layering, upstreamLayers: Layering): LayerParity {
  const maxLayerCount = Math.max(localLayers.length, upstreamLayers.length)
  let orderMismatchLayers = 0
  let compositionMismatchLayers = 0
  let exactOrderMatchLayers = 0
  let comparableLayers = 0
  let displacementSum = 0
  let displacementCount = 0

  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const local = localLayers[rank] ?? []
    const upstream = upstreamLayers[rank] ?? []
    const localKey = [...local].sort().join(',')
    const upstreamKey = [...upstream].sort().join(',')
    if (localKey !== upstreamKey) {
      compositionMismatchLayers += 1
      continue
    }
    comparableLayers += 1
    if (local.join(',') === upstream.join(',')) {
      exactOrderMatchLayers += 1
    } else {
      orderMismatchLayers += 1
    }
    const upstreamIndex = new Map<string, number>()
    upstream.forEach((nodeId, index) => upstreamIndex.set(nodeId, index))
    for (let index = 0; index < local.length; index += 1) {
      const nodeId = local[index]!
      const upstreamPos = upstreamIndex.get(nodeId)
      if (upstreamPos === undefined) continue
      displacementSum += Math.abs(index - upstreamPos)
      displacementCount += 1
    }
  }

  return {
    orderMismatchLayers,
    compositionMismatchLayers,
    exactOrderMatchRate:
      comparableLayers === 0 ? 0 : exactOrderMatchLayers / comparableLayers,
    avgOrderDisplacement:
      displacementCount === 0 ? 0 : displacementSum / displacementCount,
  }
}

function parseLayersByRank(lines: string[], source: string, trialIndex: number): Map<number, Map<number, string[]>> {
  const byPass = new Map<number, Map<number, string[]>>()
  for (const rawLine of lines) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    if (parts[0] !== 'ORDER_TRIAL_LAYER') continue
    if ((parts[1] ?? '') !== source) continue
    const candidateTrialIndex = Number.parseInt(parts[2] ?? '', 10)
    if (!Number.isFinite(candidateTrialIndex) || candidateTrialIndex !== trialIndex) continue
    const passIndex = Number.parseInt(parts[3] ?? '', 10)
    const rank = Number.parseInt(parts[4] ?? '', 10)
    if (!Number.isFinite(passIndex) || !Number.isFinite(rank)) continue
    const nodeIds = (parts[5] ?? '') === '' ? [] : (parts[5] ?? '').split(',')
    let byRank = byPass.get(passIndex)
    if (!byRank) {
      byRank = new Map<number, string[]>()
      byPass.set(passIndex, byRank)
    }
    byRank.set(rank, nodeIds)
  }
  return byPass
}

function normalizeLayers(byRank: Map<number, string[]>): Layering {
  if (byRank.size === 0) return []
  const maxRank = Math.max(...byRank.keys())
  const layers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    const layer = byRank.get(rank) ?? []
    if (layer.length > 0) layers.push(layer)
  }
  return layers
}

function parseSelectedTrialTrace(
  fixture: string,
  source: string,
  options: CliOptions,
): SelectedTrialTrace {
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
  const stdout = runOrThrow('moon', args)
  const lines = stdout.split(/\r?\n/)

  const inputNodeIdsByIndex = new Map<number, string>()
  const inputEdges: Edge[] = []
  const selectedTrialBySource = new Map<string, number>()
  const passRows: Array<Omit<PassRow, 'layers'> & { source: string; trialIndex: number }> = []
  let selectedSource = ''

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
      continue
    }
    if (parts[0] === 'ORDER_SELECTED_SOURCE') {
      selectedSource = parts[1] ?? ''
      continue
    }
    if (parts[0] === 'ORDER_TRIAL_SELECTED') {
      const sourceName = parts[1] ?? ''
      const trialIndex = Number.parseInt(parts[2] ?? '', 10)
      if (sourceName !== '' && Number.isFinite(trialIndex)) {
        selectedTrialBySource.set(sourceName, trialIndex)
      }
      continue
    }
    if (parts[0] === 'ORDER_TRIAL_PASS') {
      const sourceName = parts[1] ?? ''
      const trialIndex = Number.parseInt(parts[2] ?? '', 10)
      const passIndex = Number.parseInt(parts[3] ?? '', 10)
      const direction = parts[4] ?? ''
      const changedRaw = parts[5] ?? ''
      const layeredCrossings = Number.parseInt(parts[6] ?? '', 10)
      const globalCrossings = Number.parseInt(parts[7] ?? '', 10)
      if (
        sourceName === '' ||
        !Number.isFinite(trialIndex) ||
        !Number.isFinite(passIndex) ||
        (direction !== 'forward' && direction !== 'backward') ||
        !Number.isFinite(layeredCrossings) ||
        !Number.isFinite(globalCrossings)
      ) {
        continue
      }
      passRows.push({
        source: sourceName,
        trialIndex,
        passIndex,
        direction,
        changed: changedRaw === '1',
        layeredCrossings,
        globalCrossings,
      })
      continue
    }
  }

  if (inputNodeIdsByIndex.size === 0 || inputEdges.length === 0) {
    fail(`${fixture}: trace missing INPUT_NODE/INPUT_EDGE`)
  }
  if (selectedSource === '') {
    fail(`${fixture}: trace missing ORDER_SELECTED_SOURCE`)
  }
  const selectedTrialIndex = selectedTrialBySource.get(selectedSource)
  if (selectedTrialIndex === undefined) {
    fail(`${fixture}: trace missing ORDER_TRIAL_SELECTED for ${selectedSource}`)
  }

  const layersByPass = parseLayersByRank(lines, selectedSource, selectedTrialIndex)
  const passes = passRows
    .filter(
      row => row.source === selectedSource && row.trialIndex === selectedTrialIndex,
    )
    .sort((left, right) => left.passIndex - right.passIndex)
    .map(
      row =>
        ({
          passIndex: row.passIndex,
          direction: row.direction,
          changed: row.changed,
          layeredCrossings: row.layeredCrossings,
          globalCrossings: row.globalCrossings,
          layers: normalizeLayers(layersByPass.get(row.passIndex) ?? new Map()),
        }) as PassRow,
    )

  if (passes.length === 0) {
    fail(
      `${fixture}: no ORDER_TRIAL_PASS rows for source=${selectedSource} trial=${selectedTrialIndex}`,
    )
  }

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)

  return {
    fixture,
    inputNodeIds,
    inputEdges,
    selectedSource,
    selectedTrialIndex,
    passes,
  }
}

function comparePassParity(left: PassParity, right: PassParity): number {
  if (left.parity.compositionMismatchLayers !== right.parity.compositionMismatchLayers) {
    return left.parity.compositionMismatchLayers - right.parity.compositionMismatchLayers
  }
  if (left.parity.orderMismatchLayers !== right.parity.orderMismatchLayers) {
    return left.parity.orderMismatchLayers - right.parity.orderMismatchLayers
  }
  if (left.parity.avgOrderDisplacement !== right.parity.avgOrderDisplacement) {
    return left.parity.avgOrderDisplacement - right.parity.avgOrderDisplacement
  }
  if (left.parity.exactOrderMatchRate !== right.parity.exactOrderMatchRate) {
    return right.parity.exactOrderMatchRate - left.parity.exactOrderMatchRate
  }
  return left.pass.passIndex - right.pass.passIndex
}

function compareFixture(fixture: string, options: CliOptions): FixtureReport {
  const source = readFileSync(fixture, 'utf8')
  const trace = parseSelectedTrialTrace(fixture, source, options)
  const direction = parseGraphDirection(source)
  const upstreamLayers = runUpstreamPostBarycenter(
    trace.inputNodeIds,
    trace.inputEdges,
    direction,
  )
  const passParity: PassParity[] = trace.passes.map(pass => ({
    pass,
    parity: layerParity(pass.layers, upstreamLayers),
  }))
  const lastPass = passParity[passParity.length - 1]!
  const bestPass = [...passParity].sort(comparePassParity)[0]!
  return {
    fixture,
    selectedSource: trace.selectedSource,
    selectedTrialIndex: trace.selectedTrialIndex,
    passCount: trace.passes.length,
    lastPassParity: lastPass.parity,
    bestPassParity: bestPass.parity,
    bestPassIndex: bestPass.pass.passIndex,
    gainOrderMismatch:
      lastPass.parity.orderMismatchLayers - bestPass.parity.orderMismatchLayers,
  }
}

function discoverStressFixtures(): string[] {
  const files = readdirSync('fixtures')
    .filter(name => name.startsWith('layout_stress_') && name.endsWith('.mmd'))
    .map(name => `fixtures/${name}`)
    .sort()
  return files.length > 0 ? files : STRESS_FIXTURES
}

function formatRate(value: number): string {
  return value.toFixed(4)
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const fixtures =
    options.fixtures.length > 0 ? options.fixtures : discoverStressFixtures()
  const reports: FixtureReport[] = fixtures.map(fixture =>
    compareFixture(fixture, options),
  )

  let totalLastCompositionMismatch = 0
  let totalLastOrderMismatch = 0
  let totalBestCompositionMismatch = 0
  let totalBestOrderMismatch = 0
  let totalGainOrderMismatch = 0
  let improvedByBestPass = 0

  for (const report of reports) {
    totalLastCompositionMismatch += report.lastPassParity.compositionMismatchLayers
    totalLastOrderMismatch += report.lastPassParity.orderMismatchLayers
    totalBestCompositionMismatch += report.bestPassParity.compositionMismatchLayers
    totalBestOrderMismatch += report.bestPassParity.orderMismatchLayers
    totalGainOrderMismatch += report.gainOrderMismatch
    if (report.gainOrderMismatch > 0) improvedByBestPass += 1
    console.log(
      [
        report.fixture,
        `selected=${report.selectedSource}#${report.selectedTrialIndex}`,
        `passes=${report.passCount}`,
        `best_pass=${report.bestPassIndex}`,
        `last_comp=${report.lastPassParity.compositionMismatchLayers}`,
        `best_comp=${report.bestPassParity.compositionMismatchLayers}`,
        `last_order=${report.lastPassParity.orderMismatchLayers}`,
        `best_order=${report.bestPassParity.orderMismatchLayers}`,
        `gain_order=${report.gainOrderMismatch}`,
        `last_exact=${formatRate(report.lastPassParity.exactOrderMatchRate)}`,
        `best_exact=${formatRate(report.bestPassParity.exactOrderMatchRate)}`,
        `last_disp=${formatRate(report.lastPassParity.avgOrderDisplacement)}`,
        `best_disp=${formatRate(report.bestPassParity.avgOrderDisplacement)}`,
      ].join(' '),
    )
  }

  console.log('\n=== summary ===')
  console.log(`fixtures=${reports.length}`)
  console.log(`improved_by_best_pass=${improvedByBestPass}/${reports.length}`)
  console.log(
    `last_totals composition=${totalLastCompositionMismatch} order=${totalLastOrderMismatch}`,
  )
  console.log(
    `best_totals composition=${totalBestCompositionMismatch} order=${totalBestOrderMismatch}`,
  )
  console.log(`order_mismatch_gain_total=${totalGainOrderMismatch}`)
}

main()
