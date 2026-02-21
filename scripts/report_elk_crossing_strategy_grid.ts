/**
 * Evaluate ELK crossing strategy combinations against upstream on stress fixtures.
 *
 * The report combines:
 * - crossing phase trace parity (intermediate output)
 * - end-to-end layout quality summary
 *
 * Usage:
 *   bun run scripts/report_elk_crossing_strategy_grid.ts
 *   bun run scripts/report_elk_crossing_strategy_grid.ts --skip-end-to-end
 *   bun run scripts/report_elk_crossing_strategy_grid.ts --trials 1,5 --passes 4,6 --kernels default --policies default,objective-improves
 *   bun run scripts/report_elk_crossing_strategy_grid.ts --profiles default,none
 */

import { readdirSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type SweepKernel = 'default' | 'neighbor-median' | 'edge-slot'
type TrialPolicy = 'default' | 'pass-changes' | 'objective-improves'
type LocalRefinementProfile =
  | 'default'
  | 'none'
  | 'adjacent-swap'
  | 'rank-permutation'
  | 'adjacent-swap-then-rank-permutation'

type CliOptions = {
  trials: number[]
  passes: number[]
  kernels: SweepKernel[]
  policies: TrialPolicy[]
  profiles: LocalRefinementProfile[]
  skipEndToEnd: boolean
}

type CrossingSummary = {
  finalOrderMismatch: number
  finalOrderComparable: number
  finalCompositionMismatch: number
  finalCompositionComparable: number
  finalAvgExactOrderMatchRate: number
  finalAvgOrderDisplacement: number
}

type EndToEndSummary = {
  avgWeightedGapIndex: number
  avgLogicalCrossingMultiplier: number
  totalMajorRankCompositionMismatches: number
  structuralOk: number
  fixtures: number
}

type CandidateResult = {
  trialCount: number
  sweepPassCount: number
  sweepKernel: SweepKernel
  trialPolicy: TrialPolicy
  localRefinementProfile: LocalRefinementProfile
  crossing: CrossingSummary
  endToEnd?: EndToEndSummary
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

function parseCsvPositiveInts(raw: string, flag: string): number[] {
  const values = raw
    .split(',')
    .map(item => item.trim())
    .filter(item => item !== '')
  if (values.length === 0) fail(`empty ${flag} list`)
  const parsed: number[] = []
  for (const value of values) {
    const n = Number.parseInt(value, 10)
    if (!Number.isFinite(n) || n <= 0) {
      fail(`invalid ${flag} value: ${value}`)
    }
    parsed.push(n)
  }
  return [...new Set(parsed)]
}

function parseKernelCsv(raw: string): SweepKernel[] {
  const values = raw
    .split(',')
    .map(item => item.trim().toLowerCase())
    .filter(item => item !== '')
  if (values.length === 0) fail('empty --kernels list')
  const parsed: SweepKernel[] = []
  for (const value of values) {
    if (
      value !== 'default' &&
      value !== 'neighbor-median' &&
      value !== 'edge-slot'
    ) {
      fail(`invalid --kernels value: ${value}`)
    }
    parsed.push(value)
  }
  return [...new Set(parsed)]
}

function parsePolicyCsv(raw: string): TrialPolicy[] {
  const values = raw
    .split(',')
    .map(item => item.trim().toLowerCase())
    .filter(item => item !== '')
  if (values.length === 0) fail('empty --policies list')
  const parsed: TrialPolicy[] = []
  for (const value of values) {
    if (
      value !== 'default' &&
      value !== 'pass-changes' &&
      value !== 'objective-improves'
    ) {
      fail(`invalid --policies value: ${value}`)
    }
    parsed.push(value)
  }
  return [...new Set(parsed)]
}

function parseProfileCsv(raw: string): LocalRefinementProfile[] {
  const values = raw
    .split(',')
    .map(item => item.trim().toLowerCase())
    .filter(item => item !== '')
  if (values.length === 0) fail('empty --profiles list')
  const parsed: LocalRefinementProfile[] = []
  for (const value of values) {
    if (
      value !== 'default' &&
      value !== 'none' &&
      value !== 'adjacent-swap' &&
      value !== 'rank-permutation' &&
      value !== 'adjacent-swap-then-rank-permutation'
    ) {
      fail(`invalid --profiles value: ${value}`)
    }
    parsed.push(value)
  }
  return [...new Set(parsed)]
}

function parseCliOptions(args: string[]): CliOptions {
  let trials: number[] = [1, 2, 5]
  let passes: number[] = [4, 5, 6]
  let kernels: SweepKernel[] = ['default', 'neighbor-median']
  let policies: TrialPolicy[] = ['default', 'objective-improves']
  let profiles: LocalRefinementProfile[] = ['default']
  let skipEndToEnd = false
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--trials') {
      const next = args[i + 1]
      if (!next) fail('missing value after --trials')
      trials = parseCsvPositiveInts(next, '--trials')
      i += 1
      continue
    }
    if (arg.startsWith('--trials=')) {
      trials = parseCsvPositiveInts(arg.slice('--trials='.length), '--trials')
      continue
    }
    if (arg === '--passes') {
      const next = args[i + 1]
      if (!next) fail('missing value after --passes')
      passes = parseCsvPositiveInts(next, '--passes')
      i += 1
      continue
    }
    if (arg.startsWith('--passes=')) {
      passes = parseCsvPositiveInts(arg.slice('--passes='.length), '--passes')
      continue
    }
    if (arg === '--kernels') {
      const next = args[i + 1]
      if (!next) fail('missing value after --kernels')
      kernels = parseKernelCsv(next)
      i += 1
      continue
    }
    if (arg.startsWith('--kernels=')) {
      kernels = parseKernelCsv(arg.slice('--kernels='.length))
      continue
    }
    if (arg === '--policies') {
      const next = args[i + 1]
      if (!next) fail('missing value after --policies')
      policies = parsePolicyCsv(next)
      i += 1
      continue
    }
    if (arg.startsWith('--policies=')) {
      policies = parsePolicyCsv(arg.slice('--policies='.length))
      continue
    }
    if (arg === '--profiles') {
      const next = args[i + 1]
      if (!next) fail('missing value after --profiles')
      profiles = parseProfileCsv(next)
      i += 1
      continue
    }
    if (arg.startsWith('--profiles=')) {
      profiles = parseProfileCsv(arg.slice('--profiles='.length))
      continue
    }
    if (arg === '--skip-end-to-end') {
      skipEndToEnd = true
      continue
    }
    fail(`unknown argument: ${arg}`)
  }
  return {
    trials,
    passes,
    kernels,
    policies,
    profiles,
    skipEndToEnd,
  }
}

function parseRatio(line: string, prefix: string): [number, number] {
  const raw = line.slice(prefix.length)
  const match = /^(\d+)\/(\d+)$/.exec(raw)
  if (!match) {
    fail(`invalid ratio line for ${prefix}: ${line}`)
  }
  const left = Number.parseInt(match[1]!, 10)
  const right = Number.parseInt(match[2]!, 10)
  if (!Number.isFinite(left) || !Number.isFinite(right) || right <= 0) {
    fail(`invalid ratio value for ${prefix}: ${line}`)
  }
  return [left, right]
}

function parseFloatLine(line: string, prefix: string): number {
  const raw = line.slice(prefix.length)
  const value = Number.parseFloat(raw)
  if (!Number.isFinite(value)) {
    fail(`invalid float line for ${prefix}: ${line}`)
  }
  return value
}

function parseCrossingSummary(stdout: string): CrossingSummary {
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')
  const finalOrderLine = lines.find(line =>
    line.startsWith('final_total_order_mismatch='),
  )
  if (!finalOrderLine) fail('missing final_total_order_mismatch line')
  const [finalOrderMismatch, finalOrderComparable] = parseRatio(
    finalOrderLine,
    'final_total_order_mismatch=',
  )
  const finalCompositionLine = lines.find(line =>
    line.startsWith('final_total_composition_mismatch='),
  )
  if (!finalCompositionLine) fail('missing final_total_composition_mismatch line')
  const [finalCompositionMismatch, finalCompositionComparable] = parseRatio(
    finalCompositionLine,
    'final_total_composition_mismatch=',
  )
  const finalExactOrderLine = lines.find(line =>
    line.startsWith('final_avg_exact_order_match_rate='),
  )
  if (!finalExactOrderLine) fail('missing final_avg_exact_order_match_rate line')
  const finalAvgExactOrderMatchRate = parseFloatLine(
    finalExactOrderLine,
    'final_avg_exact_order_match_rate=',
  )
  const finalDisplacementLine = lines.find(line =>
    line.startsWith('final_avg_order_displacement='),
  )
  if (!finalDisplacementLine) fail('missing final_avg_order_displacement line')
  const finalAvgOrderDisplacement = parseFloatLine(
    finalDisplacementLine,
    'final_avg_order_displacement=',
  )
  return {
    finalOrderMismatch,
    finalOrderComparable,
    finalCompositionMismatch,
    finalCompositionComparable,
    finalAvgExactOrderMatchRate,
    finalAvgOrderDisplacement,
  }
}

function parseEndToEndSummary(stdout: string): EndToEndSummary {
  const lines = stdout
    .split('\n')
    .map(line => line.trim())
    .filter(line => line !== '')

  const structuralLine = lines.find(line => line.startsWith('fixtures='))
  if (!structuralLine) fail('missing compare_layout_stress fixtures summary line')
  const structuralMatch = /^fixtures=(\d+)\s+structural_ok=(\d+)\/(\d+)$/.exec(
    structuralLine,
  )
  if (!structuralMatch) {
    fail(`invalid structural summary line: ${structuralLine}`)
  }
  const fixtures = Number.parseInt(structuralMatch[1]!, 10)
  const structuralOk = Number.parseInt(structuralMatch[2]!, 10)
  const structuralComparable = Number.parseInt(structuralMatch[3]!, 10)
  if (
    !Number.isFinite(fixtures) ||
    !Number.isFinite(structuralOk) ||
    !Number.isFinite(structuralComparable)
  ) {
    fail(`invalid structural counters: ${structuralLine}`)
  }

  const rankLine = lines.find(line =>
    line.startsWith('avg_major_rank_exact_match_rate='),
  )
  if (!rankLine) fail('missing major rank summary line')
  const rankMatch =
    /^avg_major_rank_exact_match_rate=([0-9.]+)\s+avg_major_rank_displacement=[0-9.]+\s+total_major_rank_composition_mismatches=(\d+)$/.exec(
      rankLine,
    )
  if (!rankMatch) {
    fail(`invalid major rank summary line: ${rankLine}`)
  }
  const totalMajorRankCompositionMismatches = Number.parseInt(rankMatch[2]!, 10)
  if (!Number.isFinite(totalMajorRankCompositionMismatches)) {
    fail(`invalid rank composition mismatch count: ${rankLine}`)
  }

  const logicalLine = lines.find(line =>
    line.startsWith('avg_logical_crossing_multiplier='),
  )
  if (!logicalLine) fail('missing avg_logical_crossing_multiplier line')
  const avgLogicalCrossingMultiplier = parseFloatLine(
    logicalLine,
    'avg_logical_crossing_multiplier=',
  )

  const weightedGapLine = lines.find(line =>
    line.startsWith('avg_weighted_gap_index='),
  )
  if (!weightedGapLine) fail('missing avg_weighted_gap_index line')
  const weightedGapMatch =
    /^avg_weighted_gap_index=([0-9.]+)\s+max_weighted_gap_index=[0-9.]+$/.exec(
      weightedGapLine,
    )
  if (!weightedGapMatch) {
    fail(`invalid avg_weighted_gap_index summary line: ${weightedGapLine}`)
  }
  const avgWeightedGapIndex = Number.parseFloat(weightedGapMatch[1]!)
  if (!Number.isFinite(avgWeightedGapIndex)) {
    fail(`invalid avg_weighted_gap_index value: ${weightedGapLine}`)
  }

  return {
    avgWeightedGapIndex,
    avgLogicalCrossingMultiplier,
    totalMajorRankCompositionMismatches,
    structuralOk,
    fixtures: fixtures === structuralComparable ? fixtures : structuralComparable,
  }
}

function discoverStressFixtures(): string[] {
  return readdirSync('fixtures')
    .filter(name => name.startsWith('layout_stress_') && name.endsWith('.mmd'))
    .sort()
    .map(name => `fixtures/${name}`)
}

function crossingArgs(
  fixtures: string[],
  trialCount: number,
  sweepPassCount: number,
  sweepKernel: SweepKernel,
  trialPolicy: TrialPolicy,
  localRefinementProfile: LocalRefinementProfile,
): string[] {
  const args = [
    'run',
    'scripts/compare_elk_crossing_phase_trace.ts',
    ...fixtures,
    '--trial-count',
    String(trialCount),
    '--sweep-pass-count',
    String(sweepPassCount),
  ]
  if (sweepKernel !== 'default') {
    args.push('--sweep-kernel', sweepKernel)
  }
  if (trialPolicy !== 'default') {
    args.push('--trial-continuation-policy', trialPolicy)
  }
  if (localRefinementProfile !== 'default') {
    args.push('--local-refinement-profile', localRefinementProfile)
  }
  return args
}

function endToEndArgs(
  trialCount: number,
  sweepPassCount: number,
  sweepKernel: SweepKernel,
  trialPolicy: TrialPolicy,
  localRefinementProfile: LocalRefinementProfile,
): string[] {
  const args = [
    'run',
    'scripts/compare_layout_stress.ts',
    '--local-layout-engine',
    'elk',
    '--official-flowchart-renderer',
    'elk',
    '--include-rank-layers',
    '--elk-trial-count',
    String(trialCount),
    '--elk-sweep-pass-count',
    String(sweepPassCount),
  ]
  if (sweepKernel !== 'default') {
    args.push('--elk-sweep-kernel', sweepKernel)
  }
  if (trialPolicy !== 'default') {
    args.push('--elk-trial-continuation-policy', trialPolicy)
  }
  if (localRefinementProfile !== 'default') {
    args.push('--elk-local-refinement-profile', localRefinementProfile)
  }
  return args
}

function runCandidate(
  fixtures: string[],
  trialCount: number,
  sweepPassCount: number,
  sweepKernel: SweepKernel,
  trialPolicy: TrialPolicy,
  localRefinementProfile: LocalRefinementProfile,
  skipEndToEnd: boolean,
): CandidateResult {
  const crossingStdout = runOrThrow(
    'bun',
    crossingArgs(
      fixtures,
      trialCount,
      sweepPassCount,
      sweepKernel,
      trialPolicy,
      localRefinementProfile,
    ),
  )
  const crossing = parseCrossingSummary(crossingStdout)
  if (skipEndToEnd) {
    return {
      trialCount,
      sweepPassCount,
      sweepKernel,
      trialPolicy,
      localRefinementProfile,
      crossing,
    }
  }
  const endToEndStdout = runOrThrow(
    'bun',
    endToEndArgs(
      trialCount,
      sweepPassCount,
      sweepKernel,
      trialPolicy,
      localRefinementProfile,
    ),
  )
  const endToEnd = parseEndToEndSummary(endToEndStdout)
  return {
    trialCount,
    sweepPassCount,
    sweepKernel,
    trialPolicy,
    localRefinementProfile,
    crossing,
    endToEnd,
  }
}

function candidateTag(result: CandidateResult): string {
  return `trial=${result.trialCount} pass=${result.sweepPassCount} kernel=${result.sweepKernel} policy=${result.trialPolicy} profile=${result.localRefinementProfile}`
}

function printRow(result: CandidateResult): void {
  const crossing = result.crossing
  const base = [
    candidateTag(result),
    `final_order=${crossing.finalOrderMismatch}/${crossing.finalOrderComparable}`,
    `final_comp=${crossing.finalCompositionMismatch}/${crossing.finalCompositionComparable}`,
    `exact=${crossing.finalAvgExactOrderMatchRate.toFixed(4)}`,
    `disp=${crossing.finalAvgOrderDisplacement.toFixed(4)}`,
  ]
  if (!result.endToEnd) {
    console.log(base.join('  '))
    return
  }
  base.push(
    `wgap=${result.endToEnd.avgWeightedGapIndex.toFixed(4)}`,
    `logical=${result.endToEnd.avgLogicalCrossingMultiplier.toFixed(4)}`,
    `major_comp=${result.endToEnd.totalMajorRankCompositionMismatches}`,
    `struct=${result.endToEnd.structuralOk}/${result.endToEnd.fixtures}`,
  )
  console.log(base.join('  '))
}

function compareResult(a: CandidateResult, b: CandidateResult): number {
  if (a.crossing.finalOrderMismatch !== b.crossing.finalOrderMismatch) {
    return a.crossing.finalOrderMismatch - b.crossing.finalOrderMismatch
  }
  if (
    a.crossing.finalCompositionMismatch !== b.crossing.finalCompositionMismatch
  ) {
    return a.crossing.finalCompositionMismatch - b.crossing.finalCompositionMismatch
  }
  if (!!a.endToEnd && !!b.endToEnd) {
    if (a.endToEnd.avgWeightedGapIndex !== b.endToEnd.avgWeightedGapIndex) {
      return a.endToEnd.avgWeightedGapIndex - b.endToEnd.avgWeightedGapIndex
    }
    if (
      a.endToEnd.avgLogicalCrossingMultiplier !==
      b.endToEnd.avgLogicalCrossingMultiplier
    ) {
      return (
        a.endToEnd.avgLogicalCrossingMultiplier -
        b.endToEnd.avgLogicalCrossingMultiplier
      )
    }
  }
  return (
    b.crossing.finalAvgExactOrderMatchRate -
    a.crossing.finalAvgExactOrderMatchRate
  )
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const fixtures = discoverStressFixtures()
  if (fixtures.length === 0) {
    fail('no layout_stress fixtures discovered')
  }

  const results: CandidateResult[] = []
  for (const trialCount of options.trials) {
    for (const sweepPassCount of options.passes) {
      for (const sweepKernel of options.kernels) {
        for (const trialPolicy of options.policies) {
          for (const localRefinementProfile of options.profiles) {
            if (trialPolicy === 'pass-changes') {
              // Same behavior as default policy; keep one representative.
              continue
            }
            const result = runCandidate(
              fixtures,
              trialCount,
              sweepPassCount,
              sweepKernel,
              trialPolicy,
              localRefinementProfile,
              options.skipEndToEnd,
            )
            results.push(result)
          }
        }
      }
    }
  }

  results.sort(compareResult)
  console.log('=== elk crossing strategy grid ===')
  console.log(`fixtures=${fixtures.length}`)
  console.log(`candidates=${results.length}`)
  if (options.skipEndToEnd) {
    console.log('mode=crossing-only')
  } else {
    console.log('mode=crossing+end-to-end')
  }
  for (const result of results) {
    printRow(result)
  }
}

main()
