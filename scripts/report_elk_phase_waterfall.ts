/**
 * Report ELK parity phase waterfall on stress fixtures.
 *
 * This helps identify the first divergent phase versus upstream:
 * - cycle orientation
 * - sort-by-input-model layering
 * - sort-by-input-model port ordering
 * - placement-major parity
 * - end-to-end layout parity
 *
 * Usage:
 *   bun run scripts/report_elk_phase_waterfall.ts
 *   bun run scripts/report_elk_phase_waterfall.ts --json /tmp/elk_phase_waterfall.json
 */

import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type CliOptions = {
  jsonPath?: string
}

type PhaseWaterfallReport = {
  fixtures: string[]
  cycleOrientation: {
    mismatched: number
    comparable: number
  }
  sortByInputModel: {
    orderMismatched: number
    orderComparable: number
    compositionMismatched: number
    compositionComparable: number
  }
  sortByInputPorts: {
    mismatchedSlots: number
    comparableSlots: number
  }
  crossingRankOrder: {
    orderMismatched: number
    orderComparable: number
    compositionMismatched: number
    compositionComparable: number
    avgDisplacement: number
  }
  placementMajor: {
    totalLayerMismatch: number
    avgInversionRate: number
  }
  endToEnd: {
    avgWeightedGapIndex: number
    totalMajorRankCompositionMismatches: number
    avgLogicalCrossingMultiplier: number
    structuralOk: number
    fixtures: number
  }
  firstDivergentPhase:
    | 'none'
    | 'cycle-orientation'
    | 'sort-by-input-model'
    | 'sort-by-input-ports'
    | 'crossing-rank-order'
    | 'placement-major'
}

type StressSummary = {
  fixtures: number
  structuralOk: number
  avgWeightedGapIndex: number
  totalMajorRankCompositionMismatches: number
  avgLogicalCrossingMultiplier: number
}

type StressPayload = {
  summary: StressSummary
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
    maxBuffer: 32 * 1024 * 1024,
  })
  if (result.status !== 0) {
    const stderr = (result.stderr ?? '').toString().trim()
    const stdout = (result.stdout ?? '').toString().trim()
    const parts = [`command failed: ${cmd} ${args.join(' ')}`]
    if (stderr !== '') parts.push(`stderr:\n${stderr}`)
    if (stdout !== '') parts.push(`stdout:\n${stdout}`)
    fail(parts.join('\n'))
  }
  return (result.stdout ?? '').toString()
}

function parseCliOptions(args: string[]): CliOptions {
  let jsonPath: string | undefined
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
    fail(`unknown argument: ${arg}`)
  }
  return { jsonPath }
}

function parseCounter(line: string, pattern: RegExp, label: string): [number, number] {
  const match = pattern.exec(line)
  if (!match) fail(`invalid ${label} summary line: ${line}`)
  const left = Number.parseInt(match[1]!, 10)
  const right = Number.parseInt(match[2]!, 10)
  if (!Number.isFinite(left) || !Number.isFinite(right)) {
    fail(`invalid ${label} counters: ${line}`)
  }
  return [left, right]
}

function parseCycleOrientation(): { mismatched: number; comparable: number } {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_cycle_orientation.ts',
    ...STRESS_FIXTURES,
  ])
  const summaryLine = stdout
    .split('\n')
    .map(line => line.trim())
    .find(line => line.startsWith('total_mismatch='))
  if (!summaryLine) fail('missing cycle-orientation summary line')
  const [mismatched, comparable] = parseCounter(
    summaryLine,
    /^total_mismatch=(\d+)\/(\d+)$/,
    'cycle-orientation',
  )
  return { mismatched, comparable }
}

function parseSortByInputModel(): {
  orderMismatched: number
  orderComparable: number
  compositionMismatched: number
  compositionComparable: number
} {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_sort_by_input_model.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const orderLine = lines.find(line => line.startsWith('total_order_mismatch='))
  if (!orderLine) fail('missing sort-by-input-model order summary line')
  const [orderMismatched, orderComparable] = parseCounter(
    orderLine,
    /^total_order_mismatch=(\d+)\/(\d+)$/,
    'sort-by-input-model order',
  )
  const compositionLine = lines.find(line =>
    line.startsWith('total_composition_mismatch='),
  )
  if (!compositionLine) fail('missing sort-by-input-model composition summary line')
  const [compositionMismatched, compositionComparable] = parseCounter(
    compositionLine,
    /^total_composition_mismatch=(\d+)\/(\d+)$/,
    'sort-by-input-model composition',
  )
  return {
    orderMismatched,
    orderComparable,
    compositionMismatched,
    compositionComparable,
  }
}

function parseSortByInputPorts(): { mismatchedSlots: number; comparableSlots: number } {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_sort_by_input_ports.ts',
    ...STRESS_FIXTURES,
  ])
  const summaryLine = stdout
    .split('\n')
    .map(line => line.trim())
    .find(line => line.startsWith('total_port_order_mismatch_slots='))
  if (!summaryLine) fail('missing sort-by-input-ports summary line')
  const [mismatchedSlots, comparableSlots] = parseCounter(
    summaryLine,
    /^total_port_order_mismatch_slots=(\d+)\/(\d+)$/,
    'sort-by-input-ports',
  )
  return { mismatchedSlots, comparableSlots }
}

function parseCrossingRankOrder(): {
  orderMismatched: number
  orderComparable: number
  compositionMismatched: number
  compositionComparable: number
  avgDisplacement: number
} {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_crossing_rank_order.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const orderLine = lines.find(line => line.startsWith('total_order_mismatch='))
  if (!orderLine) fail('missing crossing-rank order summary line')
  const [orderMismatched, orderComparable] = parseCounter(
    orderLine,
    /^total_order_mismatch=(\d+)\/(\d+)$/,
    'crossing-rank order',
  )
  const compositionLine = lines.find(line =>
    line.startsWith('total_composition_mismatch='),
  )
  if (!compositionLine) fail('missing crossing-rank composition summary line')
  const [compositionMismatched, compositionComparable] = parseCounter(
    compositionLine,
    /^total_composition_mismatch=(\d+)\/(\d+)$/,
    'crossing-rank composition',
  )
  const displacementLine = lines.find(line => line.startsWith('avg_displacement='))
  if (!displacementLine) fail('missing crossing-rank avg displacement summary line')
  const displacementMatch = /^avg_displacement=([0-9.]+)$/.exec(displacementLine)
  if (!displacementMatch) {
    fail(`invalid crossing-rank avg displacement summary: ${displacementLine}`)
  }
  const avgDisplacement = Number.parseFloat(displacementMatch[1]!)
  if (!Number.isFinite(avgDisplacement)) {
    fail(`invalid crossing-rank avg displacement value: ${displacementLine}`)
  }
  return {
    orderMismatched,
    orderComparable,
    compositionMismatched,
    compositionComparable,
    avgDisplacement,
  }
}

function parsePlacementMajor(): { totalLayerMismatch: number; avgInversionRate: number } {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_placement_major.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const mismatchLine = lines.find(line => line.startsWith('total_layer_mismatch='))
  if (!mismatchLine) fail('missing placement-major mismatch summary line')
  const mismatchMatch = /^total_layer_mismatch=(\d+)$/.exec(mismatchLine)
  if (!mismatchMatch) fail(`invalid placement-major mismatch summary: ${mismatchLine}`)
  const totalLayerMismatch = Number.parseInt(mismatchMatch[1]!, 10)
  if (!Number.isFinite(totalLayerMismatch)) {
    fail(`invalid placement-major mismatch counter: ${mismatchLine}`)
  }
  const inversionLine = lines.find(line => line.startsWith('avg_inversion_rate='))
  if (!inversionLine) fail('missing placement-major inversion summary line')
  const inversionMatch = /^avg_inversion_rate=([0-9.]+)$/.exec(inversionLine)
  if (!inversionMatch) fail(`invalid placement-major inversion summary: ${inversionLine}`)
  const avgInversionRate = Number.parseFloat(inversionMatch[1]!)
  if (!Number.isFinite(avgInversionRate)) {
    fail(`invalid placement-major inversion value: ${inversionLine}`)
  }
  return { totalLayerMismatch, avgInversionRate }
}

function parseEndToEnd(): {
  avgWeightedGapIndex: number
  totalMajorRankCompositionMismatches: number
  avgLogicalCrossingMultiplier: number
  structuralOk: number
  fixtures: number
} {
  const tempRoot = mkdtempSync(join(tmpdir(), 'elk-phase-waterfall-'))
  const jsonPath = join(tempRoot, 'elk.json')
  runOrThrow('bun', [
    'run',
    'scripts/compare_layout_stress.ts',
    '--local-layout-engine',
    'elk',
    '--official-flowchart-renderer',
    'elk',
    '--include-rank-layers',
    '--json',
    jsonPath,
  ])
  const payload = JSON.parse(readFileSync(jsonPath, 'utf8')) as StressPayload
  const summary = payload.summary
  if (!summary) fail('missing end-to-end summary')
  return {
    avgWeightedGapIndex: summary.avgWeightedGapIndex,
    totalMajorRankCompositionMismatches: summary.totalMajorRankCompositionMismatches,
    avgLogicalCrossingMultiplier: summary.avgLogicalCrossingMultiplier,
    structuralOk: summary.structuralOk,
    fixtures: summary.fixtures,
  }
}

function firstDivergentPhase(report: Omit<PhaseWaterfallReport, 'firstDivergentPhase'>):
  | 'none'
  | 'cycle-orientation'
  | 'sort-by-input-model'
  | 'sort-by-input-ports'
  | 'crossing-rank-order'
  | 'placement-major' {
  if (report.cycleOrientation.mismatched > 0) return 'cycle-orientation'
  if (
    report.sortByInputModel.orderMismatched > 0 ||
    report.sortByInputModel.compositionMismatched > 0
  ) {
    return 'sort-by-input-model'
  }
  if (report.sortByInputPorts.mismatchedSlots > 0) return 'sort-by-input-ports'
  if (
    report.crossingRankOrder.orderMismatched > 0 ||
    report.crossingRankOrder.compositionMismatched > 0 ||
    report.crossingRankOrder.avgDisplacement > 0
  ) {
    return 'crossing-rank-order'
  }
  if (
    report.placementMajor.totalLayerMismatch > 0 ||
    report.placementMajor.avgInversionRate > 0
  ) {
    return 'placement-major'
  }
  return 'none'
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))

  const cycleOrientation = parseCycleOrientation()
  const sortByInputModel = parseSortByInputModel()
  const sortByInputPorts = parseSortByInputPorts()
  const crossingRankOrder = parseCrossingRankOrder()
  const placementMajor = parsePlacementMajor()
  const endToEnd = parseEndToEnd()

  const reportBase = {
    fixtures: STRESS_FIXTURES,
    cycleOrientation,
    sortByInputModel,
    sortByInputPorts,
    crossingRankOrder,
    placementMajor,
    endToEnd,
  }
  const report: PhaseWaterfallReport = {
    ...reportBase,
    firstDivergentPhase: firstDivergentPhase(reportBase),
  }

  console.log('=== elk phase waterfall ===')
  console.log(
    `cycle_orientation_mismatch=${report.cycleOrientation.mismatched}/${report.cycleOrientation.comparable}`,
  )
  console.log(
    `sort_by_input_model_order_mismatch=${report.sortByInputModel.orderMismatched}/${report.sortByInputModel.orderComparable}`,
  )
  console.log(
    `sort_by_input_model_composition_mismatch=${report.sortByInputModel.compositionMismatched}/${report.sortByInputModel.compositionComparable}`,
  )
  console.log(
    `sort_by_input_ports_mismatch_slots=${report.sortByInputPorts.mismatchedSlots}/${report.sortByInputPorts.comparableSlots}`,
  )
  console.log(
    `crossing_rank_order_mismatch=${report.crossingRankOrder.orderMismatched}/${report.crossingRankOrder.orderComparable}`,
  )
  console.log(
    `crossing_rank_composition_mismatch=${report.crossingRankOrder.compositionMismatched}/${report.crossingRankOrder.compositionComparable}`,
  )
  console.log(
    `crossing_rank_avg_displacement=${report.crossingRankOrder.avgDisplacement.toFixed(4)}`,
  )
  console.log(
    `placement_major_layer_mismatch=${report.placementMajor.totalLayerMismatch}`,
  )
  console.log(
    `placement_major_avg_inversion_rate=${report.placementMajor.avgInversionRate.toFixed(4)}`,
  )
  console.log(
    `end_to_end_avg_weighted_gap=${report.endToEnd.avgWeightedGapIndex.toFixed(4)}`,
  )
  console.log(
    `end_to_end_total_rank_composition_mismatch=${report.endToEnd.totalMajorRankCompositionMismatches}`,
  )
  console.log(
    `end_to_end_avg_logical_crossing_multiplier=${report.endToEnd.avgLogicalCrossingMultiplier.toFixed(4)}`,
  )
  console.log(
    `end_to_end_structural_ok=${report.endToEnd.structuralOk}/${report.endToEnd.fixtures}`,
  )
  console.log(`first_divergent_phase=${report.firstDivergentPhase}`)

  if (options.jsonPath) {
    writeFileSync(
      options.jsonPath,
      JSON.stringify(
        {
          generatedAt: new Date().toISOString(),
          report,
        },
        null,
        2,
      ),
    )
    console.log(`json_report=${options.jsonPath}`)
  }
}

main()
