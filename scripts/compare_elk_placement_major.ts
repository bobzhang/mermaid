/**
 * Compare local ELK layered placement (pre-routing) major/minor node order
 * against upstream elkjs node placement.
 *
 * Usage:
 *   bun run scripts/compare_elk_placement_major.ts fixtures/layout_stress_007_dependency_weave.mmd
 *   bun run scripts/compare_elk_placement_major.ts fixtures/layout_stress_001_dense_dag.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 */

import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Axis = 'x' | 'y'
type Edge = { source: string; target: string }
type LocalTrace = {
  majorStrategy: string
  inputNodeIds: string[]
  inputEdges: Edge[]
  majorByNodeId: Map<string, number>
  minorByNodeId: Map<string, number>
}
type UpstreamPlacement = {
  majorByNodeId: Map<string, number>
  minorByNodeId: Map<string, number>
}
type CaseMetrics = {
  fixture: string
  majorStrategy: string
  sharedNodes: number
  localLayers: number
  upstreamLayers: number
  layerMismatch: number
  inversionRate: number
}

function fail(message: string): never {
  throw new Error(message)
}

function runOrThrow(
  cmd: string,
  args: string[],
  env?: NodeJS.ProcessEnv,
): string {
  const result = spawnSync(cmd, args, {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    maxBuffer: 32 * 1024 * 1024,
    env,
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

function parseGraphDirection(source: string): Direction {
  for (const rawLine of source.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '' || line.startsWith('%')) continue
    const match = line.match(/^(?:flowchart|graph)\s+([A-Za-z]{2})\b/i)
    if (!match) continue
    const dir = match[1]!.toUpperCase()
    if (dir === 'LR' || dir === 'RL' || dir === 'TB' || dir === 'TD' || dir === 'BT') {
      return dir
    }
  }
  return 'LR'
}

function majorAxisByDirection(direction: Direction): Axis {
  if (direction === 'LR' || direction === 'RL') return 'x'
  return 'y'
}

function elkDirection(direction: Direction): 'RIGHT' | 'LEFT' | 'DOWN' | 'UP' {
  if (direction === 'RL') return 'LEFT'
  if (direction === 'BT') return 'UP'
  if (direction === 'TB' || direction === 'TD') return 'DOWN'
  return 'RIGHT'
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
  const inputNodeIdsByIndex = new Map<number, string>()
  const inputEdges: Edge[] = []
  const majorByNodeId = new Map<string, number>()
  const minorByNodeId = new Map<string, number>()
  let majorStrategy = ''

  for (const rawLine of stdout.split(/\r?\n/)) {
    const line = rawLine.trim()
    if (line === '') continue
    const parts = line.split('\t')
    if (parts[0] === 'INPUT_NODE') {
      const index = Number.parseInt(parts[1] ?? '', 10)
      const nodeId = parts[2] ?? ''
      if (Number.isFinite(index) && nodeId !== '') {
        inputNodeIdsByIndex.set(index, nodeId)
      }
      continue
    }
    if (parts[0] === 'INPUT_EDGE') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        inputEdges.push({ source: sourceId, target: targetId })
      }
      continue
    }
    if (parts[0] === 'PLACEMENT_MAJOR_STRATEGY') {
      majorStrategy = parts[1] ?? ''
      continue
    }
    if (parts[0] === 'PLACEMENT_MAJOR') {
      const nodeId = parts[1] ?? ''
      const major = Number.parseInt(parts[2] ?? '', 10)
      if (nodeId !== '' && Number.isFinite(major)) {
        majorByNodeId.set(nodeId, major)
      }
      continue
    }
    if (parts[0] === 'PLACEMENT_MINOR') {
      const nodeId = parts[1] ?? ''
      const minor = Number.parseInt(parts[2] ?? '', 10)
      if (nodeId !== '' && Number.isFinite(minor)) {
        minorByNodeId.set(nodeId, minor)
      }
    }
  }

  if (inputNodeIdsByIndex.size === 0) {
    fail('local trace missing INPUT_NODE output')
  }
  if (inputEdges.length === 0) {
    fail('local trace missing INPUT_EDGE output')
  }
  if (majorByNodeId.size === 0 || minorByNodeId.size === 0) {
    fail('local trace missing placement axis output')
  }
  if (majorStrategy === '') {
    fail('local trace missing PLACEMENT_MAJOR_STRATEGY output')
  }

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)
  return { majorStrategy, inputNodeIds, inputEdges, majorByNodeId, minorByNodeId }
}

function parseJsonPlacement(raw: string): Array<{ id: string; x: number; y: number }> {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream placement payload: ${String(error)}`)
  }
  if (!Array.isArray(parsed)) {
    fail('invalid upstream placement payload: root is not an array')
  }
  const rows: Array<{ id: string; x: number; y: number }> = []
  for (const row of parsed) {
    if (!row || typeof row !== 'object') {
      fail('invalid upstream placement payload: row is not object')
    }
    const maybeId = (row as { id?: unknown }).id
    const maybeX = (row as { x?: unknown }).x
    const maybeY = (row as { y?: unknown }).y
    if (typeof maybeId !== 'string' || typeof maybeX !== 'number' || typeof maybeY !== 'number') {
      fail('invalid upstream placement payload: malformed row')
    }
    rows.push({ id: maybeId, x: maybeX, y: maybeY })
  }
  return rows
}

function runUpstreamPlacement(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
): UpstreamPlacement {
  const payload = {
    inputNodeIds,
    inputEdges,
    elkDirection: elkDirection(direction),
  }
  const script = [
    "const ELK = require('./.repos/elkjs_pkg/package/lib/main.js');",
    'const payload = JSON.parse(process.argv[1]);',
    'const graph = {',
    "  id: 'g',",
    '  layoutOptions: {',
    "    'elk.algorithm': 'layered',",
    "    'org.eclipse.elk.randomSeed': '1',",
    "    'elk.direction': payload.elkDirection,",
    "    'org.eclipse.elk.layered.considerModelOrder.strategy': 'NODES_AND_EDGES',",
    "    'spacing.baseValue': '40',",
    "    'spacing.nodeNode': '130',",
    "    'spacing.nodeNodeBetweenLayers': '90',",
    "    'elk.edgeRouting': 'POLYLINE',",
    "    'org.eclipse.elk.layered.unnecessaryBendpoints': 'true',",
    '  },',
    '  children: payload.inputNodeIds.map(id => ({ id, width: 80, height: 40 })),',
    '  edges: payload.inputEdges.map((edge, index) => ({',
    "    id: `e${index}`,",
    '    sources: [edge.source],',
    '    targets: [edge.target],',
    '  })),',
    '};',
    'new ELK().layout(graph).then(out => {',
    '  const rows = (out.children ?? []).map(child => ({ id: child.id, x: child.x, y: child.y }));',
    '  process.stdout.write(JSON.stringify(rows));',
    '}).catch(err => {',
    '  console.error(String(err));',
    '  process.exit(1);',
    '});',
  ].join('\n')
  const stdout = runOrThrow('node', ['-e', script, JSON.stringify(payload)])
  const rows = parseJsonPlacement(stdout)
  const majorByNodeId = new Map<string, number>()
  const minorByNodeId = new Map<string, number>()
  const majorAxis = majorAxisByDirection(direction)
  for (const row of rows) {
    if (majorAxis === 'x') {
      majorByNodeId.set(row.id, row.x)
      minorByNodeId.set(row.id, row.y)
    } else {
      majorByNodeId.set(row.id, row.y)
      minorByNodeId.set(row.id, row.x)
    }
  }
  return { majorByNodeId, minorByNodeId }
}

function sortByAxis(
  labels: string[],
  majorByNodeId: Map<string, number>,
  minorByNodeId: Map<string, number>,
): string[] {
  return labels
    .slice()
    .sort((left, right) => {
      const leftMajor = majorByNodeId.get(left) ?? 0
      const rightMajor = majorByNodeId.get(right) ?? 0
      if (leftMajor !== rightMajor) return leftMajor - rightMajor
      const leftMinor = minorByNodeId.get(left) ?? 0
      const rightMinor = minorByNodeId.get(right) ?? 0
      if (leftMinor !== rightMinor) return leftMinor - rightMinor
      return left.localeCompare(right)
    })
}

function countPairInversions(reference: string[], actual: string[]): number {
  const index = new Map<string, number>()
  actual.forEach((label, i) => index.set(label, i))
  let inversions = 0
  for (let i = 0; i < reference.length; i += 1) {
    for (let j = i + 1; j < reference.length; j += 1) {
      const left = reference[i]!
      const right = reference[j]!
      if ((index.get(left) ?? 0) > (index.get(right) ?? 0)) {
        inversions += 1
      }
    }
  }
  return inversions
}

function buildLayersByMajor(
  labels: string[],
  majorByNodeId: Map<string, number>,
  minorByNodeId: Map<string, number>,
): string[][] {
  if (labels.length === 0) return []
  const entries = labels
    .map(label => ({
      label,
      major: majorByNodeId.get(label) ?? 0,
      minor: minorByNodeId.get(label) ?? 0,
    }))
    .sort((left, right) => {
      if (left.major !== right.major) return left.major - right.major
      if (left.minor !== right.minor) return left.minor - right.minor
      return left.label.localeCompare(right.label)
    })
  const layers: string[][] = []
  const epsilon = 0.5
  let anchor = entries[0]!.major
  let layer: string[] = []
  for (const entry of entries) {
    if (Math.abs(entry.major - anchor) > epsilon && layer.length > 0) {
      layers.push(layer)
      layer = []
      anchor = entry.major
    }
    layer.push(entry.label)
  }
  if (layer.length > 0) {
    layers.push(layer)
  }
  return layers
}

function layerMismatchCount(left: string[][], right: string[][]): number {
  const maxLayerCount = Math.max(left.length, right.length)
  let mismatch = 0
  for (let i = 0; i < maxLayerCount; i += 1) {
    const leftLayer = (left[i] ?? []).slice().sort()
    const rightLayer = (right[i] ?? []).slice().sort()
    if (JSON.stringify(leftLayer) !== JSON.stringify(rightLayer)) {
      mismatch += 1
    }
  }
  return mismatch
}

function compareFixture(fixturePath: string): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const local = parseLocalTrace(source)
  const upstream = runUpstreamPlacement(local.inputNodeIds, local.inputEdges, direction)
  const sharedLabels = local.inputNodeIds.filter(
    id => local.majorByNodeId.has(id) && upstream.majorByNodeId.has(id),
  )
  const localOrder = sortByAxis(sharedLabels, local.majorByNodeId, local.minorByNodeId)
  const upstreamOrder = sortByAxis(sharedLabels, upstream.majorByNodeId, upstream.minorByNodeId)
  const pairCount = (sharedLabels.length * (sharedLabels.length - 1)) / 2
  const inversions = countPairInversions(upstreamOrder, localOrder)
  const inversionRate = pairCount <= 0 ? 0 : inversions / pairCount

  const localLayers = buildLayersByMajor(
    sharedLabels,
    local.majorByNodeId,
    local.minorByNodeId,
  )
  const upstreamLayers = buildLayersByMajor(
    sharedLabels,
    upstream.majorByNodeId,
    upstream.minorByNodeId,
  )

  return {
    fixture: fixturePath,
    majorStrategy: local.majorStrategy,
    sharedNodes: sharedLabels.length,
    localLayers: localLayers.length,
    upstreamLayers: upstreamLayers.length,
    layerMismatch: layerMismatchCount(localLayers, upstreamLayers),
    inversionRate,
  }
}

function round(value: number): string {
  return Number.isFinite(value) ? value.toFixed(4) : 'NaN'
}

function main(): void {
  const fixtures = process.argv.slice(2)
  if (fixtures.length === 0) {
    fail(
      'usage: bun run scripts/compare_elk_placement_major.ts <fixture.mmd> [more...]',
    )
  }

  const rows = fixtures.map(compareFixture)
  let totalSharedNodes = 0
  let totalLayerMismatch = 0
  let inversionRateSum = 0

  for (const row of rows) {
    console.log(`\n=== ${row.fixture} ===`)
    console.log(`major_strategy=${row.majorStrategy}`)
    console.log(
      `shared_nodes=${row.sharedNodes} layers local/upstream=${row.localLayers}/${row.upstreamLayers}`,
    )
    console.log(
      `layer_mismatch=${row.layerMismatch} inversion_rate=${round(row.inversionRate)}`,
    )
    totalSharedNodes += row.sharedNodes
    totalLayerMismatch += row.layerMismatch
    inversionRateSum += row.inversionRate
  }

  const avgInversionRate = rows.length === 0 ? 0 : inversionRateSum / rows.length
  console.log('\n=== summary ===')
  console.log(`fixtures=${rows.length}`)
  console.log(`total_shared_nodes=${totalSharedNodes}`)
  console.log(`total_layer_mismatch=${totalLayerMismatch}`)
  console.log(`avg_inversion_rate=${round(avgInversionRate)}`)
}

main()
