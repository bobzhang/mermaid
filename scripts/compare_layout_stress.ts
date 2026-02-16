/**
 * Compare local MoonBit SVG layout against official Mermaid CLI for stress fixtures.
 *
 * Usage:
 *   bun run scripts/compare_layout_stress.ts
 *   bun run scripts/compare_layout_stress.ts fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_layout_stress.ts --json /tmp/layout_stress_metrics.json
 *   bun run scripts/compare_layout_stress.ts --profile strict
 *   bun run scripts/compare_layout_stress.ts --max-logical-crossing-multiplier 1.8
 *   bun run scripts/compare_layout_stress.ts --allow-unparsed-edge-lines
 *   bun run scripts/compare_layout_stress.ts --use-local-edge-dump
 *   bun run scripts/compare_layout_stress.ts --max-polyline-crossing-multiplier 4.6 --min-span-area-ratio 0.04
 *   bun run scripts/compare_layout_stress.ts --max-avg-rmse 0.70 --max-avg-inversion-rate 0.35 --max-avg-polyline-crossing-multiplier 3.6 --min-avg-span-area-ratio 0.18
 *   bun run scripts/compare_layout_stress.ts --max-major-inversion-rate 0.55 --max-avg-major-inversion-rate 0.20
 *   bun run scripts/compare_layout_stress.ts --min-major-span-ratio 0.25 --min-minor-span-ratio 0.05 --min-avg-major-span-ratio 0.80 --min-avg-minor-span-ratio 0.20
 *   bun run scripts/compare_layout_stress.ts --local-timeout-ms 120000 --local-render-retries 2 --retry-backoff-ms 500
 *   bun run scripts/compare_layout_stress.ts fixtures/layout_challenge_001_nested_portal_mesh.mmd --explain-logical-crossings
 *   bun run scripts/compare_layout_stress.ts fixtures/layout_stress_010_bipartite_crossfire.mmd --explain-rank-order
 *   bun run scripts/compare_layout_stress.ts --max-logical-crossing-multiplier 1.0 --explain-on-failure
 */

import { mkdtempSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join } from 'node:path'
import { tmpdir } from 'node:os'

type Point = { x: number; y: number }
type Bounds = { minX: number; maxX: number; minY: number; maxY: number }
type FixtureEdge = { source: string; target: string }
type ParsedFixtureEdges = { edges: FixtureEdge[]; unparsedEdgeLines: string[] }
type Axis = 'x' | 'y'
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
  inversionRateY: number
  majorAxis: Axis
  majorRankLayersLocal: number
  majorRankLayersOfficial: number
  majorRankExactMatchRate: number
  majorRankAvgDisplacement: number
  majorRankCompositionMismatchCount: number
  majorInversionRate: number
  majorSpanRatio: number
  minorSpanRatio: number
  graphDirection: string
  localPolylineCrossings: number
  officialPolylineCrossings: number
  polylineCrossingMultiplier: number
  localLogicalCrossings: number
  officialLogicalCrossings: number
  logicalCrossingMultiplier: number
  spanXRatio: number
  spanYRatio: number
  spanAreaRatio: number
  status: 'ok' | 'mismatch'
  logicalCrossingPairShared?: number
  logicalCrossingPairLocalOnly?: number
  logicalCrossingPairOfficialOnly?: number
  logicalCrossingPairLocalOnlySample?: string[]
  logicalCrossingPairOfficialOnlySample?: string[]
  logicalCrossingLocalOnlyTopEdges?: Array<{ edge: string; count: number }>
  logicalCrossingOfficialOnlyTopEdges?: Array<{ edge: string; count: number }>
  majorRankOrderMismatchSample?: string[]
  majorRankCompositionMismatchSample?: string[]
}

type CliOptions = {
  profile?: string
  fixtures: string[]
  jsonPath?: string
  allowUnparsedEdgeLines: boolean
  useLocalEdgeDump: boolean
  maxLogicalCrossingMultiplier?: number
  maxPolylineCrossingMultiplier?: number
  minSpanXRatio?: number
  minSpanYRatio?: number
  minSpanAreaRatio?: number
  minMajorSpanRatio?: number
  minMinorSpanRatio?: number
  maxMajorInversionRate?: number
  maxAvgRmse?: number
  maxAvgInversionRate?: number
  maxAvgMajorInversionRate?: number
  minAvgMajorSpanRatio?: number
  minAvgMinorSpanRatio?: number
  maxAvgPolylineCrossingMultiplier?: number
  maxAvgLogicalCrossingMultiplier?: number
  minAvgSpanAreaRatio?: number
  officialTimeoutMs: number
  localTimeoutMs: number
  localRenderRetries: number
  retryBackoffMs: number
  explainLogicalCrossings: boolean
  explainRankOrder: boolean
  explainOnFailure: boolean
  topCrossingPairs: number
  topCrossingEdges: number
}

const DEFAULT_OFFICIAL_TIMEOUT_MS = 120_000
const DEFAULT_LOCAL_TIMEOUT_MS = 60_000
const DEFAULT_LOCAL_RENDER_RETRIES = 1
const DEFAULT_RETRY_BACKOFF_MS = 250

type QualityProfile = {
  maxLogicalCrossingMultiplier?: number
  maxPolylineCrossingMultiplier?: number
  minSpanXRatio?: number
  minSpanYRatio?: number
  minSpanAreaRatio?: number
  minMajorSpanRatio?: number
  minMinorSpanRatio?: number
  maxMajorInversionRate?: number
  maxAvgRmse?: number
  maxAvgInversionRate?: number
  maxAvgMajorInversionRate?: number
  minAvgMajorSpanRatio?: number
  minAvgMinorSpanRatio?: number
  maxAvgPolylineCrossingMultiplier?: number
  maxAvgLogicalCrossingMultiplier?: number
  minAvgSpanAreaRatio?: number
}

const QUALITY_PROFILES: Record<string, QualityProfile> = {
  strict: {
    maxLogicalCrossingMultiplier: 1.0,
    maxPolylineCrossingMultiplier: 4.6,
    minSpanXRatio: 0.12,
    minSpanYRatio: 0.05,
    minSpanAreaRatio: 0.04,
    minMajorSpanRatio: 0.25,
    minMinorSpanRatio: 0.05,
    maxMajorInversionRate: 0.55,
    maxAvgRmse: 0.70,
    maxAvgInversionRate: 0.35,
    maxAvgMajorInversionRate: 0.20,
    minAvgMajorSpanRatio: 0.80,
    minAvgMinorSpanRatio: 0.20,
    maxAvgPolylineCrossingMultiplier: 3.6,
    maxAvgLogicalCrossingMultiplier: 0.8,
    minAvgSpanAreaRatio: 0.18,
  },
}

function fail(message: string): never {
  throw new Error(message)
}

class CommandExecutionError extends Error {
  cmd: string
  args: string[]
  stdout: string
  stderr: string
  timedOut: boolean

  constructor(
    cmd: string,
    args: string[],
    stdout: string,
    stderr: string,
    timedOut: boolean,
    detail?: string,
  ) {
    const parts = [`command failed: ${cmd} ${args.join(' ')}`]
    if (detail) parts.push(`error: ${detail}`)
    if (stderr !== '') parts.push(`stderr: ${stderr}`)
    if (stdout !== '') parts.push(`stdout: ${stdout}`)
    super(parts.join('\n'))
    this.name = 'CommandExecutionError'
    this.cmd = cmd
    this.args = args
    this.stdout = stdout
    this.stderr = stderr
    this.timedOut = timedOut
  }
}

function runOrThrow(cmd: string, args: string[], timeoutMs: number, env?: NodeJS.ProcessEnv): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    timeout: timeoutMs,
    maxBuffer: 16 * 1024 * 1024,
    env,
  })
  const stdout = (result.stdout ?? '').toString().trim()
  const stderr = (result.stderr ?? '').toString().trim()
  const timedOut =
    (result.error as { code?: string } | null)?.code === 'ETIMEDOUT' ||
    (result.signal ?? '') === 'SIGTERM'

  if (result.error) {
    throw new CommandExecutionError(
      cmd,
      args,
      stdout,
      stderr,
      timedOut,
      String(result.error.message ?? result.error),
    )
  }
  if (result.status !== 0) {
    throw new CommandExecutionError(
      cmd,
      args,
      stdout,
      stderr,
      timedOut,
      `exit status ${result.status}`,
    )
  }
  return (result.stdout ?? '').toString()
}

function sleepMs(ms: number): void {
  if (ms <= 0) return
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms)
}

function isTimeoutError(error: unknown): error is CommandExecutionError {
  return error instanceof CommandExecutionError && error.timedOut
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
  const polylineRe = /<polyline class="edge" points="([^"]+)"/g
  for (const match of svg.matchAll(polylineRe)) {
    const points = parsePointPairs(match[1]!)
    if (points.length >= 2) edges.push(points)
  }
  const pathRe = /<path class="edge" d="([^"]+)"/g
  for (const match of svg.matchAll(pathRe)) {
    const points = parsePathPoints(match[1]!)
    if (points.length >= 2) edges.push(points)
  }
  return edges
}

function parseLocalEdgeDump(output: string): Point[][] {
  const edges: Point[][] = []
  for (const rawLine of output.split('\n')) {
    const line = rawLine.trim()
    if (line === '' || !line.startsWith('EDGE\t')) continue
    const parts = line.split('\t')
    if (parts.length < 4) continue
    const points = parsePointPairs(parts[3]!)
    if (points.length >= 2) edges.push(points)
  }
  return edges
}

function parsePointPairs(raw: string): Point[] {
  return raw
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
}

function parsePathPoints(pathD: string): Point[] {
  const tokenRe = /[a-zA-Z]|-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/g
  const tokens = [...pathD.matchAll(tokenRe)].map(match => match[0]!)
  const points: Point[] = []

  let index = 0
  let command = ''
  let currentX = 0
  let currentY = 0
  let subpathStartX = 0
  let subpathStartY = 0
  let previousCommandUpper = ''
  let previousCubicControlX: number | null = null
  let previousCubicControlY: number | null = null
  let previousQuadraticControlX: number | null = null
  let previousQuadraticControlY: number | null = null
  const curveSamples = 4

  const pushPoint = (x: number, y: number): void => {
    if (Number.isNaN(x) || Number.isNaN(y)) return
    const previous = points[points.length - 1]
    if (previous && Math.abs(previous.x - x) <= 1e-9 && Math.abs(previous.y - y) <= 1e-9) {
      return
    }
    points.push({ x, y })
  }

  const clearCurveControls = (): void => {
    previousCubicControlX = null
    previousCubicControlY = null
    previousQuadraticControlX = null
    previousQuadraticControlY = null
  }

  const sampleQuadraticTo = (
    startX: number,
    startY: number,
    controlX: number,
    controlY: number,
    endX: number,
    endY: number,
  ): void => {
    for (let step = 1; step <= curveSamples; step += 1) {
      const t = step / curveSamples
      const mt = 1 - t
      const x = mt * mt * startX + 2 * mt * t * controlX + t * t * endX
      const y = mt * mt * startY + 2 * mt * t * controlY + t * t * endY
      pushPoint(x, y)
    }
  }

  const sampleCubicTo = (
    startX: number,
    startY: number,
    control1X: number,
    control1Y: number,
    control2X: number,
    control2Y: number,
    endX: number,
    endY: number,
  ): void => {
    for (let step = 1; step <= curveSamples; step += 1) {
      const t = step / curveSamples
      const mt = 1 - t
      const x =
        mt * mt * mt * startX +
        3 * mt * mt * t * control1X +
        3 * mt * t * t * control2X +
        t * t * t * endX
      const y =
        mt * mt * mt * startY +
        3 * mt * mt * t * control1Y +
        3 * mt * t * t * control2Y +
        t * t * t * endY
      pushPoint(x, y)
    }
  }

  const clamp = (value: number, min: number, max: number): number =>
    Math.min(max, Math.max(min, value))

  const vectorAngle = (ux: number, uy: number, vx: number, vy: number): number => {
    const dot = ux * vx + uy * vy
    const det = ux * vy - uy * vx
    const lenU = Math.hypot(ux, uy)
    const lenV = Math.hypot(vx, vy)
    if (lenU <= 1e-12 || lenV <= 1e-12) return 0
    const ratio = clamp(dot / (lenU * lenV), -1, 1)
    const angle = Math.acos(ratio)
    return det < 0 ? -angle : angle
  }

  const sampleArcTo = (
    startX: number,
    startY: number,
    rawRx: number,
    rawRy: number,
    axisRotationDeg: number,
    largeArcFlag: number,
    sweepFlag: number,
    endX: number,
    endY: number,
  ): void => {
    let rx = Math.abs(rawRx)
    let ry = Math.abs(rawRy)
    if (rx <= 1e-12 || ry <= 1e-12) {
      pushPoint(endX, endY)
      return
    }
    if (Math.abs(startX - endX) <= 1e-12 && Math.abs(startY - endY) <= 1e-12) {
      pushPoint(endX, endY)
      return
    }

    const phi = (axisRotationDeg * Math.PI) / 180
    const cosPhi = Math.cos(phi)
    const sinPhi = Math.sin(phi)
    const dx2 = (startX - endX) / 2
    const dy2 = (startY - endY) / 2
    const x1p = cosPhi * dx2 + sinPhi * dy2
    const y1p = -sinPhi * dx2 + cosPhi * dy2

    const x1pSq = x1p * x1p
    const y1pSq = y1p * y1p
    let rxSq = rx * rx
    let rySq = ry * ry

    const lambda = x1pSq / rxSq + y1pSq / rySq
    if (lambda > 1) {
      const scale = Math.sqrt(lambda)
      rx *= scale
      ry *= scale
      rxSq = rx * rx
      rySq = ry * ry
    }

    const fa = Math.abs(largeArcFlag) > 0.5 ? 1 : 0
    const fs = Math.abs(sweepFlag) > 0.5 ? 1 : 0
    const sign = fa === fs ? -1 : 1
    const numerator = rxSq * rySq - rxSq * y1pSq - rySq * x1pSq
    const denominator = rxSq * y1pSq + rySq * x1pSq
    const coeff =
      denominator <= 1e-12 ? 0 : sign * Math.sqrt(Math.max(0, numerator / denominator))
    const cxp = coeff * ((rx * y1p) / ry)
    const cyp = coeff * (-(ry * x1p) / rx)

    const centerX = cosPhi * cxp - sinPhi * cyp + (startX + endX) / 2
    const centerY = sinPhi * cxp + cosPhi * cyp + (startY + endY) / 2

    const ux = (x1p - cxp) / rx
    const uy = (y1p - cyp) / ry
    const vx = (-x1p - cxp) / rx
    const vy = (-y1p - cyp) / ry
    const theta1 = vectorAngle(1, 0, ux, uy)
    let deltaTheta = vectorAngle(ux, uy, vx, vy)
    if (fs === 0 && deltaTheta > 0) deltaTheta -= 2 * Math.PI
    if (fs === 1 && deltaTheta < 0) deltaTheta += 2 * Math.PI

    const segmentCount = Math.max(1, Math.ceil(Math.abs(deltaTheta) / (Math.PI / 8)))
    for (let step = 1; step <= segmentCount; step += 1) {
      const t = step / segmentCount
      const theta = theta1 + deltaTheta * t
      const cosTheta = Math.cos(theta)
      const sinTheta = Math.sin(theta)
      const x = centerX + cosPhi * rx * cosTheta - sinPhi * ry * sinTheta
      const y = centerY + sinPhi * rx * cosTheta + cosPhi * ry * sinTheta
      pushPoint(x, y)
    }
  }

  const readNumber = (): number | null => {
    if (index >= tokens.length) return null
    const token = tokens[index]!
    if (/^[a-zA-Z]$/.test(token)) return null
    const parsed = Number.parseFloat(token)
    if (Number.isNaN(parsed)) return null
    index += 1
    return parsed
  }

  while (index < tokens.length) {
    const token = tokens[index]!
    if (/^[a-zA-Z]$/.test(token)) {
      command = token
      index += 1
    } else if (command === '') {
      break
    }

    switch (command) {
      case 'M':
      case 'm': {
        const isRelative = command === 'm'
        const firstX = readNumber()
        const firstY = readNumber()
        if (firstX == null || firstY == null) break
        currentX = isRelative ? currentX + firstX : firstX
        currentY = isRelative ? currentY + firstY : firstY
        subpathStartX = currentX
        subpathStartY = currentY
        pushPoint(currentX, currentY)
        clearCurveControls()
        previousCommandUpper = 'M'

        while (true) {
          const x = readNumber()
          const y = readNumber()
          if (x == null || y == null) break
          currentX = isRelative ? currentX + x : x
          currentY = isRelative ? currentY + y : y
          pushPoint(currentX, currentY)
          clearCurveControls()
          previousCommandUpper = 'L'
        }
        break
      }
      case 'L':
      case 'l': {
        const isRelative = command === 'l'
        while (true) {
          const x = readNumber()
          const y = readNumber()
          if (x == null || y == null) break
          currentX = isRelative ? currentX + x : x
          currentY = isRelative ? currentY + y : y
          pushPoint(currentX, currentY)
          clearCurveControls()
          previousCommandUpper = 'L'
        }
        break
      }
      case 'H':
      case 'h': {
        const isRelative = command === 'h'
        while (true) {
          const x = readNumber()
          if (x == null) break
          currentX = isRelative ? currentX + x : x
          pushPoint(currentX, currentY)
          clearCurveControls()
          previousCommandUpper = 'H'
        }
        break
      }
      case 'V':
      case 'v': {
        const isRelative = command === 'v'
        while (true) {
          const y = readNumber()
          if (y == null) break
          currentY = isRelative ? currentY + y : y
          pushPoint(currentX, currentY)
          clearCurveControls()
          previousCommandUpper = 'V'
        }
        break
      }
      case 'C':
      case 'c': {
        const isRelative = command === 'c'
        while (true) {
          const x1 = readNumber()
          const y1 = readNumber()
          const x2 = readNumber()
          const y2 = readNumber()
          const x = readNumber()
          const y = readNumber()
          if (x1 == null || y1 == null || x2 == null || y2 == null || x == null || y == null) break
          const startX = currentX
          const startY = currentY
          const control1X = isRelative ? currentX + x1 : x1
          const control1Y = isRelative ? currentY + y1 : y1
          const control2X = isRelative ? currentX + x2 : x2
          const control2Y = isRelative ? currentY + y2 : y2
          const endX = isRelative ? currentX + x : x
          const endY = isRelative ? currentY + y : y
          sampleCubicTo(
            startX,
            startY,
            control1X,
            control1Y,
            control2X,
            control2Y,
            endX,
            endY,
          )
          currentX = endX
          currentY = endY
          previousCubicControlX = control2X
          previousCubicControlY = control2Y
          previousQuadraticControlX = null
          previousQuadraticControlY = null
          previousCommandUpper = 'C'
        }
        break
      }
      case 'S':
      case 's': {
        const isRelative = command === 's'
        while (true) {
          const x2 = readNumber()
          const y2 = readNumber()
          const x = readNumber()
          const y = readNumber()
          if (x2 == null || y2 == null || x == null || y == null) break
          const startX = currentX
          const startY = currentY
          const control1X =
            (previousCommandUpper === 'C' || previousCommandUpper === 'S') &&
            previousCubicControlX != null
              ? 2 * currentX - previousCubicControlX
              : currentX
          const control1Y =
            (previousCommandUpper === 'C' || previousCommandUpper === 'S') &&
            previousCubicControlY != null
              ? 2 * currentY - previousCubicControlY
              : currentY
          const control2X = isRelative ? currentX + x2 : x2
          const control2Y = isRelative ? currentY + y2 : y2
          const endX = isRelative ? currentX + x : x
          const endY = isRelative ? currentY + y : y
          sampleCubicTo(
            startX,
            startY,
            control1X,
            control1Y,
            control2X,
            control2Y,
            endX,
            endY,
          )
          currentX = endX
          currentY = endY
          previousCubicControlX = control2X
          previousCubicControlY = control2Y
          previousQuadraticControlX = null
          previousQuadraticControlY = null
          previousCommandUpper = 'S'
        }
        break
      }
      case 'Q':
      case 'q': {
        const isRelative = command === 'q'
        while (true) {
          const x1 = readNumber()
          const y1 = readNumber()
          const x = readNumber()
          const y = readNumber()
          if (x1 == null || y1 == null || x == null || y == null) break
          const startX = currentX
          const startY = currentY
          const controlX = isRelative ? currentX + x1 : x1
          const controlY = isRelative ? currentY + y1 : y1
          const endX = isRelative ? currentX + x : x
          const endY = isRelative ? currentY + y : y
          sampleQuadraticTo(startX, startY, controlX, controlY, endX, endY)
          currentX = endX
          currentY = endY
          previousQuadraticControlX = controlX
          previousQuadraticControlY = controlY
          previousCubicControlX = null
          previousCubicControlY = null
          previousCommandUpper = 'Q'
        }
        break
      }
      case 'T':
      case 't': {
        const isRelative = command === 't'
        while (true) {
          const x = readNumber()
          const y = readNumber()
          if (x == null || y == null) break
          const startX = currentX
          const startY = currentY
          const controlX =
            (previousCommandUpper === 'Q' || previousCommandUpper === 'T') &&
            previousQuadraticControlX != null
              ? 2 * currentX - previousQuadraticControlX
              : currentX
          const controlY =
            (previousCommandUpper === 'Q' || previousCommandUpper === 'T') &&
            previousQuadraticControlY != null
              ? 2 * currentY - previousQuadraticControlY
              : currentY
          const endX = isRelative ? currentX + x : x
          const endY = isRelative ? currentY + y : y
          sampleQuadraticTo(startX, startY, controlX, controlY, endX, endY)
          currentX = endX
          currentY = endY
          previousQuadraticControlX = controlX
          previousQuadraticControlY = controlY
          previousCubicControlX = null
          previousCubicControlY = null
          previousCommandUpper = 'T'
        }
        break
      }
      case 'A':
      case 'a': {
        const isRelative = command === 'a'
        while (true) {
          const rx = readNumber()
          const ry = readNumber()
          const axisRotation = readNumber()
          const largeArcFlag = readNumber()
          const sweepFlag = readNumber()
          const x = readNumber()
          const y = readNumber()
          if (
            rx == null ||
            ry == null ||
            axisRotation == null ||
            largeArcFlag == null ||
            sweepFlag == null ||
            x == null ||
            y == null
          ) {
            break
          }
          const startX = currentX
          const startY = currentY
          const endX = isRelative ? currentX + x : x
          const endY = isRelative ? currentY + y : y
          sampleArcTo(
            startX,
            startY,
            rx,
            ry,
            axisRotation,
            largeArcFlag,
            sweepFlag,
            endX,
            endY,
          )
          currentX = endX
          currentY = endY
          clearCurveControls()
          previousCommandUpper = 'A'
        }
        break
      }
      case 'Z':
      case 'z': {
        currentX = subpathStartX
        currentY = subpathStartY
        pushPoint(currentX, currentY)
        clearCurveControls()
        previousCommandUpper = 'Z'
        break
      }
      default: {
        // Unknown command: consume one numeric token and continue.
        if (readNumber() == null) {
          index += 1
        }
      }
    }
  }

  return points
}

function parseOfficialEdges(svg: string): Point[][] {
  const edgeById = new Map<string, Point[]>()
  const pathTagRe = /<path\b([^>]*)>/g
  let syntheticId = 0

  for (const match of svg.matchAll(pathTagRe)) {
    const attrs = match[1]!
    if (!/\bdata-edge="true"/.test(attrs)) continue

    const id = attrs.match(/\bdata-id="([^"]+)"/)?.[1] ?? `__edge_${syntheticId++}`

    let points: Point[] = []
    const dataPoints = attrs.match(/\bdata-points="([^"]+)"/)?.[1]
    if (dataPoints) {
      try {
        const raw = Buffer.from(dataPoints, 'base64').toString('utf8')
        const parsed = JSON.parse(raw) as Array<{ x: number; y: number }>
        if (Array.isArray(parsed)) {
          points = parsed
            .map(point => ({
              x: Number(point.x),
              y: Number(point.y),
            }))
            .filter(p => !Number.isNaN(p.x) && !Number.isNaN(p.y))
        }
      } catch {
        points = []
      }
    }

    if (points.length < 2) {
      const d = attrs.match(/\bd="([^"]+)"/)?.[1]
      if (d) {
        points = parsePathPoints(d)
      }
    }

    if (points.length >= 2) {
      edgeById.set(id, points)
    }
  }

  return [...edgeById.values()]
}

function parseFixtureEdges(source: string): ParsedFixtureEdges {
  const parseEndpoint = (raw: string): string | null => {
    let token = raw.trim()
    if (token === '') return null
    token = token.split(':::')[0]!.trim()
    const shapeMetaIndex = token.indexOf('@{')
    if (shapeMetaIndex >= 0) {
      token = token.slice(0, shapeMetaIndex).trim()
    }

    const idMatch = token.match(/^([A-Za-z0-9_./:#-]+)/)
    if (idMatch) {
      const normalized = normalizeLabel(idMatch[1]!)
      return normalized === '' ? null : normalized
    }

    if (
      (token.startsWith('"') && token.endsWith('"')) ||
      (token.startsWith("'") && token.endsWith("'"))
    ) {
      const normalized = normalizeLabel(token.slice(1, -1))
      return normalized === '' ? null : normalized
    }
    return null
  }

  const splitTopLevelByAmpersand = (raw: string): string[] => {
    const parts: string[] = []
    let current = ''
    let squareDepth = 0
    let curlyDepth = 0
    let parenDepth = 0
    let quote: '"' | "'" | '' = ''

    for (let i = 0; i < raw.length; i += 1) {
      const ch = raw[i]!
      if (quote !== '') {
        current += ch
        const escaped = i > 0 && raw[i - 1] === '\\'
        if (ch === quote && !escaped) {
          quote = ''
        }
        continue
      }

      if (ch === '"' || ch === "'") {
        quote = ch
        current += ch
        continue
      }

      if (ch === '[') {
        squareDepth += 1
        current += ch
        continue
      }
      if (ch === ']') {
        squareDepth = Math.max(0, squareDepth - 1)
        current += ch
        continue
      }
      if (ch === '{') {
        curlyDepth += 1
        current += ch
        continue
      }
      if (ch === '}') {
        curlyDepth = Math.max(0, curlyDepth - 1)
        current += ch
        continue
      }
      if (ch === '(') {
        parenDepth += 1
        current += ch
        continue
      }
      if (ch === ')') {
        parenDepth = Math.max(0, parenDepth - 1)
        current += ch
        continue
      }

      if (ch === '&' && squareDepth === 0 && curlyDepth === 0 && parenDepth === 0) {
        const trimmed = current.trim()
        if (trimmed !== '') {
          parts.push(trimmed)
        }
        current = ''
        continue
      }

      current += ch
    }

    const tail = current.trim()
    if (tail !== '') {
      parts.push(tail)
    }
    return parts
  }

  const parseEndpointList = (raw: string): string[] | null => {
    const segments = splitTopLevelByAmpersand(raw)
    if (segments.length === 0) return null
    const ids: string[] = []
    for (const segment of segments) {
      const id = parseEndpoint(segment)
      if (!id) return null
      ids.push(id)
    }
    return ids
  }

  const parseEdgeLine = (line: string): FixtureEdge[] | null => {
    const patterns: RegExp[] = [
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
      const sourceIds = parseEndpointList(match[1]!)
      const targetIds = parseEndpointList(match[2]!)
      if (!sourceIds || !targetIds) return null
      const expanded: FixtureEdge[] = []
      for (const sourceId of sourceIds) {
        for (const targetId of targetIds) {
          expanded.push({ source: sourceId, target: targetId })
        }
      }
      return expanded
    }
    return null
  }

  const looksLikeEdgeCandidate = (line: string): boolean =>
    /-->|-\.\->|==>|===>|---/.test(line)

  const edges: FixtureEdge[] = []
  const unparsedEdgeLines: string[] = []
  const dedupe = new Set<string>()
  const lines = source.split('\n')
  for (const rawLine of lines) {
    const line = rawLine.split('%%')[0]!.trim()
    if (
      line === '' ||
      line.startsWith('graph ') ||
      line.startsWith('flowchart ') ||
      line === 'end' ||
      line.startsWith('subgraph ')
    ) {
      continue
    }
    const parsed = parseEdgeLine(line)
    if (!parsed) {
      if (looksLikeEdgeCandidate(line)) {
        unparsedEdgeLines.push(line)
      }
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

function parseGraphDirection(source: string): string {
  const lines = source.split('\n')
  for (const rawLine of lines) {
    const line = rawLine.split('%%')[0]!.trim()
    if (line === '') continue
    const match = line.match(/^(?:graph|flowchart)\s+([A-Za-z]+)/i)
    if (match) {
      return match[1]!.toUpperCase()
    }
  }
  return 'UNKNOWN'
}

function majorAxisForDirection(direction: string): Axis {
  switch (direction) {
    case 'LR':
    case 'RL':
      return 'x'
    case 'TB':
    case 'TD':
    case 'BT':
      return 'y'
    default:
      return 'x'
  }
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

function pairOrderByY(labels: string[], positions: Map<string, Point>): string[] {
  return labels
    .slice()
    .sort((a, b) => {
      const pa = positions.get(a)!
      const pb = positions.get(b)!
      if (pa.y !== pb.y) return pa.y - pb.y
      return pa.x - pb.x
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

function majorCoord(point: Point, majorAxis: Axis): number {
  return majorAxis === 'x' ? point.x : point.y
}

function minorCoord(point: Point, majorAxis: Axis): number {
  return majorAxis === 'x' ? point.y : point.x
}

function orderByMinorAxis(labels: string[], positions: Map<string, Point>, majorAxis: Axis): string[] {
  return labels
    .slice()
    .sort((left, right) => {
      const leftPoint = positions.get(left)!
      const rightPoint = positions.get(right)!
      const minorDelta = minorCoord(leftPoint, majorAxis) - minorCoord(rightPoint, majorAxis)
      if (minorDelta !== 0) return minorDelta
      const majorDelta = majorCoord(leftPoint, majorAxis) - majorCoord(rightPoint, majorAxis)
      if (majorDelta !== 0) return majorDelta
      return left.localeCompare(right)
    })
}

function buildMajorRankLayers(
  labels: string[],
  positions: Map<string, Point>,
  majorAxis: Axis,
): string[][] {
  if (labels.length === 0) return []
  const entries = labels
    .map(label => ({ label, major: majorCoord(positions.get(label)!, majorAxis) }))
    .sort((left, right) => {
      if (left.major !== right.major) return left.major - right.major
      return left.label.localeCompare(right.label)
    })

  const layers: string[][] = []
  const epsilon = 0.5
  let anchor = entries[0]!.major
  let currentLayer: string[] = []
  for (const entry of entries) {
    if (Math.abs(entry.major - anchor) > epsilon && currentLayer.length > 0) {
      layers.push(currentLayer)
      currentLayer = []
      anchor = entry.major
    }
    currentLayer.push(entry.label)
  }
  if (currentLayer.length > 0) {
    layers.push(currentLayer)
  }
  return layers
}

function buildRankIndexByLabel(layers: string[][]): Map<string, number> {
  const rankByLabel = new Map<string, number>()
  for (let rank = 0; rank < layers.length; rank += 1) {
    for (const label of layers[rank]!) {
      rankByLabel.set(label, rank)
    }
  }
  return rankByLabel
}

function sortedLayerLabels(layer: string[]): string[] {
  return layer.slice().sort((left, right) => left.localeCompare(right))
}

function sampleLayerLabels(layer: string[], maxLabels: number): string {
  if (layer.length <= maxLabels) return layer.join(',')
  const head = layer.slice(0, maxLabels).join(',')
  return `${head},...(${layer.length - maxLabels} more)`
}

type MajorRankDiagnostics = {
  localLayers: number
  officialLayers: number
  exactMatchRate: number
  avgDisplacement: number
  compositionMismatchCount: number
  orderMismatchSample?: string[]
  compositionMismatchSample?: string[]
}

function computeMajorRankDiagnostics(
  sharedLabels: string[],
  officialNodes: Map<string, Point>,
  localNodes: Map<string, Point>,
  majorAxis: Axis,
  includeSamples: boolean,
): MajorRankDiagnostics {
  if (sharedLabels.length === 0) {
    return {
      localLayers: 0,
      officialLayers: 0,
      exactMatchRate: Number.NaN,
      avgDisplacement: Number.NaN,
      compositionMismatchCount: 0,
      ...(includeSamples
        ? {
            orderMismatchSample: [],
            compositionMismatchSample: [],
          }
        : {}),
    }
  }

  const officialLayers = buildMajorRankLayers(sharedLabels, officialNodes, majorAxis)
  const localLayers = buildMajorRankLayers(sharedLabels, localNodes, majorAxis)
  const officialRankByLabel = buildRankIndexByLabel(officialLayers)
  const localRankByLabel = buildRankIndexByLabel(localLayers)

  let exactMatches = 0
  let displacementSum = 0
  let displacementCount = 0
  for (const label of sharedLabels) {
    const officialRank = officialRankByLabel.get(label)
    const localRank = localRankByLabel.get(label)
    if (officialRank === undefined || localRank === undefined) continue
    if (officialRank === localRank) exactMatches += 1
    displacementSum += Math.abs(localRank - officialRank)
    displacementCount += 1
  }

  const maxLayerCount = Math.max(officialLayers.length, localLayers.length)
  let compositionMismatchCount = 0
  const compositionMismatchSample: string[] = []
  const orderMismatches: Array<{
    rank: number
    inversionRate: number
    officialOrder: string[]
    localOrder: string[]
  }> = []

  for (let rank = 0; rank < maxLayerCount; rank += 1) {
    const officialLayer = officialLayers[rank] ?? []
    const localLayer = localLayers[rank] ?? []
    const sortedOfficial = sortedLayerLabels(officialLayer)
    const sortedLocal = sortedLayerLabels(localLayer)
    const sameComposition =
      sortedOfficial.length === sortedLocal.length &&
      sortedOfficial.every((label, i) => label === sortedLocal[i])

    if (!sameComposition) {
      compositionMismatchCount += 1
      if (includeSamples && compositionMismatchSample.length < 5) {
        compositionMismatchSample.push(
          `r${rank}: local=[${sampleLayerLabels(sortedLocal, 6)}] official=[${sampleLayerLabels(sortedOfficial, 6)}]`,
        )
      }
      continue
    }

    if (officialLayer.length < 2) continue
    const officialOrder = orderByMinorAxis(officialLayer, officialNodes, majorAxis)
    const localOrder = orderByMinorAxis(officialLayer, localNodes, majorAxis)
    const inversions = countPairInversions(officialOrder, localOrder)
    const pairCount = (officialOrder.length * (officialOrder.length - 1)) / 2
    if (pairCount <= 0 || inversions <= 0) continue
    orderMismatches.push({
      rank,
      inversionRate: inversions / pairCount,
      officialOrder,
      localOrder,
    })
  }

  orderMismatches.sort((left, right) => {
    if (left.inversionRate !== right.inversionRate) {
      return right.inversionRate - left.inversionRate
    }
    return left.rank - right.rank
  })

  const orderMismatchSample = includeSamples
    ? orderMismatches.slice(0, 5).map(
        mismatch =>
          `r${mismatch.rank} inv=${mismatch.inversionRate.toFixed(4)} local=[${sampleLayerLabels(mismatch.localOrder, 6)}] official=[${sampleLayerLabels(mismatch.officialOrder, 6)}]`,
      )
    : undefined

  return {
    localLayers: localLayers.length,
    officialLayers: officialLayers.length,
    exactMatchRate:
      displacementCount === 0 ? Number.NaN : exactMatches / Math.max(displacementCount, 1),
    avgDisplacement:
      displacementCount === 0 ? Number.NaN : displacementSum / Math.max(displacementCount, 1),
    compositionMismatchCount,
    ...(includeSamples
      ? {
          orderMismatchSample,
          compositionMismatchSample,
        }
      : {}),
  }
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

function polylineEndpointPoints(points: Point[]): [Point, Point] | null {
  if (points.length < 2) return null
  return [points[0]!, points[points.length - 1]!]
}

function polylinesShareEndpoint(a: Point[], b: Point[]): boolean {
  const aEndpoints = polylineEndpointPoints(a)
  const bEndpoints = polylineEndpointPoints(b)
  if (!aEndpoints || !bEndpoints) return false
  const [aStart, aEnd] = aEndpoints
  const [bStart, bEnd] = bEndpoints
  return pointsEqual(aStart, bStart) || pointsEqual(aStart, bEnd) || pointsEqual(aEnd, bStart) || pointsEqual(aEnd, bEnd)
}

function countPolylineCrossings(polylines: Point[][]): number {
  let crossings = 0
  for (let i = 0; i < polylines.length; i += 1) {
    const a = polylines[i]!
    for (let j = i + 1; j < polylines.length; j += 1) {
      const b = polylines[j]!
      if (polylinesShareEndpoint(a, b)) {
        continue
      }
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
  return collectLogicalCrossingPairKeys(segments).length
}

function edgeSegmentKey(edge: LogicalEdgeSegment): string {
  return `${edge.source}->${edge.target}`
}

function normalizedPairKey(left: string, right: string): string {
  return left < right ? `${left} || ${right}` : `${right} || ${left}`
}

function collectLogicalCrossingPairKeys(segments: LogicalEdgeSegment[]): string[] {
  const pairs = new Set<string>()
  for (let i = 0; i < segments.length; i += 1) {
    const left = segments[i]!
    const leftKey = edgeSegmentKey(left)
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
        const rightKey = edgeSegmentKey(right)
        pairs.add(normalizedPairKey(leftKey, rightKey))
      }
    }
  }
  return [...pairs].sort()
}

function splitPairKey(pairKey: string): [string, string] {
  const [left, right] = pairKey.split(' || ')
  return [left!, right!]
}

function countEdgeParticipation(pairKeys: string[]): Map<string, number> {
  const counts = new Map<string, number>()
  for (const pairKey of pairKeys) {
    const [left, right] = splitPairKey(pairKey)
    counts.set(left, (counts.get(left) ?? 0) + 1)
    counts.set(right, (counts.get(right) ?? 0) + 1)
  }
  return counts
}

function topEdgeCounts(pairKeys: string[], limit: number): Array<{ edge: string; count: number }> {
  const counts = countEdgeParticipation(pairKeys)
  return [...counts.entries()]
    .sort((a, b) => {
      if (a[1] !== b[1]) return b[1] - a[1]
      return a[0].localeCompare(b[0])
    })
    .slice(0, limit)
    .map(([edge, count]) => ({ edge, count }))
}

function pairSetDiff(left: string[], right: string[]): string[] {
  const rightSet = new Set(right)
  return left.filter(key => !rightSet.has(key))
}

function pairSetIntersection(left: string[], right: string[]): string[] {
  const rightSet = new Set(right)
  return left.filter(key => rightSet.has(key))
}

function samplePairs(pairs: string[], limit: number): string[] {
  return pairs.slice(0, limit)
}

function crossingMultiplier(local: number, official: number): number {
  if (official === 0) {
    return local === 0 ? 1 : Number.POSITIVE_INFINITY
  }
  return local / official
}

function renderOfficial(
  inputPath: string,
  outPath: string,
  npmCacheDir: string,
  options: CliOptions,
): void {
  runOrThrow(
    'npx',
    ['-y', '@mermaid-js/mermaid-cli', '-i', inputPath, '-o', outPath, '-b', 'transparent'],
    options.officialTimeoutMs,
    {
      ...process.env,
      npm_config_cache: npmCacheDir,
    },
  )
}

function renderLocal(inputPath: string, outPath: string, options: CliOptions): void {
  const source = readFileSync(inputPath, 'utf8')
  for (let attempt = 0; attempt <= options.localRenderRetries; attempt += 1) {
    try {
      const svg = runOrThrow(
        'moon',
        ['run', 'cmd/main', '--target', 'native', '--', source],
        options.localTimeoutMs,
      )
      writeFileSync(outPath, svg)
      return
    } catch (error) {
      const hasRetry = attempt < options.localRenderRetries
      if (!hasRetry || !isTimeoutError(error)) {
        throw error
      }
      sleepMs(options.retryBackoffMs * (attempt + 1))
    }
  }
}

function renderLocalEdgePoints(inputPath: string, options: CliOptions): Point[][] {
  const source = readFileSync(inputPath, 'utf8')
  for (let attempt = 0; attempt <= options.localRenderRetries; attempt += 1) {
    try {
      const output = runOrThrow(
        'moon',
        ['run', 'cmd/main', '--target', 'native', '--', '--dump-edge-points', source],
        options.localTimeoutMs,
      )
      return parseLocalEdgeDump(output)
    } catch (error) {
      const hasRetry = attempt < options.localRenderRetries
      if (!hasRetry || !isTimeoutError(error)) {
        throw error
      }
      sleepMs(options.retryBackoffMs * (attempt + 1))
    }
  }
  return []
}

function compareFixture(
  path: string,
  tempRoot: string,
  npmCacheDir: string,
  options: CliOptions,
): Metrics {
  const safe = path.replaceAll(/[^A-Za-z0-9._/-]/g, '_').replaceAll('/', '__')
  const officialPath = join(tempRoot, `${safe}.official.svg`)
  const localPath = join(tempRoot, `${safe}.local.svg`)

  renderOfficial(path, officialPath, npmCacheDir, options)
  renderLocal(path, localPath, options)

  const fixtureSource = readFileSync(path, 'utf8')
  const parsedFixtureEdges = parseFixtureEdges(fixtureSource)
  if (!options.allowUnparsedEdgeLines && parsedFixtureEdges.unparsedEdgeLines.length > 0) {
    const sample = parsedFixtureEdges.unparsedEdgeLines.slice(0, 6)
    fail(
      [
        `fixture contains unparsed edge lines: ${path}`,
        ...sample.map(line => `  ${line}`),
        ...(parsedFixtureEdges.unparsedEdgeLines.length > sample.length
          ? [
              `  ... (${parsedFixtureEdges.unparsedEdgeLines.length - sample.length} more lines)`,
            ]
          : []),
        'If this is expected, rerun with --allow-unparsed-edge-lines.',
      ].join('\n'),
    )
  }
  const fixtureEdges = parsedFixtureEdges.edges
  const graphDirection = parseGraphDirection(fixtureSource)
  const majorAxis = majorAxisForDirection(graphDirection)

  const officialSvg = readFileSync(officialPath, 'utf8')
  const localSvg = readFileSync(localPath, 'utf8')
  const officialNodes = parseOfficialNodePositions(officialSvg)
  const localNodes = parseLocalNodePositions(localSvg)
  const officialEdges = parseOfficialEdges(officialSvg)
  const localEdgesFromSvg = parseLocalEdges(localSvg)
  let localEdges = localEdgesFromSvg
  if (options.useLocalEdgeDump) {
    try {
      const dumpedEdges = renderLocalEdgePoints(path, options)
      if (dumpedEdges.length === localEdgesFromSvg.length && dumpedEdges.length > 0) {
        localEdges = dumpedEdges
      }
    } catch {
      localEdges = localEdgesFromSvg
    }
  }

  const sharedLabels = [...officialNodes.keys()].filter(label => localNodes.has(label)).sort()
  const rankDiagnostics = computeMajorRankDiagnostics(
    sharedLabels,
    officialNodes,
    localNodes,
    majorAxis,
    options.explainRankOrder,
  )
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
  const officialLogicalPairKeys = collectLogicalCrossingPairKeys(officialLogicalSegments)
  const localLogicalPairKeys = collectLogicalCrossingPairKeys(localLogicalSegments)
  const officialLogicalCrossings = officialLogicalPairKeys.length
  const localLogicalCrossings = localLogicalPairKeys.length
  const logicalCrossingMultiplier = crossingMultiplier(
    localLogicalCrossings,
    officialLogicalCrossings,
  )
  const localPolylineCrossings = countPolylineCrossings(localEdges)
  const officialPolylineCrossings = countPolylineCrossings(officialEdges)
  const polylineCrossingMultiplier = crossingMultiplier(
    localPolylineCrossings,
    officialPolylineCrossings,
  )

  if (sharedLabels.length < 2) {
    const sharedPairs = pairSetIntersection(localLogicalPairKeys, officialLogicalPairKeys)
    const localOnlyPairs = pairSetDiff(localLogicalPairKeys, officialLogicalPairKeys)
    const officialOnlyPairs = pairSetDiff(officialLogicalPairKeys, localLogicalPairKeys)
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
      inversionRateY: Number.NaN,
      majorAxis,
      majorRankLayersLocal: rankDiagnostics.localLayers,
      majorRankLayersOfficial: rankDiagnostics.officialLayers,
      majorRankExactMatchRate: rankDiagnostics.exactMatchRate,
      majorRankAvgDisplacement: rankDiagnostics.avgDisplacement,
      majorRankCompositionMismatchCount: rankDiagnostics.compositionMismatchCount,
      majorInversionRate: Number.NaN,
      majorSpanRatio: Number.NaN,
      minorSpanRatio: Number.NaN,
      graphDirection,
      localPolylineCrossings,
      officialPolylineCrossings,
      polylineCrossingMultiplier,
      localLogicalCrossings,
      officialLogicalCrossings,
      logicalCrossingMultiplier,
      spanXRatio: Number.NaN,
      spanYRatio: Number.NaN,
      spanAreaRatio: Number.NaN,
      status: structuralOk ? 'ok' : 'mismatch',
      ...(options.explainLogicalCrossings
        ? {
            logicalCrossingPairShared: sharedPairs.length,
            logicalCrossingPairLocalOnly: localOnlyPairs.length,
            logicalCrossingPairOfficialOnly: officialOnlyPairs.length,
            logicalCrossingPairLocalOnlySample: samplePairs(localOnlyPairs, options.topCrossingPairs),
            logicalCrossingPairOfficialOnlySample: samplePairs(
              officialOnlyPairs,
              options.topCrossingPairs,
            ),
            logicalCrossingLocalOnlyTopEdges: topEdgeCounts(localOnlyPairs, options.topCrossingEdges),
            logicalCrossingOfficialOnlyTopEdges: topEdgeCounts(
              officialOnlyPairs,
              options.topCrossingEdges,
            ),
          }
        : {}),
      ...(options.explainRankOrder
        ? {
            majorRankOrderMismatchSample: rankDiagnostics.orderMismatchSample,
            majorRankCompositionMismatchSample: rankDiagnostics.compositionMismatchSample,
          }
        : {}),
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
  const officialOrderY = pairOrderByY(sharedLabels, officialNodes)
  const localOrderY = pairOrderByY(sharedLabels, localNodes)
  const inversionsX = countPairInversions(officialOrderX, localOrderX)
  const inversionsY = countPairInversions(officialOrderY, localOrderY)
  const pairCount = (sharedLabels.length * (sharedLabels.length - 1)) / 2
  const inversionRate = pairCount === 0 ? 0 : inversionsX / pairCount
  const inversionRateY = pairCount === 0 ? 0 : inversionsY / pairCount
  const majorInversionRate = majorAxis === 'x' ? inversionRate : inversionRateY

  const officialSpanX = officialBounds.maxX - officialBounds.minX
  const officialSpanY = officialBounds.maxY - officialBounds.minY
  const localSpanX = localBounds.maxX - localBounds.minX
  const localSpanY = localBounds.maxY - localBounds.minY
  const spanXRatio = localSpanX / Math.max(officialSpanX, 1e-9)
  const spanYRatio = localSpanY / Math.max(officialSpanY, 1e-9)
  const spanAreaRatio = spanXRatio * spanYRatio
  const majorSpanRatio = majorAxis === 'x' ? spanXRatio : spanYRatio
  const minorSpanRatio = majorAxis === 'x' ? spanYRatio : spanXRatio

  const sharedPairs = pairSetIntersection(localLogicalPairKeys, officialLogicalPairKeys)
  const localOnlyPairs = pairSetDiff(localLogicalPairKeys, officialLogicalPairKeys)
  const officialOnlyPairs = pairSetDiff(officialLogicalPairKeys, localLogicalPairKeys)

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
    inversionRateY,
    majorAxis,
    majorRankLayersLocal: rankDiagnostics.localLayers,
    majorRankLayersOfficial: rankDiagnostics.officialLayers,
    majorRankExactMatchRate: rankDiagnostics.exactMatchRate,
    majorRankAvgDisplacement: rankDiagnostics.avgDisplacement,
    majorRankCompositionMismatchCount: rankDiagnostics.compositionMismatchCount,
    majorInversionRate,
    majorSpanRatio,
    minorSpanRatio,
    graphDirection,
    localPolylineCrossings,
    officialPolylineCrossings,
    polylineCrossingMultiplier,
    localLogicalCrossings,
    officialLogicalCrossings,
    logicalCrossingMultiplier,
    spanXRatio,
    spanYRatio,
    spanAreaRatio,
    status: structuralOk ? 'ok' : 'mismatch',
    ...(options.explainLogicalCrossings
      ? {
          logicalCrossingPairShared: sharedPairs.length,
          logicalCrossingPairLocalOnly: localOnlyPairs.length,
          logicalCrossingPairOfficialOnly: officialOnlyPairs.length,
          logicalCrossingPairLocalOnlySample: samplePairs(localOnlyPairs, options.topCrossingPairs),
          logicalCrossingPairOfficialOnlySample: samplePairs(
            officialOnlyPairs,
            options.topCrossingPairs,
          ),
          logicalCrossingLocalOnlyTopEdges: topEdgeCounts(localOnlyPairs, options.topCrossingEdges),
          logicalCrossingOfficialOnlyTopEdges: topEdgeCounts(
            officialOnlyPairs,
            options.topCrossingEdges,
          ),
        }
      : {}),
    ...(options.explainRankOrder
      ? {
          majorRankOrderMismatchSample: rankDiagnostics.orderMismatchSample,
          majorRankCompositionMismatchSample: rankDiagnostics.compositionMismatchSample,
        }
      : {}),
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
  let profile: string | undefined = undefined
  const fixtures: string[] = []
  let jsonPath: string | undefined = undefined
  let allowUnparsedEdgeLines = false
  let useLocalEdgeDump = false
  let maxLogicalCrossingMultiplier: number | undefined = undefined
  let maxPolylineCrossingMultiplier: number | undefined = undefined
  let minSpanXRatio: number | undefined = undefined
  let minSpanYRatio: number | undefined = undefined
  let minSpanAreaRatio: number | undefined = undefined
  let minMajorSpanRatio: number | undefined = undefined
  let minMinorSpanRatio: number | undefined = undefined
  let maxMajorInversionRate: number | undefined = undefined
  let maxAvgRmse: number | undefined = undefined
  let maxAvgInversionRate: number | undefined = undefined
  let maxAvgMajorInversionRate: number | undefined = undefined
  let minAvgMajorSpanRatio: number | undefined = undefined
  let minAvgMinorSpanRatio: number | undefined = undefined
  let maxAvgPolylineCrossingMultiplier: number | undefined = undefined
  let maxAvgLogicalCrossingMultiplier: number | undefined = undefined
  let minAvgSpanAreaRatio: number | undefined = undefined
  let officialTimeoutMs = DEFAULT_OFFICIAL_TIMEOUT_MS
  let localTimeoutMs = DEFAULT_LOCAL_TIMEOUT_MS
  let localRenderRetries = DEFAULT_LOCAL_RENDER_RETRIES
  let retryBackoffMs = DEFAULT_RETRY_BACKOFF_MS
  let explainLogicalCrossings = false
  let explainRankOrder = false
  let explainOnFailure = false
  let topCrossingPairs = 8
  let topCrossingEdges = 8

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!
    if (arg === '--profile') {
      const next = args[i + 1]
      if (!next) fail('missing profile name after --profile')
      profile = next
      i += 1
      continue
    }
    if (arg === '--json') {
      const next = args[i + 1]
      if (!next) fail('missing path after --json')
      jsonPath = next
      i += 1
      continue
    }
    if (arg === '--allow-unparsed-edge-lines') {
      allowUnparsedEdgeLines = true
      continue
    }
    if (arg === '--use-local-edge-dump') {
      useLocalEdgeDump = true
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
    if (arg === '--max-polyline-crossing-multiplier') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-polyline-crossing-multiplier')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --max-polyline-crossing-multiplier value, expected positive number')
      }
      maxPolylineCrossingMultiplier = parsed
      i += 1
      continue
    }
    if (arg === '--min-span-x-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-span-x-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-span-x-ratio value, expected positive number')
      }
      minSpanXRatio = parsed
      i += 1
      continue
    }
    if (arg === '--min-span-y-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-span-y-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-span-y-ratio value, expected positive number')
      }
      minSpanYRatio = parsed
      i += 1
      continue
    }
    if (arg === '--min-span-area-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-span-area-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-span-area-ratio value, expected positive number')
      }
      minSpanAreaRatio = parsed
      i += 1
      continue
    }
    if (arg === '--min-major-span-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-major-span-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-major-span-ratio value, expected positive number')
      }
      minMajorSpanRatio = parsed
      i += 1
      continue
    }
    if (arg === '--min-minor-span-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-minor-span-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-minor-span-ratio value, expected positive number')
      }
      minMinorSpanRatio = parsed
      i += 1
      continue
    }
    if (arg === '--max-major-inversion-rate') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-major-inversion-rate')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 1) {
        fail('invalid --max-major-inversion-rate value, expected number in (0, 1]')
      }
      maxMajorInversionRate = parsed
      i += 1
      continue
    }
    if (arg === '--max-avg-rmse') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-rmse')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --max-avg-rmse value, expected positive number')
      }
      maxAvgRmse = parsed
      i += 1
      continue
    }
    if (arg === '--max-avg-inversion-rate') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-inversion-rate')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 1) {
        fail('invalid --max-avg-inversion-rate value, expected number in (0, 1]')
      }
      maxAvgInversionRate = parsed
      i += 1
      continue
    }
    if (arg === '--max-avg-major-inversion-rate') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-major-inversion-rate')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 1) {
        fail('invalid --max-avg-major-inversion-rate value, expected number in (0, 1]')
      }
      maxAvgMajorInversionRate = parsed
      i += 1
      continue
    }
    if (arg === '--min-avg-major-span-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-avg-major-span-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-avg-major-span-ratio value, expected positive number')
      }
      minAvgMajorSpanRatio = parsed
      i += 1
      continue
    }
    if (arg === '--min-avg-minor-span-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-avg-minor-span-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-avg-minor-span-ratio value, expected positive number')
      }
      minAvgMinorSpanRatio = parsed
      i += 1
      continue
    }
    if (arg === '--max-avg-polyline-crossing-multiplier') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-polyline-crossing-multiplier')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --max-avg-polyline-crossing-multiplier value, expected positive number')
      }
      maxAvgPolylineCrossingMultiplier = parsed
      i += 1
      continue
    }
    if (arg === '--max-avg-logical-crossing-multiplier') {
      const next = args[i + 1]
      if (!next) fail('missing number after --max-avg-logical-crossing-multiplier')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --max-avg-logical-crossing-multiplier value, expected positive number')
      }
      maxAvgLogicalCrossingMultiplier = parsed
      i += 1
      continue
    }
    if (arg === '--min-avg-span-area-ratio') {
      const next = args[i + 1]
      if (!next) fail('missing number after --min-avg-span-area-ratio')
      const parsed = Number.parseFloat(next)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --min-avg-span-area-ratio value, expected positive number')
      }
      minAvgSpanAreaRatio = parsed
      i += 1
      continue
    }
    if (arg === '--official-timeout-ms') {
      const next = args[i + 1]
      if (!next) fail('missing number after --official-timeout-ms')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --official-timeout-ms value, expected positive integer')
      }
      officialTimeoutMs = parsed
      i += 1
      continue
    }
    if (arg === '--local-timeout-ms') {
      const next = args[i + 1]
      if (!next) fail('missing number after --local-timeout-ms')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --local-timeout-ms value, expected positive integer')
      }
      localTimeoutMs = parsed
      i += 1
      continue
    }
    if (arg === '--local-render-retries') {
      const next = args[i + 1]
      if (!next) fail('missing number after --local-render-retries')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed < 0) {
        fail('invalid --local-render-retries value, expected non-negative integer')
      }
      localRenderRetries = parsed
      i += 1
      continue
    }
    if (arg === '--retry-backoff-ms') {
      const next = args[i + 1]
      if (!next) fail('missing number after --retry-backoff-ms')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --retry-backoff-ms value, expected positive integer')
      }
      retryBackoffMs = parsed
      i += 1
      continue
    }
    if (arg === '--explain-logical-crossings') {
      explainLogicalCrossings = true
      continue
    }
    if (arg === '--explain-rank-order') {
      explainRankOrder = true
      continue
    }
    if (arg === '--explain-on-failure') {
      explainOnFailure = true
      continue
    }
    if (arg === '--top-crossing-pairs') {
      const next = args[i + 1]
      if (!next) fail('missing number after --top-crossing-pairs')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --top-crossing-pairs value, expected positive integer')
      }
      topCrossingPairs = parsed
      i += 1
      continue
    }
    if (arg === '--top-crossing-edges') {
      const next = args[i + 1]
      if (!next) fail('missing number after --top-crossing-edges')
      const parsed = Number.parseInt(next, 10)
      if (!Number.isFinite(parsed) || parsed <= 0) {
        fail('invalid --top-crossing-edges value, expected positive integer')
      }
      topCrossingEdges = parsed
      i += 1
      continue
    }
    fixtures.push(arg)
  }

  if (profile !== undefined) {
    const normalizedProfile = profile.toLowerCase()
    const selectedProfile = QUALITY_PROFILES[normalizedProfile]
    if (!selectedProfile) {
      fail(
        `unknown profile '${profile}', available profiles: ${Object.keys(QUALITY_PROFILES).sort().join(', ')}`,
      )
    }
    profile = normalizedProfile
    maxLogicalCrossingMultiplier =
      maxLogicalCrossingMultiplier ?? selectedProfile.maxLogicalCrossingMultiplier
    maxPolylineCrossingMultiplier =
      maxPolylineCrossingMultiplier ?? selectedProfile.maxPolylineCrossingMultiplier
    minSpanXRatio = minSpanXRatio ?? selectedProfile.minSpanXRatio
    minSpanYRatio = minSpanYRatio ?? selectedProfile.minSpanYRatio
    minSpanAreaRatio = minSpanAreaRatio ?? selectedProfile.minSpanAreaRatio
    minMajorSpanRatio = minMajorSpanRatio ?? selectedProfile.minMajorSpanRatio
    minMinorSpanRatio = minMinorSpanRatio ?? selectedProfile.minMinorSpanRatio
    maxMajorInversionRate = maxMajorInversionRate ?? selectedProfile.maxMajorInversionRate
    maxAvgRmse = maxAvgRmse ?? selectedProfile.maxAvgRmse
    maxAvgInversionRate = maxAvgInversionRate ?? selectedProfile.maxAvgInversionRate
    maxAvgMajorInversionRate =
      maxAvgMajorInversionRate ?? selectedProfile.maxAvgMajorInversionRate
    minAvgMajorSpanRatio = minAvgMajorSpanRatio ?? selectedProfile.minAvgMajorSpanRatio
    minAvgMinorSpanRatio = minAvgMinorSpanRatio ?? selectedProfile.minAvgMinorSpanRatio
    maxAvgPolylineCrossingMultiplier =
      maxAvgPolylineCrossingMultiplier ?? selectedProfile.maxAvgPolylineCrossingMultiplier
    maxAvgLogicalCrossingMultiplier =
      maxAvgLogicalCrossingMultiplier ?? selectedProfile.maxAvgLogicalCrossingMultiplier
    minAvgSpanAreaRatio = minAvgSpanAreaRatio ?? selectedProfile.minAvgSpanAreaRatio
  }

  return {
    profile,
    fixtures,
    jsonPath,
    allowUnparsedEdgeLines,
    useLocalEdgeDump,
    maxLogicalCrossingMultiplier,
    maxPolylineCrossingMultiplier,
    minSpanXRatio,
    minSpanYRatio,
    minSpanAreaRatio,
    minMajorSpanRatio,
    minMinorSpanRatio,
    maxMajorInversionRate,
    maxAvgRmse,
    maxAvgInversionRate,
    maxAvgMajorInversionRate,
    minAvgMajorSpanRatio,
    minAvgMinorSpanRatio,
    maxAvgPolylineCrossingMultiplier,
    maxAvgLogicalCrossingMultiplier,
    minAvgSpanAreaRatio,
    officialTimeoutMs,
    localTimeoutMs,
    localRenderRetries,
    retryBackoffMs,
    explainLogicalCrossings,
    explainRankOrder,
    explainOnFailure,
    topCrossingPairs,
    topCrossingEdges,
  }
}

function printLogicalCrossingExplanation(result: Metrics): void {
  console.log(
    `logicalCrossingPairs shared=${result.logicalCrossingPairShared ?? 0} localOnly=${result.logicalCrossingPairLocalOnly ?? 0} officialOnly=${result.logicalCrossingPairOfficialOnly ?? 0}`,
  )
  const localEdgeSummary =
    result.logicalCrossingLocalOnlyTopEdges
      ?.map(item => `${item.edge}:${item.count}`)
      .join(', ') ?? ''
  const officialEdgeSummary =
    result.logicalCrossingOfficialOnlyTopEdges
      ?.map(item => `${item.edge}:${item.count}`)
      .join(', ') ?? ''
  if (localEdgeSummary !== '') {
    console.log(`localOnlyTopEdges ${localEdgeSummary}`)
  }
  if (officialEdgeSummary !== '') {
    console.log(`officialOnlyTopEdges ${officialEdgeSummary}`)
  }
  const localPairs = result.logicalCrossingPairLocalOnlySample ?? []
  const officialPairs = result.logicalCrossingPairOfficialOnlySample ?? []
  if (localPairs.length > 0) {
    console.log(`localOnlyPairs ${localPairs.join(' | ')}`)
  }
  if (officialPairs.length > 0) {
    console.log(`officialOnlyPairs ${officialPairs.join(' | ')}`)
  }
}

function printRankOrderExplanation(result: Metrics): void {
  const composition = result.majorRankCompositionMismatchSample ?? []
  const order = result.majorRankOrderMismatchSample ?? []
  if (composition.length > 0) {
    console.log(`majorRankCompositionMismatch ${composition.join(' | ')}`)
  }
  if (order.length > 0) {
    console.log(`majorRankOrderMismatch ${order.join(' | ')}`)
  }
}

function main(): void {
  const options = parseCliOptions(process.argv.slice(2))
  const includeLogicalExplanations = options.explainLogicalCrossings || options.explainOnFailure
  const includeRankExplanations = options.explainRankOrder || options.explainOnFailure
  const targets = options.fixtures.length > 0 ? options.fixtures : discoverDefaultFixtures()
  if (targets.length === 0) {
    fail('no stress fixtures found (expected fixtures/layout_stress_*.mmd)')
  }

  const tempRoot = mkdtempSync(join(tmpdir(), 'mermaid-layout-stress-'))
  const npmCacheDir = join(tempRoot, '.npm-cache')
  const compareOptions = {
    ...options,
    explainLogicalCrossings: includeLogicalExplanations,
    explainRankOrder: includeRankExplanations,
  }
  const results = targets.map(path =>
    compareFixture(path, tempRoot, npmCacheDir, compareOptions),
  )

  for (const result of results) {
    console.log(`\n=== ${result.fixture} ===`)
    console.log(
      `status=${result.status} nodes shared/local/official=${result.sharedNodes}/${result.localNodes}/${result.officialNodes} edges local/official=${result.localEdges}/${result.officialEdges} fixtureEdges=${result.fixtureEdges}`,
    )
    console.log(
      `rmse=${round(result.rmse)} maxDist=${round(result.maxDist)} inversionRateX=${round(result.inversionRate)} inversionRateY=${round(result.inversionRateY)} majorAxis=${result.majorAxis} majorInversionRate=${round(result.majorInversionRate)}`,
    )
    console.log(
      `majorRankAlignment layers local/official=${result.majorRankLayersLocal}/${result.majorRankLayersOfficial} exact=${round(result.majorRankExactMatchRate)} avgDisp=${round(result.majorRankAvgDisplacement)} compositionMismatch=${result.majorRankCompositionMismatchCount}`,
    )
    console.log(
      `spanRatio x=${round(result.spanXRatio)} y=${round(result.spanYRatio)} area=${round(result.spanAreaRatio)} major=${round(result.majorSpanRatio)} minor=${round(result.minorSpanRatio)}`,
    )
    console.log(
      `polylineCrossings local=${result.localPolylineCrossings} official=${result.officialPolylineCrossings} delta=${result.localPolylineCrossings - result.officialPolylineCrossings} multiplier=${round(result.polylineCrossingMultiplier)}`,
    )
    console.log(
      `logicalCrossings local=${result.localLogicalCrossings} official=${result.officialLogicalCrossings} multiplier=${round(result.logicalCrossingMultiplier)}`,
    )
    if (options.explainLogicalCrossings) {
      printLogicalCrossingExplanation(result)
    }
    if (options.explainRankOrder) {
      printRankOrderExplanation(result)
    }
  }

  const okCount = results.filter(r => r.status === 'ok').length
  const avgRmse =
    results.reduce((acc, row) => acc + (Number.isFinite(row.rmse) ? row.rmse : 0), 0) /
    Math.max(results.length, 1)
  const avgInversion =
    results.reduce((acc, row) => acc + (Number.isFinite(row.inversionRate) ? row.inversionRate : 0), 0) /
    Math.max(results.length, 1)
  const avgInversionY =
    results.reduce((acc, row) => acc + (Number.isFinite(row.inversionRateY) ? row.inversionRateY : 0), 0) /
    Math.max(results.length, 1)
  const avgMajorInversion =
    results.reduce((acc, row) => acc + (Number.isFinite(row.majorInversionRate) ? row.majorInversionRate : 0), 0) /
    Math.max(results.length, 1)
  const avgMajorRankExactMatchRate =
    results.reduce((acc, row) => acc + (Number.isFinite(row.majorRankExactMatchRate) ? row.majorRankExactMatchRate : 0), 0) /
    Math.max(results.length, 1)
  const avgMajorRankDisplacement =
    results.reduce((acc, row) => acc + (Number.isFinite(row.majorRankAvgDisplacement) ? row.majorRankAvgDisplacement : 0), 0) /
    Math.max(results.length, 1)
  const totalMajorRankCompositionMismatches = results.reduce(
    (acc, row) => acc + row.majorRankCompositionMismatchCount,
    0,
  )
  const avgLogicalMultiplier =
    results.reduce((acc, row) => acc + (Number.isFinite(row.logicalCrossingMultiplier) ? row.logicalCrossingMultiplier : 0), 0) /
    Math.max(results.length, 1)
  const avgPolylineMultiplier =
    results.reduce((acc, row) => acc + (Number.isFinite(row.polylineCrossingMultiplier) ? row.polylineCrossingMultiplier : 0), 0) /
    Math.max(results.length, 1)
  const avgSpanAreaRatio =
    results.reduce((acc, row) => acc + (Number.isFinite(row.spanAreaRatio) ? row.spanAreaRatio : 0), 0) /
    Math.max(results.length, 1)
  const avgMajorSpanRatio =
    results.reduce((acc, row) => acc + (Number.isFinite(row.majorSpanRatio) ? row.majorSpanRatio : 0), 0) /
    Math.max(results.length, 1)
  const avgMinorSpanRatio =
    results.reduce((acc, row) => acc + (Number.isFinite(row.minorSpanRatio) ? row.minorSpanRatio : 0), 0) /
    Math.max(results.length, 1)
  const totalLocalPolylineCrossings = results.reduce((acc, row) => acc + row.localPolylineCrossings, 0)
  const totalOfficialPolylineCrossings = results.reduce((acc, row) => acc + row.officialPolylineCrossings, 0)
  const totalLocalLogicalCrossings = results.reduce((acc, row) => acc + row.localLogicalCrossings, 0)
  const totalOfficialLogicalCrossings = results.reduce((acc, row) => acc + row.officialLogicalCrossings, 0)

  console.log('\n=== summary ===')
  console.log(`profile=${options.profile ?? 'custom'}`)
  console.log(`fixtures=${results.length} structural_ok=${okCount}/${results.length}`)
  console.log(
    `avg_rmse=${round(avgRmse)} avg_inversion_rate_x=${round(avgInversion)} avg_inversion_rate_y=${round(avgInversionY)} avg_major_inversion_rate=${round(avgMajorInversion)}`,
  )
  console.log(
    `avg_major_rank_exact_match_rate=${round(avgMajorRankExactMatchRate)} avg_major_rank_displacement=${round(avgMajorRankDisplacement)} total_major_rank_composition_mismatches=${totalMajorRankCompositionMismatches}`,
  )
  console.log(
    `total_polyline_crossings local=${totalLocalPolylineCrossings} official=${totalOfficialPolylineCrossings} delta=${totalLocalPolylineCrossings - totalOfficialPolylineCrossings}`,
  )
  console.log(
    `total_logical_crossings local=${totalLocalLogicalCrossings} official=${totalOfficialLogicalCrossings} delta=${totalLocalLogicalCrossings - totalOfficialLogicalCrossings}`,
  )
  console.log(`avg_polyline_crossing_multiplier=${round(avgPolylineMultiplier)}`)
  console.log(`avg_logical_crossing_multiplier=${round(avgLogicalMultiplier)}`)
  console.log(`avg_span_area_ratio=${round(avgSpanAreaRatio)}`)
  console.log(`avg_major_span_ratio=${round(avgMajorSpanRatio)} avg_minor_span_ratio=${round(avgMinorSpanRatio)}`)
  console.log(`rendered_svgs_dir=${tempRoot}`)

  if (options.jsonPath) {
    const payload = {
      generatedAt: new Date().toISOString(),
      renderedSvgDir: tempRoot,
      options: {
        profile: options.profile ?? null,
        allowUnparsedEdgeLines: options.allowUnparsedEdgeLines,
        maxLogicalCrossingMultiplier: options.maxLogicalCrossingMultiplier ?? null,
        maxPolylineCrossingMultiplier: options.maxPolylineCrossingMultiplier ?? null,
        minSpanXRatio: options.minSpanXRatio ?? null,
        minSpanYRatio: options.minSpanYRatio ?? null,
        minSpanAreaRatio: options.minSpanAreaRatio ?? null,
        minMajorSpanRatio: options.minMajorSpanRatio ?? null,
        minMinorSpanRatio: options.minMinorSpanRatio ?? null,
        maxMajorInversionRate: options.maxMajorInversionRate ?? null,
        maxAvgRmse: options.maxAvgRmse ?? null,
        maxAvgInversionRate: options.maxAvgInversionRate ?? null,
        maxAvgMajorInversionRate: options.maxAvgMajorInversionRate ?? null,
        minAvgMajorSpanRatio: options.minAvgMajorSpanRatio ?? null,
        minAvgMinorSpanRatio: options.minAvgMinorSpanRatio ?? null,
        maxAvgPolylineCrossingMultiplier: options.maxAvgPolylineCrossingMultiplier ?? null,
        maxAvgLogicalCrossingMultiplier: options.maxAvgLogicalCrossingMultiplier ?? null,
        minAvgSpanAreaRatio: options.minAvgSpanAreaRatio ?? null,
        officialTimeoutMs: options.officialTimeoutMs,
        localTimeoutMs: options.localTimeoutMs,
        localRenderRetries: options.localRenderRetries,
        retryBackoffMs: options.retryBackoffMs,
        explainLogicalCrossings: includeLogicalExplanations,
        explainRankOrder: includeRankExplanations,
        explainOnFailure: options.explainOnFailure,
        topCrossingPairs: options.topCrossingPairs,
        topCrossingEdges: options.topCrossingEdges,
      },
      summary: {
        fixtures: results.length,
        structuralOk: okCount,
        avgRmse,
        avgInversionRateX: avgInversion,
        avgInversionRateY: avgInversionY,
        avgMajorInversionRate: avgMajorInversion,
        avgMajorRankExactMatchRate,
        avgMajorRankDisplacement,
        totalMajorRankCompositionMismatches,
        avgMajorSpanRatio,
        avgMinorSpanRatio,
        totalLocalPolylineCrossings,
        totalOfficialPolylineCrossings,
        totalLocalLogicalCrossings,
        totalOfficialLogicalCrossings,
        avgPolylineCrossingMultiplier: avgPolylineMultiplier,
        avgLogicalCrossingMultiplier: avgLogicalMultiplier,
        avgSpanAreaRatio,
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
      if (options.explainOnFailure && !options.explainLogicalCrossings) {
        for (const result of violating) {
          console.error(`\n--- explain ${result.fixture} ---`)
          printLogicalCrossingExplanation(result)
          if (!options.explainRankOrder) {
            printRankOrderExplanation(result)
          }
        }
      }
      process.exitCode = 3
    }
  }

  if (options.maxPolylineCrossingMultiplier !== undefined) {
    const threshold = options.maxPolylineCrossingMultiplier
    const violating = results.filter(result => result.polylineCrossingMultiplier > threshold)
    if (violating.length > 0) {
      console.error(
        [
          `polyline crossing multiplier threshold exceeded: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: multiplier=${round(result.polylineCrossingMultiplier)} local=${result.localPolylineCrossings} official=${result.officialPolylineCrossings}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 4
    }
  }

  if (options.minSpanXRatio !== undefined) {
    const threshold = options.minSpanXRatio
    const violating = results.filter(result => !Number.isFinite(result.spanXRatio) || result.spanXRatio < threshold)
    if (violating.length > 0) {
      console.error(
        [
          `span x ratio minimum not met: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: spanXRatio=${round(result.spanXRatio)}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 5
    }
  }

  if (options.minSpanYRatio !== undefined) {
    const threshold = options.minSpanYRatio
    const violating = results.filter(result => !Number.isFinite(result.spanYRatio) || result.spanYRatio < threshold)
    if (violating.length > 0) {
      console.error(
        [
          `span y ratio minimum not met: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: spanYRatio=${round(result.spanYRatio)}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 6
    }
  }

  if (options.minSpanAreaRatio !== undefined) {
    const threshold = options.minSpanAreaRatio
    const violating = results.filter(
      result => !Number.isFinite(result.spanAreaRatio) || result.spanAreaRatio < threshold,
    )
    if (violating.length > 0) {
      console.error(
        [
          `span area ratio minimum not met: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: spanAreaRatio=${round(result.spanAreaRatio)} x=${round(result.spanXRatio)} y=${round(result.spanYRatio)}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 7
    }
  }

  if (options.minMajorSpanRatio !== undefined) {
    const threshold = options.minMajorSpanRatio
    const violating = results.filter(
      result => !Number.isFinite(result.majorSpanRatio) || result.majorSpanRatio < threshold,
    )
    if (violating.length > 0) {
      console.error(
        [
          `major span ratio minimum not met: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: direction=${result.graphDirection} majorAxis=${result.majorAxis} majorSpanRatio=${round(result.majorSpanRatio)} x=${round(result.spanXRatio)} y=${round(result.spanYRatio)}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 15
    }
  }

  if (options.minMinorSpanRatio !== undefined) {
    const threshold = options.minMinorSpanRatio
    const violating = results.filter(
      result => !Number.isFinite(result.minorSpanRatio) || result.minorSpanRatio < threshold,
    )
    if (violating.length > 0) {
      console.error(
        [
          `minor span ratio minimum not met: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: direction=${result.graphDirection} majorAxis=${result.majorAxis} minorSpanRatio=${round(result.minorSpanRatio)} x=${round(result.spanXRatio)} y=${round(result.spanYRatio)}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 16
    }
  }

  if (options.maxMajorInversionRate !== undefined) {
    const threshold = options.maxMajorInversionRate
    const violating = results.filter(
      result =>
        !Number.isFinite(result.majorInversionRate) || result.majorInversionRate > threshold,
    )
    if (violating.length > 0) {
      console.error(
        [
          `major inversion rate threshold exceeded: threshold=${threshold}`,
          ...violating.map(
            result =>
              `  ${result.fixture}: majorAxis=${result.majorAxis} majorInversionRate=${round(result.majorInversionRate)} x=${round(result.inversionRate)} y=${round(result.inversionRateY)}`,
          ),
        ].join('\n'),
      )
      process.exitCode = 13
    }
  }

  if (options.maxAvgRmse !== undefined && (!Number.isFinite(avgRmse) || avgRmse > options.maxAvgRmse)) {
    console.error(
      `average RMSE threshold exceeded: threshold=${options.maxAvgRmse} avgRmse=${round(avgRmse)}`,
    )
    process.exitCode = 8
  }

  if (
    options.maxAvgInversionRate !== undefined &&
    (!Number.isFinite(avgInversion) || avgInversion > options.maxAvgInversionRate)
  ) {
    console.error(
      `average inversion rate threshold exceeded: threshold=${options.maxAvgInversionRate} avgInversionRate=${round(avgInversion)}`,
    )
    process.exitCode = 9
  }

  if (
    options.maxAvgMajorInversionRate !== undefined &&
    (!Number.isFinite(avgMajorInversion) ||
      avgMajorInversion > options.maxAvgMajorInversionRate)
  ) {
    console.error(
      `average major inversion rate threshold exceeded: threshold=${options.maxAvgMajorInversionRate} avgMajorInversionRate=${round(avgMajorInversion)}`,
    )
    process.exitCode = 14
  }

  if (
    options.minAvgMajorSpanRatio !== undefined &&
    (!Number.isFinite(avgMajorSpanRatio) || avgMajorSpanRatio < options.minAvgMajorSpanRatio)
  ) {
    console.error(
      `average major span ratio minimum not met: threshold=${options.minAvgMajorSpanRatio} avgMajorSpanRatio=${round(avgMajorSpanRatio)}`,
    )
    process.exitCode = 17
  }

  if (
    options.minAvgMinorSpanRatio !== undefined &&
    (!Number.isFinite(avgMinorSpanRatio) || avgMinorSpanRatio < options.minAvgMinorSpanRatio)
  ) {
    console.error(
      `average minor span ratio minimum not met: threshold=${options.minAvgMinorSpanRatio} avgMinorSpanRatio=${round(avgMinorSpanRatio)}`,
    )
    process.exitCode = 18
  }

  if (
    options.maxAvgPolylineCrossingMultiplier !== undefined &&
    (!Number.isFinite(avgPolylineMultiplier) ||
      avgPolylineMultiplier > options.maxAvgPolylineCrossingMultiplier)
  ) {
    console.error(
      `average polyline crossing multiplier threshold exceeded: threshold=${options.maxAvgPolylineCrossingMultiplier} avgPolylineCrossingMultiplier=${round(avgPolylineMultiplier)}`,
    )
    process.exitCode = 10
  }

  if (
    options.maxAvgLogicalCrossingMultiplier !== undefined &&
    (!Number.isFinite(avgLogicalMultiplier) ||
      avgLogicalMultiplier > options.maxAvgLogicalCrossingMultiplier)
  ) {
    console.error(
      `average logical crossing multiplier threshold exceeded: threshold=${options.maxAvgLogicalCrossingMultiplier} avgLogicalCrossingMultiplier=${round(avgLogicalMultiplier)}`,
    )
    process.exitCode = 11
  }

  if (
    options.minAvgSpanAreaRatio !== undefined &&
    (!Number.isFinite(avgSpanAreaRatio) || avgSpanAreaRatio < options.minAvgSpanAreaRatio)
  ) {
    console.error(
      `average span area ratio minimum not met: threshold=${options.minAvgSpanAreaRatio} avgSpanAreaRatio=${round(avgSpanAreaRatio)}`,
    )
    process.exitCode = 12
  }
}

main()
