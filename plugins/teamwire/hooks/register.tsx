import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Lead, Member, MemberState, Msg } from '../types'
import { ago, find, flowOf, fromAgent, fromHerdr, herdrCalls, LEAD, modelOnScreen, oneLine, runs, shortModel, surge, upsert, wireCells } from './model'

const PANE = 'teamwire'
const TITLE = 'Team'
const FRAME_MS = 150
const POLL_MS = 2000

const membersAtom = atom({ plugin: 'teamwire', key: 'members' } as const, [] as Member[])
const msgsAtom = atom({ plugin: 'teamwire', key: 'msgs' } as const, [] as Msg[])
const leadAtom = atom({ plugin: 'teamwire', key: 'lead' } as const, { busy: false, model: '' } as Lead)
const tickAtom = atom({ plugin: 'teamwire', key: 'tick' } as const, 0)

const COLOR: Record<MemberState, string> = {
  working: '#22D3EE',
  reply: '#FBBF24',
  blocked: '#FB7185',
  idle: '#64748B',
  done: '#34D399',
  failed: '#FB7185',
}
const BADGE: Record<MemberState, string> = {
  working: 'WORKING',
  reply: 'REPLY READY',
  blocked: 'NEEDS YOU',
  idle: 'IDLE',
  done: 'DONE',
  failed: 'FAILED',
}
const GLYPH: Record<MemberState, string> = { working: '●', reply: '◉', blocked: '▲', idle: '○', done: '✓', failed: '×' }
/** Each kind of member hangs on its own wire: live while current flows, idle when not. */
const WIRE: Record<Member['kind'], { live: string; idle: string; label: string }> = {
  subagent: { live: '┅', idle: '┄', label: 'subagent' },
  teammate: { live: '═', idle: '═', label: 'teammate' },
  herdr: { live: '━', idle: '─', label: 'herdr' },
  peer: { live: '┉', idle: '┈', label: 'session' },
}
const COPPER = '#475569'
const SPARK = '#F8FAFC'
const GOLD = '#E5B650'

type HerdrAgent = { agent: string; agent_status: string; pane_id: string; name?: string }

// Last model·effort seen per loop ('' the lead's), so a model request writes state only on a change.
const seen = new Map<string, string>()

/** What a model request says the loop runs on: the truth for subagents, whose spawn only names an alias. */
const record = async ($: EngineInterface, agentId: string | undefined, model: string, effort: string | number | undefined) => {
  const key = `${model}|${effort ?? ''}`
  if (seen.get(agentId ?? '') === key) return
  // A subagent's first request can beat its spawn hook to the roster; its next one records it.
  if (agentId && !(await read($, membersAtom)).some(m => m.id === agentId)) return
  seen.set(agentId ?? '', key)
  const fields = { model: shortModel(model), effort: effort === undefined ? undefined : String(effort) }
  if (agentId) await patch($, agentId, m => ({ ...m, ...fields }))
  else await update($, leadAtom, l => ({ ...l, ...fields }))
}

// The person closed the pane: stop opening it unasked until /teamwire.
let dismissed = false
let wasFlowing = false

const show = async ($: EngineInterface) => {
  if (!dismissed) await $.ui.open({ id: PANE, title: TITLE })
}

/** Adds a member (opening the pane for the first one) or patches one already wired. */
const wire = async ($: EngineInterface, id: string, fresh: Omit<Member, 'id' | 'addedAt'>, patch: Partial<Member> = {}) => {
  const now = await $.clock.now()
  const isNew = !(await read($, membersAtom)).some(m => m.id === id)
  await update($, membersAtom, list => upsert(list, id, { ...(isNew ? fresh : {}), ...patch, addedAt: now }))
  if (isNew) await show($)
}

const patch = async ($: EngineInterface, id: string, fn: (m: Member) => Member) => {
  await update($, membersAtom, list => list.map(m => (m.id === id ? fn(m) : m)))
}

const note = async ($: EngineInterface, from: string, to: string, text: string) => {
  const at = await $.clock.now()
  await update($, msgsAtom, list => [...list, { at, from, to, text: oneLine(text, 120) }].slice(-20))
}

const pollAgents = async ($: EngineInterface) => {
  if (!(await read($, membersAtom)).some(m => m.kind === 'subagent' || m.kind === 'teammate')) return
  const listed = await $.agent.list().catch(() => [])
  const now = await $.clock.now()
  await update($, membersAtom, list =>
    list.map(m => {
      const a = (m.kind === 'subagent' || m.kind === 'teammate') && listed.find(x => x.id === m.id)
      if (!a) return m
      const state = fromAgent(a.status)
      if (state === m.state) return m
      return { ...m, state, ...(m.state === 'working' && (state === 'done' || state === 'idle') ? surge('in', now) : {}) }
    }),
  )
}

const pollHerdr = async ($: EngineInterface) => {
  if (!(await read($, membersAtom)).some(m => m.kind === 'herdr')) return
  const r = await $.process.run(['herdr', 'agent', 'list']).catch(() => undefined)
  if (!r || r.exitCode !== 0) return
  let agents: HerdrAgent[]
  try {
    agents = (JSON.parse(r.stdout) as { result: { agents: HerdrAgent[] } }).result.agents
  } catch {
    return
  }
  // One footer read per member whose model is not known yet.
  const models = new Map<string, string>()
  for (const m of await read($, membersAtom)) {
    const pane = m.kind === 'herdr' && m.model === undefined ? (m.pane ?? agents.find(x => x.pane_id === m.id.slice(6) || x.name === m.id.slice(6))?.pane_id) : undefined
    if (!pane) continue
    const screen = await $.process.run(['herdr', 'agent', 'read', pane, '--source', 'visible']).catch(() => undefined)
    const model = screen?.exitCode === 0 ? modelOnScreen(screen.stdout) : undefined
    if (model) models.set(m.id, model)
  }
  const now = await $.clock.now()
  await update($, membersAtom, list =>
    list.map(m => {
      if (m.kind !== 'herdr') return m
      const target = m.id.slice('herdr:'.length)
      const a = agents.find(x => x.pane_id === (m.pane ?? target) || x.name === target)
      const state = fromHerdr(m, a?.agent_status, now)
      const name = m.name === target && a ? (a.name ?? `${a.agent}·${a.pane_id.split(':')[1]}`) : m.name
      const engine = a?.agent ?? m.engine
      const pane = a?.pane_id ?? m.pane
      const model = models.get(m.id) ?? m.model
      if (state === m.state && name === m.name && engine === m.engine && pane === m.pane && model === m.model) return m
      return { ...m, state, name, engine, model, ...(pane ? { pane } : {}), ...(m.state === 'working' && state === 'reply' ? surge('in', now) : {}) }
    }),
  )
}

/** Advances the sparks while current flows, and draws one still frame once it stops. */
const animate = async ($: EngineInterface) => {
  if (dismissed) return
  const now = await $.clock.now()
  const flowing = (await read($, membersAtom)).some(m => flowOf(m, now).dir)
  if (flowing || wasFlowing) await update($, tickAtom, n => n + 1)
  wasFlowing = flowing
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'teamwire', description: 'Open the team wiring diagram: who the lead works with and where current flows' })
    const model = shortModel(await $.session.model().catch(() => ''))
    await update($, leadAtom, l => ({ ...l, model }))
    $.clock.every(POLL_MS, () => void Promise.all([pollAgents($), pollHerdr($)]).catch(() => undefined))
    $.clock.every(FRAME_MS, () => void animate($).catch(() => undefined))
    if ((await read($, membersAtom)).length) await show($)
    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'teamwire' }, async $ => {
    dismissed = false
    await $.ui.open({ id: PANE, title: TITLE })
    const n = (await read($, membersAtom)).length
    return { text: n ? `Teamwire open: ${n} members.` : 'Teamwire open. Members appear when the lead hands out work.' }
  }).catch(($, e, next) => next(e))

  on('ui.close', async ($, e, next) => {
    if (e.id === PANE && e.origin.kind === 'person') dismissed = true
    return next(e)
  }).catch(($, e, next) => next(e))

  // Every model request, the lead's and each agent's: which model, how much effort. Observed, never held up.
  on('turn.step', async function* ($, e, next) {
    void record($, e.agentId, e.model, e.effort).catch(() => undefined)
    return yield* next(e)
  })

  on('turn.start', async ($, e, next) => {
    if (!e.agentId) await update($, leadAtom, l => ({ ...l, busy: true }))
    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    if (!e.agentId) await update($, leadAtom, l => ({ ...l, busy: false }))
    return next(e)
  }).catch(($, e, next) => next(e))

  // A subagent or teammate joins: its task is its role.
  on('agent.spawn', async ($, e, next) => {
    const r = await next(e)
    if (r.deny !== undefined || !r.agentId) return r
    const id = r.agentId
    const now = await $.clock.now()
    await wire($, id, {
      name: oneLine(e.name || e.description, 24),
      kind: r.teammateId ? 'teammate' : 'subagent',
      engine: e.fork ? 'fork' : e.subagentType === 'general-purpose' ? 'general' : e.subagentType,
      // A teammate's prompt arrives wrapped by the engine; the task is what follows the wrapper.
      role: oneLine(e.prompt.replace(/^You are teammate "[^"]*" on team \S+\.\s*/, '') || e.description),
      state: 'working',
      toolUseId: e.tool_use_id,
      bg: e.background,
      model: shortModel(r.model),
      ...surge('out', now),
    })
    await note($, e.parentAgentId ?? LEAD, id, e.description)
    // The engine, not the call, decides background; a foreground spawn of the lead's holds the lead.
    if (!e.background && !e.parentAgentId) await update($, leadAtom, l => ({ ...l, waitingOn: id }))
    return r
  }).catch(($, e, next) => next(e))

  // A foreground Agent call returning: that member has answered.
  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    if (e.agentId) return next(e)
    let ok = false
    try {
      const r = await next(e)
      ok = r.deny === undefined && r.isError !== true
      return r
    } finally {
      const now = await $.clock.now()
      const m = (await read($, membersAtom)).find(x => x.toolUseId === e.tool_use_id)
      // A teammate's or background agent's call returns once it has started; its work goes on.
      if (m && m.kind === 'subagent' && !m.bg) {
        await patch($, m.id, x => ({ ...x, state: ok ? 'done' : 'failed', ...surge('in', now) }))
        await update($, leadAtom, l => (l.waitingOn === m.id ? { ...l, waitingOn: undefined } : l))
      }
    }
  }).catch(($, e, next) => next(e))

  // The lead driving herdr panes: prompts and keys run out, reads pull the answer in.
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const calls = e.agentId ? [] : herdrCalls(e.command ?? '')
    if (!calls.length) return next(e)
    let waitOn: string | undefined
    for (const c of calls) {
      const now = await $.clock.now()
      const known = find(await read($, membersAtom), c.target)
      const id = known?.id ?? `herdr:${c.target}`
      if (c.verb === 'prompt' || c.verb === 'send') {
        await wire(
          $,
          id,
          { name: c.target, kind: 'herdr', engine: '', role: '', state: 'idle' },
          {
            ...(c.verb === 'prompt' ? { state: 'working' as const, model: undefined, ...(c.text ? { role: oneLine(c.text) } : {}) } : {}),
            sentAt: now,
            ...surge('out', now),
          },
        )
        await note($, LEAD, id, c.text || c.verb)
      } else if (c.verb === 'read' && known) {
        await patch($, id, m => ({ ...m, state: m.state === 'reply' ? 'idle' : m.state, ...surge('in', now) }))
      }
      if (c.wait) waitOn = id
    }
    if (waitOn) await update($, leadAtom, l => ({ ...l, waitingOn: waitOn }))
    try {
      return await next(e)
    } finally {
      if (waitOn) await update($, leadAtom, l => (l.waitingOn === waitOn ? { ...l, waitingOn: undefined } : l))
      await pollHerdr($).catch(() => undefined)
    }
  }).catch(($, e, next) => next(e))

  // Messages between the lead, its agents and other sessions.
  on('session.send', async ($, e, next) => {
    const r = await next(e)
    if (!r.isDelivered) return r
    const now = await $.clock.now()
    const from = e.agentId ?? LEAD
    let to = find(await read($, membersAtom), e.to)
    if (!to && from === LEAD) {
      await wire($, `peer:${e.to}`, { name: oneLine(e.to.replace(/^.*\//, ''), 20), kind: 'peer', engine: 'claude', role: oneLine(e.text), state: 'idle' })
      to = find(await read($, membersAtom), e.to)
    }
    if (to) await patch($, to.id, m => ({ ...m, ...surge('out', now) }))
    if (from !== LEAD) await patch($, from, m => ({ ...m, ...surge('in', now) }))
    await note($, from, to?.id ?? e.to, e.text)
    return r
  }).catch(($, e, next) => next(e))

  // A teammate in a pane of its own writes to the team inbox; this process never saw it send.
  on('session.receive', async ($, e, next) => {
    const r = await next(e)
    const o = e.origin as { teammate?: string; isVerified?: boolean }
    const from = typeof o.teammate === 'string' && o.isVerified === false ? find(await read($, membersAtom), o.teammate) : undefined
    if (from) {
      const now = await $.clock.now()
      await patch($, from.id, m => ({ ...m, ...surge('in', now) }))
      await note($, from.id, e.agentId ?? LEAD, e.text)
    }
    return r
  }).catch(($, e, next) => next(e))

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text, Button } = $.ui.resolve(e)
    const tick = await read($, tickAtom)
    const now = await $.clock.now()
    const members = await read($, membersAtom)
    const lead = await read($, leadAtom)
    const msgs = await read($, msgsAtom)
    const nameOf = (id: string) => (id === LEAD ? 'lead' : (members.find(m => m.id === id)?.name ?? id))

    const W = Math.max(48, (e.props.bodyColumns || 80) - 2)
    // A member row is 33 cells besides its wire and name; both give way so it never wraps.
    const NW = Math.max(10, Math.min(20, W - 33 - 12))
    const L = Math.max(4, Math.min(24, W - 33 - NW))
    // Rows the body has room for (an inline pane is short): COMMS gets what the diagram leaves.
    const room = e.props.scroll?.bodyRows ?? 40
    const commsN = Math.max(0, Math.min(3, room - (3 * members.length + 5) - 2))
    const count = (s: MemberState) => members.filter(m => m.state === s).length
    const waiting = lead.waitingOn ? members.find(m => m.id === lead.waitingOn) : undefined
    const leadSays = waiting ? `waiting on ${waiting.name}` : lead.busy ? 'working' : 'idle'

    type Seg = { t: string; c?: string; b?: boolean; d?: boolean }
    const rows: Seg[][] = []
    const boxC = lead.busy ? GOLD : COPPER
    const leadCol = (r: number): Seg[] => {
      if (r === 0) return [{ t: '│', c: boxC }, { t: ' ◆ LEAD   ', c: GOLD, b: true }, { t: '├', c: boxC }]
      if (r === 1) return [{ t: '│', c: boxC }, { t: ` ${lead.model.slice(0, 8).padEnd(9)}`, d: true }, { t: '│', c: boxC }]
      if (r === 2) return [{ t: '╰─', c: boxC }, { t: (lead.effort ?? '').slice(0, 6), d: true }, { t: `${'─'.repeat(9 - Math.min(6, (lead.effort ?? '').length))}╯`, c: boxC }]
      return [{ t: ' '.repeat(12) }]
    }
    const n = members.length
    members.forEach((m, k) => {
      const { dir, hot } = flowOf(m, now)
      const color = COLOR[m.state]
      const isWaitedOn = waiting?.id === m.id
      const bus = n === 1 ? '━' : k === 0 ? '┳' : k === n - 1 ? '┗' : '┣'
      const g = WIRE[m.kind]
      const cable = dir ? g.live : g.idle
      const cells = wireCells(L, dir, tick, hot ? 4 : 7)
      const wireSegs: Seg[] = runs(cells).map(({ v, n: len }) =>
        v === 1
          ? { t: g.live.repeat(len), c: SPARK, b: true }
          : v === 2
            ? { t: g.live.repeat(len), c: color, b: true }
            : { t: cable.repeat(len), c: dir ? color : COPPER, d: !!dir },
      )
      const down = { t: k < n - 1 ? '┃' : ' ', c: COPPER }
      const under = { t: ' '.repeat(L + 5) }
      rows.push([
        ...leadCol(3 * k),
        { t: bus, c: COPPER },
        { t: dir === 'in' ? '◀' : cable, c: dir ? color : COPPER, b: dir === 'in' },
        ...wireSegs,
        { t: dir === 'out' ? '▶' : cable, c: dir ? color : COPPER, b: dir === 'out' },
        { t: ` ${GLYPH[m.state]} `, c: color, b: true },
        { t: oneLine(m.name, NW - 1).padEnd(NW), b: true },
        { t: ` ${BADGE[m.state]} `, c: color, b: true },
        ...(isWaitedOn ? [{ t: ' ⏳', c: GOLD }] : []),
      ])
      // What it is and what it thinks with, then what it was handed.
      rows.push([
        ...leadCol(3 * k + 1),
        down,
        under,
        { t: g.label, c: color },
        { t: ` · ${oneLine([m.engine, m.model, m.effort].filter(Boolean).join(' · ') || '—', Math.max(8, W - L - 21 - g.label.length))}`, d: true },
      ])
      rows.push([...leadCol(3 * k + 2), down, under, { t: oneLine(m.role || '—', Math.max(12, W - L - 19)), d: true }])
    })

    const clear = () =>
      void update($, membersAtom, list => list.filter(m => m.state === 'working' || m.state === 'blocked' || m.state === 'reply'))

    return (
      <Box flexDirection="column" paddingX={1} gap={1}>
        <Box justifyContent="space-between">
          <Text>
            <Text bold color={GOLD}>TEAMWIRE</Text>
            <Text dimColor>{`  ${n} members · ${count('working')} working · ${count('reply')} reply · ${count('blocked')} needs you`}</Text>
          </Text>
          <Text color={waiting ? GOLD : undefined} dimColor={!waiting && !lead.busy}>{`lead: ${leadSays}`}</Text>
        </Box>

        {n === 0 ? (
          <Text dimColor>No team yet. Members appear when the lead spawns agents, messages a session, or prompts a herdr pane.</Text>
        ) : (
          <Box flexDirection="column">
            <Text color={boxC}>╭──────────╮</Text>
            {rows.map((segs, r) => (
              <Text key={`r${r}`}>
                {segs.map((s, i) => (
                  <Text key={`s${i}`} color={s.c} bold={s.b} dimColor={s.d}>
                    {s.t}
                  </Text>
                ))}
              </Text>
            ))}
          </Box>
        )}

        {msgs.length > 0 && commsN > 0 && (
          <Box flexDirection="column">
            <Text dimColor bold>COMMS</Text>
            {msgs
              .slice(-commsN)
              .reverse()
              .map((m, i) => (
                <Text key={`m${i}`}>
                  <Text color={GOLD} bold>{`${nameOf(m.from)} → ${nameOf(m.to)}`}</Text>
                  <Text dimColor>{`  ${oneLine(m.text, Math.max(10, W - 34))}  ${ago(now - m.at)}`}</Text>
                </Text>
              ))}
          </Box>
        )}
        <Box gap={2}>
          <Button key="clear" label="clear finished" hotkey="c" onPress={clear} />
        </Box>
      </Box>
    )
  })
}
