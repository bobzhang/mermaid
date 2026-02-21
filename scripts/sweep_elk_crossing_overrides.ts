/**
 * Sweep ELK crossing override configurations and report robust candidates.
 *
 * The sweep executes `report_elk_phase_waterfall.ts` for each configuration and
 * compares against baseline (`trial=1`, `sweep-pass=4`, `kernel=default`) using:
 * - crossing rank-order mismatches
 * - crossing phase post-sweep/final order mismatches
 * - end-to-end weighted gap index
 * - end-to-end logical crossing multiplier
 *
 * Usage:
 *   bun run scripts/sweep_elk_crossing_overrides.ts
 *   bun run scripts/sweep_elk_crossing_overrides.ts --trial-counts 1,3,5 --sweep-pass-counts 4,6 --sweep-kernels default,edge-slot
 *   bun run scripts/sweep_elk_crossing_overrides.ts --model-order-inversion-influences none,0.25,0.5
 *   bun run scripts/sweep_elk_crossing_overrides.ts --json /tmp/elk_crossing_sweep.json
 */

import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type SweepKernel = 'default' | 'neighbor-mean' | 'edge-slot'

type SweepCliOptions = {
  trialCounts: number[]
  sweepPassCounts: number[]
  sweepKernels: SweepKernel[]
  modelOrderInversionInfluences: Array<number | null>
  jsonPath?: string
}

type WaterfallReport = {
  crossingRankOrder: {
    orderMismatched: number
    orderComparable: number
  }
  crossingPhaseTrace: {
    postSweepOrderMismatched: number
    postSweepOrderComparable: number
    finalOrderMismatched: number
    finalOrderComparable: number
  }
  endToEnd: {
    avgWeightedGapIndex: number
    avgLogicalCrossingMultiplier: number
    structuralOk: number
    fixtures: number
  }
}

type CandidateConfig = {
  trialCount: number
  sweepPassCount: number
  sweepKernel: SweepKernel
  modelOrderInversionInfluence: number | null
}

type CandidateMetrics = {
  config: CandidateConfig
  rankOrderMismatch: number
  rankOrderComparable: number
  postSweepOrderMismatch: number
  postSweepOrderComparable: number
  finalOrderMismatch: number
  finalOrderComparable: number
  weightedGap: number
  logicalCrossingMultiplier: number
  structuralOk: number
  fixtures: number
}

type CandidateDelta = {
  config: CandidateConfig
  metrics: CandidateMetrics
  deltaRankOrderMismatch: number
  deltaPostSweepOrderMismatch: number
  deltaFinalOrderMismatch: number
  deltaWeightedGap: number
  deltaLogicalCrossingMultiplier: number
  nonRegressing: boolean
  improvedCrossingParity: boolean
}

type SweepReport = {
  baseline: CandidateMetrics
  candidates: CandidateDelta[]
  nonRegressingCandidates: CandidateDelta[]
  paretoNonRegressingCandidates: CandidateDelta[]
}

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

function parsePositiveInt(raw: string, flag: string): number {
  const parsed = Number.parseInt(raw.trim(), 10)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    fail(`invalid ${flag} value: ${raw}`)
  }
  return parsed
}

function parsePositiveIntList(raw: string, flag: string): number[] {
  const values = raw
    .split(',')
    .map(value => value.trim())
    .filter(value => value !== '')
    .map(value => parsePositiveInt(value, flag))
  if (values.length === 0) {
    fail(`invalid ${flag} value: expected comma-separated positive integers`)
  }
  const seen = new Set<number>()
  const deduped: number[] = []
  for (const value of values) {
    if (seen.has(value)) continue
    seen.add(value)
    deduped.push(value)
  }
  deduped.sort((left, right) => left - right)
  return deduped
}

function parseKernelList(raw: string, flag: string): SweepKernel[] {
  const values = raw
    .split(',')
    .map(value => value.trim().toLowerCase())
    .filter(value => value !== '')
  if (values.length === 0) {
    fail(`invalid ${flag} value: expected comma-separated kernels`)
  }
  const kernels: SweepKernel[] = []
  for (const value of values) {
    if (value !== 'default' && value !== 'neighbor-mean' && value !== 'edge-slot') {
      fail(
        `invalid ${flag} entry '${value}', expected default|neighbor-mean|edge-slot`,
      )
    }
    kernels.push(value)
  }
  const seen = new Set<SweepKernel>()
  const deduped: SweepKernel[] = []
  for (const kernel of kernels) {
    if (seen.has(kernel)) continue
    seen.add(kernel)
    deduped.push(kernel)
  }
  return deduped
}

function parseNonNegativeDouble(raw: string, flag: string): number {
  const parsed = Number.parseFloat(raw.trim())
  if (!Number.isFinite(parsed) || parsed < 0) {
    fail(`invalid ${flag} value: ${raw}`)
  }
  return parsed
}

function parseModelOrderInfluenceList(
  raw: string,
  flag: string,
): Array<number | null> {
  const entries = raw
    .split(',')
    .map(value => value.trim().toLowerCase())
    .filter(value => value !== '')
  if (entries.length === 0) {
    fail(
      `invalid ${flag} value: expected comma-separated values (none or non-negative numbers)`,
    )
  }
  const seen = new Set<string>()
  const parsed: Array<number | null> = []
  for (const entry of entries) {
    if (entry === 'none' || entry === 'default') {
      if (seen.has('none')) continue
      seen.add('none')
      parsed.push(null)
      continue
    }
    const value = parseNonNegativeDouble(entry, flag)
    const key = value.toString()
    if (seen.has(key)) continue
    seen.add(key)
    parsed.push(value)
  }
  parsed.sort((left, right) => {
    if (left === null && right === null) return 0
    if (left === null) return -1
    if (right === null) return 1
    return left - right
  })
  return parsed
}

function parseCliOptions(args: string[]): SweepCliOptions {
  let trialCounts = [1, 3, 5, 7]
  let sweepPassCounts = [4, 6]
  let sweepKernels: SweepKernel[] = ['default', 'neighbor-mean', 'edge-slot']
  let modelOrderInversionInfluences: Array<number | null> = [null]
  let jsonPath: string | undefined

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index]!
    if (arg === '--trial-counts') {
      const next = args[index + 1]
      if (!next) fail('missing value after --trial-counts')
      trialCounts = parsePositiveIntList(next, '--trial-counts')
      index += 1
      continue
    }
    if (arg.startsWith('--trial-counts=')) {
      const raw = arg.slice('--trial-counts='.length)
      trialCounts = parsePositiveIntList(raw, '--trial-counts')
      continue
    }
    if (arg === '--sweep-pass-counts') {
      const next = args[index + 1]
      if (!next) fail('missing value after --sweep-pass-counts')
      sweepPassCounts = parsePositiveIntList(next, '--sweep-pass-counts')
      index += 1
      continue
    }
    if (arg.startsWith('--sweep-pass-counts=')) {
      const raw = arg.slice('--sweep-pass-counts='.length)
      sweepPassCounts = parsePositiveIntList(raw, '--sweep-pass-counts')
      continue
    }
    if (arg === '--sweep-kernels') {
      const next = args[index + 1]
      if (!next) fail('missing value after --sweep-kernels')
      sweepKernels = parseKernelList(next, '--sweep-kernels')
      index += 1
      continue
    }
    if (arg.startsWith('--sweep-kernels=')) {
      const raw = arg.slice('--sweep-kernels='.length)
      sweepKernels = parseKernelList(raw, '--sweep-kernels')
      continue
    }
    if (arg === '--model-order-inversion-influences') {
      const next = args[index + 1]
      if (!next) fail('missing value after --model-order-inversion-influences')
      modelOrderInversionInfluences = parseModelOrderInfluenceList(
        next,
        '--model-order-inversion-influences',
      )
      index += 1
      continue
    }
    if (arg.startsWith('--model-order-inversion-influences=')) {
      const raw = arg.slice('--model-order-inversion-influences='.length)
      modelOrderInversionInfluences = parseModelOrderInfluenceList(
        raw,
        '--model-order-inversion-influences',
      )
      continue
    }
    if (arg === '--json') {
      const next = args[index + 1]
      if (!next) fail('missing path after --json')
      jsonPath = next
      index += 1
      continue
    }
    if (arg.startsWith('--json=')) {
      const raw = arg.slice('--json='.length)
      if (raw === '') fail('missing path after --json=')
      jsonPath = raw
      continue
    }
    fail(`unknown argument: ${arg}`)
  }

  return {
    trialCounts,
    sweepPassCounts,
    sweepKernels,
    modelOrderInversionInfluences,
    jsonPath,
  }
}

function candidateKey(config: CandidateConfig): string {
  const modelOrderInfluenceKey = config.modelOrderInversionInfluence === null
    ? 'none'
    : config.modelOrderInversionInfluence.toString()
  return `${config.sweepKernel}|${config.trialCount}|${config.sweepPassCount}|${modelOrderInfluenceKey}`
}

function parseWaterfallJson(path: string): WaterfallReport {
  const payload = JSON.parse(readFileSync(path, 'utf8')) as { report?: unknown }
  const report = payload.report as WaterfallReport | undefined
  if (!report) fail(`missing report payload in ${path}`)
  return report
}

function runWaterfallForConfig(config: CandidateConfig): CandidateMetrics {
  const tempRoot = mkdtempSync(join(tmpdir(), 'elk-crossing-sweep-'))
  const jsonPath = join(tempRoot, 'waterfall.json')
  runOrThrow('bun', [
    'run',
    'scripts/report_elk_phase_waterfall.ts',
    '--trial-count',
    String(config.trialCount),
    '--sweep-pass-count',
    String(config.sweepPassCount),
    '--sweep-kernel',
    config.sweepKernel,
    ...(config.modelOrderInversionInfluence === null
      ? []
      : [
          '--model-order-inversion-influence',
          String(config.modelOrderInversionInfluence),
        ]),
    '--json',
    jsonPath,
  ])
  const report = parseWaterfallJson(jsonPath)
  return {
    config,
    rankOrderMismatch: report.crossingRankOrder.orderMismatched,
    rankOrderComparable: report.crossingRankOrder.orderComparable,
    postSweepOrderMismatch: report.crossingPhaseTrace.postSweepOrderMismatched,
    postSweepOrderComparable: report.crossingPhaseTrace.postSweepOrderComparable,
    finalOrderMismatch: report.crossingPhaseTrace.finalOrderMismatched,
    finalOrderComparable: report.crossingPhaseTrace.finalOrderComparable,
    weightedGap: report.endToEnd.avgWeightedGapIndex,
    logicalCrossingMultiplier: report.endToEnd.avgLogicalCrossingMultiplier,
    structuralOk: report.endToEnd.structuralOk,
    fixtures: report.endToEnd.fixtures,
  }
}

function toCandidateDelta(
  baseline: CandidateMetrics,
  metrics: CandidateMetrics,
): CandidateDelta {
  const epsilon = 1e-9
  const nonRegressing =
    metrics.structuralOk === metrics.fixtures &&
    metrics.weightedGap <= baseline.weightedGap + epsilon &&
    metrics.logicalCrossingMultiplier <=
      baseline.logicalCrossingMultiplier + epsilon
  const improvedCrossingParity =
    metrics.rankOrderMismatch < baseline.rankOrderMismatch ||
    metrics.postSweepOrderMismatch < baseline.postSweepOrderMismatch ||
    metrics.finalOrderMismatch < baseline.finalOrderMismatch
  return {
    config: metrics.config,
    metrics,
    deltaRankOrderMismatch: metrics.rankOrderMismatch - baseline.rankOrderMismatch,
    deltaPostSweepOrderMismatch:
      metrics.postSweepOrderMismatch - baseline.postSweepOrderMismatch,
    deltaFinalOrderMismatch: metrics.finalOrderMismatch - baseline.finalOrderMismatch,
    deltaWeightedGap: metrics.weightedGap - baseline.weightedGap,
    deltaLogicalCrossingMultiplier:
      metrics.logicalCrossingMultiplier - baseline.logicalCrossingMultiplier,
    nonRegressing,
    improvedCrossingParity,
  }
}

function dominates(left: CandidateDelta, right: CandidateDelta): boolean {
  const noWorse =
    left.metrics.rankOrderMismatch <= right.metrics.rankOrderMismatch &&
    left.metrics.postSweepOrderMismatch <= right.metrics.postSweepOrderMismatch &&
    left.metrics.finalOrderMismatch <= right.metrics.finalOrderMismatch &&
    left.metrics.weightedGap <= right.metrics.weightedGap &&
    left.metrics.logicalCrossingMultiplier <=
      right.metrics.logicalCrossingMultiplier
  const strictlyBetter =
    left.metrics.rankOrderMismatch < right.metrics.rankOrderMismatch ||
    left.metrics.postSweepOrderMismatch < right.metrics.postSweepOrderMismatch ||
    left.metrics.finalOrderMismatch < right.metrics.finalOrderMismatch ||
    left.metrics.weightedGap < right.metrics.weightedGap ||
    left.metrics.logicalCrossingMultiplier <
      right.metrics.logicalCrossingMultiplier
  return noWorse && strictlyBetter
}

function paretoFront(candidates: CandidateDelta[]): CandidateDelta[] {
  const out: CandidateDelta[] = []
  for (const candidate of candidates) {
    let dominated = false
    for (const other of candidates) {
      if (candidate === other) continue
      if (dominates(other, candidate)) {
        dominated = true
        break
      }
    }
    if (!dominated) out.push(candidate)
  }
  return out
}

function sortedCandidates(candidates: CandidateDelta[]): CandidateDelta[] {
  return candidates.slice().sort((left, right) => {
    if (left.metrics.finalOrderMismatch !== right.metrics.finalOrderMismatch) {
      return left.metrics.finalOrderMismatch - right.metrics.finalOrderMismatch
    }
    if (
      left.metrics.postSweepOrderMismatch !== right.metrics.postSweepOrderMismatch
    ) {
      return left.metrics.postSweepOrderMismatch - right.metrics.postSweepOrderMismatch
    }
    if (left.metrics.rankOrderMismatch !== right.metrics.rankOrderMismatch) {
      return left.metrics.rankOrderMismatch - right.metrics.rankOrderMismatch
    }
    if (left.metrics.weightedGap !== right.metrics.weightedGap) {
      return left.metrics.weightedGap - right.metrics.weightedGap
    }
    if (
      left.metrics.logicalCrossingMultiplier !==
      right.metrics.logicalCrossingMultiplier
    ) {
      return (
        left.metrics.logicalCrossingMultiplier -
        right.metrics.logicalCrossingMultiplier
      )
    }
    return candidateKey(left.config).localeCompare(candidateKey(right.config))
  })
}

function printCandidate(prefix: string, row: CandidateDelta): void {
  console.log(
    [
      prefix,
      `kernel=${row.config.sweepKernel}`,
      `trial=${row.config.trialCount}`,
      `sweep=${row.config.sweepPassCount}`,
      `model_order_influence=${row.config.modelOrderInversionInfluence === null ? 'none' : row.config.modelOrderInversionInfluence.toFixed(4)}`,
      `rank=${row.metrics.rankOrderMismatch}/${row.metrics.rankOrderComparable}`,
      `post=${row.metrics.postSweepOrderMismatch}/${row.metrics.postSweepOrderComparable}`,
      `final=${row.metrics.finalOrderMismatch}/${row.metrics.finalOrderComparable}`,
      `wg=${row.metrics.weightedGap.toFixed(4)}`,
      `lc=${row.metrics.logicalCrossingMultiplier.toFixed(4)}`,
      `d_rank=${row.deltaRankOrderMismatch >= 0 ? '+' : ''}${row.deltaRankOrderMismatch}`,
      `d_post=${row.deltaPostSweepOrderMismatch >= 0 ? '+' : ''}${row.deltaPostSweepOrderMismatch}`,
      `d_final=${row.deltaFinalOrderMismatch >= 0 ? '+' : ''}${row.deltaFinalOrderMismatch}`,
      `d_wg=${row.deltaWeightedGap >= 0 ? '+' : ''}${row.deltaWeightedGap.toFixed(4)}`,
      `d_lc=${row.deltaLogicalCrossingMultiplier >= 0 ? '+' : ''}${row.deltaLogicalCrossingMultiplier.toFixed(4)}`,
      `non_regressing=${row.nonRegressing ? 'yes' : 'no'}`,
      `crossing_improved=${row.improvedCrossingParity ? 'yes' : 'no'}`,
    ].join(' '),
  )
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const baselineConfig: CandidateConfig = {
    trialCount: 1,
    sweepPassCount: 4,
    sweepKernel: 'default',
    modelOrderInversionInfluence: null,
  }

  const configs: CandidateConfig[] = []
  const seen = new Set<string>()

  const enqueue = (config: CandidateConfig): void => {
    const key = candidateKey(config)
    if (seen.has(key)) return
    seen.add(key)
    configs.push(config)
  }

  enqueue(baselineConfig)
  for (const sweepKernel of options.sweepKernels) {
    for (const trialCount of options.trialCounts) {
      for (const sweepPassCount of options.sweepPassCounts) {
        for (const modelOrderInversionInfluence of options.modelOrderInversionInfluences) {
          enqueue({
            trialCount,
            sweepPassCount,
            sweepKernel,
            modelOrderInversionInfluence,
          })
        }
      }
    }
  }

  const metricsByKey = new Map<string, CandidateMetrics>()
  for (const config of configs) {
    console.log(
      `run kernel=${config.sweepKernel} trial=${config.trialCount} sweep=${config.sweepPassCount} model_order_influence=${config.modelOrderInversionInfluence === null ? 'none' : config.modelOrderInversionInfluence.toFixed(4)}`,
    )
    const metrics = runWaterfallForConfig(config)
    metricsByKey.set(candidateKey(config), metrics)
  }

  const baseline = metricsByKey.get(candidateKey(baselineConfig))
  if (!baseline) {
    fail('baseline metrics missing after sweep')
  }

  const deltas: CandidateDelta[] = []
  for (const config of configs) {
    const metrics = metricsByKey.get(candidateKey(config))
    if (!metrics) continue
    deltas.push(toCandidateDelta(baseline, metrics))
  }

  const nonRegressingCandidates = sortedCandidates(
    deltas.filter(candidate => candidate.nonRegressing),
  )
  const paretoNonRegressingCandidates = sortedCandidates(
    paretoFront(nonRegressingCandidates),
  )

  console.log('=== elk crossing override sweep ===')
  console.log(
    `baseline kernel=${baseline.config.sweepKernel} trial=${baseline.config.trialCount} sweep=${baseline.config.sweepPassCount} model_order_influence=${baseline.config.modelOrderInversionInfluence === null ? 'none' : baseline.config.modelOrderInversionInfluence.toFixed(4)} rank=${baseline.rankOrderMismatch}/${baseline.rankOrderComparable} post=${baseline.postSweepOrderMismatch}/${baseline.postSweepOrderComparable} final=${baseline.finalOrderMismatch}/${baseline.finalOrderComparable} wg=${baseline.weightedGap.toFixed(4)} lc=${baseline.logicalCrossingMultiplier.toFixed(4)} structural_ok=${baseline.structuralOk}/${baseline.fixtures}`,
  )
  console.log(`total_candidates=${deltas.length}`)
  console.log(`non_regressing_candidates=${nonRegressingCandidates.length}`)
  console.log(
    `non_regressing_crossing_improved=${nonRegressingCandidates.filter(candidate => candidate.improvedCrossingParity).length}`,
  )
  console.log(
    `pareto_non_regressing_candidates=${paretoNonRegressingCandidates.length}`,
  )

  for (const candidate of nonRegressingCandidates) {
    printCandidate('candidate', candidate)
  }
  if (paretoNonRegressingCandidates.length > 0) {
    console.log('=== pareto non-regressing ===')
    for (const candidate of paretoNonRegressingCandidates) {
      printCandidate('pareto', candidate)
    }
  }

  if (options.jsonPath) {
    const report: SweepReport = {
      baseline,
      candidates: deltas,
      nonRegressingCandidates,
      paretoNonRegressingCandidates,
    }
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
