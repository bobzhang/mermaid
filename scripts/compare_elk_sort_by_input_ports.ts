/**
 * Compare local oriented-edge port order against upstream ELK Sort-By-Input-Model ports.
 *
 * Usage:
 *   bun run scripts/compare_elk_sort_by_input_ports.ts fixtures/layout_stress_001_dense_dag.mmd
 *   bun run scripts/compare_elk_sort_by_input_ports.ts fixtures/layout_stress_001_dense_dag.mmd fixtures/layout_stress_013_rl_dual_scc_weave.mmd
 */

import { readFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'

type Direction = 'LR' | 'RL' | 'TB' | 'TD' | 'BT'
type Edge = { source: string; target: string }
type PortOrderBySource = Map<string, string[]>

type LocalTrace = {
  inputNodeIds: string[]
  inputEdges: Edge[]
  virtualNodeIds: Set<string>
  virtualPortsBySource: PortOrderBySource
}

type CaseMetrics = {
  fixture: string
  sourceCount: number
  mismatchSlots: number
  comparableSlots: number
  mismatchDetails: string[]
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
    maxBuffer: 16 * 1024 * 1024,
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
  const feedbackEdges: Edge[] = []
  const seedVirtualNodeIds = new Set<string>()
  const selectedVirtualNodeIds = new Set<string>()
  const seedVirtualTargetBySourceBySlot = new Map<string, Map<number, string>>()
  const selectedVirtualTargetBySourceBySlot = new Map<string, Map<number, string>>()

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
    if (parts[0] === 'FEEDBACK_EDGE') {
      const sourceId = parts[1] ?? ''
      const targetId = parts[2] ?? ''
      if (sourceId !== '' && targetId !== '') {
        feedbackEdges.push({ source: sourceId, target: targetId })
      }
      continue
    }
    if (parts[0] === 'SEED_VIRTUAL_NODE') {
      const nodeId = parts[1] ?? ''
      if (nodeId !== '') {
        seedVirtualNodeIds.add(nodeId)
      }
      continue
    }
    if (parts[0] === 'VIRTUAL_NODE') {
      const nodeId = parts[1] ?? ''
      if (nodeId !== '') {
        selectedVirtualNodeIds.add(nodeId)
      }
      continue
    }
    if (parts[0] === 'SEED_VIRTUAL_PORT') {
      const sourceId = parts[1] ?? ''
      const slot = Number.parseInt(parts[2] ?? '', 10)
      const targetId = parts[3] ?? ''
      if (sourceId === '' || targetId === '' || !Number.isFinite(slot)) {
        fail(`invalid SEED_VIRTUAL_PORT line: ${line}`)
      }
      const bySlot = seedVirtualTargetBySourceBySlot.get(sourceId) ?? new Map<number, string>()
      bySlot.set(slot, targetId)
      seedVirtualTargetBySourceBySlot.set(sourceId, bySlot)
      continue
    }
    if (parts[0] === 'VIRTUAL_PORT') {
      const sourceId = parts[1] ?? ''
      const slot = Number.parseInt(parts[2] ?? '', 10)
      const targetId = parts[3] ?? ''
      if (sourceId === '' || targetId === '' || !Number.isFinite(slot)) {
        fail(`invalid VIRTUAL_PORT line: ${line}`)
      }
      const bySlot = selectedVirtualTargetBySourceBySlot.get(sourceId) ?? new Map<number, string>()
      bySlot.set(slot, targetId)
      selectedVirtualTargetBySourceBySlot.set(sourceId, bySlot)
      continue
    }
  }

  if (inputNodeIdsByIndex.size === 0) {
    fail('local trace missing INPUT_NODE output')
  }
  if (inputEdges.length === 0) {
    fail('local trace missing INPUT_EDGE output')
  }

  const inputNodeIds = [...inputNodeIdsByIndex.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([, nodeId]) => nodeId)
  const selectedSeedVirtualPorts =
    seedVirtualTargetBySourceBySlot.size > 0
      ? seedVirtualTargetBySourceBySlot
      : selectedVirtualTargetBySourceBySlot
  const virtualNodeIds =
    seedVirtualNodeIds.size > 0 ? seedVirtualNodeIds : selectedVirtualNodeIds
  const virtualPortsBySource = new Map<string, string[]>()
  for (const [sourceId, targetBySlot] of selectedSeedVirtualPorts.entries()) {
    const slots = [...targetBySlot.keys()].sort((left, right) => left - right)
    const targets: string[] = []
    for (const slot of slots) {
      const targetId = targetBySlot.get(slot)
      if (typeof targetId === 'string') {
        targets.push(targetId)
      }
    }
    virtualPortsBySource.set(sourceId, targets)
  }
  if (virtualPortsBySource.size === 0) {
    for (const edge of feedbackEdges) {
      const targets = virtualPortsBySource.get(edge.source) ?? []
      targets.push(edge.target)
      virtualPortsBySource.set(edge.source, targets)
    }
  }
  if (virtualPortsBySource.size === 0) {
    fail('local trace missing SEED_VIRTUAL_PORT/VIRTUAL_PORT output')
  }
  return { inputNodeIds, inputEdges, virtualNodeIds, virtualPortsBySource }
}

function parseJsonRecord(raw: string): Record<string, string[]> {
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (error) {
    fail(`invalid upstream ports payload: ${String(error)}`)
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    fail('invalid upstream ports payload: root is not an object')
  }
  const result: Record<string, string[]> = {}
  for (const [sourceId, maybeTargets] of Object.entries(parsed)) {
    if (!Array.isArray(maybeTargets)) {
      fail(`invalid upstream ports payload: source ${sourceId} has non-array value`)
    }
    const targets: string[] = []
    for (const maybeTarget of maybeTargets) {
      if (typeof maybeTarget !== 'string') {
        fail(`invalid upstream ports payload: source ${sourceId} has non-string target`)
      }
      targets.push(maybeTarget)
    }
    result[sourceId] = targets
  }
  return result
}

function runUpstreamSortByInputPorts(
  inputNodeIds: string[],
  inputEdges: Edge[],
  direction: Direction,
): PortOrderBySource {
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
    "    'org.eclipse.elk.debugMode': 'true',",
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
    'const findSortByInputNode = (root) => {',
    "  if (!root || typeof root !== 'object') return null;",
    "  if (root.name === 'Sort By Input Model NODES_AND_EDGES') return root;",
    '  if (Array.isArray(root.children)) {',
    '    for (const child of root.children) {',
    '      const found = findSortByInputNode(child);',
    '      if (found) return found;',
    '    }',
    '  }',
    '  return null;',
    '};',
    'const parsePortsBySource = (logs) => {',
    '  const bySource = new Map();',
    "  const nodePattern = /^Node n_g\\.([^ ]+) ports: \\[(.*)\\]$/;",
    "  const edgePattern = /\\] (>>|<<) \\d+\\[([^\\]]+)\\]$/;",
    '  for (const entry of logs) {',
    '    const text = String(entry);',
    '    const nodeMatch = text.match(nodePattern);',
    '    if (!nodeMatch) continue;',
    '    const sourceId = nodeMatch[1];',
    '    const rawPorts = nodeMatch[2].trim();',
    "    if (rawPorts === '') continue;",
    "    const tokens = rawPorts.split(',').map(token => token.trim());",
    '    for (const token of tokens) {',
    '      const edgeMatch = token.match(edgePattern);',
    "      if (!edgeMatch || edgeMatch[1] !== '>>') continue;",
    '      const rawTarget = edgeMatch[2];',
    "      const targetId = rawTarget.startsWith('n_g.') ? rawTarget.slice('n_g.'.length) : '__virtual__';",
    '      const list = bySource.get(sourceId) ?? [];',
    '      list.push(targetId);',
    '      bySource.set(sourceId, list);',
    '    }',
    '  }',
    '  return Object.fromEntries(bySource);',
    '};',
    "new ELK().layout(graph, { logging: true, measureExecutionTime: true })",
    '  .then(out => {',
    '    const sortNode = findSortByInputNode(out.logging);',
    "    if (!sortNode || !Array.isArray(sortNode.logs)) throw new Error('missing Sort By Input Model phase logs');",
    '    const portsBySource = parsePortsBySource(sortNode.logs);',
    '    process.stdout.write(JSON.stringify(portsBySource));',
    '  })',
    '  .catch(err => {',
    '    console.error(String(err));',
    '    process.exit(1);',
    '  });',
  ].join('\n')

  const stdout = runOrThrow('node', ['-e', script, JSON.stringify(payload)])
  const record = parseJsonRecord(stdout)
  const portsBySource = new Map<string, string[]>()
  for (const [sourceId, targets] of Object.entries(record)) {
    portsBySource.set(sourceId, targets)
  }
  return portsBySource
}

function groupLocalPorts(localTrace: LocalTrace): PortOrderBySource {
  const portsBySource = new Map<string, string[]>()
  const realNodeIds = new Set(localTrace.inputNodeIds)
  for (const sourceId of localTrace.inputNodeIds) {
    const rawTargets = localTrace.virtualPortsBySource.get(sourceId) ?? []
    const targets: string[] = []
    for (const targetId of rawTargets) {
      if (localTrace.virtualNodeIds.has(targetId)) {
        targets.push('__virtual__')
      } else if (realNodeIds.has(targetId)) {
        targets.push(targetId)
      } else {
        targets.push('__virtual__')
      }
    }
    if (targets.length > 0) {
      portsBySource.set(sourceId, targets)
    }
  }
  return portsBySource
}

function comparePortsBySource(
  localPortsBySource: PortOrderBySource,
  upstreamPortsBySource: PortOrderBySource,
): {
  mismatchSlots: number
  comparableSlots: number
  mismatchDetails: string[]
} {
  const sourceIds = new Set<string>([
    ...localPortsBySource.keys(),
    ...upstreamPortsBySource.keys(),
  ])
  let mismatchSlots = 0
  let comparableSlots = 0
  const mismatchDetails: string[] = []
  for (const sourceId of sourceIds) {
    const localTargets = localPortsBySource.get(sourceId) ?? []
    const upstreamTargets = upstreamPortsBySource.get(sourceId) ?? []
    const slotCount = Math.max(localTargets.length, upstreamTargets.length)
    comparableSlots += slotCount
    let sourceMismatch = false
    for (let i = 0; i < slotCount; i += 1) {
      if ((localTargets[i] ?? '') !== (upstreamTargets[i] ?? '')) {
        mismatchSlots += 1
        sourceMismatch = true
      }
    }
    if (sourceMismatch) {
      mismatchDetails.push(
        `${sourceId}: local=[${localTargets.join(',')}] upstream=[${upstreamTargets.join(',')}]`,
      )
    }
  }
  return { mismatchSlots, comparableSlots, mismatchDetails }
}

function compareFixture(fixturePath: string): CaseMetrics {
  const source = readFileSync(fixturePath, 'utf8')
  const direction = parseGraphDirection(source)
  const localTrace = parseLocalTrace(source)
  const localPortsBySource = groupLocalPorts(localTrace)
  const upstreamPortsBySource = runUpstreamSortByInputPorts(
    localTrace.inputNodeIds,
    localTrace.inputEdges,
    direction,
  )
  const { mismatchSlots, comparableSlots, mismatchDetails } = comparePortsBySource(
    localPortsBySource,
    upstreamPortsBySource,
  )
  return {
    fixture: fixturePath,
    sourceCount: new Set([
      ...localPortsBySource.keys(),
      ...upstreamPortsBySource.keys(),
    ]).size,
    mismatchSlots,
    comparableSlots,
    mismatchDetails,
  }
}

function main(): void {
  const fixtures = process.argv.slice(2)
  if (fixtures.length === 0) {
    fail('usage: bun run scripts/compare_elk_sort_by_input_ports.ts <fixture...>')
  }

  const metrics = fixtures.map(compareFixture)
  let totalMismatchSlots = 0
  let totalComparableSlots = 0
  let totalSources = 0

  for (const item of metrics) {
    totalMismatchSlots += item.mismatchSlots
    totalComparableSlots += item.comparableSlots
    totalSources += item.sourceCount
    console.log(`\n=== ${item.fixture} ===`)
    console.log(`sources=${item.sourceCount}`)
    console.log(
      `port_order_mismatch_slots=${item.mismatchSlots}/${item.comparableSlots}`,
    )
    if (item.mismatchDetails.length > 0) {
      for (const detail of item.mismatchDetails) {
        console.log(`mismatch_source ${detail}`)
      }
    }
  }

  console.log('\n=== summary ===')
  console.log(`fixtures=${metrics.length}`)
  console.log(`sources=${totalSources}`)
  console.log(
    `total_port_order_mismatch_slots=${totalMismatchSlots}/${totalComparableSlots}`,
  )
}

main()
