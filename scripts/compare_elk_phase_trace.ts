/**
 * Compare local ELK rank/cycle trace against official Mermaid ELK rank layers.
 *
 * This script is phase-focused:
 * - local intermediate output comes from `cmd/elk_trace`
 * - official reference layers come from `compare_layout_stress.ts --include-rank-layers`
 *
 * Usage:
 *   bun run scripts/compare_elk_phase_trace.ts fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd
 *   bun run scripts/compare_elk_phase_trace.ts fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 *   bun run scripts/compare_elk_phase_trace.ts --json /tmp/elk_phase_trace.json fixtures/layout_stress_012_interleaved_subgraph_feedback.mmd
 */

import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'

type FixtureEdge = { source: string; target: string }
type ParsedFixtureEdges = { edges: FixtureEdge[]; unparsedEdgeLines: string[] }
type Layering = string[][]

type LocalTrace = {
  seedStrategy: string
  rankLayers: Layering
  orientedEdges: Set<string>
  modelOrderOrientedEdges: Set<string>
}

type OfficialResult = {
  fixture: string
  graphDirection: string
  majorRankLayersOfficialDetail: Layering
}

type OrientationMetrics = {
  comparable: number
  matched: number
  mismatched: number
  missing: number
  matchRate: number
}

type CaseMetrics = {
  fixture: string
  direction: string
  seedStrategy: string
  layerExactMatchRate: number
  layerAvgDisplacement: number
  layerCompositionMismatchCount: number
  seedOrientation: OrientationMetrics
  modelOrderOrientation: OrientationMetrics
}

type CliOptions = {
  fixtures: string[]
  jsonPath?: string
}

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(cmd: string, args: string[], timeoutMs = 300_000): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 32 * 1024 * 1024,
    timeout: timeoutMs,
  })
  if (result.error) {
    fail(
      [
        `command failed: ${cmd} ${args.join(' ')}`,
        `error: ${String(result.error)}`,
      ].join('\n'),
    )
  }
  if (result.status !== 0) {
    const stdout = (result.stdout ?? '').toString().trim()
    const stderr = (result.stderr ?? '').toString().trim()
    fail(
      [
        `command failed: ${cmd} ${args.join(' ')}`,
        stderr === '' ? '' : `stderr:\n${stderr}`,
        stdout === '' ? '' : `stdout:\n${stdout}`,
      ]
        .filter(Boolean)
        .join('\n'),
    )
  }
  return (result.stdout ?? '').toString()
}

function parseFixtureEdges(source: string): ParsedFixtureEdges {
  const parseEndpoint = (raw: string): string | null => {
    let token = raw.trim()
    if (token === '') return null
    token = token.split(':::')[0]!.trim()
    const shapeMetaIndex = token.indexOf('@{')
    if (shapeMetaIndex >= 0) token = token.slice(0, shapeMetaIndex).trim()
    const idMatch = token.match(/^([A-Za-z0-9_./:#-]+)/)
    return idMatch ? idMatch[1]! : null
  }

  const parseEdgeLine = (line: string): FixtureEdge[] | null => {
    const patterns: RegExp[] = [
      /^\s*(.+?)\s*-->\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-\.\->\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*===>\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*==>\s*\|[^|]*\|\s*(.+?)\s*$/,
      /^\s*(.+?)\s*--\s*(?:\[[^\]]*\]|"[^"]*"|'[^']*'|\|[^|]*\|)?\s*-->\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-\.\->\s*(.+?)\s*$/,
      /^\s*(.+?)\s*-->\s*(.+?)\s*$/,
      /^\s*(.+?)\s*---\s*(.+?)\s*$/,
      /^\s*(.+?)\s*===>\s*(.+?)\s*$/,
      /^\s*(.+?)\s*==>\s*(.+?)\s*$/,
    ]
    for (const pattern of patterns) {
      const match = line.match(pattern)
      if (!match) continue
      const sourceId = parseEndpoint(match[1]!)
      const targetId = parseEndpoint(match[2]!)
      if (!sourceId || !targetId) return null
      return [{ source: sourceId, target: targetId }]
    }
    return null
  }

  const looksLikeEdgeCandidate = (line: string): boolean =>
    /-->|-\.\->|==>|===>|---/.test(line)

  const edges: FixtureEdge[] = []
  const unparsedEdgeLines: string[] = []
  const dedupe = new Set<string>()

  for (const rawLine of source.split('\n')) {
    const line = rawLine.split('%%')[0]!.trim()
    if (
      line === '' ||
      line.startsWith('graph ') ||
      line.startsWith('flowchart ') ||
      line.startsWith('subgraph ') ||
      line === 'end'
    ) {
      continue
    }
    const parsed = parseEdgeLine(line)
    if (!parsed) {
      if (looksLikeEdgeCandidate(line)) unparsedEdgeLines.push(line)
      continue
    }
    for (const edge of parsed) {
      const key = `${edge.source}->${edge.target}`
      if (dedupe.has(key)) continue
      dedupe.add(key)
      edges.push(edge)
    }
  }
  return { edges, unparsedEdgeLines }
}

function parseLocalTrace(source: string): LocalTrace {
  const stdout = runOrThrow('moon', [
    'run',
    'cmd/elk_trace',
    '--target',
    'native',
    '--',
    '--source',
    source,
  ])
  const rankLayersByRank = new Map<number, string[]>()
  const orientedEdges = new Set<string>()
  const modelOrderOrientedEdges = new Set<string>()
  let seedStrategy = ''

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    if (parts[0] === 'SEED') {
      seedStrategy = parts[1] ?? ''
      continue
    }
    if (parts[0] === 'SEED_LAYER') {
      const rank = Number.parseInt(parts[1] ?? '', 10)
      if (!Number.isFinite(rank)) fail(`invalid SEED_LAYER rank line: ${line}`)
      const nodes = (parts[2] ?? '') === '' ? [] : (parts[2] ?? '').split(',')
      rankLayersByRank.set(rank, nodes)
      continue
    }
    if (parts[0] === 'SEED_EDGE') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') orientedEdges.add(`${sourceId}->${targetId}`)
      continue
    }
    if (parts[0] === 'FEEDBACK_EDGE_MODEL_ORDER') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        modelOrderOrientedEdges.add(`${sourceId}->${targetId}`)
      }
      continue
    }
  }

  if (rankLayersByRank.size === 0) fail('local trace missing SEED_LAYER output')

  const maxRank = Math.max(...rankLayersByRank.keys())
  const rankLayers: Layering = []
  for (let rank = 0; rank <= maxRank; rank += 1) {
    rankLayers.push(rankLayersByRank.get(rank) ?? [])
  }

  return {
    seedStrategy,
    rankLayers,
    orientedEdges,
    modelOrderOrientedEdges:
      modelOrderOrientedEdges.size === 0
        ? new Set([...orientedEdges])
        : modelOrderOrientedEdges,
  }
}

function layeringToRankMap(layers: Layering): Map<string, number> {
  const rankByNodeId = new Map<string, number>()
  layers.forEach((layer, rank) => {
    layer.forEach(nodeId => rankByNodeId.set(nodeId, rank))
  })
  return rankByNodeId
}

function layeringToOrderMap(layers: Layering): Map<string, number> {
  const orderByNodeId = new Map<string, number>()
  layers.forEach(layer => {
    layer.forEach((nodeId, index) => orderByNodeId.set(nodeId, index))
  })
  return orderByNodeId
}

function rankLayerMismatchCount(left: Layering, right: Layering): number {
  const maxLayerCount = Math.max(left.length, right.length)
  let mismatchCount = 0
  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const leftLayer = left[rank] ?? []
    const rightLayer = right[rank] ?? []
    if (JSON.stringify(leftLayer) !== JSON.stringify(rightLayer)) mismatchCount += 1
  }
  return mismatchCount
}

function layerParityMetrics(localLayers: Layering, officialLayers: Layering): {
  exactMatchRate: number
  avgDisplacement: number
  compositionMismatch: number
} {
  const localRankByNodeId = layeringToRankMap(localLayers)
  const officialRankByNodeId = layeringToRankMap(officialLayers)
  let sharedNodeCount = 0
  let exactMatchCount = 0
  let displacementSum = 0
  for (const [nodeId, officialRank] of officialRankByNodeId.entries()) {
    const localRank = localRankByNodeId.get(nodeId)
    if (localRank === undefined) continue
    sharedNodeCount += 1
    if (localRank === officialRank) exactMatchCount += 1
    displacementSum += Math.abs(localRank - officialRank)
  }
  return {
    exactMatchRate: sharedNodeCount === 0 ? 0 : exactMatchCount / sharedNodeCount,
    avgDisplacement: sharedNodeCount === 0 ? 0 : displacementSum / sharedNodeCount,
    compositionMismatch: rankLayerMismatchCount(localLayers, officialLayers),
  }
}

function deriveOrientedEdgesFromLayers(edges: FixtureEdge[], layers: Layering): Set<string> {
  const oriented = new Set<string>()
  const rankByNodeId = layeringToRankMap(layers)
  const orderByNodeId = layeringToOrderMap(layers)
  for (const edge of edges) {
    const sourceRank = rankByNodeId.get(edge.source)
    const targetRank = rankByNodeId.get(edge.target)
    if (sourceRank === undefined || targetRank === undefined) continue
    if (sourceRank < targetRank) {
      oriented.add(`${edge.source}->${edge.target}`)
      continue
    }
    if (sourceRank > targetRank) {
      oriented.add(`${edge.target}->${edge.source}`)
      continue
    }
    const sourceOrder = orderByNodeId.get(edge.source) ?? 0
    const targetOrder = orderByNodeId.get(edge.target) ?? 0
    if (sourceOrder <= targetOrder) oriented.add(`${edge.source}->${edge.target}`)
    else oriented.add(`${edge.target}->${edge.source}`)
  }
  return oriented
}

function orientationParity(
  fixtureEdges: FixtureEdge[],
  localOrientedEdges: Set<string>,
  officialOrientedEdges: Set<string>,
): OrientationMetrics {
  let comparable = 0
  let matched = 0
  let mismatched = 0
  let missing = 0
  for (const edge of fixtureEdges) {
    const forward = `${edge.source}->${edge.target}`
    const reverse = `${edge.target}->${edge.source}`
    const local =
      localOrientedEdges.has(forward) ? 1 : localOrientedEdges.has(reverse) ? -1 : 0
    const official =
      officialOrientedEdges.has(forward) ? 1 : officialOrientedEdges.has(reverse) ? -1 : 0
    if (local === 0 || official === 0) {
      missing += 1
      continue
    }
    comparable += 1
    if (local === official) matched += 1
    else mismatched += 1
  }
  return {
    comparable,
    matched,
    mismatched,
    missing,
    matchRate: comparable === 0 ? 0 : matched / comparable,
  }
}

function parseCliOptions(args: string[]): CliOptions {
  const fixtures: string[] = []
  let jsonPath: string | undefined
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--json') {
      const value = args[i + 1]
      if (!value) fail('missing value for --json')
      jsonPath = value
      i += 1
      continue
    }
    if (arg.startsWith('--json=')) {
      jsonPath = arg.slice('--json='.length)
      continue
    }
    if (arg.startsWith('--')) fail(`unknown option: ${arg}`)
    fixtures.push(arg)
  }
  if (fixtures.length === 0) {
    fail('usage: bun run scripts/compare_elk_phase_trace.ts [--json <path>] <fixture.mmd> [more...]')
  }
  return { fixtures, jsonPath }
}

function collectOfficialResults(fixtures: string[]): Map<string, OfficialResult> {
  const tempRoot = mkdtempSync(join(tmpdir(), 'elk-phase-trace-official-'))
  const jsonPath = join(tempRoot, 'official.json')
  runOrThrow('bun', [
    'run',
    'scripts/compare_layout_stress.ts',
    ...fixtures,
    '--local-layout-engine',
    'elk-layered',
    '--official-flowchart-renderer',
    'elk',
    '--include-rank-layers',
    '--json',
    jsonPath,
  ])
  const parsed = JSON.parse(readFileSync(jsonPath, 'utf8')) as {
    results?: Array<Record<string, unknown>>
  }
  const results = parsed.results ?? []
  const byFixture = new Map<string, OfficialResult>()
  for (const row of results) {
    const fixture = typeof row.fixture === 'string' ? row.fixture : ''
    const graphDirection =
      typeof row.graphDirection === 'string' ? row.graphDirection : 'UNKNOWN'
    const details = row.majorRankLayersOfficialDetail
    if (fixture === '' || !Array.isArray(details)) continue
    const layers: Layering = []
    for (const maybeLayer of details) {
      if (!Array.isArray(maybeLayer)) continue
      const layer = maybeLayer.filter(value => typeof value === 'string') as string[]
      layers.push(layer)
    }
    byFixture.set(fixture, {
      fixture,
      graphDirection,
      majorRankLayersOfficialDetail: layers,
    })
  }
  return byFixture
}

function compareFixture(fixturePath: string, official: OfficialResult): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const parsedEdges = parseFixtureEdges(source)
  if (parsedEdges.unparsedEdgeLines.length > 0) {
    fail(
      [
        `fixture has unparsed edge lines: ${fixturePath}`,
        ...parsedEdges.unparsedEdgeLines.slice(0, 5).map(line => `  ${line}`),
      ].join('\n'),
    )
  }
  const localTrace = parseLocalTrace(source)
  const officialLayers = official.majorRankLayersOfficialDetail
  const layerParity = layerParityMetrics(localTrace.rankLayers, officialLayers)
  const officialOrientedEdges = deriveOrientedEdgesFromLayers(parsedEdges.edges, officialLayers)
  const seedOrientation = orientationParity(
    parsedEdges.edges,
    localTrace.orientedEdges,
    officialOrientedEdges,
  )
  const modelOrderOrientation = orientationParity(
    parsedEdges.edges,
    localTrace.modelOrderOrientedEdges,
    officialOrientedEdges,
  )
  return {
    fixture: fixturePath,
    direction: official.graphDirection,
    seedStrategy: localTrace.seedStrategy,
    layerExactMatchRate: layerParity.exactMatchRate,
    layerAvgDisplacement: layerParity.avgDisplacement,
    layerCompositionMismatchCount: layerParity.compositionMismatch,
    seedOrientation,
    modelOrderOrientation,
  }
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const officialByFixture = collectOfficialResults(options.fixtures)
  const results: CaseMetrics[] = []

  for (const fixturePath of options.fixtures) {
    const official = officialByFixture.get(fixturePath)
    if (!official) fail(`missing official rank layers for fixture: ${fixturePath}`)
    results.push(compareFixture(fixturePath, official))
  }

  for (const row of results) {
    console.log(`\n=== ${row.fixture} ===`)
    console.log(`direction=${row.direction} seed_strategy=${row.seedStrategy}`)
    console.log(
      `layers exact=${row.layerExactMatchRate.toFixed(4)} avg_disp=${row.layerAvgDisplacement.toFixed(4)} composition_mismatch=${row.layerCompositionMismatchCount}`,
    )
    console.log(
      `seed_orientation comparable=${row.seedOrientation.comparable} matched=${row.seedOrientation.matched} mismatch=${row.seedOrientation.mismatched} missing=${row.seedOrientation.missing} match_rate=${row.seedOrientation.matchRate.toFixed(4)}`,
    )
    console.log(
      `model_order_orientation comparable=${row.modelOrderOrientation.comparable} matched=${row.modelOrderOrientation.matched} mismatch=${row.modelOrderOrientation.mismatched} missing=${row.modelOrderOrientation.missing} match_rate=${row.modelOrderOrientation.matchRate.toFixed(4)}`,
    )
  }

  const avgLayerExact =
    results.reduce((sum, row) => sum + row.layerExactMatchRate, 0) / results.length
  const avgSeedOrientationMatch =
    results.reduce((sum, row) => sum + row.seedOrientation.matchRate, 0) / results.length
  const avgModelOrientationMatch =
    results.reduce((sum, row) => sum + row.modelOrderOrientation.matchRate, 0) / results.length
  const totalLayerMismatch = results.reduce(
    (sum, row) => sum + row.layerCompositionMismatchCount,
    0,
  )
  const totalSeedComparable = results.reduce(
    (sum, row) => sum + row.seedOrientation.comparable,
    0,
  )
  const totalSeedMismatch = results.reduce(
    (sum, row) => sum + row.seedOrientation.mismatched,
    0,
  )
  const totalModelComparable = results.reduce(
    (sum, row) => sum + row.modelOrderOrientation.comparable,
    0,
  )
  const totalModelMismatch = results.reduce(
    (sum, row) => sum + row.modelOrderOrientation.mismatched,
    0,
  )

  console.log('\n=== summary ===')
  console.log(`fixtures=${results.length}`)
  console.log(`avg_layer_exact_match_rate=${avgLayerExact.toFixed(4)}`)
  console.log(`avg_seed_orientation_match_rate=${avgSeedOrientationMatch.toFixed(4)}`)
  console.log(`avg_model_order_orientation_match_rate=${avgModelOrientationMatch.toFixed(4)}`)
  console.log(`total_layer_composition_mismatch=${totalLayerMismatch}`)
  console.log(`total_seed_orientation_mismatch=${totalSeedMismatch}/${totalSeedComparable}`)
  console.log(
    `total_model_order_orientation_mismatch=${totalModelMismatch}/${totalModelComparable}`,
  )

  if (options.jsonPath) {
    writeFileSync(
      options.jsonPath,
      JSON.stringify(
        {
          generatedAt: new Date().toISOString(),
          results,
          summary: {
            fixtures: results.length,
            avgLayerExact,
            avgSeedOrientationMatch,
            avgModelOrientationMatch,
            totalLayerMismatch,
            totalSeedMismatch,
            totalSeedComparable,
            totalModelMismatch,
            totalModelComparable,
          },
        },
        null,
        2,
      ),
    )
    console.log(`json_report=${options.jsonPath}`)
  }
}

main()
