/**
 * Run stress parity checks for dagre-parity and elk engines with explicit quality gates.
 *
 * Usage:
 *   bun run scripts/check_layout_parity_gates.ts
 *   bun run scripts/check_layout_parity_gates.ts --profile target
 *   bun run scripts/check_layout_parity_gates.ts fixtures/layout_stress_001_dense_dag.mmd
 */

import { mkdtempSync, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type Engine = 'dagre-parity' | 'elk'

type StressSummary = {
  fixtures: number
  structuralOk: number
  avgWeightedGapIndex: number
  avgMajorRankExactMatchRate: number
  totalMajorRankCompositionMismatches: number
  avgLogicalCrossingMultiplier: number
}

type StressReport = {
  summary: StressSummary
}

type AbsoluteGate = {
  maxAvgWeightedGapIndex: number
  minAvgMajorRankExactMatchRate: number
  maxTotalMajorRankCompositionMismatches: number
  maxAvgLogicalCrossingMultiplier: number
}

type DeltaGate = {
  maxAvgWeightedGapIndexIncrease: number
  maxAvgMajorRankExactMatchRateDrop: number
  maxTotalMajorRankCompositionMismatchesIncrease: number
  maxAvgLogicalCrossingMultiplierIncrease: number
}

type Profile = {
  absolute: Record<Engine, AbsoluteGate>
  delta: Record<Engine, DeltaGate>
}

type CliOptions = {
  profile: 'baseline' | 'target'
  passThroughArgs: string[]
}

const BASELINE_REPORT_PATH: Record<Engine, string> = {
  'dagre-parity': 'testdata/layout_parity/baseline/2026-02-19/dagre-parity.json',
  elk: 'testdata/layout_parity/baseline/2026-02-19/elk.json',
}

const PROFILES: Record<'baseline' | 'target', Profile> = {
  baseline: {
    absolute: {
      'dagre-parity': {
        maxAvgWeightedGapIndex: 0.08,
        minAvgMajorRankExactMatchRate: 0.72,
        maxTotalMajorRankCompositionMismatches: 0,
        maxAvgLogicalCrossingMultiplier: 0.95,
      },
      elk: {
        maxAvgWeightedGapIndex: 0.13,
        minAvgMajorRankExactMatchRate: 0.52,
        maxTotalMajorRankCompositionMismatches: 60,
        maxAvgLogicalCrossingMultiplier: 1.0,
      },
    },
    delta: {
      'dagre-parity': {
        maxAvgWeightedGapIndexIncrease: 0.01,
        maxAvgMajorRankExactMatchRateDrop: 0.03,
        maxTotalMajorRankCompositionMismatchesIncrease: 0,
        maxAvgLogicalCrossingMultiplierIncrease: 0.05,
      },
      elk: {
        maxAvgWeightedGapIndexIncrease: 0.02,
        maxAvgMajorRankExactMatchRateDrop: 0.05,
        maxTotalMajorRankCompositionMismatchesIncrease: 8,
        maxAvgLogicalCrossingMultiplierIncrease: 0.08,
      },
    },
  },
  target: {
    absolute: {
      'dagre-parity': {
        maxAvgWeightedGapIndex: 0.055,
        minAvgMajorRankExactMatchRate: 0.82,
        maxTotalMajorRankCompositionMismatches: 0,
        maxAvgLogicalCrossingMultiplier: 0.8,
      },
      elk: {
        maxAvgWeightedGapIndex: 0.07,
        minAvgMajorRankExactMatchRate: 0.75,
        maxTotalMajorRankCompositionMismatches: 3,
        maxAvgLogicalCrossingMultiplier: 0.8,
      },
    },
    delta: {
      'dagre-parity': {
        maxAvgWeightedGapIndexIncrease: 0.0,
        maxAvgMajorRankExactMatchRateDrop: 0.0,
        maxTotalMajorRankCompositionMismatchesIncrease: 0,
        maxAvgLogicalCrossingMultiplierIncrease: 0.0,
      },
      elk: {
        maxAvgWeightedGapIndexIncrease: 0.0,
        maxAvgMajorRankExactMatchRateDrop: 0.0,
        maxTotalMajorRankCompositionMismatchesIncrease: 0,
        maxAvgLogicalCrossingMultiplierIncrease: 0.0,
      },
    },
  },
}

function fail(message: string): never {
  throw new Error(message)
}

function parseArgs(args: string[]): CliOptions {
  let profile: 'baseline' | 'target' = 'baseline'
  const passThroughArgs: string[] = []

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--profile') {
      const next = args[i + 1]
      if (!next) fail('missing profile after --profile')
      if (next !== 'baseline' && next !== 'target') {
        fail("invalid --profile value, expected 'baseline' or 'target'")
      }
      profile = next
      i += 1
      continue
    }
    if (arg.startsWith('--profile=')) {
      const value = arg.slice('--profile='.length)
      if (value !== 'baseline' && value !== 'target') {
        fail("invalid --profile value, expected 'baseline' or 'target'")
      }
      profile = value
      continue
    }
    passThroughArgs.push(arg)
  }

  return { profile, passThroughArgs }
}

function runStress(engine: Engine, jsonPath: string, passThroughArgs: string[]): StressReport {
  const args = [
    'run',
    'scripts/compare_layout_stress.ts',
    '--local-layout-engine',
    engine,
    '--json',
    jsonPath,
    ...passThroughArgs,
  ]
  const result = spawnSync('bun', args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 16 * 1024 * 1024,
  })

  if (result.status !== 0) {
    const stderr = (result.stderr ?? '').toString().trim()
    const stdout = (result.stdout ?? '').toString().trim()
    const parts = [`stress compare failed for engine=${engine}`]
    if (stderr !== '') parts.push(`stderr:\n${stderr}`)
    if (stdout !== '') parts.push(`stdout:\n${stdout}`)
    fail(parts.join('\n'))
  }

  return JSON.parse(readFileSync(jsonPath, 'utf8')) as StressReport
}

function loadBaseline(engine: Engine): StressReport {
  return JSON.parse(readFileSync(BASELINE_REPORT_PATH[engine], 'utf8')) as StressReport
}

function round(value: number): string {
  return Number.isFinite(value) ? value.toFixed(4) : 'NaN'
}

function pushAbsoluteFailures(
  failures: string[],
  engine: Engine,
  summary: StressSummary,
  gate: AbsoluteGate,
): void {
  if (summary.structuralOk !== summary.fixtures) {
    failures.push(
      `[${engine}] structural mismatch: structuralOk=${summary.structuralOk}/${summary.fixtures}`,
    )
  }
  if (summary.avgWeightedGapIndex > gate.maxAvgWeightedGapIndex) {
    failures.push(
      `[${engine}] avgWeightedGapIndex ${round(summary.avgWeightedGapIndex)} > ${round(gate.maxAvgWeightedGapIndex)}`,
    )
  }
  if (summary.avgMajorRankExactMatchRate < gate.minAvgMajorRankExactMatchRate) {
    failures.push(
      `[${engine}] avgMajorRankExactMatchRate ${round(summary.avgMajorRankExactMatchRate)} < ${round(gate.minAvgMajorRankExactMatchRate)}`,
    )
  }
  if (
    summary.totalMajorRankCompositionMismatches >
    gate.maxTotalMajorRankCompositionMismatches
  ) {
    failures.push(
      `[${engine}] totalMajorRankCompositionMismatches ${summary.totalMajorRankCompositionMismatches} > ${gate.maxTotalMajorRankCompositionMismatches}`,
    )
  }
  if (summary.avgLogicalCrossingMultiplier > gate.maxAvgLogicalCrossingMultiplier) {
    failures.push(
      `[${engine}] avgLogicalCrossingMultiplier ${round(summary.avgLogicalCrossingMultiplier)} > ${round(gate.maxAvgLogicalCrossingMultiplier)}`,
    )
  }
}

function pushDeltaFailures(
  failures: string[],
  engine: Engine,
  baseline: StressSummary,
  current: StressSummary,
  gate: DeltaGate,
): void {
  const weightedGapIncrease = current.avgWeightedGapIndex - baseline.avgWeightedGapIndex
  if (weightedGapIncrease > gate.maxAvgWeightedGapIndexIncrease) {
    failures.push(
      `[${engine}] avgWeightedGapIndex increase ${round(weightedGapIncrease)} > ${round(gate.maxAvgWeightedGapIndexIncrease)}`,
    )
  }

  const rankExactDrop = baseline.avgMajorRankExactMatchRate - current.avgMajorRankExactMatchRate
  if (rankExactDrop > gate.maxAvgMajorRankExactMatchRateDrop) {
    failures.push(
      `[${engine}] avgMajorRankExactMatchRate drop ${round(rankExactDrop)} > ${round(gate.maxAvgMajorRankExactMatchRateDrop)}`,
    )
  }

  const compositionIncrease =
    current.totalMajorRankCompositionMismatches -
    baseline.totalMajorRankCompositionMismatches
  if (compositionIncrease > gate.maxTotalMajorRankCompositionMismatchesIncrease) {
    failures.push(
      `[${engine}] totalMajorRankCompositionMismatches increase ${compositionIncrease} > ${gate.maxTotalMajorRankCompositionMismatchesIncrease}`,
    )
  }

  const logicalMultiplierIncrease =
    current.avgLogicalCrossingMultiplier - baseline.avgLogicalCrossingMultiplier
  if (logicalMultiplierIncrease > gate.maxAvgLogicalCrossingMultiplierIncrease) {
    failures.push(
      `[${engine}] avgLogicalCrossingMultiplier increase ${round(logicalMultiplierIncrease)} > ${round(gate.maxAvgLogicalCrossingMultiplierIncrease)}`,
    )
  }
}

function printSummary(engine: Engine, baseline: StressSummary, current: StressSummary): void {
  console.log(`\n[${engine}]`)
  console.log(`fixtures=${current.fixtures} structural_ok=${current.structuralOk}/${current.fixtures}`)
  console.log(
    `avg_weighted_gap_index baseline=${round(baseline.avgWeightedGapIndex)} current=${round(current.avgWeightedGapIndex)} delta=${round(current.avgWeightedGapIndex - baseline.avgWeightedGapIndex)}`,
  )
  console.log(
    `avg_major_rank_exact_match_rate baseline=${round(baseline.avgMajorRankExactMatchRate)} current=${round(current.avgMajorRankExactMatchRate)} delta=${round(current.avgMajorRankExactMatchRate - baseline.avgMajorRankExactMatchRate)}`,
  )
  console.log(
    `total_major_rank_composition_mismatches baseline=${baseline.totalMajorRankCompositionMismatches} current=${current.totalMajorRankCompositionMismatches} delta=${current.totalMajorRankCompositionMismatches - baseline.totalMajorRankCompositionMismatches}`,
  )
  console.log(
    `avg_logical_crossing_multiplier baseline=${round(baseline.avgLogicalCrossingMultiplier)} current=${round(current.avgLogicalCrossingMultiplier)} delta=${round(current.avgLogicalCrossingMultiplier - baseline.avgLogicalCrossingMultiplier)}`,
  )
}

function main(): void {
  const options = parseArgs(process.argv.slice(2))
  const profile = PROFILES[options.profile]
  const tempRoot = mkdtempSync(join(tmpdir(), 'mermaid-layout-parity-gates-'))

  const engines: Engine[] = ['dagre-parity', 'elk']
  const currentReports = new Map<Engine, StressReport>()
  const baselineReports = new Map<Engine, StressReport>()
  for (const engine of engines) {
    baselineReports.set(engine, loadBaseline(engine))
    const outPath = join(tempRoot, `${engine}.json`)
    currentReports.set(engine, runStress(engine, outPath, options.passThroughArgs))
  }

  const failures: string[] = []
  console.log(`profile=${options.profile}`)
  for (const engine of engines) {
    const baselineSummary = baselineReports.get(engine)!.summary
    const currentSummary = currentReports.get(engine)!.summary
    printSummary(engine, baselineSummary, currentSummary)
    pushAbsoluteFailures(failures, engine, currentSummary, profile.absolute[engine])
    pushDeltaFailures(failures, engine, baselineSummary, currentSummary, profile.delta[engine])
  }

  if (failures.length > 0) {
    console.error('\nParity gates failed:')
    failures.forEach(item => console.error(`- ${item}`))
    process.exit(1)
  }
  console.log('\nParity gates passed.')
}

main()
