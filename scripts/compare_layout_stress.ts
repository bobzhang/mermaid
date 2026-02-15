/**
 * Compare local MoonBit SVG layout against official Mermaid CLI for stress fixtures.
 *
 * Usage:
 *   bun run scripts/compare_layout_stress.ts
 *   bun run scripts/compare_layout_stress.ts fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_layout_stress.ts --json /tmp/layout_stress_metrics.json
 *   bun run scripts/compare_layout_stress.ts --max-logical-crossing-multiplier 1.8
 */

import { mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type Point = { x: number; y: number }
type Bounds = { minX: number; maxX: number; minY: number; maxY: number }
type FixtureEdge = { source: string; target: string }
type LogicalEdgeSegment = {
  source: string
  target: string
  start: Point
  end: Point
}

type Metrics = {
  fixture: string
  fixtureEdges: number
  comparableLogicalEdges: number
  officialNodes: number
  localNodes: number
  sharedNodes: number
  officialEdges: number
  localEdges: number
  rmse: number
  maxDist: number
  inversionRate: number
  localPolylineCrossings: number
  officialPolylineCrossings: number
  localLogicalCrossings: number
  officialLogicalCrossings: number
  logicalCrossingMultiplier: number
  spanXRatio: number
  spanYRatio: number
  status: 'ok' | 'mismatch'
}

type CliOptions = {
  fixtures: string[]
  jsonPath?: string
  maxLogicalCrossingMultiplier?: number
}

const OFFICIAL_TIMEOUT_MS = 120_000
const LOCAL_TIMEOUT_MS = 60_000

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(cmd: string, args: string[], timeoutMs: number, env?: NodeJS.ProcessEnv): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    timeout: timeoutMs,
    maxBuffer: 16 * 1024 * 1024,
    env,
  })
  if (result.error) {
    fail(
      `command failed: ${cmd} ${args.join(' ')}\nerror: ${String(result.error.message ?? result.error)}`,
    )
  }
  if (result.status !== 0) {
    const stderr = (result.stderr ?? '').toString().trim()
    const stdout = (result.stdout ?? '').toString().trim()
    fail(
      [
        `command failed: ${cmd} ${args.join(' ')}`,
        stderr ? `stderr: ${stderr}` : '',
        stdout ? `stdout: ${stdout}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
    )
  }
  return (result.stdout ?? '').toString()
}

function decodeHtml(text: string): string {
  return text
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
}

function normalizeLabel(label: string): string {
  const trimmed = label.trim()
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.slice(1, -1)
  }
  return trimmed
}

function findMatchingGEnd(svg: string, gStartIndex: number): number {
  let depth = 0
  let i = gStartIndex
  while (i < svg.length) {
    const open = svg.indexOf('<g', i)
    const close = svg.indexOf('</g>', i)
    if (open === -1 && close === -1) return -1
    if (open !== -1 && (open < close || close === -1)) {
      depth += 1
      i = open + 2
      continue
    }
    if (close !== -1) {
      depth -= 1
      i = close + 4
      if (depth === 0) return i
    }
  }
  return -1
}

function parseOfficialNodePositions(svg: string): Map<string, Point> {
  const nodes = new Map<string, Point>()
  let searchIndex = 0
  while (true) {
    const gIndex = svg.indexOf('<g class="node ', searchIndex)
    if (gIndex === -1) break
    const gEnd = findMatchingGEnd(svg, gIndex)
    if (gEnd === -1) break
    const chunk = svg.slice(gIndex, gEnd)
    const transformMatch = chunk.match(/transform="translate\(([^,]+), ([^)]+)\)"/)
    const labelMatch = chunk.match(/class="nodeLabel"><p>([\s\S]*?)<\/p>/)
    if (transformMatch && labelMatch) {
      const x = Number.parseFloat(transformMatch[1]!.trim())
      const y = Number.parseFloat(transformMatch[2]!.trim())
      const label = normalizeLabel(decodeHtml(labelMatch[1]!.trim()))
      if (!Number.isNaN(x) && !Number.isNaN(y) && label !== '') {
        nodes.set(label, { x, y })
      }
    }
    searchIndex = gEnd
  }
  return nodes
}

function parseLocalNodePositions(svg: string): Map<string, Point> {
  const nodes = new Map<string, Point>()
  const re = /<text class="label" x="([^"]+)" y="([^"]+)"[^>]*>([\s\S]*?)<\/text>/g
  for (const match of svg.matchAll(re)) {
    const x = Number.parseFloat(match[1]!.trim())
    const y = Number.parseFloat(match[2]!.trim())
    const label = normalizeLabel(decodeHtml(match[3]!.trim()))
    if (Number.isNaN(x) || Number.isNaN(y) || label === '') continue
    nodes.set(label, { x, y })
  }
  return nodes
}

function parseLocalEdges(svg: string): Point[][] {
  const edges: Point[][] = []
  const re = /<polyline class="edge" points="([^"]+)"/g
  for (const match of svg.matchAll(re)) {
    const points = match[1]!
      .trim()
      .split(/\s+/)
      .map(pair => {
        const [x, y] = pair.split(',')
        return {
          x: Number.parseFloat(x!),
          y: Number.parseFloat(y!),
        }
      })
      .filter(p => !Number.isNaN(p.x) && !Number.isNaN(p.y))
    if (points.length >= 2) edges.push(points)
  }
  return edges
}

function parseOfficialEdges(svg: string): Point[][] {
  const edges: Point[][] = []
  const re = /data-points="([^"]+)"/g
  for (const match of svg.matchAll(re)) {
    try {
      const raw = Buffer.from(match[1]!, 'base64').toString('utf8')
      const parsed = JSON.parse(raw) as Array<{ x: number; y: number }>
      if (!Array.isArray(parsed)) continue
      const points = parsed
        .map(point => ({
          x: Number(point.x),
          y: Number(point.y),
        }))
        .filter(p => !Number.isNaN(p.x) && !Number.isNaN(p.y))
      if (points.length >= 2) edges.push(points)
    } catch {
      // Ignore malformed edge payloads.
    }
  }
  return edges
}

function parseFixtureEdges(source: string): FixtureEdge[] {
  const edges: FixtureEdge[] = []
  const lines = source.split('\n')
  const edgeLine =
    /^\s*([A-Za-z0-9_./:-]+)(?:\[[^\]]*\])?\s*(?:-->|-.->|==>|===>|-.->)\s*(?:\|[^|]*\|)?\s*([A-Za-z0-9_./:-]+)(?:\[[^\]]*\])?\s*$/
  for (const rawLine of lines) {
    const line = rawLine.split('%%')[0]!.trim()
    if (line === '' || line.startsWith('graph ') || line === 'end' || line.startsWith('subgraph ')) {
      continue
    }
    const match = line.match(edgeLine)
    if (!match) continue
    const sourceId = normalizeLabel(match[1]!)
    const targetId = normalizeLabel(match[2]!)
    if (sourceId === '' || targetId === '') continue
    edges.push({ source: sourceId, target: targetId })
  }
  return edges
}

function boundsOf(points: Point[]): Bounds {
  if (points.length === 0) return { minX: 0, maxX: 0, minY: 0, maxY: 0 }
  let minX = points[0]!.x
  let maxX = points[0]!.x
  let minY = points[0]!.y
  let maxY = points[0]!.y
  for (const point of points) {
    minX = Math.min(minX, point.x)
    maxX = Math.max(maxX, point.x)
    minY = Math.min(minY, point.y)
    maxY = Math.max(maxY, point.y)
  }
  return { minX, maxX, minY, maxY }
}

function normalize(point: Point, bounds: Bounds): Point {
  const width = Math.max(bounds.maxX - bounds.minX, 1e-9)
  const height = Math.max(bounds.maxY - bounds.minY, 1e-9)
  return {
    x: (point.x - bounds.minX) / width,
    y: (point.y - bounds.minY) / height,
  }
}

function pairOrderByX(labels: string[], positions: Map<string, Point>): string[] {
  return labels
    .slice()
    .sort((a, b) => {
      const pa = positions.get(a)!
      const pb = positions.get(b)!
      if (pa.x !== pb.x) return pa.x - pb.x
      return pa.y - pb.y
    })
}

function countPairInversions(reference: string[], actual: string[]): number {
  const index = new Map<string, number>()
  actual.forEach((label, i) => index.set(label, i))
  let inversions = 0
  for (let i = 0; i < reference.length; i += 1) {
    for (let j = i + 1; j < reference.length; j += 1) {
      const li = reference[i]!
      const lj = reference[j]!
      if (index.get(li)! > index.get(lj)!) inversions += 1
    }
  }
  return inversions
}

function pointsEqual(a: Point, b: Point): boolean {
  return Math.abs(a.x - b.x) <= 1e-6 && Math.abs(a.y - b.y) <= 1e-6
}

function orientation(a: Point, b: Point, c: Point): number {
  return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

function onSegment(a: Point, b: Point, c: Point): boolean {
  const eps = 1e-9
  return (
    b.x >= Math.min(a.x, c.x) - eps &&
    b.x <= Math.max(a.x, c.x) + eps &&
    b.y >= Math.min(a.y, c.y) - eps &&
    b.y <= Math.max(a.y, c.y) + eps
  )
}

function segmentsIntersect(a1: Point, a2: Point, b1: Point, b2: Point): boolean {
  const eps = 1e-9
  const o1 = orientation(a1, a2, b1)
  const o2 = orientation(a1, a2, b2)
  const o3 = orientation(b1, b2, a1)
  const o4 = orientation(b1, b2, a2)

  const opposite =
    ((o1 > eps && o2 < -eps) || (o1 < -eps && o2 > eps)) &&
    ((o3 > eps && o4 < -eps) || (o3 < -eps && o4 > eps))
  if (opposite) return true

  if (Math.abs(o1) <= eps && onSegment(a1, b1, a2)) return true
  if (Math.abs(o2) <= eps && onSegment(a1, b2, a2)) return true
  if (Math.abs(o3) <= eps && onSegment(b1, a1, b2)) return true
  if (Math.abs(o4) <= eps && onSegment(b1, a2, b2)) return true

  return false
}

function segmentsProperlyIntersect(a1: Point, a2: Point, b1: Point, b2: Point): boolean {
  const eps = 1e-9
  const o1 = orientation(a1, a2, b1)
  const o2 = orientation(a1, a2, b2)
  const o3 = orientation(b1, b2, a1)
  const o4 = orientation(b1, b2, a2)
  return (
    ((o1 > eps && o2 < -eps) || (o1 < -eps && o2 > eps)) &&
    ((o3 > eps && o4 < -eps) || (o3 < -eps && o4 > eps))
  )
}

function countPolylineCrossings(polylines: Point[][]): number {
  let crossings = 0
  for (let i = 0; i < polylines.length; i += 1) {
    const a = polylines[i]!
    for (let j = i + 1; j < polylines.length; j += 1) {
      const b = polylines[j]!
      let crossed = false
      for (let ai = 0; ai < a.length - 1 && !crossed; ai += 1) {
        const a1 = a[ai]!
        const a2 = a[ai + 1]!
        for (let bi = 0; bi < b.length - 1 && !crossed; bi += 1) {
          const b1 = b[bi]!
          const b2 = b[bi + 1]!
          if (
            pointsEqual(a1, b1) ||
            pointsEqual(a1, b2) ||
            pointsEqual(a2, b1) ||
            pointsEqual(a2, b2)
          ) {
            continue
          }
          if (segmentsIntersect(a1, a2, b1, b2)) {
            crossed = true
            crossings += 1
          }
        }
      }
    }
  }
  return crossings
}

function toLogicalEdgeSegments(edges: FixtureEdge[], nodes: Map<string, Point>): LogicalEdgeSegment[] {
  const segments: LogicalEdgeSegment[] = []
  for (const edge of edges) {
    const sourcePoint = nodes.get(edge.source)
    const targetPoint = nodes.get(edge.target)
    if (!sourcePoint || !targetPoint) {
      continue
    }
    segments.push({
      source: edge.source,
      target: edge.target,
      start: sourcePoint,
      end: targetPoint,
    })
  }
  return segments
}

function logicalEdgesShareEndpoint(left: LogicalEdgeSegment, right: LogicalEdgeSegment): boolean {
  return (
    left.source === right.source ||
    left.source === right.target ||
    left.target === right.source ||
    left.target === right.target
  )
}

function countLogicalCrossings(segments: LogicalEdgeSegment[]): number {
  let crossings = 0
  for (let i = 0; i < segments.length; i += 1) {
    const left = segments[i]!
    for (let j = i + 1; j < segments.length; j += 1) {
      const right = segments[j]!
      if (logicalEdgesShareEndpoint(left, right)) {
        continue
      }
      if (
        segmentsProperlyIntersect(
          left.start,
          left.end,
          right.start,
          right.end,
        )
      ) {
        crossings += 1
      }
    }
  }
  return crossings
}

function renderOfficial(inputPath: string, outPath: string, npmCacheDir: string): void {
  runOrThrow(
    'npx',
    ['-y', '@mermaid-js/mermaid-cli', '-i', inputPath, '-o', outPath, '-b', 'transparent'],
    OFFICIAL_TIMEOUT_MS,
    {
      ...process.env,
      npm_config_cache: npmCacheDir,
    },
  )
}

function renderLocal(inputPath: string, outPath: string): void {
  const source = readFileSync(inputPath, 'utf8')
  const svg = runOrThrow(
    'moon',
    ['run', 'cmd/main', '--target', 'native', '--', source],
    LOCAL_TIMEOUT_MS,
  )
  writeFileSync(outPath, svg)
}

function compareFixture(path: string, tempRoot: string, npmCacheDir: string): Metrics {
  const safe = path.replaceAll(/[^A-Za-z0-9._/-]/g, '_').replaceAll('/', '__')
  const officialPath = join(tempRoot, `${safe}.official.svg`)
  const localPath = join(tempRoot, `${safe}.local.svg`)

  renderOfficial(path, officialPath, npmCacheDir)
  renderLocal(path, localPath)

  const fixtureSource = readFileSync(path, 'utf8')
  const fixtureEdges = parseFixtureEdges(fixtureSource)

  const officialSvg = readFileSync(officialPath, 'utf8')
  const localSvg = readFileSync(localPath, 'utf8')
  const officialNodes = parseOfficialNodePositions(officialSvg)
  const localNodes = parseLocalNodePositions(localSvg)
  const officialEdges = parseOfficialEdges(officialSvg)
  const localEdges = parseLocalEdges(localSvg)

  const sharedLabels = [...officialNodes.keys()].filter(label => localNodes.has(label)).sort()
  const structuralOk =
    sharedLabels.length === officialNodes.size &&
    sharedLabels.length === localNodes.size &&
    officialEdges.length === localEdges.length

  const officialLogicalSegments = toLogicalEdgeSegments(fixtureEdges, officialNodes)
  const localLogicalSegments = toLogicalEdgeSegments(fixtureEdges, localNodes)
  const comparableLogicalEdges = Math.min(
    officialLogicalSegments.length,
    localLogicalSegments.length,
  )
  const officialLogicalCrossings = countLogicalCrossings(officialLogicalSegments)
  const localLogicalCrossings = countLogicalCrossings(localLogicalSegments)
  const logicalCrossingMultiplier =
    officialLogicalCrossings === 0
      ? localLogicalCrossings === 0
        ? 1
        : Number.POSITIVE_INFINITY
      : localLogicalCrossings / officialLogicalCrossings

  if (sharedLabels.length < 2) {
    return {
      fixture: path,
      fixtureEdges: fixtureEdges.length,
      comparableLogicalEdges,
      officialNodes: officialNodes.size,
      localNodes: localNodes.size,
      sharedNodes: sharedLabels.length,
      officialEdges: officialEdges.length,
      localEdges: localEdges.length,
      rmse: Number.NaN,
      maxDist: Number.NaN,
      inversionRate: Number.NaN,
      localPolylineCrossings: countPolylineCrossings(localEdges),
      officialPolylineCrossings: countPolylineCrossings(officialEdges),
      localLogicalCrossings,
      officialLogicalCrossings,
      logicalCrossingMultiplier,
      spanXRatio: Number.NaN,
      spanYRatio: Number.NaN,
      status: structuralOk ? 'ok' : 'mismatch',
    }
  }

  const officialSharedPoints = sharedLabels.map(label => officialNodes.get(label)!)
  const localSharedPoints = sharedLabels.map(label => localNodes.get(label)!)
  const officialBounds = boundsOf(officialSharedPoints)
  const localBounds = boundsOf(localSharedPoints)

  let sumSq = 0
  let maxDist = 0
  for (const label of sharedLabels) {
    const off = normalize(officialNodes.get(label)!, officialBounds)
    const loc = normalize(localNodes.get(label)!, localBounds)
    const dist = Math.hypot(loc.x - off.x, loc.y - off.y)
    sumSq += dist * dist
    maxDist = Math.max(maxDist, dist)
  }
  const rmse = Math.sqrt(sumSq / sharedLabels.length)

  const officialOrderX = pairOrderByX(sharedLabels, officialNodes)
  const localOrderX = pairOrderByX(sharedLabels, localNodes)
  const inversions = countPairInversions(officialOrderX, localOrderX)
  const pairCount = (sharedLabels.length * (sharedLabels.length - 1)) / 2
  const inversionRate = pairCount === 0 ? 0 : inversions / pairCount

  const officialSpanX = officialBounds.maxX - officialBounds.minX
  const officialSpanY = officialBounds.maxY - officialBounds.minY
  const localSpanX = localBounds.maxX - localBounds.minX
  const localSpanY = localBounds.maxY - localBounds.minY

  return {
    fixture: path,
    fixtureEdges: fixtureEdges.length,
    comparableLogicalEdges,
    officialNodes: officialNodes.size,
    localNodes: localNodes.size,
    sharedNodes: sharedLabels.length,
    officialEdges: officialEdges.length,
    localEdges: localEdges.length,
    rmse,
    maxDist,
    inversionRate,
    localPolylineCrossings: countPolylineCrossings(localEdges),
    officialPolylineCrossings: countPolylineCrossings(officialEdges),
    localLogicalCrossings,
    officialLogicalCrossings,
    logicalCrossingMultiplier,
    spanXRatio: localSpanX / Math.max(officialSpanX, 1e-9),
    spanYRatio: localSpanY / Math.max(officialSpanY, 1e-9),
    status: structuralOk ? 'ok' : 'mismatch',
  }
}

function round(value: number): string {
  if (!Number.isFinite(value)) return 'NaN'
  return value.toFixed(4)
}

function discoverDefaultFixtures(): string[] {
  return readdirSync('fixtures')
    .filter(name => name.startsWith('layout_stress_') && name.endsWith('.mmd'))
    .sort()
    .map(name => join('fixtures', name))
}

function parseCliOptions(args: string[]): CliOptions {
  const fixtures: string[] = []
  let jsonPath: string | undefined = undefined
  let maxLogicalCrossingMultiplier: number | undefined = undefined

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--json') {
      const next = args[i + 1]
      if (!next) fail('missing path after --json')
      jsonPath = next
      i += 1
      continue
    }
    if (arg === '--max-logical-crossing-multiplier') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-logical-crossing-multiplier')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --max-logical-crossing-multiplier value, expected positive number')
      }
      maxLogicalCrossingMultiplier = parsed
      i += 1
      continue
    }
    fixtures.push(arg)
  }

  return { fixtures, jsonPath, maxLogicalCrossingMultiplier }
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const targets = options.fixtures.length > 0 ? options.fixtures : discoverDefaultFixtures()
  if (targets.length === 0) {
    fail('no stress fixtures found (expected fixtures/layout_stress_*.mmd)')
  }

  const tempRoot = mkdtempSync(join(tmpdir(), 'mermaid-layout-stress-'))
  const npmCacheDir = join(tempRoot, '.npm-cache')
  const results = targets.map(path => compareFixture(path, tempRoot, npmCacheDir))

  for (const result of results) {
    console.log(`\n=== ${result.fixture} ===`)
    console.log(
      `status=${result.status} nodes shared/local/official=${result.sharedNodes}/${result.localNodes}/${result.officialNodes} edges local/official=${result.localEdges}/${result.officialEdges} fixtureEdges=${result.fixtureEdges}`,
    )
    console.log(
      `rmse=${round(result.rmse)} maxDist=${round(result.maxDist)} inversionRate=${round(result.inversionRate)}`,
    )
    console.log(`spanRatio x=${round(result.spanXRatio)} y=${round(result.spanYRatio)}`)
    console.log(
      `polylineCrossings local=${result.localPolylineCrossings} official=${result.officialPolylineCrossings} delta=${result.localPolylineCrossings - result.officialPolylineCrossings}`,
    )
    console.log(
      `logicalCrossings local=${result.localLogicalCrossings} official=${result.officialLogicalCrossings} multiplier=${round(result.logicalCrossingMultiplier)}`,
    )
  }

  const okCount = results.filter(r => r.status === 'ok').length
  const avgRmse =
    results.reduce((acc, row) => acc + (Number.isFinite(row.rmse) ? row.rmse : 0), 0) /
    Math.max(results.length, 1)
  const avgInversion =
    results.reduce((acc, row) => acc + (Number.isFinite(row.inversionRate) ? row.inversionRate : 0), 0) /
    Math.max(results.length, 1)
  const avgLogicalMultiplier =
    results.reduce((acc, row) => acc + (Number.isFinite(row.logicalCrossingMultiplier) ? row.logicalCrossingMultiplier : 0), 0) /
    Math.max(results.length, 1)
  const totalLocalPolylineCrossings = results.reduce((acc, row) => acc + row.localPolylineCrossings, 0)
  const totalOfficialPolylineCrossings = results.reduce((acc, row) => acc + row.officialPolylineCrossings, 0)
  const totalLocalLogicalCrossings = results.reduce((acc, row) => acc + row.localLogicalCrossings, 0)
  const totalOfficialLogicalCrossings = results.reduce((acc, row) => acc + row.officialLogicalCrossings, 0)

  console.log('\n=== summary ===')
  console.log(`fixtures=${results.length} structural_ok=${okCount}/${results.length}`)
  console.log(`avg_rmse=${round(avgRmse)} avg_inversion_rate=${round(avgInversion)}`)
  console.log(
    `total_polyline_crossings local=${totalLocalPolylineCrossings} official=${totalOfficialPolylineCrossings} delta=${totalLocalPolylineCrossings - totalOfficialPolylineCrossings}`,
  )
  console.log(
    `total_logical_crossings local=${totalLocalLogicalCrossings} official=${totalOfficialLogicalCrossings} delta=${totalLocalLogicalCrossings - totalOfficialLogicalCrossings}`,
  )
  console.log(`avg_logical_crossing_multiplier=${round(avgLogicalMultiplier)}`)
  console.log(`rendered_svgs_dir=${tempRoot}`)

  if (options.jsonPath) {
    const payload = {
      generatedAt: new Date().toISOString(),
      renderedSvgDir: tempRoot,
      options: {
        maxLogicalCrossingMultiplier: options.maxLogicalCrossingMultiplier ?? null,
      },
      summary: {
        fixtures: results.length,
        structuralOk: okCount,
        avgRmse,
        avgInversionRate: avgInversion,
        totalLocalPolylineCrossings,
        totalOfficialPolylineCrossings,
        totalLocalLogicalCrossings,
        totalOfficialLogicalCrossings,
        avgLogicalCrossingMultiplier: avgLogicalMultiplier,
      },
      results,
    }
    writeFileSync(options.jsonPath, JSON.stringify(payload, null, 2))
    console.log(`json_report=${options.jsonPath}`)
  }

  const structuralMismatch = results.some(result => result.status !== 'ok')
  if (structuralMismatch) {
    process.exitCode = 2
  }

  if (options.maxLogicalCrossingMultiplier !== undefined) {
    const threshold = options.maxLogicalCrossingMultiplier
    const violating = results.filter(result => result.logicalCrossingMultiplier > threshold)
    if (violating.length > 0) {
      console.error(
        [
          `logical crossing multiplier threshold exceeded: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: multiplier=${round(result.logicalCrossingMultiplier)} local=${result.localLogicalCrossings} official=${result.officialLogicalCrossings}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 3
    }
  }
}

main()
