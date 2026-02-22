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
 *   bun run scripts/report_elk_phase_waterfall.ts --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --sweep-kernel neighbor-median --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --sweep-kernel edge-slot --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --sweep-kernel port-rank --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --trial-continuation-policy objective-improves --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --local-refinement-profile none --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --model-order-inversion-influence 0.25 --trial-count 5 --sweep-pass-count 6
 *   bun run scripts/report_elk_phase_waterfall.ts --upstream-layer-source layer-logs
 */

import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type CliOptions = {
  jsonPath?: string
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
  upstreamLayerSource?: 'final-coordinates' | 'layer-logs'
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
  let upstreamLayerSource: 'final-coordinates' | 'layer-logs' | undefined
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
    if (arg.startsWith('--sweep-pass-count=')) {
      const value = arg.slice('--sweep-pass-count='.length)
      const parsed = Number.parseInt(value, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail(`invalid --sweep-pass-count value: ${value}`)
      }
      sweepPassCount = parsed
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
  return {
    jsonPath,
    trialCount,
    sweepPassCount,
    sweepKernel,
    trialContinuationPolicy,
    localRefinementProfile,
    modelOrderInversionInfluence,
    upstreamLayerSource,
  }
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

function parseCrossingRankOrder(options: CliOptions): {
  orderMismatched: number
  orderComparable: number
  compositionMismatched: number
  compositionComparable: number
  avgDisplacement: number
  avgExactOrderMatchRate: number
  avgOrderDisplacement: number
} {
  const args = [
    'run',
    'scripts/compare_elk_crossing_rank_order.ts',
    ...STRESS_FIXTURES,
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
  if (options.upstreamLayerSource !== undefined) {
    args.push('--upstream-layer-source', options.upstreamLayerSource)
  }
  const stdout = runOrThrow('bun', args)
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

function parseCrossingPhaseTrace(options: CliOptions): {
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
  const args = [
    'run',
    'scripts/compare_elk_crossing_phase_trace.ts',
    ...STRESS_FIXTURES,
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
  const stdout = runOrThrow('bun', args)
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

function parseEndToEnd(options: CliOptions): {
  avgWeightedGapIndex: number
  totalMajorRankCompositionMismatches: number
  avgLogicalCrossingMultiplier: number
  structuralOk: number
  fixtures: number
} {
  const tempRoot = mkdtempSync(join(tmpdir(), 'elk-phase-waterfall-'))
  const jsonPath = join(tempRoot, 'elk.json')
  const args = [
    'run',
    'scripts/compare_layout_stress.ts',
    '--local-layout-engine',
    'elk',
    '--official-flowchart-renderer',
    'elk',
    '--include-rank-layers',
    '--json',
    jsonPath,
  ]
  if (options.trialCount !== undefined) {
    args.push('--elk-trial-count', String(options.trialCount))
  }
  if (options.sweepPassCount !== undefined) {
    args.push('--elk-sweep-pass-count', String(options.sweepPassCount))
  }
  if (options.sweepKernel !== undefined) {
    args.push('--elk-sweep-kernel', options.sweepKernel)
  }
  if (options.trialContinuationPolicy !== undefined) {
    args.push(
      '--elk-trial-continuation-policy',
      options.trialContinuationPolicy,
    )
  }
  if (options.localRefinementProfile !== undefined) {
    args.push(
      '--elk-local-refinement-profile',
      options.localRefinementProfile,
    )
  }
  if (options.modelOrderInversionInfluence !== undefined) {
    args.push(
      '--elk-model-order-inversion-influence',
      String(options.modelOrderInversionInfluence),
    )
  }
  runOrThrow('bun', args)
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
  const crossingRankOrder = parseCrossingRankOrder(options)
  const crossingPhaseTrace = parseCrossingPhaseTrace(options)
  const placementMajor = parsePlacementMajor()
  const endToEnd = parseEndToEnd(options)

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
    `crossing_rank_upstream_layer_source=${options.upstreamLayerSource ?? 'final-coordinates'}`,
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
