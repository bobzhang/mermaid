/**
 * Compare upstream ELK Brandes-Koepf placement logs with local MoonBit ELK
 * placement-phase output.
 *
 * Usage:
 *   bun run scripts/compare_elk_bk_phase.ts fixtures/layout_stress_007_dependency_weave.mmd
 *   bun run scripts/compare_elk_bk_phase.ts fixtures/layout_stress_001_dense_dag.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 */

import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Axis = 'x' | 'y'
type Edge = { source: string; target: string }

type LocalPlacementTrace = {
  majorStrategy: string
  inputNodeIds: string[]
  inputEdges: Edge[]
  majorByNodeId: Map<string, number>
}

type UpstreamBkMetrics = {
  chosenLayout: string
  rightdownSize?: number
  rightupSize?: number
  leftdownSize?: number
  leftupSize?: number
  majorByNodeId: Map<string, number>
}

type CaseMetrics = {
  fixture: string
  localMajorStrategy: string
  upstreamChosenLayout: string
  sharedNodes: number
  localMajorSpan: number
  upstreamMajorSpan: number
  majorSpanRatio: number
  rightdownSize?: number
  rightupSize?: number
  leftdownSize?: number
  leftupSize?: number
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

function parseLocalPlacementTrace(source: string): LocalPlacementTrace {
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
    }
  }

  if (inputNodeIdsByIndex.size === 0) {
    fail('local trace missing INPUT_NODE output')
  }
  if (inputEdges.length === 0) {
    fail('local trace missing INPUT_EDGE output')
  }
  if (majorByNodeId.size === 0) {
    fail('local trace missing PLACEMENT_MAJOR output')
  }
  if (majorStrategy === '') {
    fail('local trace missing PLACEMENT_MAJOR_STRATEGY output')
  }

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)
  return { majorStrategy, inputNodeIds, inputEdges, majorByNodeId }
}

function parseUpstreamBkPayload(raw: string): {
  rows: Array<{ id: string; x: number; y: number }>
  bkLogs: string[]
} {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream BK payload: ${String(error)}`)
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    fail('invalid upstream BK payload: root is not an object')
  }
  const rows = (parsed as { rows?: unknown }).rows
  const bkLogs = (parsed as { bkLogs?: unknown }).bkLogs
  if (!Array.isArray(rows) || !Array.isArray(bkLogs)) {
    fail('invalid upstream BK payload: missing rows/bkLogs array')
  }
  const typedRows: Array<{ id: string; x: number; y: number }> = []
  for (const row of rows) {
    if (!row || typeof row !== 'object') {
      fail('invalid upstream BK payload: row is not object')
    }
    const id = (row as { id?: unknown }).id
    const x = (row as { x?: unknown }).x
    const y = (row as { y?: unknown }).y
    if (typeof id !== 'string' || typeof x !== 'number' || typeof y !== 'number') {
      fail('invalid upstream BK payload: malformed row')
    }
    typedRows.push({ id, x, y })
  }
  const typedLogs: string[] = []
  for (const log of bkLogs) {
    if (typeof log !== 'string') {
      fail('invalid upstream BK payload: non-string BK log line')
    }
    typedLogs.push(log)
  }
  return { rows: typedRows, bkLogs: typedLogs }
}

function runUpstreamBkMetrics(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
): UpstreamBkMetrics {
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
    'const findNode = (root, name) => {',
    "  if (!root || typeof root !== 'object') return null;",
    '  if (root.name === name) return root;',
    '  if (Array.isArray(root.children)) {',
    '    for (const child of root.children) {',
    '      const found = findNode(child, name);',
    '      if (found) return found;',
    '    }',
    '  }',
    '  return null;',
    '};',
    "new ELK().layout(graph, { logging: true, measureExecutionTime: true }).then(out => {",
    "  const bkNode = findNode(out.logging, 'Brandes & Koepf node placement');",
    '  const bkLogs = Array.isArray(bkNode?.logs) ? bkNode.logs.map(item => String(item)) : [];',
    '  const rows = (out.children ?? []).map(child => ({ id: child.id, x: child.x, y: child.y }));',
    '  process.stdout.write(JSON.stringify({ rows, bkLogs }));',
    '}).catch(err => {',
    '  console.error(String(err));',
    '  process.exit(1);',
    '});',
  ].join('\n')
  const stdout = runOrThrow('node', ['-e', script, JSON.stringify(payload)])
  const upstream = parseUpstreamBkPayload(stdout)

  const chosenLayoutLine = upstream.bkLogs.find(line =>
    line.startsWith('Chosen node placement: '),
  )
  const chosenLayout = chosenLayoutLine
    ? chosenLayoutLine.slice('Chosen node placement: '.length).trim()
    : 'UNKNOWN'

  const parseSize = (prefix: string): number | undefined => {
    const line = upstream.bkLogs.find(item => item.startsWith(prefix))
    if (!line) return undefined
    const raw = line.slice(prefix.length).trim()
    const value = Number.parseFloat(raw)
    return Number.isFinite(value) ? value : undefined
  }

  const rightdownSize = parseSize('RIGHTDOWN size is ')
  const rightupSize = parseSize('RIGHTUP size is ')
  const leftdownSize = parseSize('LEFTDOWN size is ')
  const leftupSize = parseSize('LEFTUP size is ')

  const majorByNodeId = new Map<string, number>()
  const majorAxis = majorAxisByDirection(direction)
  for (const row of upstream.rows) {
    majorByNodeId.set(row.id, majorAxis === 'x' ? row.x : row.y)
  }
  return {
    chosenLayout,
    rightdownSize,
    rightupSize,
    leftdownSize,
    leftupSize,
    majorByNodeId,
  }
}

function majorSpan(labels: string[], majorByNodeId: Map<string, number>): number {
  let hasMajor = false
  let minMajor = 0
  let maxMajor = 0
  for (const label of labels) {
    const major = majorByNodeId.get(label)
    if (major == null) continue
    if (!hasMajor) {
      hasMajor = true
      minMajor = major
      maxMajor = major
    } else {
      if (major < minMajor) minMajor = major
      if (major > maxMajor) maxMajor = major
    }
  }
  return hasMajor ? maxMajor - minMajor : 0
}

function compareFixture(fixturePath: string): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const local = parseLocalPlacementTrace(source)
  const upstream = runUpstreamBkMetrics(local.inputNodeIds, local.inputEdges, direction)
  const sharedLabels = local.inputNodeIds.filter(
    id => local.majorByNodeId.has(id) && upstream.majorByNodeId.has(id),
  )
  const localMajorSpan = majorSpan(sharedLabels, local.majorByNodeId)
  const upstreamMajorSpan = majorSpan(sharedLabels, upstream.majorByNodeId)
  const majorSpanRatio =
    upstreamMajorSpan <= 1e-9 ? 1 : localMajorSpan / Math.max(upstreamMajorSpan, 1e-9)

  return {
    fixture: fixturePath,
    localMajorStrategy: local.majorStrategy,
    upstreamChosenLayout: upstream.chosenLayout,
    sharedNodes: sharedLabels.length,
    localMajorSpan,
    upstreamMajorSpan,
    majorSpanRatio,
    rightdownSize: upstream.rightdownSize,
    rightupSize: upstream.rightupSize,
    leftdownSize: upstream.leftdownSize,
    leftupSize: upstream.leftupSize,
  }
}

function round(value: number | undefined): string {
  if (value == null || !Number.isFinite(value)) return 'n/a'
  return value.toFixed(4)
}

function main(): void {
  const fixtures = process.argv.slice(2)
  if (fixtures.length === 0) {
    fail('usage: bun run scripts/compare_elk_bk_phase.ts <fixture.mmd> [more...]')
  }

  const rows = fixtures.map(compareFixture)
  let spanRatioSum = 0
  const chosenLayoutCount = new Map<string, number>()
  const localStrategyCount = new Map<string, number>()

  for (const row of rows) {
    spanRatioSum += row.majorSpanRatio
    chosenLayoutCount.set(
      row.upstreamChosenLayout,
      (chosenLayoutCount.get(row.upstreamChosenLayout) ?? 0) + 1,
    )
    localStrategyCount.set(
      row.localMajorStrategy,
      (localStrategyCount.get(row.localMajorStrategy) ?? 0) + 1,
    )

    console.log(`\n=== ${row.fixture} ===`)
    console.log(
      `local_major_strategy=${row.localMajorStrategy} upstream_chosen_layout=${row.upstreamChosenLayout}`,
    )
    console.log(
      `shared_nodes=${row.sharedNodes} major_span local/upstream=${round(row.localMajorSpan)}/${round(row.upstreamMajorSpan)} ratio=${round(row.majorSpanRatio)}`,
    )
    console.log(
      `bk_sizes rightdown=${round(row.rightdownSize)} rightup=${round(row.rightupSize)} leftdown=${round(row.leftdownSize)} leftup=${round(row.leftupSize)}`,
    )
  }

  const avgMajorSpanRatio = rows.length === 0 ? 1 : spanRatioSum / rows.length
  const chosenSummary = [...chosenLayoutCount.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([key, count]) => `${key}:${count}`)
    .join(', ')
  const strategySummary = [...localStrategyCount.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([key, count]) => `${key}:${count}`)
    .join(', ')

  console.log('\n=== summary ===')
  console.log(`fixtures=${rows.length}`)
  console.log(`avg_major_span_ratio=${round(avgMajorSpanRatio)}`)
  console.log(`upstream_chosen_layouts=${chosenSummary}`)
  console.log(`local_major_strategies=${strategySummary}`)
}

main()
