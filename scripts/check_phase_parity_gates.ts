/**
 * Phase-level parity gates for dagre order traces and elk layered pipeline traces.
 *
 * Usage:
 *   bun run scripts/check_phase_parity_gates.ts
 */

import { spawnSync } from 'node:child_process'

type ElkCaseMetrics = {
  seedStrategy: string
  upstreamLayers: string[][]
  upstreamLayersForceModelOrder: string[][]
  localRankLayers: string[][]
  compositionMismatch: number
  forceModelOrderCompositionMismatch: number
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
    maxBuffer: 16 * 1024 * 1024,
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

function parseJsonArray(raw: string, key: string): string[][] {
  try {
    return JSON.parse(raw) as string[][]
  } catch (error) {
    fail(`invalid ${key} payload: ${raw} (${String(error)})`)
  }
}

function checkDagreTraceGate(): void {
  const stdout = runOrThrow('bun', ['run', 'scripts/compare_dagre_order_trace.ts'])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const expected = ['PASS case1', 'PASS case2', 'PASS case3']
  if (lines.length !== expected.length) {
    fail(`dagre trace gate expected ${expected.length} lines, got ${lines.length}`)
  }
  for (let i = 0; i < expected.length; i += 1) {
    if (lines[i] !== expected[i]) {
      fail(`dagre trace gate mismatch at line ${i}: expected '${expected[i]}', got '${lines[i]}'`)
    }
  }
}

function checkElkRankLayerGate(): void {
  const stdout = runOrThrow('bun', ['run', 'scripts/compare_elk_rank_layers.ts'])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')

  const byCase = new Map<string, ElkCaseMetrics>()
  let currentCase: string | null = null

  for (const line of lines) {
    const caseHeaderMatch = /^===\s+([a-zA-Z0-9_]+)\s+===$/.exec(line)
    if (caseHeaderMatch) {
      currentCase = caseHeaderMatch[1]!
      byCase.set(currentCase, {
        seedStrategy: '',
        upstreamLayers: [],
        upstreamLayersForceModelOrder: [],
        localRankLayers: [],
        compositionMismatch: Number.NaN,
        forceModelOrderCompositionMismatch: Number.NaN,
      })
      continue
    }
    if (!currentCase) continue
    const metrics = byCase.get(currentCase)!

    if (line.startsWith('seed_strategy=')) {
      metrics.seedStrategy = line.slice('seed_strategy='.length)
      continue
    }
    if (line.startsWith('upstream_layers=')) {
      metrics.upstreamLayers = parseJsonArray(
        line.slice('upstream_layers='.length),
        `upstream_layers(${currentCase})`,
      )
      continue
    }
    if (line.startsWith('upstream_layers_force_model_order=')) {
      metrics.upstreamLayersForceModelOrder = parseJsonArray(
        line.slice('upstream_layers_force_model_order='.length),
        `upstream_layers_force_model_order(${currentCase})`,
      )
      continue
    }
    if (line.startsWith('local_rank_layers=')) {
      metrics.localRankLayers = parseJsonArray(
        line.slice('local_rank_layers='.length),
        `local_rank_layers(${currentCase})`,
      )
      continue
    }

    let match =
      /^shared=\d+\s+exact=\d+\s+displacement_sum=\d+\s+composition_mismatch=(\d+)$/.exec(
        line,
      )
    if (match) {
      metrics.compositionMismatch = Number.parseInt(match[1]!, 10)
      continue
    }
    match =
      /^force_model_order_shared=\d+\s+force_model_order_exact=\d+\s+force_model_order_displacement_sum=\d+\s+force_model_order_composition_mismatch=(\d+)$/.exec(
        line,
      )
    if (match) {
      metrics.forceModelOrderCompositionMismatch = Number.parseInt(match[1]!, 10)
      continue
    }
  }

  const expectedCases = ['fanout', 'feedback_mesh', 'long_span']
  for (const caseName of expectedCases) {
    if (!byCase.has(caseName)) {
      fail(`elk rank layer gate missing case '${caseName}'`)
    }
  }

  const expectedMismatchByCase: Record<string, number> = {
    fanout: 1,
    feedback_mesh: 1,
    long_span: 1,
  }
  const expectedForceMismatchByCase: Record<string, number> = {
    fanout: 1,
    feedback_mesh: 1,
    long_span: 0,
  }

  for (const caseName of expectedCases) {
    const metrics = byCase.get(caseName)!
    if (metrics.seedStrategy !== 'native-feedback') {
      fail(
        `elk rank layer gate case=${caseName} seed_strategy expected native-feedback, got ${metrics.seedStrategy}`,
      )
    }
    if (metrics.compositionMismatch !== expectedMismatchByCase[caseName]) {
      fail(
        `elk rank layer gate case=${caseName} composition_mismatch expected ${expectedMismatchByCase[caseName]}, got ${metrics.compositionMismatch}`,
      )
    }
    if (
      metrics.forceModelOrderCompositionMismatch !==
      expectedForceMismatchByCase[caseName]
    ) {
      fail(
        `elk rank layer gate case=${caseName} force_model_order_composition_mismatch expected ${expectedForceMismatchByCase[caseName]}, got ${metrics.forceModelOrderCompositionMismatch}`,
      )
    }
  }

  // Keep this gate focused on composition parity budgets. Exact in-layer order
  // parity is guarded by the dedicated crossing rank-order and crossing phase
  // gates below.
}

function checkElkCycleOrientationGate(): void {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_cycle_orientation.ts',
    ...STRESS_FIXTURES,
  ])
  const totalMismatchLine = stdout
    .split('\n')
    .map(line => line.trim())
    .find(line => line.startsWith('total_mismatch='))
  if (!totalMismatchLine) {
    fail('elk cycle-orientation gate missing total_mismatch summary line')
  }
  const match = /^total_mismatch=(\d+)\/(\d+)$/.exec(totalMismatchLine)
  if (!match) {
    fail(
      `elk cycle-orientation gate invalid summary format: ${totalMismatchLine}`,
    )
  }
  const mismatched = Number.parseInt(match[1]!, 10)
  const comparable = Number.parseInt(match[2]!, 10)
  if (!Number.isFinite(mismatched) || !Number.isFinite(comparable)) {
    fail(
      `elk cycle-orientation gate invalid mismatch counters: ${totalMismatchLine}`,
    )
  }
  if (mismatched !== 0) {
    fail(
      `elk cycle-orientation gate expected 0 mismatches, got ${mismatched}/${comparable}`,
    )
  }
}

function checkElkSortByInputModelGate(): void {
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
  if (!orderLine) {
    fail('elk sort-by-input-model gate missing total_order_mismatch summary line')
  }
  const orderMatch = /^total_order_mismatch=(\d+)\/(\d+)$/.exec(orderLine)
  if (!orderMatch) {
    fail(
      `elk sort-by-input-model gate invalid order summary format: ${orderLine}`,
    )
  }
  const orderMismatched = Number.parseInt(orderMatch[1]!, 10)
  const orderComparable = Number.parseInt(orderMatch[2]!, 10)
  if (!Number.isFinite(orderMismatched) || !Number.isFinite(orderComparable)) {
    fail(
      `elk sort-by-input-model gate invalid order mismatch counters: ${orderLine}`,
    )
  }
  if (orderComparable <= 0) {
    fail(
      `elk sort-by-input-model gate invalid order denominator: ${orderLine}`,
    )
  }

  const compositionLine = lines.find(line =>
    line.startsWith('total_composition_mismatch='),
  )
  if (!compositionLine) {
    fail(
      'elk sort-by-input-model gate missing total_composition_mismatch summary line',
    )
  }
  const compositionMatch =
    /^total_composition_mismatch=(\d+)\/(\d+)$/.exec(compositionLine)
  if (!compositionMatch) {
    fail(
      `elk sort-by-input-model gate invalid composition summary format: ${compositionLine}`,
    )
  }
  const compositionMismatched = Number.parseInt(compositionMatch[1]!, 10)
  const compositionComparable = Number.parseInt(compositionMatch[2]!, 10)
  if (
    !Number.isFinite(compositionMismatched) ||
    !Number.isFinite(compositionComparable)
  ) {
    fail(
      `elk sort-by-input-model gate invalid composition mismatch counters: ${compositionLine}`,
    )
  }
  if (compositionComparable <= 0) {
    fail(
      `elk sort-by-input-model gate invalid composition denominator: ${compositionLine}`,
    )
  }

  const maxAllowedOrderMismatch = 0
  const maxAllowedCompositionMismatch = 0
  if (orderMismatched > maxAllowedOrderMismatch) {
    fail(
      `elk sort-by-input-model gate expected order mismatches <= ${maxAllowedOrderMismatch}, got ${orderMismatched}/${orderComparable}`,
    )
  }
  if (compositionMismatched > maxAllowedCompositionMismatch) {
    fail(
      `elk sort-by-input-model gate expected composition mismatches <= ${maxAllowedCompositionMismatch}, got ${compositionMismatched}/${compositionComparable}`,
    )
  }
}

function checkElkSortByInputPortOrderGate(): void {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_sort_by_input_ports.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const summaryLine = lines.find(line =>
    line.startsWith('total_port_order_mismatch_slots='),
  )
  if (!summaryLine) {
    fail(
      'elk sort-by-input port-order gate missing total_port_order_mismatch_slots summary line',
    )
  }
  const summaryMatch =
    /^total_port_order_mismatch_slots=(\d+)\/(\d+)$/.exec(summaryLine)
  if (!summaryMatch) {
    fail(
      `elk sort-by-input port-order gate invalid summary format: ${summaryLine}`,
    )
  }
  const mismatched = Number.parseInt(summaryMatch[1]!, 10)
  const comparable = Number.parseInt(summaryMatch[2]!, 10)
  if (!Number.isFinite(mismatched) || !Number.isFinite(comparable)) {
    fail(
      `elk sort-by-input port-order gate invalid counters: ${summaryLine}`,
    )
  }
  if (comparable <= 0) {
    fail(
      `elk sort-by-input port-order gate invalid denominator: ${summaryLine}`,
    )
  }
  const maxAllowedMismatchSlots = 0
  if (mismatched > maxAllowedMismatchSlots) {
    fail(
      `elk sort-by-input port-order gate expected mismatches <= ${maxAllowedMismatchSlots}, got ${mismatched}/${comparable}`,
    )
  }
}

function checkElkPlacementMajorGate(): void {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_placement_major.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')

  const layerMismatchLine = lines.find(line =>
    line.startsWith('total_layer_mismatch='),
  )
  if (!layerMismatchLine) {
    fail(
      'elk placement-major gate missing total_layer_mismatch summary line',
    )
  }
  const mismatchMatch = /^total_layer_mismatch=(\d+)$/.exec(layerMismatchLine)
  if (!mismatchMatch) {
    fail(
      `elk placement-major gate invalid mismatch summary format: ${layerMismatchLine}`,
    )
  }
  const totalLayerMismatch = Number.parseInt(mismatchMatch[1]!, 10)
  if (!Number.isFinite(totalLayerMismatch)) {
    fail(
      `elk placement-major gate invalid mismatch counter: ${layerMismatchLine}`,
    )
  }

  const avgInversionLine = lines.find(line =>
    line.startsWith('avg_inversion_rate='),
  )
  if (!avgInversionLine) {
    fail(
      'elk placement-major gate missing avg_inversion_rate summary line',
    )
  }
  const inversionMatch = /^avg_inversion_rate=([0-9.]+)$/.exec(avgInversionLine)
  if (!inversionMatch) {
    fail(
      `elk placement-major gate invalid inversion summary format: ${avgInversionLine}`,
    )
  }
  const avgInversionRate = Number.parseFloat(inversionMatch[1]!)
  if (!Number.isFinite(avgInversionRate)) {
    fail(
      `elk placement-major gate invalid inversion value: ${avgInversionLine}`,
    )
  }

  // Major-axis parity requires exact rank-layer composition alignment.
  const maxAllowedLayerMismatch = 0
  const maxAllowedAvgInversionRate = 0.031
  if (totalLayerMismatch > maxAllowedLayerMismatch) {
    fail(
      `elk placement-major gate expected total_layer_mismatch <= ${maxAllowedLayerMismatch}, got ${totalLayerMismatch}`,
    )
  }
  if (avgInversionRate > maxAllowedAvgInversionRate) {
    fail(
      `elk placement-major gate expected avg_inversion_rate <= ${maxAllowedAvgInversionRate.toFixed(4)}, got ${avgInversionRate.toFixed(4)}`,
    )
  }
}

function checkElkCrossingRankOrderGate(): void {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/compare_elk_crossing_rank_order.ts',
    ...STRESS_FIXTURES,
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')

  const fixtureOrderMismatchByFixture = new Map<string, number>()
  let currentFixture: string | null = null
  for (const line of lines) {
    const fixtureHeaderMatch = /^===\s+(.+)\s+===$/.exec(line)
    if (fixtureHeaderMatch) {
      currentFixture = fixtureHeaderMatch[1]!
      continue
    }
    if (!currentFixture) continue
    const orderMatch =
      /^order_mismatch_layers=(\d+)\s+composition_mismatch_layers=(\d+)$/.exec(
        line,
      )
    if (!orderMatch) continue
    fixtureOrderMismatchByFixture.set(
      currentFixture,
      Number.parseInt(orderMatch[1]!, 10),
    )
  }

  const orderMismatchLine = lines.find(line =>
    line.startsWith('total_order_mismatch='),
  )
  if (!orderMismatchLine) {
    fail('elk crossing-rank gate missing total_order_mismatch summary line')
  }
  const orderMismatchMatch =
    /^total_order_mismatch=(\d+)\/(\d+)$/.exec(orderMismatchLine)
  if (!orderMismatchMatch) {
    fail(
      `elk crossing-rank gate invalid order summary format: ${orderMismatchLine}`,
    )
  }
  const orderMismatch = Number.parseInt(orderMismatchMatch[1]!, 10)
  const orderComparable = Number.parseInt(orderMismatchMatch[2]!, 10)
  if (!Number.isFinite(orderMismatch) || !Number.isFinite(orderComparable)) {
    fail(`elk crossing-rank gate invalid order counters: ${orderMismatchLine}`)
  }
  if (orderComparable <= 0) {
    fail(
      `elk crossing-rank gate invalid order denominator: ${orderMismatchLine}`,
    )
  }

  const compositionMismatchLine = lines.find(line =>
    line.startsWith('total_composition_mismatch='),
  )
  if (!compositionMismatchLine) {
    fail(
      'elk crossing-rank gate missing total_composition_mismatch summary line',
    )
  }
  const compositionMismatchMatch =
    /^total_composition_mismatch=(\d+)\/(\d+)$/.exec(compositionMismatchLine)
  if (!compositionMismatchMatch) {
    fail(
      `elk crossing-rank gate invalid composition summary format: ${compositionMismatchLine}`,
    )
  }
  const compositionMismatch = Number.parseInt(compositionMismatchMatch[1]!, 10)
  const compositionComparable = Number.parseInt(compositionMismatchMatch[2]!, 10)
  if (
    !Number.isFinite(compositionMismatch) ||
    !Number.isFinite(compositionComparable)
  ) {
    fail(
      `elk crossing-rank gate invalid composition counters: ${compositionMismatchLine}`,
    )
  }
  if (compositionComparable <= 0) {
    fail(
      `elk crossing-rank gate invalid composition denominator: ${compositionMismatchLine}`,
    )
  }

  const avgDisplacementLine = lines.find(line =>
    line.startsWith('avg_displacement='),
  )
  if (!avgDisplacementLine) {
    fail('elk crossing-rank gate missing avg_displacement summary line')
  }
  const avgDisplacementMatch = /^avg_displacement=([0-9.]+)$/.exec(
    avgDisplacementLine,
  )
  if (!avgDisplacementMatch) {
    fail(
      `elk crossing-rank gate invalid displacement summary format: ${avgDisplacementLine}`,
    )
  }
  const avgDisplacement = Number.parseFloat(avgDisplacementMatch[1]!)
  if (!Number.isFinite(avgDisplacement)) {
    fail(
      `elk crossing-rank gate invalid avg_displacement value: ${avgDisplacementLine}`,
    )
  }
  const avgExactOrderMatchRateLine = lines.find(line =>
    line.startsWith('avg_exact_order_match_rate='),
  )
  if (!avgExactOrderMatchRateLine) {
    fail(
      'elk crossing-rank gate missing avg_exact_order_match_rate summary line',
    )
  }
  const avgExactOrderMatchRateMatch = /^avg_exact_order_match_rate=([0-9.]+)$/.exec(
    avgExactOrderMatchRateLine,
  )
  if (!avgExactOrderMatchRateMatch) {
    fail(
      `elk crossing-rank gate invalid exact-order summary format: ${avgExactOrderMatchRateLine}`,
    )
  }
  const avgExactOrderMatchRate = Number.parseFloat(avgExactOrderMatchRateMatch[1]!)
  if (!Number.isFinite(avgExactOrderMatchRate)) {
    fail(
      `elk crossing-rank gate invalid avg_exact_order_match_rate value: ${avgExactOrderMatchRateLine}`,
    )
  }
  const avgOrderDisplacementLine = lines.find(line =>
    line.startsWith('avg_order_displacement='),
  )
  if (!avgOrderDisplacementLine) {
    fail('elk crossing-rank gate missing avg_order_displacement summary line')
  }
  const avgOrderDisplacementMatch = /^avg_order_displacement=([0-9.]+)$/.exec(
    avgOrderDisplacementLine,
  )
  if (!avgOrderDisplacementMatch) {
    fail(
      `elk crossing-rank gate invalid order-displacement summary format: ${avgOrderDisplacementLine}`,
    )
  }
  const avgOrderDisplacement = Number.parseFloat(avgOrderDisplacementMatch[1]!)
  if (!Number.isFinite(avgOrderDisplacement)) {
    fail(
      `elk crossing-rank gate invalid avg_order_displacement value: ${avgOrderDisplacementLine}`,
    )
  }

  const maxAllowedOrderMismatch = 34
  const maxAllowedCompositionMismatch = 0
  const maxAllowedAvgDisplacement = 0
  const minAllowedAvgExactOrderMatchRate = 0.703
  const maxAllowedAvgOrderDisplacement = 0.436
  const maxAllowedOrderMismatchByFixture: Record<string, number> = {
    'fixtures/layout_stress_001_dense_dag.mmd': 1,
    'fixtures/layout_stress_002_feedback_mesh.mmd': 0,
    'fixtures/layout_stress_003_subgraph_bridges.mmd': 3,
    'fixtures/layout_stress_004_fanin_fanout.mmd': 4,
    'fixtures/layout_stress_005_long_span_backjumps.mmd': 2,
    'fixtures/layout_stress_006_nested_bridge_loops.mmd': 4,
    'fixtures/layout_stress_007_dependency_weave.mmd': 5,
    'fixtures/layout_stress_008_hyper_weave_pipeline.mmd': 2,
    'fixtures/layout_stress_009_nested_ring_bridges.mmd': 4,
    'fixtures/layout_stress_010_bipartite_crossfire.mmd': 0,
    'fixtures/layout_stress_011_feedback_lattice.mmd': 1,
    'fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd': 7,
    'fixtures/layout_stress_013_rl_dual_scc_weave.mmd': 1,
  }
  if (orderMismatch > maxAllowedOrderMismatch) {
    fail(
      `elk crossing-rank gate expected order mismatches <= ${maxAllowedOrderMismatch}, got ${orderMismatch}/${orderComparable}`,
    )
  }
  if (compositionMismatch > maxAllowedCompositionMismatch) {
    fail(
      `elk crossing-rank gate expected composition mismatches <= ${maxAllowedCompositionMismatch}, got ${compositionMismatch}/${compositionComparable}`,
    )
  }
  if (avgDisplacement > maxAllowedAvgDisplacement) {
    fail(
      `elk crossing-rank gate expected avg_displacement <= ${maxAllowedAvgDisplacement.toFixed(4)}, got ${avgDisplacement.toFixed(4)}`,
    )
  }
  if (avgExactOrderMatchRate < minAllowedAvgExactOrderMatchRate) {
    fail(
      `elk crossing-rank gate expected avg_exact_order_match_rate >= ${minAllowedAvgExactOrderMatchRate.toFixed(4)}, got ${avgExactOrderMatchRate.toFixed(4)}`,
    )
  }
  if (avgOrderDisplacement > maxAllowedAvgOrderDisplacement) {
    fail(
      `elk crossing-rank gate expected avg_order_displacement <= ${maxAllowedAvgOrderDisplacement.toFixed(4)}, got ${avgOrderDisplacement.toFixed(4)}`,
    )
  }
  for (const fixture of STRESS_FIXTURES) {
    const expected = maxAllowedOrderMismatchByFixture[fixture]
    if (expected === undefined) {
      fail(`elk crossing-rank gate missing fixture threshold for ${fixture}`)
    }
    const actual = fixtureOrderMismatchByFixture.get(fixture)
    if (actual === undefined) {
      fail(`elk crossing-rank gate missing fixture report for ${fixture}`)
    }
    if (actual > expected) {
      fail(
        `elk crossing-rank gate fixture=${fixture} expected order_mismatch_layers <= ${expected}, got ${actual}`,
      )
    }
  }
}

function checkElkCrossingPhaseTraceGate(): void {
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
  const finalOrderLine = lines.find(line =>
    line.startsWith('final_total_order_mismatch='),
  )
  const postSweepCompositionLine = lines.find(line =>
    line.startsWith('post_sweep_total_composition_mismatch='),
  )
  const finalCompositionLine = lines.find(line =>
    line.startsWith('final_total_composition_mismatch='),
  )
  const finalExactOrderLine = lines.find(line =>
    line.startsWith('final_avg_exact_order_match_rate='),
  )
  const finalOrderDisplacementLine = lines.find(line =>
    line.startsWith('final_avg_order_displacement='),
  )
  if (
    !postSweepOrderLine ||
    !finalOrderLine ||
    !postSweepCompositionLine ||
    !finalCompositionLine ||
    !finalExactOrderLine ||
    !finalOrderDisplacementLine
  ) {
    fail('elk crossing-phase gate missing summary lines')
  }

  const postSweepOrderMatch =
    /^post_sweep_total_order_mismatch=(\d+)\/(\d+)$/.exec(postSweepOrderLine)
  const finalOrderMatch = /^final_total_order_mismatch=(\d+)\/(\d+)$/.exec(
    finalOrderLine,
  )
  const postSweepCompositionMatch =
    /^post_sweep_total_composition_mismatch=(\d+)\/(\d+)$/.exec(
      postSweepCompositionLine,
    )
  const finalCompositionMatch =
    /^final_total_composition_mismatch=(\d+)\/(\d+)$/.exec(
      finalCompositionLine,
    )
  const finalExactOrderMatch =
    /^final_avg_exact_order_match_rate=([0-9.]+)$/.exec(finalExactOrderLine)
  const finalOrderDisplacementMatch =
    /^final_avg_order_displacement=([0-9.]+)$/.exec(finalOrderDisplacementLine)
  if (
    !postSweepOrderMatch ||
    !finalOrderMatch ||
    !postSweepCompositionMatch ||
    !finalCompositionMatch ||
    !finalExactOrderMatch ||
    !finalOrderDisplacementMatch
  ) {
    fail('elk crossing-phase gate failed to parse summary lines')
  }

  const postSweepOrderMismatch = Number.parseInt(postSweepOrderMatch[1]!, 10)
  const finalOrderMismatch = Number.parseInt(finalOrderMatch[1]!, 10)
  const postSweepCompositionMismatch = Number.parseInt(
    postSweepCompositionMatch[1]!,
    10,
  )
  const finalCompositionMismatch = Number.parseInt(
    finalCompositionMatch[1]!,
    10,
  )
  const finalExactOrderMatchRate = Number.parseFloat(finalExactOrderMatch[1]!)
  const finalOrderDisplacement = Number.parseFloat(
    finalOrderDisplacementMatch[1]!,
  )
  if (
    !Number.isFinite(postSweepOrderMismatch) ||
    !Number.isFinite(finalOrderMismatch) ||
    !Number.isFinite(postSweepCompositionMismatch) ||
    !Number.isFinite(finalCompositionMismatch) ||
    !Number.isFinite(finalExactOrderMatchRate) ||
    !Number.isFinite(finalOrderDisplacement)
  ) {
    fail('elk crossing-phase gate parsed non-finite values')
  }

  const maxAllowedPostSweepOrderMismatch = 39
  const maxAllowedFinalOrderMismatch = 34
  const maxAllowedPostSweepCompositionMismatch = 0
  const maxAllowedFinalCompositionMismatch = 0
  const minAllowedFinalExactOrderMatchRate = 0.703
  const maxAllowedFinalOrderDisplacement = 0.436

  if (postSweepOrderMismatch > maxAllowedPostSweepOrderMismatch) {
    fail(
      `elk crossing-phase gate expected post_sweep_total_order_mismatch <= ${maxAllowedPostSweepOrderMismatch}, got ${postSweepOrderMismatch}`,
    )
  }
  if (finalOrderMismatch > maxAllowedFinalOrderMismatch) {
    fail(
      `elk crossing-phase gate expected final_total_order_mismatch <= ${maxAllowedFinalOrderMismatch}, got ${finalOrderMismatch}`,
    )
  }
  if (postSweepCompositionMismatch > maxAllowedPostSweepCompositionMismatch) {
    fail(
      `elk crossing-phase gate expected post_sweep_total_composition_mismatch <= ${maxAllowedPostSweepCompositionMismatch}, got ${postSweepCompositionMismatch}`,
    )
  }
  if (finalCompositionMismatch > maxAllowedFinalCompositionMismatch) {
    fail(
      `elk crossing-phase gate expected final_total_composition_mismatch <= ${maxAllowedFinalCompositionMismatch}, got ${finalCompositionMismatch}`,
    )
  }
  if (finalExactOrderMatchRate < minAllowedFinalExactOrderMatchRate) {
    fail(
      `elk crossing-phase gate expected final_avg_exact_order_match_rate >= ${minAllowedFinalExactOrderMatchRate.toFixed(3)}, got ${finalExactOrderMatchRate.toFixed(4)}`,
    )
  }
  if (finalOrderDisplacement > maxAllowedFinalOrderDisplacement) {
    fail(
      `elk crossing-phase gate expected final_avg_order_displacement <= ${maxAllowedFinalOrderDisplacement.toFixed(3)}, got ${finalOrderDisplacement.toFixed(4)}`,
    )
  }
}

function checkElkCrossingCandidateSelectionGate(): void {
  const stdout = runOrThrow('bun', [
    'run',
    'scripts/report_elk_crossing_candidate_gap.ts',
  ])
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')

  const mismatchLine = lines.find(line =>
    line.startsWith('candidate_order_mismatch '),
  )
  const selectionGapLine = lines.find(line =>
    line.startsWith('selection_gap_total='),
  )
  const selectedEqualsOracleLine = lines.find(line =>
    line.startsWith('selected_equals_oracle='),
  )
  if (!mismatchLine || !selectionGapLine || !selectedEqualsOracleLine) {
    fail('elk crossing-candidate gate missing summary lines')
  }

  const mismatchMatch =
    /^candidate_order_mismatch seed=(\d+) reversed=(\d+) virtual=(\d+) selected=(\d+) oracle=(\d+)$/.exec(
      mismatchLine,
    )
  const selectionGapMatch = /^selection_gap_total=(\d+)$/.exec(selectionGapLine)
  const selectedEqualsOracleMatch =
    /^selected_equals_oracle=(\d+)\/(\d+)$/.exec(selectedEqualsOracleLine)
  if (!mismatchMatch || !selectionGapMatch || !selectedEqualsOracleMatch) {
    fail('elk crossing-candidate gate failed to parse summary lines')
  }

  const selectedMismatch = Number.parseInt(mismatchMatch[4]!, 10)
  const oracleMismatch = Number.parseInt(mismatchMatch[5]!, 10)
  const selectionGapTotal = Number.parseInt(selectionGapMatch[1]!, 10)
  const selectedEqualsOracle = Number.parseInt(selectedEqualsOracleMatch[1]!, 10)
  const fixtureCount = Number.parseInt(selectedEqualsOracleMatch[2]!, 10)
  if (
    !Number.isFinite(selectedMismatch) ||
    !Number.isFinite(oracleMismatch) ||
    !Number.isFinite(selectionGapTotal) ||
    !Number.isFinite(selectedEqualsOracle) ||
    !Number.isFinite(fixtureCount)
  ) {
    fail('elk crossing-candidate gate parsed non-finite values')
  }

  const maxAllowedSelectedMismatch = 33
  const maxAllowedSelectionGapTotal = 1
  const minAllowedSelectedEqualsOracle = 12
  if (selectedMismatch > maxAllowedSelectedMismatch) {
    fail(
      `elk crossing-candidate gate expected selected mismatch <= ${maxAllowedSelectedMismatch}, got ${selectedMismatch}`,
    )
  }
  if (selectionGapTotal > maxAllowedSelectionGapTotal) {
    fail(
      `elk crossing-candidate gate expected selection_gap_total <= ${maxAllowedSelectionGapTotal}, got ${selectionGapTotal}`,
    )
  }
  if (selectedEqualsOracle < minAllowedSelectedEqualsOracle) {
    fail(
      `elk crossing-candidate gate expected selected_equals_oracle >= ${minAllowedSelectedEqualsOracle}/${fixtureCount}, got ${selectedEqualsOracle}/${fixtureCount}`,
    )
  }
  if (oracleMismatch > selectedMismatch) {
    fail(
      `elk crossing-candidate gate expected oracle mismatch <= selected mismatch, got oracle=${oracleMismatch} selected=${selectedMismatch}`,
    )
  }
}

function main(): void {
  checkDagreTraceGate()
  checkElkRankLayerGate()
  checkElkCycleOrientationGate()
  checkElkSortByInputModelGate()
  checkElkSortByInputPortOrderGate()
  checkElkPlacementMajorGate()
  checkElkCrossingRankOrderGate()
  checkElkCrossingPhaseTraceGate()
  checkElkCrossingCandidateSelectionGate()
  console.log('Phase parity gates passed.')
}

main()
