/**
 * Run layout stress comparison for both local engines and report deltas.
 *
 * Usage:
 *   bun run scripts/compare_layout_engines.ts
 *   bun run scripts/compare_layout_engines.ts fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_layout_engines.ts --profile strict --official-timeout-ms 120000 --local-timeout-ms 120000
 *   bun run scripts/compare_layout_engines.ts --max-avg-weighted-gap-delta 0.0
 *   bun run scripts/compare_layout_engines.ts --max-avg-logical-crossing-multiplier-delta 0.0
 *   bun run scripts/compare_layout_engines.ts --max-avg-weighted-gap-delta-elk 0.0
 *   bun run scripts/compare_layout_engines.ts --max-avg-logical-crossing-multiplier-delta-elk 0.0
 */

import { mkdtempSync, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type Engine = 'legacy' | 'dagre-parity' | 'elk'

type StressSummary = {
  fixtures: number
  structuralOk: number
  avgRmse: number
  avgInversionRateX: number
  avgInversionRateY: number
  avgMajorInversionRate: number
  avgMajorRankExactMatchRate: number
  avgMajorRankDisplacement: number
  totalMajorRankCompositionMismatches: number
  avgMajorSpanRatio: number
  avgMinorSpanRatio: number
  totalLocalPolylineCrossings: number
  totalOfficialPolylineCrossings: number
  totalLocalLogicalCrossings: number
  totalOfficialLogicalCrossings: number
  avgPolylineCrossingMultiplier: number
  avgLogicalCrossingMultiplier: number
  avgSpanAreaRatio: number
  avgWeightedGapIndex: number
  maxWeightedGapIndex: number
  topWeightedGapFixtures: string[]
}

type StressResult = {
  fixture: string
  weightedGapIndex: number
  logicalCrossingMultiplier: number
  polylineCrossingMultiplier: number
  localPolylineCrossings: number
  officialPolylineCrossings: number
  localLogicalCrossings: number
  officialLogicalCrossings: number
}

type StressPayload = {
  summary: StressSummary
  results: StressResult[]
}

type CliOptions = {
  passThroughArgs: string[]
  maxAvgWeightedGapDelta?: number
  maxAvgLogicalCrossingMultiplierDelta?: number
  maxAvgWeightedGapDeltaElk?: number
  maxAvgLogicalCrossingMultiplierDeltaElk?: number
}

function fail(message: string): never {
  throw new Error(message)
}

function round(value: number): string {
  if (!Number.isFinite(value)) return 'NaN'
  return value.toFixed(4)
}

function parsePositiveOrZeroFloat(flag: string, raw: string): number {
  const parsed = Number.parseFloat(raw)
  if (!Number.isFinite(parsed) || parsed < 0) {
    fail(`invalid ${flag} value, expected number >= 0`)
  }
  return parsed
}

function parseCliOptions(args: string[]): CliOptions {
  const passThroughArgs: string[] = []
  let maxAvgWeightedGapDelta: number | undefined = undefined
  let maxAvgLogicalCrossingMultiplierDelta: number | undefined = undefined
  let maxAvgWeightedGapDeltaElk: number | undefined = undefined
  let maxAvgLogicalCrossingMultiplierDeltaElk: number | undefined = undefined

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!

    if (arg === '--max-avg-weighted-gap-delta') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-weighted-gap-delta')
      maxAvgWeightedGapDelta = parsePositiveOrZeroFloat(
        '--max-avg-weighted-gap-delta',
        next,
      )
      i += 1
      continue
    }

    if (arg.startsWith('--max-avg-weighted-gap-delta=')) {
      const raw = arg.slice('--max-avg-weighted-gap-delta='.length)
      maxAvgWeightedGapDelta = parsePositiveOrZeroFloat(
        '--max-avg-weighted-gap-delta',
        raw,
      )
      continue
    }

    if (arg === '--max-avg-logical-crossing-multiplier-delta') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-logical-crossing-multiplier-delta')
      maxAvgLogicalCrossingMultiplierDelta = parsePositiveOrZeroFloat(
        '--max-avg-logical-crossing-multiplier-delta',
        next,
      )
      i += 1
      continue
    }

    if (arg.startsWith('--max-avg-logical-crossing-multiplier-delta=')) {
      const raw = arg.slice('--max-avg-logical-crossing-multiplier-delta='.length)
      maxAvgLogicalCrossingMultiplierDelta = parsePositiveOrZeroFloat(
        '--max-avg-logical-crossing-multiplier-delta',
        raw,
      )
      continue
    }

    if (arg === '--max-avg-weighted-gap-delta-elk') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-weighted-gap-delta-elk')
      maxAvgWeightedGapDeltaElk = parsePositiveOrZeroFloat(
        '--max-avg-weighted-gap-delta-elk',
        next,
      )
      i += 1
      continue
    }

    if (arg.startsWith('--max-avg-weighted-gap-delta-elk=')) {
      const raw = arg.slice('--max-avg-weighted-gap-delta-elk='.length)
      maxAvgWeightedGapDeltaElk = parsePositiveOrZeroFloat(
        '--max-avg-weighted-gap-delta-elk',
        raw,
      )
      continue
    }

    if (arg === '--max-avg-logical-crossing-multiplier-delta-elk') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-logical-crossing-multiplier-delta-elk')
      maxAvgLogicalCrossingMultiplierDeltaElk = parsePositiveOrZeroFloat(
        '--max-avg-logical-crossing-multiplier-delta-elk',
        next,
      )
      i += 1
      continue
    }

    if (arg.startsWith('--max-avg-logical-crossing-multiplier-delta-elk=')) {
      const raw = arg.slice('--max-avg-logical-crossing-multiplier-delta-elk='.length)
      maxAvgLogicalCrossingMultiplierDeltaElk = parsePositiveOrZeroFloat(
        '--max-avg-logical-crossing-multiplier-delta-elk',
        raw,
      )
      continue
    }

    if (arg === '--json' || arg === '--local-layout-engine') {
      fail(`${arg} is reserved by scripts/compare_layout_stress.ts and cannot be passed directly`)
    }
    if (arg.startsWith('--json=') || arg.startsWith('--local-layout-engine=')) {
      fail(`${arg.split('=')[0]} is reserved by scripts/compare_layout_stress.ts and cannot be passed directly`)
    }

    passThroughArgs.push(arg)
  }

  return {
    passThroughArgs,
    maxAvgWeightedGapDelta,
    maxAvgLogicalCrossingMultiplierDelta,
    maxAvgWeightedGapDeltaElk,
    maxAvgLogicalCrossingMultiplierDeltaElk,
  }
}

function runStressCompare(engine: Engine, jsonPath: string, passThroughArgs: string[]): StressPayload {
  const args = [
    'run',
    'scripts/compare_layout_stress.ts',
    '--local-layout-engine',
    engine,
    '--json',
    jsonPath,
    ...passThroughArgs,
  ]
  const runResult = spawnSync('bun', args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 16 * 1024 * 1024,
  })

  if (runResult.error) {
    fail(`failed to run bun (${engine}): ${String(runResult.error.message ?? runResult.error)}`)
  }
  if (runResult.status !== 0) {
    const stderr = (runResult.stderr ?? '').toString().trim()
    const stdout = (runResult.stdout ?? '').toString().trim()
    fail(
      [
        `compare_layout_stress failed for engine=${engine} with status=${runResult.status}`,
        stderr === '' ? '' : `stderr:\n${stderr}`,
        stdout === '' ? '' : `stdout:\n${stdout}`,
      ]
        .filter(Boolean)
        .join('\n'),
    )
  }

  const payload = JSON.parse(readFileSync(jsonPath, 'utf8')) as StressPayload
  return payload
}

function sortByAbsDelta(
  entries: Array<{ fixture: string; delta: number }>,
): Array<{ fixture: string; delta: number }> {
  return entries
    .slice()
    .sort((left, right) => {
      const leftAbs = Math.abs(left.delta)
      const rightAbs = Math.abs(right.delta)
      if (leftAbs !== rightAbs) return rightAbs - leftAbs
      return left.fixture.localeCompare(right.fixture)
    })
}

function fixtureIndex(results: StressResult[]): Map<string, StressResult> {
  const index = new Map<string, StressResult>()
  for (const row of results) {
    index.set(row.fixture, row)
  }
  return index
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const tempRoot = mkdtempSync(join(tmpdir(), 'mermaid-layout-engine-ab-'))
  const legacyJson = join(tempRoot, 'legacy.json')
  const parityJson = join(tempRoot, 'dagre-parity.json')
  const elkJson = join(tempRoot, 'elk.json')

  const legacy = runStressCompare('legacy', legacyJson, options.passThroughArgs)
  const parity = runStressCompare('dagre-parity', parityJson, options.passThroughArgs)
  const elk = runStressCompare('elk', elkJson, options.passThroughArgs)

  const legacySummary = legacy.summary
  const paritySummary = parity.summary
  const elkSummary = elk.summary
  const parityAvgWeightedGapDelta =
    paritySummary.avgWeightedGapIndex - legacySummary.avgWeightedGapIndex
  const parityAvgLogicalMultiplierDelta =
    paritySummary.avgLogicalCrossingMultiplier - legacySummary.avgLogicalCrossingMultiplier
  const parityTotalPolylineCrossingDelta =
    paritySummary.totalLocalPolylineCrossings - legacySummary.totalLocalPolylineCrossings
  const parityTotalLogicalCrossingDelta =
    paritySummary.totalLocalLogicalCrossings - legacySummary.totalLocalLogicalCrossings
  const elkAvgWeightedGapDelta = elkSummary.avgWeightedGapIndex - legacySummary.avgWeightedGapIndex
  const elkAvgLogicalMultiplierDelta =
    elkSummary.avgLogicalCrossingMultiplier - legacySummary.avgLogicalCrossingMultiplier
  const elkTotalPolylineCrossingDelta =
    elkSummary.totalLocalPolylineCrossings - legacySummary.totalLocalPolylineCrossings
  const elkTotalLogicalCrossingDelta =
    elkSummary.totalLocalLogicalCrossings - legacySummary.totalLocalLogicalCrossings

  const legacyByFixture = fixtureIndex(legacy.results)
  const parityByFixture = fixtureIndex(parity.results)
  const elkByFixture = fixtureIndex(elk.results)
  const allFixtures = [...legacyByFixture.keys()].sort()
  const parityWeightedGapDeltas: Array<{ fixture: string; delta: number }> = []
  const parityLogicalMultiplierDeltas: Array<{ fixture: string; delta: number }> = []
  const elkWeightedGapDeltas: Array<{ fixture: string; delta: number }> = []
  const elkLogicalMultiplierDeltas: Array<{ fixture: string; delta: number }> = []
  for (const fixture of allFixtures) {
    const legacyFixture = legacyByFixture.get(fixture)
    const parityFixture = parityByFixture.get(fixture)
    const elkFixture = elkByFixture.get(fixture)
    if (!legacyFixture || !parityFixture || !elkFixture) {
      fail(`fixture mismatch between engines: ${fixture}`)
    }
    parityWeightedGapDeltas.push({
      fixture,
      delta: parityFixture.weightedGapIndex - legacyFixture.weightedGapIndex,
    })
    parityLogicalMultiplierDeltas.push({
      fixture,
      delta: parityFixture.logicalCrossingMultiplier - legacyFixture.logicalCrossingMultiplier,
    })
    elkWeightedGapDeltas.push({
      fixture,
      delta: elkFixture.weightedGapIndex - legacyFixture.weightedGapIndex,
    })
    elkLogicalMultiplierDeltas.push({
      fixture,
      delta: elkFixture.logicalCrossingMultiplier - legacyFixture.logicalCrossingMultiplier,
    })
  }

  const topParityWeightedDeltas = sortByAbsDelta(parityWeightedGapDeltas).slice(0, 8)
  const topParityLogicalMultiplierDeltas = sortByAbsDelta(parityLogicalMultiplierDeltas).slice(0, 8)
  const topElkWeightedDeltas = sortByAbsDelta(elkWeightedGapDeltas).slice(0, 8)
  const topElkLogicalMultiplierDeltas = sortByAbsDelta(elkLogicalMultiplierDeltas).slice(0, 8)

  console.log('=== local engine A/B summary (dagre-parity - legacy) ===')
  console.log(`fixtures=${allFixtures.length}`)
  console.log(
    `avg_weighted_gap_index legacy=${round(legacySummary.avgWeightedGapIndex)} dagre_parity=${round(paritySummary.avgWeightedGapIndex)} delta=${round(parityAvgWeightedGapDelta)}`,
  )
  console.log(
    `avg_logical_crossing_multiplier legacy=${round(legacySummary.avgLogicalCrossingMultiplier)} dagre_parity=${round(paritySummary.avgLogicalCrossingMultiplier)} delta=${round(parityAvgLogicalMultiplierDelta)}`,
  )
  console.log(
    `total_local_polyline_crossings legacy=${legacySummary.totalLocalPolylineCrossings} dagre_parity=${paritySummary.totalLocalPolylineCrossings} delta=${parityTotalPolylineCrossingDelta}`,
  )
  console.log(
    `total_local_logical_crossings legacy=${legacySummary.totalLocalLogicalCrossings} dagre_parity=${paritySummary.totalLocalLogicalCrossings} delta=${parityTotalLogicalCrossingDelta}`,
  )
  console.log(
    `top_weighted_gap_fixture_deltas=${topParityWeightedDeltas
      .map(item => `${item.fixture}:${round(item.delta)}`)
      .join(', ')}`,
  )
  console.log(
    `top_logical_multiplier_fixture_deltas=${topParityLogicalMultiplierDeltas
      .map(item => `${item.fixture}:${round(item.delta)}`)
      .join(', ')}`,
  )

  console.log('\n=== local engine A/B summary (elk - legacy) ===')
  console.log(`fixtures=${allFixtures.length}`)
  console.log(
    `avg_weighted_gap_index legacy=${round(legacySummary.avgWeightedGapIndex)} elk=${round(elkSummary.avgWeightedGapIndex)} delta=${round(elkAvgWeightedGapDelta)}`,
  )
  console.log(
    `avg_logical_crossing_multiplier legacy=${round(legacySummary.avgLogicalCrossingMultiplier)} elk=${round(elkSummary.avgLogicalCrossingMultiplier)} delta=${round(elkAvgLogicalMultiplierDelta)}`,
  )
  console.log(
    `total_local_polyline_crossings legacy=${legacySummary.totalLocalPolylineCrossings} elk=${elkSummary.totalLocalPolylineCrossings} delta=${elkTotalPolylineCrossingDelta}`,
  )
  console.log(
    `total_local_logical_crossings legacy=${legacySummary.totalLocalLogicalCrossings} elk=${elkSummary.totalLocalLogicalCrossings} delta=${elkTotalLogicalCrossingDelta}`,
  )
  console.log(
    `top_weighted_gap_fixture_deltas=${topElkWeightedDeltas
      .map(item => `${item.fixture}:${round(item.delta)}`)
      .join(', ')}`,
  )
  console.log(
    `top_logical_multiplier_fixture_deltas=${topElkLogicalMultiplierDeltas
      .map(item => `${item.fixture}:${round(item.delta)}`)
      .join(', ')}`,
  )
  console.log(`legacy_report=${legacyJson}`)
  console.log(`dagre_parity_report=${parityJson}`)
  console.log(`elk_report=${elkJson}`)

  if (
    options.maxAvgWeightedGapDelta !== undefined &&
    parityAvgWeightedGapDelta > options.maxAvgWeightedGapDelta
  ) {
    console.error(
      `avg weighted gap delta threshold exceeded: threshold=${options.maxAvgWeightedGapDelta} delta=${round(parityAvgWeightedGapDelta)}`,
    )
    process.exitCode = 2
  }

  if (
    options.maxAvgLogicalCrossingMultiplierDelta !== undefined &&
    parityAvgLogicalMultiplierDelta > options.maxAvgLogicalCrossingMultiplierDelta
  ) {
    console.error(
      `avg logical crossing multiplier delta threshold exceeded: threshold=${options.maxAvgLogicalCrossingMultiplierDelta} delta=${round(parityAvgLogicalMultiplierDelta)}`,
    )
    process.exitCode = 3
  }

  if (
    options.maxAvgWeightedGapDeltaElk !== undefined &&
    elkAvgWeightedGapDelta > options.maxAvgWeightedGapDeltaElk
  ) {
    console.error(
      `avg weighted gap delta (elk) threshold exceeded: threshold=${options.maxAvgWeightedGapDeltaElk} delta=${round(elkAvgWeightedGapDelta)}`,
    )
    process.exitCode = 4
  }

  if (
    options.maxAvgLogicalCrossingMultiplierDeltaElk !== undefined &&
    elkAvgLogicalMultiplierDelta > options.maxAvgLogicalCrossingMultiplierDeltaElk
  ) {
    console.error(
      `avg logical crossing multiplier delta (elk) threshold exceeded: threshold=${options.maxAvgLogicalCrossingMultiplierDeltaElk} delta=${round(elkAvgLogicalMultiplierDelta)}`,
    )
    process.exitCode = 5
  }
}

main()
