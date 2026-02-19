/**
 * Report ELK rank-layer parity gaps against official ELK per stress fixture.
 *
 * Usage:
 *   bun run scripts/report_elk_rank_gap.ts
 *   bun run scripts/report_elk_rank_gap.ts --top 10
 *   bun run scripts/report_elk_rank_gap.ts --json /tmp/elk.json
 */

import { mkdtempSync, readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type CliOptions = {
  jsonPath?: string
  top: number
  passThroughArgs: string[]
}

type StressResult = {
  fixture: string
  status: string
  weightedGapIndex: number
  majorRankExactMatchRate: number
  majorRankAvgDisplacement: number
  majorRankCompositionMismatchCount: number
  majorInversionRate: number
  majorSpanRatio: number
  minorSpanRatio: number
}

type StressReport = {
  results: StressResult[]
}

function fail(message: string): never {
  throw new Error(message)
}

function parsePositiveInt(raw: string, flag: string): number {
  const value = Number.parseInt(raw, 10)
  if (!Number.isFinite(value) || value <= 0) {
    fail(`invalid ${flag} value '${raw}', expected positive integer`)
  }
  return value
}

function parseArgs(args: string[]): CliOptions {
  let jsonPath: string | undefined
  let top = 8
  const passThroughArgs: string[] = []

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
      jsonPath = arg.slice('--json='.length)
      if (jsonPath === '') fail('missing path after --json=')
      continue
    }
    if (arg === '--top') {
      const next = args[i + 1]
      if (!next) fail('missing number after --top')
      top = parsePositiveInt(next, '--top')
      i += 1
      continue
    }
    if (arg.startsWith('--top=')) {
      top = parsePositiveInt(arg.slice('--top='.length), '--top')
      continue
    }
    passThroughArgs.push(arg)
  }

  return { jsonPath, top, passThroughArgs }
}

function runStressToJson(path: string, passThroughArgs: string[]): void {
  const args = [
    'run',
    'scripts/compare_layout_stress.ts',
    '--local-layout-engine',
    'elk',
    '--official-flowchart-renderer',
    'elk',
    '--include-rank-layers',
    '--json',
    path,
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
    const parts = ['elk stress compare failed']
    if (stderr !== '') parts.push(`stderr:\n${stderr}`)
    if (stdout !== '') parts.push(`stdout:\n${stdout}`)
    fail(parts.join('\n'))
  }
}

function round(value: number): string {
  return Number.isFinite(value) ? value.toFixed(4) : 'NaN'
}

function rankWeight(result: StressResult): number {
  return (
    result.weightedGapIndex * 1000 +
    result.majorRankCompositionMismatchCount * 10 +
    (1 - result.majorRankExactMatchRate) * 100 +
    result.majorRankAvgDisplacement * 10
  )
}

function main(): void {
  const options = parseArgs(process.argv.slice(2))
  const reportPath =
    options.jsonPath ?? join(mkdtempSync(join(tmpdir(), 'elk-rank-gap-')), 'elk.json')

  if (!options.jsonPath) {
    runStressToJson(reportPath, options.passThroughArgs)
  }

  const report = JSON.parse(readFileSync(reportPath, 'utf8')) as StressReport
  const results = report.results ?? []
  if (results.length === 0) {
    fail(`no results found in ${reportPath}`)
  }

  const structuralFailures = results.filter(row => row.status !== 'ok')
  const ranked = results
    .slice()
    .sort((left, right) => {
      const leftWeight = rankWeight(left)
      const rightWeight = rankWeight(right)
      if (leftWeight !== rightWeight) {
        return rightWeight - leftWeight
      }
      return left.fixture.localeCompare(right.fixture)
    })

  const topRows = ranked.slice(0, Math.min(options.top, ranked.length))
  const rankHeavyCount = results.filter(
    row => row.majorRankCompositionMismatchCount >= 10,
  ).length
  const highGapCount = results.filter(row => row.weightedGapIndex >= 0.25).length

  console.log('=== elk rank-gap report ===')
  console.log(`fixtures=${results.length} structural_failures=${structuralFailures.length}`)
  console.log(`rank_heavy_fixtures(composition>=10)=${rankHeavyCount}`)
  console.log(`high_weighted_gap_fixtures(weighted>=0.25)=${highGapCount}`)
  console.log(`source_json=${reportPath}`)
  console.log('')
  console.log('top fixtures by rank-gap pressure:')
  for (const row of topRows) {
    console.log(
      [
        `- ${row.fixture}`,
        `status=${row.status}`,
        `weighted=${round(row.weightedGapIndex)}`,
        `exact=${round(row.majorRankExactMatchRate)}`,
        `disp=${round(row.majorRankAvgDisplacement)}`,
        `composition=${row.majorRankCompositionMismatchCount}`,
        `majorInv=${round(row.majorInversionRate)}`,
        `majorSpan=${round(row.majorSpanRatio)}`,
        `minorSpan=${round(row.minorSpanRatio)}`,
      ].join(' '),
    )
  }
}

main()
