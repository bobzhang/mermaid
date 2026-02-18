/**
 * Compare local dagre ordering trace against upstream dagre trace kernels.
 *
 * Usage:
 *   bun run scripts/compare_dagre_order_trace.ts
 *   bun run scripts/compare_dagre_order_trace.ts --case case1
 *   bun run scripts/compare_dagre_order_trace.ts --case case2
 *   bun run scripts/compare_dagre_order_trace.ts --case case3
 */

import { spawnSync } from 'node:child_process'

type Layering = string[][]

type PassStep = {
  pass: number
  incomingFromNeighbor: boolean
  biasRight: boolean
  crossings: number
  layering: Layering
}

type TraceResult = {
  trace: Layering[]
  passTrace: PassStep[]
}

type LocalPassState = {
  pass: number
  incomingFromNeighbor: boolean
  biasRight: boolean
  crossings: number
  layers: Map<number, string[]>
}

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(cmd: string, args: string[]): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
  })
  if (result.status !== 0) {
    const stderr = (result.stderr ?? '').toString().trim()
    const stdout = (result.stdout ?? '').toString().trim()
    fail(
      [
        `command failed: ${cmd} ${args.join(' ')}`,
        stderr ? `stderr: ${stderr}` : '',
        stdout ? `stdout: ${stdout}` : '',
      ].filter(Boolean).join('\n'),
    )
  }
  return (result.stdout ?? '').toString()
}

function parseCaseArg(args: string[]): string {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--case') {
      const value = args[i + 1]
      if (!value) {
        fail('missing value for --case')
      }
      return value
    }
    if (arg.startsWith('--case=')) {
      return arg.slice('--case='.length)
    }
  }
  return 'all'
}

function parseBool(raw: string): boolean {
  if (raw === 'true') return true
  if (raw === 'false') return false
  fail(`invalid boolean literal: ${raw}`)
}

function parseIntStrict(raw: string): number {
  const value = Number.parseInt(raw, 10)
  if (!Number.isFinite(value)) {
    fail(`invalid integer literal: ${raw}`)
  }
  return value
}

function parseNodeList(raw: string): string[] {
  if (raw === '') {
    return []
  }
  return raw.split(',')
}

function layeringFromRankMap(rankMap: Map<number, string[]>): Layering {
  if (rankMap.size === 0) {
    return []
  }
  const maxRank = Math.max(...rankMap.keys())
  const layers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    layers.push(rankMap.get(rank) ?? [])
  }
  return layers
}

function parseLocalTraceOutput(stdout: string): TraceResult {
  const traceByIndex = new Map<number, Map<number, string[]>>()
  const passByIndex = new Map<number, LocalPassState>()

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') {
      continue
    }
    const parts = line.split('\t')
    const kind = parts[0]
    if (kind === 'TRACE') {
      if (parts.length < 4) {
        fail(`invalid TRACE line: ${line}`)
      }
      const traceIndex = parseIntStrict(parts[1]!)
      const rank = parseIntStrict(parts[2]!)
      const nodes = parseNodeList(parts[3]!)
      if (!traceByIndex.has(traceIndex)) {
        traceByIndex.set(traceIndex, new Map<number, string[]>())
      }
      traceByIndex.get(traceIndex)!.set(rank, nodes)
      continue
    }
    if (kind === 'PASS') {
      if (parts.length < 5) {
        fail(`invalid PASS line: ${line}`)
      }
      const pass = parseIntStrict(parts[1]!)
      passByIndex.set(pass, {
        pass,
        incomingFromNeighbor: parseBool(parts[2]!),
        biasRight: parseBool(parts[3]!),
        crossings: parseIntStrict(parts[4]!),
        layers: new Map<number, string[]>(),
      })
      continue
    }
    if (kind === 'PASS_LAYER') {
      if (parts.length < 4) {
        fail(`invalid PASS_LAYER line: ${line}`)
      }
      const pass = parseIntStrict(parts[1]!)
      const rank = parseIntStrict(parts[2]!)
      const nodes = parseNodeList(parts[3]!)
      const passState = passByIndex.get(pass)
      if (!passState) {
        fail(`PASS_LAYER before PASS for pass=${pass}`)
      }
      passState.layers.set(rank, nodes)
      continue
    }
    if (kind === 'BARY' || kind === 'CASE') {
      continue
    }
    fail(`unknown trace line: ${line}`)
  }

  const traceIndices = [...traceByIndex.keys()].sort((a, b) => a - b)
  const trace: Layering[] = traceIndices.map(traceIndex =>
    layeringFromRankMap(traceByIndex.get(traceIndex)!),
  )

  const passIndices = [...passByIndex.keys()].sort((a, b) => a - b)
  const passTrace: PassStep[] = passIndices.map(pass => {
    const state = passByIndex.get(pass)!
    return {
      pass: state.pass,
      incomingFromNeighbor: state.incomingFromNeighbor,
      biasRight: state.biasRight,
      crossings: state.crossings,
      layering: layeringFromRankMap(state.layers),
    }
  })

  return { trace, passTrace }
}

function loadUpstreamTrace(caseArg: string): Record<string, TraceResult> {
  const stdout = runOrThrow('bun', ['run', 'scripts/dump_upstream_dagre_order_trace.ts', '--case', caseArg])
  return JSON.parse(stdout) as Record<string, TraceResult>
}

function loadLocalTrace(caseName: string): TraceResult {
  const stdout = runOrThrow('moon', [
    'run',
    'cmd/dagre_trace',
    '--target',
    'native',
    '--',
    '--case',
    caseName,
  ])
  return parseLocalTraceOutput(stdout)
}

function stable(value: unknown): string {
  return JSON.stringify(value, null, 2)
}

function compareCase(
  upstream: TraceResult,
  local: TraceResult,
): string[] {
  const errors: string[] = []
  if (stable(local.trace) !== stable(upstream.trace)) {
    errors.push('trace layering mismatch')
  }
  if (stable(local.passTrace) !== stable(upstream.passTrace)) {
    errors.push('pass trace mismatch')
  }
  return errors
}

function main(): void {
  const caseArg = parseCaseArg(process.argv.slice(2)).toLowerCase()
  const upstreamByCase = loadUpstreamTrace(caseArg)
  const selectedCases = Object.keys(upstreamByCase).sort()
  if (selectedCases.length === 0) {
    fail('no upstream cases selected')
  }

  let mismatchCount = 0
  for (const caseName of selectedCases) {
    const upstream = upstreamByCase[caseName]!
    const local = loadLocalTrace(caseName)
    const errors = compareCase(upstream, local)
    if (errors.length === 0) {
      console.log(`PASS ${caseName}`)
      continue
    }
    mismatchCount += 1
    console.log(`FAIL ${caseName}`)
    errors.forEach(err => console.log(`  - ${err}`))
    console.log('  upstream:')
    console.log(stable(upstream))
    console.log('  local:')
    console.log(stable(local))
  }

  if (mismatchCount > 0) {
    process.exit(1)
  }
}

main()
