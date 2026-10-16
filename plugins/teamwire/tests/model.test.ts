import { expect, test } from 'claude-code/testing'

import type { Member } from '../types'
import { busyCount, cells, fitRow, shineAt, shineRuns, fromSession, sessionFor, oneLine, padCells, chronicle, dur, fanout, gauge, isStale, kTokens, STALE_MS, flowOf, fromHerdr, herdrCalls, modelOnScreen, runs, shortModel, wireCells } from '../hooks/model'

test('herdrCalls finds who the lead talks to, through quotes, options and chains', async () => {
  expect(herdrCalls(`herdr agent prompt wN:p2 "Review the diff; report \\"only\\" bugs" --wait --timeout 120000`)).toEqual([
    { verb: 'prompt', target: 'wN:p2', text: 'Review the diff; report "only" bugs', wait: true },
  ])
  expect(herdrCalls(`herdr pane read --source recent wN:p3 && herdr agent wait reviewer --until idle`)).toEqual([
    { verb: 'read', target: 'wN:p3', wait: false },
    { verb: 'wait', target: 'reviewer', wait: true },
  ])
  expect(herdrCalls(`~/.local/bin/herdr agent send-keys wN:p2 Enter; echo done`)).toEqual([{ verb: 'keys', target: 'wN:p2', wait: false }])
  expect(herdrCalls(`herdr pane send-text wN:p2 "run the tests"`)).toEqual([{ verb: 'send', target: 'wN:p2', text: 'run the tests', wait: false }])
  expect(herdrCalls(`herdr agent prompt wN:p4 "/teamwire" >/dev/null 2>&1`)).toEqual([{ verb: 'prompt', target: 'wN:p4', text: '/teamwire', wait: false }])
  expect(herdrCalls(`herdr agent list && git status`)).toEqual([])
  expect(herdrCalls(`echo "herdr agent prompt x hi"`)).toEqual([])
})

const member = (patch: Partial<Member>): Member => ({ id: 'herdr:wN:p2', name: 'grok·p2', kind: 'herdr', engine: 'grok', role: '', state: 'idle', addedAt: 0, ...patch })

test('herdr states: a finished worker holds REPLY until the lead reads; fresh prompts ignore stale idles', async () => {
  expect(fromHerdr(member({ state: 'working', sentAt: 0 }), 'idle', 10_000)).toBe('reply')
  expect(fromHerdr(member({ state: 'working', sentAt: 9_000 }), 'idle', 10_000)).toBe('working')
  expect(fromHerdr(member({ state: 'reply' }), 'done', 10_000)).toBe('reply')
  expect(fromHerdr(member({ state: 'idle' }), 'idle', 10_000)).toBe('idle')
  expect(fromHerdr(member({ state: 'working' }), 'blocked', 10_000)).toBe('blocked')
  expect(fromHerdr(member({ state: 'working' }), undefined, 10_000)).toBe('done')
  // Work another session handed the pane does not move a member this lead has settled with.
  expect(fromHerdr(member({ state: 'reply', owed: false }), 'working', 10_000)).toBe('reply')
  expect(fromHerdr(member({ state: 'idle', owed: false }), 'blocked', 10_000)).toBe('idle')
  expect(fromHerdr(member({ state: 'idle', owed: true }), 'working', 10_000)).toBe('working')
})

test('current runs out to a worker, back from a finished one, and surges after a message', async () => {
  expect(flowOf(member({ state: 'working' }), 0)).toEqual({ dir: 'out', hot: false })
  expect(flowOf(member({ state: 'reply' }), 0)).toEqual({ dir: 'in', hot: false })
  expect(flowOf(member({ state: 'idle' }), 0)).toEqual({ hot: false })
  expect(flowOf(member({ state: 'idle', burst: { dir: 'in', until: 5 } }), 1)).toEqual({ dir: 'in', hot: true })
})

test('sparks travel with the current, glow trailing behind', async () => {
  // out: the spark moves right one cell per tick, its glow on its left.
  expect(wireCells(8, 'out', 0, 4)).toEqual([1, 0, 0, 2, 1, 0, 0, 2])
  expect(wireCells(8, 'out', 1, 4)).toEqual([2, 1, 0, 0, 2, 1, 0, 0])
  // in: it moves left, its glow on its right.
  expect(wireCells(8, 'in', 0, 4)).toEqual([1, 2, 0, 0, 1, 2, 0, 0])
  expect(wireCells(8, 'in', 1, 4)).toEqual([2, 0, 0, 1, 2, 0, 0, 1])
  expect(wireCells(4, undefined, 3)).toEqual([0, 0, 0, 0])
  expect(runs([0, 0, 1, 2, 2])).toEqual([{ v: 0, n: 2 }, { v: 1, n: 1 }, { v: 2, n: 2 }])
})

test('the model each agent reasons with, from its footer or its id', async () => {
  expect(modelOnScreen('…\n  ╰──── Grok 4.7 (xhigh) · always-approve ─╯\n  Shift+Tab:mode')).toBe('Grok 4.7 (xhigh)')
  expect(modelOnScreen('› Ask anything\n  gpt-5.5 high · 98% context left')).toBe('gpt-5.5 high')
  expect(modelOnScreen('  ▸ ~/repo   ◇ Opus 5.5·1M·high')).toBe('Opus 5.5')
  expect(modelOnScreen('$ ls\nREADME.md')).toBe(undefined)
  expect(shortModel('claude-haiku-5-5')).toBe('haiku 5.5')
  expect(shortModel('claude-opus-5-5[1m]')).toBe('opus 5.5')
})

test('the fan: rounded ends, branches every third row, the lead at the centre', async () => {
  const one = fanout(1)
  expect([one.lead, one.rows, one.trunk(1), one.trunk(2)]).toEqual([1, 5, '─', ' '])
  const three = fanout(3)
  expect(three.lead).toBe(4)
  expect([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(three.trunk).join('')).toBe(' ╭││┼││╰  ')
  const two = fanout(2)
  expect([two.lead, two.rows]).toEqual([3, 7])
  expect([0, 1, 2, 3, 4, 5].map(two.trunk).join('')).toBe(' ╭│┤╰ ')
})

test('activity: joins, finishes with how long they took, approvals and reads', async () => {
  const base = member({ id: 'm', state: 'working', since: 1_000 })
  expect(chronicle([], [base], 5_000)).toEqual({
    beats: [{ at: 5_000, who: 'm', kind: 'join', text: 'joined as herdr · grok, working' }],
    patches: { m: { stateAt: 5_000, since: 5_000 } },
  })
  expect(chronicle([base], [{ ...base, state: 'reply' }], 81_000).patches).toEqual({ m: { stateAt: 81_000, took: 80_000 } })
  expect(chronicle([base], [{ ...base, state: 'reply' }], 81_000).beats[0]).toEqual({ at: 81_000, who: 'm', kind: 'reply', text: 'finished in 1m 20s · reply ready' })
  expect(chronicle([{ ...base, state: 'reply' }], [{ ...base, state: 'idle' }], 0).beats[0]!.text).toBe('answer read by lead')
  expect(chronicle([base], [{ ...base, state: 'blocked' }], 0).beats[0]!.kind).toBe('block')
  expect(chronicle([{ ...base, state: 'idle' }], [base], 0)).toEqual({ beats: [{ at: 0, who: 'm', kind: 'work', text: 'took a new task' }], patches: { m: { stateAt: 0, since: 0 } } })
  expect(chronicle([base], [base], 9).beats).toEqual([])
  expect([dur(800), dur(80_000), dur(7_500_000)]).toEqual(['1s', '1m 20s', '2h 5m'])
})

test('context gauge: cells filled by share, colour by how full', async () => {
  expect(gauge(42, 5)).toEqual({ on: '▰▰', off: '▱▱▱', level: 'calm' })
  expect(gauge(70, 4).level).toBe('filling')
  expect(gauge(96, 4)).toEqual({ on: '▰▰▰▰', off: '', level: 'full' })
  expect([kTokens(840), kTokens(42_300), kTokens(1_000_000)]).toEqual(['840', '42k', '1M'])
})

test('an unread answer goes stale and stops pulling current; busy counts work held', async () => {
  const reply = member({ state: 'reply', stateAt: 0 })
  expect(isStale(reply, STALE_MS - 1)).toBe(false)
  expect(flowOf(reply, STALE_MS - 1).dir).toBe('in')
  expect(isStale(reply, STALE_MS)).toBe(true)
  expect(flowOf(reply, STALE_MS)).toEqual({ hot: false })
  expect(busyCount([member({ state: 'working' }), member({ state: 'blocked' }), reply])).toBe(2)
  // No state clock (an older version wired it): counted from when it joined.
  expect(isStale(member({ state: 'reply', addedAt: 0 }), STALE_MS)).toBe(true)
  expect(flowOf(member({ state: 'reply', addedAt: 0 }), STALE_MS)).toEqual({ hot: false })
  expect([cells('grok·p2'), cells('리뷰어'), cells('a🧩')]).toEqual([7, 6, 3])
})

test('text is cut by terminal cells, so Hangul never spills past the pane', async () => {
  const task = '[상태 조사, owner 요청] Please reply briefly: what changed'
  const cut = oneLine(task, 30)
  expect(cells(cut)).toBeLessThanOrEqual(30)
  expect(cut).toBe('[상태 조사, owner 요청] Pleas…')
  expect(oneLine('리뷰어', 6)).toBe('리뷰어')
  expect(cells(padCells('리뷰어', 8))).toBe(8)
})

test('a peer address finds its session by name, socket or id, the freshest first', async () => {
  const files = [
    { file: '1.json', name: 'finpilot-89', sessionId: 'a', status: 'idle', updatedAt: 1 },
    { file: '2.json', name: 'finpilot-89', sessionId: 'b', status: 'busy', updatedAt: 2, messagingSocketPath: '/run/s/2.sock' },
  ]
  expect(sessionFor(files, 'finpilot-89')?.file).toBe('2.json')
  expect(sessionFor(files, 'uds:/run/s/2.sock')?.file).toBe('2.json')
  expect(sessionFor(files, 'a')?.file).toBe('1.json')
  expect(sessionFor(files, 'nobody')).toBeUndefined()
  const m = member({ kind: 'peer', state: 'idle' })
  expect(fromSession(m, files[1], ['1.json', '2.json'])).toBe('working')
  expect(fromSession(m, undefined, [])).toBe('idle') // never found: unknown, left alone
  expect(fromSession({ ...m, session: '2.json' }, undefined, ['1.json'])).toBe('done')
  expect(fromSession({ ...m, session: '2.json', state: 'blocked' }, undefined, ['2.json'])).toBe('blocked')
})

test('a light sweeps over a busy name, rests between passes, and splits the name around itself', async () => {
  expect([0, 1, 4, 5, 12, 13].map(t => shineAt(5, t))).toEqual([0, 1, 4, -1, -1, 0])
  expect(shineAt(5, 0, 2)).toBe(2)
  expect(shineRuns('grok·p2', 3)).toEqual([{ t: 'gr', v: 0 }, { t: 'o', v: 1 }, { t: 'k', v: 2 }, { t: '·', v: 1 }, { t: 'p2', v: 0 }])
  expect(shineRuns('grok', -1)).toEqual([{ t: 'grok', v: 0 }])
})

test('a row never runs past the pane: the span at the edge is clipped, the rest dropped', async () => {
  const row = [{ t: 'busy    ' }, { t: '▱'.repeat(10) }, { t: '  0/1 members · 7 handoffs · last event 21s ago' }]
  const fit = fitRow(row, 40)
  expect(fit.map(s => s.t).join('')).toBe('busy    ▱▱▱▱▱▱▱▱▱▱  0/1 members · 7 han…')
  expect(cells(fit.map(s => s.t).join(''))).toBe(40)
  expect(fitRow([{ t: 'ab' }, { t: 'grok·p2', pick: true }, { t: 'x' }], 10, 4).map(s => s.t)).toEqual(['ab', 'grok'.slice(0, 3) + '…'])
  expect(fitRow(row, 200)).toEqual(row)
})
