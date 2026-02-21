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
    avgExactOrderMatchRate: number
    avgOrderDisplacement: number
  }
  crossingPhaseTrace: {
    postSweepOrderMismatched: number
    postSweepOrderComparable: number
    finalOrderMismatched: number
    finalOrderComparable: number
    postSweepCompositionMismatched: number
    postSweepCompositionComparable: number
    finalCompositionMismatched: number
    finalCompositionComparable: number
    postSweepAvgExactOrderMatchRate: number
    finalAvgExactOrderMatchRate: number
    postSweepAvgOrderDisplacement: number
    finalAvgOrderDisplacement: number
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
  avgExactOrderMatchRate: number
  avgOrderDisplacement: number
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
  const exactOrderMatchLine = lines.find(line =>
    line.startsWith('avg_exact_order_match_rate='),
  )
  if (!exactOrderMatchLine) {
    fail('missing crossing-rank avg exact-order-match-rate summary line')
  }
  const exactOrderMatch = /^avg_exact_order_match_rate=([0-9.]+)$/.exec(
    exactOrderMatchLine,
  )
  if (!exactOrderMatch) {
    fail(
      `invalid crossing-rank avg exact-order-match-rate summary: ${exactOrderMatchLine}`,
    )
  }
  const avgExactOrderMatchRate = Number.parseFloat(exactOrderMatch[1]!)
  if (!Number.isFinite(avgExactOrderMatchRate)) {
    fail(
      `invalid crossing-rank avg exact-order-match-rate value: ${exactOrderMatchLine}`,
    )
  }
  const orderDisplacementLine = lines.find(line =>
    line.startsWith('avg_order_displacement='),
  )
  if (!orderDisplacementLine) {
    fail('missing crossing-rank avg order displacement summary line')
  }
  const orderDisplacementMatch = /^avg_order_displacement=([0-9.]+)$/.exec(
    orderDisplacementLine,
  )
  if (!orderDisplacementMatch) {
    fail(
      `invalid crossing-rank avg order displacement summary: ${orderDisplacementLine}`,
    )
  }
  const avgOrderDisplacement = Number.parseFloat(orderDisplacementMatch[1]!)
  if (!Number.isFinite(avgOrderDisplacement)) {
    fail(
      `invalid crossing-rank avg order displacement value: ${orderDisplacementLine}`,
    )
  }
  return {
    orderMismatched,
    orderComparable,
    compositionMismatched,
    compositionComparable,
    avgDisplacement,
    avgExactOrderMatchRate,
    avgOrderDisplacement,
  }
}

function parseCrossingPhaseTrace(): {
  postSweepOrderMismatched: number
  postSweepOrderComparable: number
  finalOrderMismatched: number
  finalOrderComparable: number
  postSweepCompositionMismatched: number
  postSweepCompositionComparable: number
  finalCompositionMismatched: number
  finalCompositionComparable: number
  postSweepAvgExactOrderMatchRate: number
  finalAvgExactOrderMatchRate: number
  postSweepAvgOrderDisplacement: number
  finalAvgOrderDisplacement: number
} {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_crossing_phase_trace.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const postSweepOrderLine = lines.find(line =>
    line.startsWith('post_sweep_total_order_mismatch='),
  )
  if (!postSweepOrderLine) {
    fail('missing crossing phase trace post-sweep order summary line')
  }
  const [postSweepOrderMismatched, postSweepOrderComparable] = parseCounter(
    postSweepOrderLine,
    /^post_sweep_total_order_mismatch=(\d+)\/(\d+)$/,
    'crossing phase trace post-sweep order',
  )
  const finalOrderLine = lines.find(line =>
    line.startsWith('final_total_order_mismatch='),
  )
  if (!finalOrderLine) fail('missing crossing phase trace final order summary line')
  const [finalOrderMismatched, finalOrderComparable] = parseCounter(
    finalOrderLine,
    /^final_total_order_mismatch=(\d+)\/(\d+)$/,
    'crossing phase trace final order',
  )
  const postSweepCompositionLine = lines.find(line =>
    line.startsWith('post_sweep_total_composition_mismatch='),
  )
  if (!postSweepCompositionLine) {
    fail('missing crossing phase trace post-sweep composition summary line')
  }
  const [postSweepCompositionMismatched, postSweepCompositionComparable] = parseCounter(
    postSweepCompositionLine,
    /^post_sweep_total_composition_mismatch=(\d+)\/(\d+)$/,
    'crossing phase trace post-sweep composition',
  )
  const finalCompositionLine = lines.find(line =>
    line.startsWith('final_total_composition_mismatch='),
  )
  if (!finalCompositionLine) {
    fail('missing crossing phase trace final composition summary line')
  }
  const [finalCompositionMismatched, finalCompositionComparable] = parseCounter(
    finalCompositionLine,
    /^final_total_composition_mismatch=(\d+)\/(\d+)$/,
    'crossing phase trace final composition',
  )
  const postSweepExactOrderLine = lines.find(line =>
    line.startsWith('post_sweep_avg_exact_order_match_rate='),
  )
  if (!postSweepExactOrderLine) {
    fail('missing crossing phase trace post-sweep exact-order rate summary line')
  }
  const postSweepExactOrderMatch = /^post_sweep_avg_exact_order_match_rate=([0-9.]+)$/.exec(
    postSweepExactOrderLine,
  )
  if (!postSweepExactOrderMatch) {
    fail(
      `invalid crossing phase trace post-sweep exact-order rate summary: ${postSweepExactOrderLine}`,
    )
  }
  const postSweepAvgExactOrderMatchRate = Number.parseFloat(
    postSweepExactOrderMatch[1]!,
  )
  if (!Number.isFinite(postSweepAvgExactOrderMatchRate)) {
    fail(
      `invalid crossing phase trace post-sweep exact-order rate value: ${postSweepExactOrderLine}`,
    )
  }
  const finalExactOrderLine = lines.find(line =>
    line.startsWith('final_avg_exact_order_match_rate='),
  )
  if (!finalExactOrderLine) {
    fail('missing crossing phase trace final exact-order rate summary line')
  }
  const finalExactOrderMatch = /^final_avg_exact_order_match_rate=([0-9.]+)$/.exec(
    finalExactOrderLine,
  )
  if (!finalExactOrderMatch) {
    fail(
      `invalid crossing phase trace final exact-order rate summary: ${finalExactOrderLine}`,
    )
  }
  const finalAvgExactOrderMatchRate = Number.parseFloat(finalExactOrderMatch[1]!)
  if (!Number.isFinite(finalAvgExactOrderMatchRate)) {
    fail(
      `invalid crossing phase trace final exact-order rate value: ${finalExactOrderLine}`,
    )
  }
  const postSweepOrderDisplacementLine = lines.find(line =>
    line.startsWith('post_sweep_avg_order_displacement='),
  )
  if (!postSweepOrderDisplacementLine) {
    fail('missing crossing phase trace post-sweep order displacement summary line')
  }
  const postSweepOrderDisplacementMatch = /^post_sweep_avg_order_displacement=([0-9.]+)$/.exec(
    postSweepOrderDisplacementLine,
  )
  if (!postSweepOrderDisplacementMatch) {
    fail(
      `invalid crossing phase trace post-sweep order displacement summary: ${postSweepOrderDisplacementLine}`,
    )
  }
  const postSweepAvgOrderDisplacement = Number.parseFloat(
    postSweepOrderDisplacementMatch[1]!,
  )
  if (!Number.isFinite(postSweepAvgOrderDisplacement)) {
    fail(
      `invalid crossing phase trace post-sweep order displacement value: ${postSweepOrderDisplacementLine}`,
    )
  }
  const finalOrderDisplacementLine = lines.find(line =>
    line.startsWith('final_avg_order_displacement='),
  )
  if (!finalOrderDisplacementLine) {
    fail('missing crossing phase trace final order displacement summary line')
  }
  const finalOrderDisplacementMatch = /^final_avg_order_displacement=([0-9.]+)$/.exec(
    finalOrderDisplacementLine,
  )
  if (!finalOrderDisplacementMatch) {
    fail(
      `invalid crossing phase trace final order displacement summary: ${finalOrderDisplacementLine}`,
    )
  }
  const finalAvgOrderDisplacement = Number.parseFloat(finalOrderDisplacementMatch[1]!)
  if (!Number.isFinite(finalAvgOrderDisplacement)) {
    fail(
      `invalid crossing phase trace final order displacement value: ${finalOrderDisplacementLine}`,
    )
  }
  return {
    postSweepOrderMismatched,
    postSweepOrderComparable,
    finalOrderMismatched,
    finalOrderComparable,
    postSweepCompositionMismatched,
    postSweepCompositionComparable,
    finalCompositionMismatched,
    finalCompositionComparable,
    postSweepAvgExactOrderMatchRate,
    finalAvgExactOrderMatchRate,
    postSweepAvgOrderDisplacement,
    finalAvgOrderDisplacement,
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
  const crossingPhaseTrace = parseCrossingPhaseTrace()
  const placementMajor = parsePlacementMajor()
  const endToEnd = parseEndToEnd()

  const reportBase = {
    fixtures: STRESS_FIXTURES,
    cycleOrientation,
    sortByInputModel,
    sortByInputPorts,
    crossingRankOrder,
    crossingPhaseTrace,
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
    `crossing_rank_avg_exact_order_match_rate=${report.crossingRankOrder.avgExactOrderMatchRate.toFixed(4)}`,
  )
  console.log(
    `crossing_rank_avg_order_displacement=${report.crossingRankOrder.avgOrderDisplacement.toFixed(4)}`,
  )
  console.log(
    `crossing_phase_post_sweep_order_mismatch=${report.crossingPhaseTrace.postSweepOrderMismatched}/${report.crossingPhaseTrace.postSweepOrderComparable}`,
  )
  console.log(
    `crossing_phase_final_order_mismatch=${report.crossingPhaseTrace.finalOrderMismatched}/${report.crossingPhaseTrace.finalOrderComparable}`,
  )
  console.log(
    `crossing_phase_post_sweep_composition_mismatch=${report.crossingPhaseTrace.postSweepCompositionMismatched}/${report.crossingPhaseTrace.postSweepCompositionComparable}`,
  )
  console.log(
    `crossing_phase_final_composition_mismatch=${report.crossingPhaseTrace.finalCompositionMismatched}/${report.crossingPhaseTrace.finalCompositionComparable}`,
  )
  console.log(
    `crossing_phase_post_sweep_avg_exact_order_match_rate=${report.crossingPhaseTrace.postSweepAvgExactOrderMatchRate.toFixed(4)}`,
  )
  console.log(
    `crossing_phase_final_avg_exact_order_match_rate=${report.crossingPhaseTrace.finalAvgExactOrderMatchRate.toFixed(4)}`,
  )
  console.log(
    `crossing_phase_post_sweep_avg_order_displacement=${report.crossingPhaseTrace.postSweepAvgOrderDisplacement.toFixed(4)}`,
  )
  console.log(
    `crossing_phase_final_avg_order_displacement=${report.crossingPhaseTrace.finalAvgOrderDisplacement.toFixed(4)}`,
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
