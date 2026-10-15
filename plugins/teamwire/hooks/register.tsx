import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Beat, Lead, Link, Member, MemberState, Msg } from '../types'
import {
  ago,
  busyCount,
  cells,
  chronicle,
  dur,
  fanout,
  gauge,
  kTokens,
  find,
  flowOf,
  fromAgent,
  fromHerdr,
  herdrCalls,
  isStale,
  KIND_LABEL,
  LEAD,
  modelOnScreen,
  oneLine,
  runs,
  shortModel,
  surge,
  upsert,
  wireCells,
} from './model'

const PANE = 'teamwire'
const TITLE = 'Team'
const FRAME_MS = 150
const POLL_MS = 2000
// A message between two members keeps its rail this long.
const LINK_MS = 8000

const membersAtom = atom({ plugin: 'teamwire', key: 'members' } as const, [] as Member[])
const msgsAtom = atom({ plugin: 'teamwire', key: 'msgs' } as const, [] as Msg[])
const beatsAtom = atom({ plugin: 'teamwire', key: 'beats' } as const, [] as Beat[])
const leadAtom = atom({ plugin: 'teamwire', key: 'lead' } as const, { busy: false, model: '' } as Lead)
const tickAtom = atom({ plugin: 'teamwire', key: 'tick' } as const, 0)
const selectedAtom = atom({ plugin: 'teamwire', key: 'selected' } as const, '')
const linkAtom = atom({ plugin: 'teamwire', key: 'link' } as const, null as Link | null)

// Pastel, warm and few: the wires are copper and their current is yellow; red is kept for what needs you,
// green for room to spare. Each state is a step along one family, not a colour of its own.
const BUTTER = '#F1DB8E' // current flowing to a working member
const HONEY = '#E6B17E' // an answer flowing back; a context window filling
const WHEAT = '#CDBF94' // work done
const LINEN = '#EDE3C4' // a member joining
const ASH = '#9A9282' // idle, and quiet figures
const CORAL = '#E8908A' // needs you, failed, a context window nearly full
const SAGE = '#9FCB98' // room to spare
const COPPER = '#6E6656' // a wire with no current, and the rules between sections
const SPARK = '#FFF8E1' // the spark running along a live wire
const GOLD = '#E3C77A' // the lead
const INK = '#2A251D' // text on a chip

const COLOR: Record<MemberState, string> = { working: BUTTER, reply: HONEY, blocked: CORAL, idle: ASH, done: WHEAT, failed: CORAL }
const BADGE: Record<MemberState, string> = {
  working: 'WORKING',
  reply: 'REPLY READY',
  blocked: 'NEEDS YOU',
  idle: 'IDLE',
  done: 'DONE',
  failed: 'FAILED',
}
const GLYPH: Record<MemberState, string> = { working: '●', reply: '◉', blocked: '▲', idle: '○', done: '✓', failed: '×' }
const LEVEL = { calm: SAGE, filling: HONEY, full: CORAL } as const
const BEAT_COLOR: Record<Beat['kind'], string> = { join: LINEN, work: BUTTER, reply: HONEY, done: WHEAT, fail: CORAL, block: CORAL, read: GOLD, idle: ASH }
/** Each kind of member hangs on its own wire: live while current flows, idle when not. */
const WIRE: Record<Member['kind'], { live: string; idle: string }> = {
  subagent: { live: '┅', idle: '┄' },
  teammate: { live: '═', idle: '═' },
  herdr: { live: '━', idle: '─' },
  peer: { live: '┉', idle: '┈' },
}

type HerdrAgent = { agent: string; agent_status: string; pane_id: string; name?: string }

// Last model·effort seen per loop ('' the lead's), so a model request writes state only on a change.
const seen = new Map<string, string>()
// The person closed the pane: stop opening it unasked until /teamwire.
let dismissed = false
let wasFlowing = false
// When the team last went from idle to busy, for the stand-down summary.
let burstAt: number | undefined
let lastStatus: string | undefined

/** Every roster change goes through here, so ACTIVITY hears each join and state change once. */
const mutate = async ($: EngineInterface, fn: (list: Member[]) => Member[]) => {
  const now = await $.clock.now()
  let beats: Beat[] = []
  let busyBefore = 0
  let busyAfter = 0
  let after: Member[] = []
  // Diffed inside the update, against the list it actually changes: two polls racing must not report one change twice.
  await update($, membersAtom, list => {
    const next = fn(list)
    const c = chronicle(list, next, now)
    beats = c.beats
    busyBefore = busyCount(list)
    busyAfter = busyCount(next)
    after = next.map(m => (c.patches[m.id] ? { ...m, ...c.patches[m.id] } : m))
    return after
  })
  const name = (id: string) => after.find(m => m.id === id)?.name ?? id
  // The moments a person should not miss reach them even with the pane closed.
  for (const b of beats) {
    if (b.kind === 'block') {
      $.ui.toast(`▲ ${name(b.who)} needs you`, { timeoutMs: 20_000 })
      void $.ui.notify(`${name(b.who)} needs you: an approval or question is open`, { title: 'teamwire' }).catch(() => undefined)
    } else if (b.kind === 'reply') $.ui.toast(`◉ ${name(b.who)}: reply ready`, { timeoutMs: 10_000 })
    else if (b.kind === 'fail') $.ui.toast(`× ${name(b.who)} failed`, { timeoutMs: 10_000 })
  }
  if (busyBefore === 0 && busyAfter > 0) burstAt = now
  if (busyBefore > 0 && busyAfter === 0) {
    const failed = after.filter(m => m.state === 'failed').length
    // After a reload the burst start is gone; the earliest work clock still knows it.
    const start = burstAt ?? Math.min(now, ...after.map(m => m.since ?? now))
    const text = `team stood down · ${after.length} members · ${dur(now - start)}${failed ? ` · ${failed} failed` : ''}`
    $.ui.toast(`◆ ${text}`, { timeoutMs: 10_000 })
    beats.push({ at: now, who: LEAD, kind: failed ? 'fail' : 'done', text })
  }
  if (beats.length) await update($, beatsAtom, list => [...list, ...beats].slice(-40))
}

/** With the pane closed or not drawn, one status line keeps the team in sight. */
const pushStatus = async ($: EngineInterface) => {
  const members = await read($, membersAtom)
  const lead = await read($, leadAtom)
  const drawn = (await $.ui.panes().catch(() => [])).some(p => p.id === PANE && p.isShown && p.isPlaced)
  const c = (s: MemberState) => members.filter(m => m.state === s).length
  const text =
    members.length && !drawn
      ? `◆ team ${c('working')} working · ${c('reply')} reply${c('blocked') ? ` · ${c('blocked')} needs you` : ''}${lead.ctx ? ` · ctx ${Math.round(lead.ctx.percent)}%` : ''} · /teamwire`
      : undefined
  if (text === lastStatus) return
  lastStatus = text
  $.ui.status(text)
}

/** A message between two members: draw the rail that joins them. */
const linkUp = async ($: EngineInterface, from: string, to: string) => {
  const now = await $.clock.now()
  await update($, linkAtom, () => ({ from, to, until: now + LINK_MS }))
}

const patch = ($: EngineInterface, id: string, fn: (m: Member) => Member) => mutate($, list => list.map(m => (m.id === id ? fn(m) : m)))

const show = async ($: EngineInterface) => {
  if (!dismissed) await $.ui.open({ id: PANE, title: TITLE })
}

/** Adds a member (opening the pane for the first one) or patches one already wired. */
const wire = async ($: EngineInterface, id: string, fresh: Omit<Member, 'id' | 'addedAt'>, fields: Partial<Member> = {}) => {
  const now = await $.clock.now()
  const isNew = !(await read($, membersAtom)).some(m => m.id === id)
  await mutate($, list => upsert(list, id, { ...(isNew ? fresh : {}), ...fields, addedAt: now }))
  if (isNew) await show($)
}

const note = async ($: EngineInterface, from: string, to: string, text: string) => {
  const at = await $.clock.now()
  await update($, msgsAtom, list => [...list, { at, from, to, text: oneLine(text, 120) }].slice(-20))
}

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

const pollAgents = async ($: EngineInterface) => {
  if (!(await read($, membersAtom)).some(m => m.kind === 'subagent' || m.kind === 'teammate')) return
  const listed = await $.agent.list().catch(() => [])
  const now = await $.clock.now()
  await mutate($, list =>
    list.map(m => {
      const a = (m.kind === 'subagent' || m.kind === 'teammate') && listed.find(x => x.id === m.id)
      if (!a) return m
      // A call waiting on approval keeps the member at NEEDS YOU while the roster still says running.
      const state = m.asking && fromAgent(a.status) === 'working' ? 'blocked' : fromAgent(a.status)
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
  await mutate($, list =>
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
    // session.measure only fires on a change; a fresh load reads the figures once.
    const u = await $.session.usage().catch(() => undefined)
    await update($, leadAtom, l => ({
      ...l,
      model,
      ...(u?.context.percent !== undefined ? { ctx: { percent: u.context.percent, tokens: u.context.tokens ?? 0, window: u.context.window } } : {}),
      ...(u?.cost ? { usd: u.cost.usd } : {}),
    }))
    $.clock.every(POLL_MS, () => void Promise.all([pollAgents($), pollHerdr($), pushStatus($)]).catch(() => undefined))
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

  // The lead's context and cost, pushed by the engine whenever they move.
  on('session.measure', async ($, e, next) => {
    const c = e.context
    await update($, leadAtom, l => ({
      ...l,
      ...(c.percent !== undefined ? { ctx: { percent: c.percent, tokens: c.tokens ?? 0, window: c.window } } : {}),
      ...(e.cost ? { usd: e.cost.usd } : {}),
    }))
    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.start', async ($, e, next) => {
    if (!e.agentId) await update($, leadAtom, l => ({ ...l, busy: true }))
    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const id = e.agentId
    const out = e.usage?.output_tokens ?? 0
    if (!id) await update($, leadAtom, l => ({ ...l, busy: false }))
    else if (out) await update($, membersAtom, list => list.map(m => (m.id === id ? { ...m, outTokens: (m.outTokens ?? 0) + out } : m)))
    return next(e)
  }).catch(($, e, next) => next(e))

  // Each tool call an agent makes, counted on its row; one that waited on approval releases NEEDS YOU when it settles.
  on('tool.call', async ($, e, next) => {
    const id = e.agentId
    if (!id) return next(e)
    await update($, membersAtom, list => (list.some(m => m.id === id) ? list.map(m => (m.id === id ? { ...m, tools: (m.tools ?? 0) + 1 } : m)) : list))
    try {
      return await next(e)
    } finally {
      if ((await read($, membersAtom)).some(m => m.id === id && m.asking))
        await patch($, id, m => ({ ...m, asking: false, state: m.state === 'blocked' ? 'working' : m.state }))
    }
  }).catch(($, e, next) => next(e))

  // The engine putting an agent's tool call to the person: that member needs you until the call settles.
  on('tool.check', async ($, e, next) => {
    const r = await next(e)
    const id = e.agentId
    if (id && r.decision === 'ask' && (await read($, membersAtom)).some(m => m.id === id))
      await patch($, id, m => ({ ...m, asking: true, state: m.state === 'working' ? 'blocked' : m.state }))
    return r
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
      role: oneLine(e.prompt.replace(/^You are teammate "[^"]*" on team \S+\.\s*/, '') || e.description, 400),
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
            ...(c.verb === 'prompt' ? { state: 'working' as const, model: undefined, ...(c.text ? { role: oneLine(c.text, 400) } : {}) } : {}),
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
    // A teammate addresses the lead by its team name.
    const toLead = e.to === 'team-lead'
    let to = toLead ? undefined : find(await read($, membersAtom), e.to)
    if (!to && !toLead && from === LEAD) {
      await wire($, `peer:${e.to}`, { name: oneLine(e.to.replace(/^.*\//, ''), 20), kind: 'peer', engine: 'claude', role: oneLine(e.text), state: 'idle' })
      to = find(await read($, membersAtom), e.to)
    }
    if (to) await patch($, to.id, m => ({ ...m, ...surge('out', now) }))
    if (from !== LEAD) await patch($, from, m => ({ ...m, ...surge('in', now) }))
    if (from !== LEAD && to) await linkUp($, from, to.id)
    await note($, from, toLead ? LEAD : (to?.id ?? e.to), e.text)
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
      if (e.agentId) await linkUp($, from.id, e.agentId)
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
    const beats = await read($, beatsAtom)
    const selectedId = await read($, selectedAtom)
    const selected = members.find(m => m.id === selectedId)
    const link = await read($, linkAtom)
    const nameOf = (id: string) => (id === LEAD ? 'lead' : (members.find(m => m.id === id)?.name ?? id))

    const W = Math.max(48, (e.props.bodyColumns || 80) - 2)
    const n = members.length
    const count = (s: MemberState) => members.filter(m => m.state === s).length
    const waiting = lead.waitingOn ? members.find(m => m.id === lead.waitingOn) : undefined
    const live = members.filter(m => flowOf(m, now).dir).length

    // A Seg with `pick` is a member's name: pressing it opens FOCUS on that member.
    type Seg = { t: string; c?: string; bg?: string; b?: boolean; d?: boolean; u?: boolean; pick?: { id: string; hotkey?: string } }
    const span = (s: Seg, i: number) => (
      <Text key={`s${i}`} color={s.c} backgroundColor={s.bg} bold={s.b} dimColor={s.d} underline={s.u}>
        {s.t}
      </Text>
    )
    const line = (key: string, segs: Seg[]) => {
      const pick = segs.find(s => s.pick)
      if (!pick) return <Text key={key}>{segs.map(span)}</Text>
      return (
        <Box key={key}>
          {segs.map((s, i) =>
            s.pick ? (
              <Button key={`m-${s.pick.id}`} hotkey={s.pick.hotkey} onPress={() => void update($, selectedAtom, cur => (cur === s.pick!.id ? '' : s.pick!.id))}>
                {span(s, i)}
              </Button>
            ) : (
              span(s, i)
            ),
          )}
        </Box>
      )
    }
    // A terminal Button draws its own `[ … ]` around the label.
    const BTN = e.surface === 'terminal' ? 4 : 0
    const width = (segs: Seg[]) => segs.reduce((w, s) => w + cells(s.t) + (s.pick ? BTN : 0), 0)
    // A titled divider: the section's name, a rule across, what it holds on the right.
    const section = (title: string, meta: string, c = GOLD) =>
      line(`h-${title}`, [
        { t: title, c, b: true },
        { t: ` ${'─'.repeat(Math.max(2, W - cells(title) - cells(meta) - 2))} `, c: COPPER },
        { t: meta, d: true },
      ])

    // ── Dashboard ──
    const leadChip = waiting
      ? { text: ` ◆ LEAD · WAITING ON ${waiting.name.toUpperCase()} `, bg: GOLD }
      : lead.busy
        ? { text: ' ◆ LEAD · WORKING ', bg: BUTTER }
        : { text: ' ◆ LEAD · IDLE ', bg: ASH }
    const first = members.reduce((t, m) => Math.min(t, m.addedAt), now)
    const tiles: { label: string; value: string; color: string; on: boolean }[] = [
      { label: 'TEAM', value: String(n), color: SPARK, on: n > 0 },
      { label: 'WORKING', value: String(count('working')), color: BUTTER, on: count('working') > 0 },
      { label: 'REPLY', value: String(count('reply')), color: HONEY, on: count('reply') > 0 },
      { label: 'NEEDS YOU', value: String(count('blocked')), color: CORAL, on: count('blocked') > 0 },
      { label: 'DONE', value: `${count('done')}${count('failed') ? `/${count('failed')}✗` : ''}`, color: count('failed') ? CORAL : WHEAT, on: count('done') + count('failed') > 0 },
      { label: 'UPTIME', value: n ? dur(now - first) : '—', color: SPARK, on: n > 0 },
    ]
    const busy = busyCount(members)
    const barW = Math.max(8, Math.min(24, W - 44))
    const filled = n ? Math.round((busy / n) * barW) : 0
    const lastBeat = beats[beats.length - 1]
    const ctxPct = Math.round(lead.ctx?.percent ?? 0)

    // ── Orchestration: the lead at the centre of a rounded fan, one branch per member ──
    const RAIL = link && link.until > now ? 3 : 0
    const NW = Math.max(10, Math.min(20, W - 41 - 12))
    const L = Math.max(4, Math.min(22, W - 41 - NW))
    const fan = fanout(Math.max(1, n))
    const boxC = lead.busy ? GOLD : COPPER
    const effort = (lead.effort ?? '').slice(0, 6)
    const leadCol = (r: number): Seg[] => {
      if (r === fan.lead - 1) return [{ t: '╭──────────╮', c: boxC }]
      if (r === fan.lead) return [{ t: '│', c: boxC }, { t: ' ◆ LEAD   ', c: GOLD, b: true }, { t: '├', c: boxC }]
      if (r === fan.lead + 1) return [{ t: '│', c: boxC }, { t: ` ${lead.model.slice(0, 8).padEnd(9)}`, d: true }, { t: '│', c: boxC }]
      if (r === fan.lead + 2) {
        const g = gauge(ctxPct, 5)
        return [{ t: '│ ', c: boxC }, { t: g.on, c: LEVEL[g.level] }, { t: g.off, c: COPPER }, { t: lead.ctx ? `${ctxPct}%`.padStart(4) : '  — ', d: !lead.ctx }, { t: '│', c: boxC }]
      }
      if (r === fan.lead + 3) return [{ t: '╰─', c: boxC }, { t: effort, d: true }, { t: `${'─'.repeat(9 - effort.length)}╯`, c: boxC }]
      return [{ t: ' '.repeat(12) }]
    }
    const metrics = (m: Member) => {
      const t = m.state === 'working' || m.state === 'blocked' ? (m.since !== undefined ? dur(now - m.since) : '') : m.took !== undefined ? dur(m.took) : ''
      return [t, m.tools ? `${m.tools} tools` : '', m.outTokens ? `${kTokens(m.outTokens)} out` : ''].filter(Boolean).join(' · ')
    }
    const diagram: Seg[][] = []
    for (let r = 0; r < fan.rows; r++) {
      const head: Seg[] = [...leadCol(r), { t: r === fan.lead ? '──' : '  ', c: live ? GOLD : COPPER }, { t: fan.trunk(r), c: COPPER }]
      const k = Math.floor((r - 1) / 3)
      const m = r >= 1 && k < n ? members[k] : undefined
      if (!m) {
        diagram.push(head)
        continue
      }
      const color = COLOR[m.state]
      const under = { t: ' '.repeat(L + 6) }
      const stale = isStale(m, now)
      if ((r - 1) % 3 === 0) {
        const { dir, hot } = flowOf(m, now)
        const g = WIRE[m.kind]
        const cable = dir ? g.live : g.idle
        const wireSegs: Seg[] = runs(wireCells(L, dir, tick, hot ? 4 : 7)).map(({ v, n: len }) =>
          v === 1
            ? { t: g.live.repeat(len), c: SPARK, b: true }
            : v === 2
              ? { t: g.live.repeat(len), c: color, b: true }
              : { t: cable.repeat(len), c: dir ? color : COPPER, d: !!dir },
        )
        diagram.push([
          ...head,
          { t: '─', c: COPPER },
          { t: dir === 'in' ? '◀' : cable, c: dir ? color : COPPER, b: dir === 'in' },
          ...wireSegs,
          { t: dir === 'out' ? '▶' : cable, c: dir ? color : COPPER, b: dir === 'out' },
          { t: ` ${GLYPH[m.state]} `, c: color, b: true },
          {
            t: oneLine(m.name, NW - 1 - BTN),
            b: true,
            u: selected?.id === m.id,
            c: selected?.id === m.id ? GOLD : undefined,
            pick: { id: m.id, ...(k < 9 ? { hotkey: String(k + 1) } : {}) },
          },
          { t: ' '.repeat(Math.max(1, NW - BTN - cells(oneLine(m.name, NW - 1 - BTN)))) },
          stale ? { t: ` REPLY · ${dur(now - (m.stateAt ?? now))} `, c: HONEY, bg: COPPER, b: true } : { t: ` ${BADGE[m.state]} `, c: INK, bg: color, b: true },
          ...(waiting?.id === m.id ? [{ t: ' ◆', c: GOLD }] : []),
        ])
      } else if ((r - 1) % 3 === 1) {
        // What it is and what it thinks with; on the right, its clock and spend.
        const label = KIND_LABEL[m.kind]
        const mx = metrics(m)
        const room = Math.max(8, W - L - 28 - label.length - RAIL - (mx ? cells(mx) + 2 : 0))
        diagram.push([
          ...head,
          under,
          { t: label, c: color },
          { t: ` · ${oneLine([m.engine, m.model, m.effort].filter(Boolean).join(' · ') || '—', room)}`, d: true },
          ...(mx ? [{ t: `  ${mx}`, c: ASH }] : []),
        ])
      } else diagram.push([...head, under, { t: oneLine(m.role || '—', Math.max(12, W - L - 21 - RAIL)), d: true }])
    }
    // Two members talking: a rail on the right joins their rows, the arrow on the receiver's.
    if (RAIL && link) {
      const a = members.findIndex(m => m.id === link.from)
      const b = members.findIndex(m => m.id === link.to)
      if (a >= 0 && b >= 0 && a !== b) {
        const [top, bottom] = [1 + 3 * Math.min(a, b), 1 + 3 * Math.max(a, b)]
        const col = W - RAIL
        for (let r = top; r <= bottom; r++) {
          const row = diagram[r]!
          const pad = Math.max(0, col - width(row))
          const end = r === top ? '╮' : r === bottom ? '╯' : '│'
          const tip = r === 1 + 3 * b ? '◀─' : r === 1 + 3 * a ? '──' : '  '
          row.push({ t: ' '.repeat(pad) }, { t: tip + end, c: GOLD, b: true })
        }
      }
    }

    // ── Focus: one member in full ──
    const focus: Seg[][] = []
    if (selected) {
      const m = selected
      const label = (t: string) => ({ t: t.padEnd(9), d: true })
      const wrap = (t: string, w: number) => {
        const out: string[] = []
        let rest = t
        while (rest && out.length < 3) {
          out.push(rest.slice(0, w))
          rest = rest.slice(w)
        }
        return out
      }
      focus.push([label('state'), { t: ` ${BADGE[m.state]} `, c: INK, bg: COLOR[m.state], b: true }, { t: `  for ${dur(now - (m.stateAt ?? m.addedAt))}`, d: true }])
      focus.push([label('agent'), { t: [KIND_LABEL[m.kind], m.engine, m.model, m.effort].filter(Boolean).join(' · ') }])
      wrap(m.role || '—', W - 10).forEach((t, i) => focus.push([label(i ? '' : 'task'), { t }]))
      focus.push([label('spend'), { t: metrics(m) || '—' }])
      const said = msgs.filter(x => x.from === m.id || x.to === m.id).slice(-2)
      said.forEach((x, i) => focus.push([label(i ? '' : 'comms'), { t: `${nameOf(x.from)} → ${nameOf(x.to)}  `, c: GOLD }, { t: oneLine(x.text, W - 40), d: true }, { t: `  ${ago(now - x.at)}`, d: true }]))
    }

    // ── Room: an inline pane is short; diagram, then FOCUS, ACTIVITY, COMMS ──
    const room = e.props.scroll?.bodyRows ?? 40
    const roomTiles = room - (fan.rows + 1) - 4 >= 7
    let left = room - 1 - (roomTiles ? 7 : 2) - (fan.rows + 2) - 2
    const focusN = selected ? Math.max(0, Math.min(focus.length, left - 2)) : 0
    left -= focusN ? focusN + 2 : 0
    const actN = Math.max(0, Math.min(6, beats.length, left - 2))
    left -= actN ? actN + 2 : 0
    const commsN = Math.max(0, Math.min(3, msgs.length, left - 2))

    const clear = () => void update($, membersAtom, list => list.filter(m => m.state === 'working' || m.state === 'blocked' || m.state === 'reply'))
    const clearLog = () => {
      void update($, msgsAtom, () => [])
      void update($, beatsAtom, () => [])
    }
    const key = (id: string, k: string, label: string, onPress: () => void) => (
      <Button key={id} hotkey={k} onPress={onPress}>
        <Text backgroundColor={GOLD} color={INK} bold>{` ${k} `}</Text>
        <Text backgroundColor={COPPER} color={SPARK}>{` ${label} `}</Text>
      </Button>
    )

    return (
      <Box flexDirection="column" paddingX={1}>
        <Box justifyContent="space-between">
          <Text>
            <Text bold color={GOLD}>◆ TEAMWIRE</Text>
            <Text dimColor>{'  agent team, live'}</Text>
          </Text>
          <Text backgroundColor={leadChip.bg} color={INK} bold>
            {oneLine(leadChip.text, Math.max(12, W - 26))}
          </Text>
        </Box>

        {roomTiles ? (
          <Box flexDirection="column" marginTop={1}>
            <Box gap={1} flexWrap="wrap">
              {tiles.map(t => (
                <Box key={t.label} borderStyle="round" borderColor={t.on ? t.color : COPPER} paddingX={1} flexDirection="column" minWidth={11}>
                  <Text bold color={t.on ? t.color : undefined} dimColor={!t.on}>
                    {t.value}
                  </Text>
                  <Text dimColor>{t.label}</Text>
                </Box>
              ))}
            </Box>
            {line('bar', [
              { t: 'busy    ', d: true },
              { t: '▰'.repeat(filled), c: BUTTER },
              { t: '▱'.repeat(barW - filled), c: COPPER },
              { t: `  ${busy}/${n} members · ${msgs.length} handoffs${lastBeat ? ` · last event ${ago(now - lastBeat.at)} ago` : ''}`, d: true },
            ])}
            {lead.ctx &&
              line('ctx', [
                { t: 'context ', d: true },
                { t: gauge(ctxPct, barW).on, c: LEVEL[gauge(ctxPct, barW).level] },
                { t: gauge(ctxPct, barW).off, c: COPPER },
                { t: `  ${ctxPct}% · ${kTokens(lead.ctx.tokens)} / ${kTokens(lead.ctx.window)} tokens${lead.usd !== undefined ? ` · $${lead.usd.toFixed(2)}` : ''}`, d: true },
              ])}
          </Box>
        ) : (
          line('summary', [
            { t: `${n} team`, b: true },
            { t: ' · ', d: true },
            { t: `${count('working')} working`, c: BUTTER },
            { t: ' · ', d: true },
            { t: `${count('reply')} reply`, c: HONEY },
            { t: ' · ', d: true },
            { t: `${count('blocked')} needs you`, c: CORAL },
            { t: ' · ', d: true },
            { t: `ctx ${ctxPct}%`, c: LEVEL[gauge(ctxPct, 1).level] },
          ])
        )}

        <Box flexDirection="column" marginTop={1}>
          {section('ORCHESTRATION', n ? `${n} wires · ${live} live${n > 1 ? ` · 1-${Math.min(9, n)} focus` : ' · 1 focus'}` : 'no team yet')}
          {n === 0 ? (
            <Text dimColor>Members appear when the lead spawns agents, messages a session, or prompts a herdr pane.</Text>
          ) : (
            diagram.map((segs, r) => line(`r${r}`, segs))
          )}
        </Box>

        {focusN > 0 && selected && (
          <Box flexDirection="column" marginTop={1}>
            {section(`FOCUS · ${oneLine(selected.name, 24)}`, `press ${members.indexOf(selected) + 1} to close`, COLOR[selected.state])}
            {focus.slice(0, focusN).map((segs, i) => line(`f${i}`, segs))}
          </Box>
        )}

        {actN > 0 && (
          <Box flexDirection="column" marginTop={1}>
            {section('ACTIVITY', `${beats.length} events`)}
            {beats
              .slice(-actN)
              .reverse()
              .map((b, i) =>
                line(`b${i}`, [
                  { t: '▍', c: BEAT_COLOR[b.kind] },
                  { t: ` ${oneLine(nameOf(b.who), 18).padEnd(19)}`, b: true },
                  { t: oneLine(b.text, Math.max(10, W - 30)).padEnd(Math.max(10, W - 30)), c: BEAT_COLOR[b.kind] },
                  { t: ` ${ago(now - b.at).padStart(4)}`, d: true },
                ]),
              )}
          </Box>
        )}

        {commsN > 0 && (
          <Box flexDirection="column" marginTop={1}>
            {section('COMMS', `${msgs.length} handoffs`)}
            {msgs
              .slice(-commsN)
              .reverse()
              .map((m, i) =>
                line(`m${i}`, [
                  { t: `${oneLine(nameOf(m.from), 14)} → ${oneLine(nameOf(m.to), 18)}`, c: GOLD, b: true },
                  { t: `  ${oneLine(m.text, Math.max(10, W - 44))}`, d: true },
                  { t: `  ${ago(now - m.at)}`, d: true },
                ]),
              )}
          </Box>
        )}

        <Box gap={2} marginTop={1}>
          {key('clear', 'c', 'clear finished', clear)}
          {key('log', 'l', 'clear log', clearLog)}
        </Box>
      </Box>
    )
  })
}
