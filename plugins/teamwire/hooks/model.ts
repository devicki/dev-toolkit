import type { Beat, Dir, Member, MemberState, Msg } from '../types'

export const LEAD = 'lead'
export const BURST_MS = 4000
/** An answer nobody has read for this long stops pulling current. */
export const STALE_MS = 5 * 60_000
/** herdr may still report idle right after a prompt lands; trust it only after this. */
const SETTLE_MS = 5000

/** `prompt`/`send` hand over work; `keys` only presses keys (an approval, Enter); `read` takes the answer; `wait` holds the lead; `close` ends the member. */
export type HerdrCall = { verb: 'prompt' | 'send' | 'keys' | 'read' | 'wait' | 'close'; target: string; text?: string; brief?: string; wait: boolean }

const VERBS: Record<string, HerdrCall['verb']> = {
  'agent prompt': 'prompt',
  'agent send-keys': 'keys',
  'pane send-text': 'send',
  'pane send-keys': 'keys',
  'pane run': 'send',
  'agent read': 'read',
  'pane read': 'read',
  'agent wait': 'wait',
}
const VALUED = new Set(['--source', '--until', '--timeout', '--lines', '--machine', '--session', '--remote'])
const SEP = '\u0000'
/** dstack's `delegate.py` runs herdr from Python, so its own subcommands are the calls; every one names the agent in `--name`. */
const DELEGATE = /(^|\/)delegate\.py$/
const DELEGATE_VERBS: Record<string, HerdrCall['verb']> = { run: 'prompt', wait: 'wait', close: 'close' }
const VAR = /\$\{?([A-Za-z_]\w*)\}?/g

/** Shell-ish split: quotes group, `;`, `&`, `|` and newlines end a command. */
export function words(cmd: string): string[] {
  const out: string[] = []
  let cur = ''
  let has = false
  let q = ''
  const push = () => {
    if (cur || has) out.push(cur)
    cur = ''
    has = false
  }
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i]!
    if (q) {
      if (c === q) q = ''
      else if (c === '\\' && q === '"' && i + 1 < cmd.length) cur += cmd[++i]
      else cur += c
    } else if (c === '"' || c === "'") {
      q = c
      has = true
    } else if (c === '\\' && i + 1 < cmd.length) {
      cur += cmd[++i]
    } else if (c === ';' || c === '&' || c === '|' || c === '\n') {
      push()
      out.push(SEP)
    } else if (/\s/.test(c)) push()
    else cur += c
  }
  push()
  return out
}

/**
 * The herdr calls in a Bash command that talk to another agent.
 * shortcut: a target in a variable is resolved only by the pane ids the command spells out (`expandCalls`); a helper sourced from a file or panes built at runtime stay unseen.
 */
export function herdrCalls(cmd: string): HerdrCall[] {
  const w = words(cmd)
  const vars = shellVars(w)
  const calls: HerdrCall[] = []
  for (let i = 0; i < w.length; i++) {
    // The script by its path (even `${CLAUDE_PLUGIN_ROOT}/…`), or a variable the command set to it (`D=…/delegate.py; python3 $D`).
    if (DELEGATE.test(w[i]!) || subst(w[i]!, vars).some(x => DELEGATE.test(x))) calls.push(...delegateCall(w, i + 1, vars))
    if (!/(^|\/)herdr$/.test(w[i]!)) continue
    let j = i + 1
    while (w[j]?.startsWith('--')) j += VALUED.has(w[j]!) ? 2 : 1
    const verb = VERBS[`${w[j]} ${w[j + 1]}`]
    if (!verb) continue
    const pos: string[] = []
    let wait = verb === 'wait'
    for (j += 2; j < w.length && w[j] !== SEP; j++) {
      const t = w[j]!
      if (t === '--wait') wait = true
      else if (VALUED.has(t)) j++
      // Redirections (`>/dev/null`, `2>`) are the shell's, not the message's.
      else if (!t.startsWith('--') && !/^\d*[<>]/.test(t)) pos.push(t)
    }
    if (pos[0]) calls.push({ verb, target: pos[0], ...(verb === 'prompt' || verb === 'send' ? { text: pos.slice(1).join(' ') } : {}), wait })
  }
  return calls
}

/**
 * The variables a command sets itself: `X=value` at the start of a command, and the list of `for X in a b c` (or `{1..4}`).
 * shortcut: a value built at runtime (`$(…)`, a glob) stays unknown, so a name that needs it is dropped rather than guessed.
 */
function shellVars(w: string[]): Map<string, string[]> {
  const vars = new Map<string, string[]>()
  for (let i = 0; i < w.length; i++) {
    if (i > 0 && w[i - 1] !== SEP) continue
    const a = /^([A-Za-z_]\w*)=(.*)$/.exec(w[i]!)
    const v = a && subst(a[2]!, vars)
    if (a && v?.length === 1 && !isVar(v[0]!)) vars.set(a[1]!, v)
    if (w[i] !== 'for' || w[i + 2] !== 'in') continue
    const list: string[] = []
    for (let j = i + 3; j < w.length && w[j] !== SEP; j++) {
      const r = /^\{(\d+)\.\.(\d+)\}$/.exec(w[j]!)
      if (r) for (let n = +r[1]!; n <= +r[2]!; n++) list.push(String(n))
      else list.push(w[j]!)
    }
    if (list.length && !list.some(x => isVar(x) || x.includes('*'))) vars.set(w[i + 1]!, list)
  }
  return vars
}

/** `word` with the command's own variables filled in, one result per loop value; empty when a variable is unknown. */
function subst(word: string, vars: Map<string, string[]>): string[] {
  let out = [word]
  for (const m of word.matchAll(VAR)) {
    const vals = vars.get(m[1]!)
    if (!vals) return []
    out = out.flatMap(o => vals.map(v => o.replace(m[0], v)))
  }
  return out
}

/** `delegate.py run|wait|close --name X …` from word `at`: one call per name, a loop's brief paired with its name. */
function delegateCall(w: string[], at: number, vars: Map<string, string[]>): HerdrCall[] {
  const verb = DELEGATE_VERBS[w[at] ?? '']
  if (!verb) return []
  const opt: Record<string, string> = {}
  for (let j = at + 1; j < w.length && w[j] !== SEP; j++) {
    const t = w[j]!
    const eq = t.indexOf('=')
    if (t.startsWith('--') && eq > 0) opt[t.slice(0, eq)] = t.slice(eq + 1)
    else if (t.startsWith('--') && w[j + 1] !== undefined && w[j + 1] !== SEP) opt[t] = w[++j]!
  }
  const name = opt['--name'] ?? ''
  const loop = [...name.matchAll(VAR)].map(m => m[1]!).find(v => (vars.get(v)?.length ?? 0) > 1)
  const envs = loop ? vars.get(loop)!.map(x => new Map(vars).set(loop, [x])) : [vars]
  return envs.flatMap(env =>
    subst(name, env)
      .filter(target => target && !isVar(target))
      .map(target => {
        const brief = subst(opt['--brief'] ?? '', env)[0]
        return {
          verb,
          target,
          ...(verb === 'prompt' ? { text: `delegate: ${target}`, ...(brief ? { brief } : {}) } : {}),
          wait: verb !== 'close',
        }
      }),
  )
}

/** A brief file's first line of prose (a heading only when there is nothing else), for a role. */
export const briefLine = (file: unknown) => {
  if (typeof file !== 'string') return
  const lines = file.split('\n').map(l => l.trim()).filter(Boolean)
  return lines.find(l => !l.startsWith('#')) ?? lines[0]?.replace(/^#+\s*/, '')
}

/** A target or text the shell fills in (`"$1"`, `$p`), which the command string cannot name. */
export const isVar = (s: string) => s.includes('$')

/**
 * Calls whose target is a shell variable, as one call per herdr pane the command names literally:
 * a loop's list (`for p in wE:pG wE:pS`) or a helper's arguments (`ask wE:pG "check A"`), the word after a pane then its text.
 * A bare pane number (`pG`) counts only where one pane has it; the lead's own pane is never a target.
 */
export function expandCalls(cmd: string, calls: HerdrCall[], panes: { pane_id: string; name?: string }[], self?: string): HerdrCall[] {
  if (!calls.some(c => isVar(c.target))) return calls
  const others = panes.filter(p => p.pane_id !== self)
  const paneOf = (word: string) => {
    const bare = panes.filter(p => p.pane_id.split(':')[1] === word)
    return others.find(p => p.pane_id === word || p.name === word) ?? (bare.length === 1 && bare[0]!.pane_id !== self ? bare[0] : undefined)
  }
  const w = words(cmd)
  const named: { pane: string; next?: string }[] = []
  for (let i = 0; i < w.length; i++) {
    const p = paneOf(w[i]!)
    // A pane a literal call already names is that call's, not the helper's.
    if (!p || named.some(n => n.pane === p.pane_id) || calls.some(c => c.target === w[i])) continue
    const next = w[i + 1]
    named.push({ pane: p.pane_id, next: next && next !== SEP && !next.startsWith('-') && !isVar(next) && !paneOf(next) ? next : undefined })
  }
  return calls.flatMap(c => {
    if (!isVar(c.target)) return [c]
    return named.map(n => ({ ...c, target: n.pane, ...(c.text !== undefined && isVar(c.text) ? { text: n.next ?? '' } : {}) }))
  })
}

/** One line of a prompt, for a role. */
export const oneLine = (s: string, max = 80) => clip(s.replace(/\s+/g, ' ').trim(), max)

/** The head of `s` that fits `max` terminal cells, ending in … when cut; Hangul and CJK take two cells. */
export const clip = (s: string, max: number) => {
  if (cells(s) <= max) return s
  let out = ''
  let n = 0
  for (const ch of s) {
    if (n + cells(ch) > max - 1) break
    out += ch
    n += cells(ch)
  }
  return `${out}…`
}

/** A row of spans cut to `max` cells, the span that crosses the edge clipped with …; a `pick` span also takes `btn` cells of button frame. */
export function fitRow<S extends { t: string; pick?: unknown }>(segs: S[], max: number, btn = 0): S[] {
  const out: S[] = []
  let w = 0
  for (const s of segs) {
    const frame = s.pick ? btn : 0
    if (w + cells(s.t) + frame <= max) {
      out.push(s)
      w += cells(s.t) + frame
      continue
    }
    if (max - w - frame > 1) out.push({ ...s, t: clip(s.t, max - w - frame) })
    break
  }
  return out
}

/** `s` in lines of at most `w` cells, broken between words (a word wider than a line is split); past `max` lines the last ends in …. */
export function wrapCells(s: string, w: number, max = 3): string[] {
  const out: string[] = []
  let line = ''
  for (const word of s.split(' ')) {
    let rest = word
    let next = line ? `${line} ${rest}` : rest
    while (cells(next) > w) {
      if (line) {
        out.push(line)
        line = ''
        next = rest
        continue
      }
      let head = ''
      for (const ch of rest) {
        if (cells(head + ch) > w) break
        head += ch
      }
      out.push(head)
      rest = rest.slice(head.length)
      next = rest
    }
    line = next
  }
  if (line) out.push(line)
  // The line after the last shown one didn't fit beside it, so joining them always overflows and clips to ….
  return out.length > max ? [...out.slice(0, max - 1), clip(out.slice(max - 1).join(' '), w)] : out
}

/** `s` padded with spaces to `w` cells. */
export const padCells = (s: string, w: number) => s + ' '.repeat(Math.max(0, w - cells(s)))

/**
 * The model a CLI agent shows in its own footer or status line.
 * shortcut: matches the footers of grok, codex, gemini and Claude Code as they read today; add a pattern per new CLI.
 */
export function modelOnScreen(screen: string): string | undefined {
  const tail = screen.split('\n').slice(-12).join('\n')
  const m =
    /\b(Grok [\d.]+(?: \((?:low|medium|high|xhigh|max)\))?)/.exec(tail) ??
    /\b(gpt-[\w.-]+(?: (?:minimal|low|medium|high|xhigh))?)/.exec(tail) ??
    /\b(gemini-[\w.-]+)/i.exec(tail) ??
    /\b((?:Opus|Sonnet|Haiku|Fable) [\d.]+)/.exec(tail)
  return m?.[1]
}

/** A Claude model id as a short label: `claude-haiku-5-5` → `haiku 5.5`. */
export const shortModel = (m: string) => m.replace(/^claude-/, '').replace(/\[.*\]$/, '').replace(/-(\d+)-(\d+).*$/, ' $1.$2')

/** herdr's agent_status folded into a member's state. */
export function fromHerdr(m: Member, status: string | undefined, now: number): MemberState {
  if (status === undefined) return m.state === 'working' || m.state === 'blocked' ? 'done' : m.state
  // Busy with work another session handed it: not this lead's to show.
  if (m.owed === false) return m.state
  if (status === 'working') return 'working'
  if (status === 'blocked') return 'blocked'
  if (status === 'idle' || status === 'done') {
    if (m.sentAt !== undefined && now - m.sentAt < SETTLE_MS) return m.state
    return m.state === 'working' || m.state === 'blocked' || m.state === 'reply' ? 'reply' : 'idle'
  }
  return m.state
}

/**
 * The fields teamwire reads from a Claude session's own status file, `<config dir>/sessions/<pid>.json`.
 * shortcut: Claude Code's internal file, not an API; if its shape changes, peers simply stop moving.
 */
export type SessionFile = { file: string; name?: string; sessionId?: string; messagingSocketPath?: string; status?: string; updatedAt?: number }

/** The session a peer address names: by name, socket or session id; the freshest when names repeat. */
export const sessionFor = (files: SessionFile[], to: string) =>
  files
    .filter(f => f.name === to || f.sessionId === to || (!!f.messagingSocketPath && to.endsWith(f.messagingSocketPath)))
    .sort((a, b) => (b.updatedAt ?? 0) - (a.updatedAt ?? 0))[0]

/** A peer session's status as a member state. `files` lists every status file present, read or not. */
export function fromSession(m: Member, f: SessionFile | undefined, files: string[]): MemberState {
  // Once found, its file gone means the session ended; a file present but unreadable is mid-write.
  if (!f) return m.session && !files.includes(m.session) ? 'done' : m.state
  if (f.status === 'busy') return 'working'
  if (f.status === 'waiting') return 'blocked'
  if (f.status === 'idle') return 'idle'
  return m.state
}

/** A Claude agent's AgentStatus as a member state. */
export function fromAgent(status: string): MemberState {
  if (status === 'running' || status === 'pending') return 'working'
  if (status === 'waiting') return 'blocked'
  if (status === 'idle') return 'idle'
  if (status === 'completed') return 'done'
  return 'failed'
}

// A member with no state clock (wired by an older version) counts from when it joined, or its answer would pull current forever.
export const isStale = (m: Member, now: number) => m.state === 'reply' && now - (m.stateAt ?? m.addedAt) >= STALE_MS

/** Which way current runs on a member's wire now, and whether it is a surge. */
export function flowOf(m: Member, now: number): { dir?: Dir; hot: boolean } {
  if (m.burst && m.burst.until > now) return { dir: m.burst.dir, hot: true }
  if (m.state === 'working') return { dir: 'out', hot: false }
  if (m.state === 'reply' && !isStale(m, now)) return { dir: 'in', hot: false }
  return { hot: false }
}

/** Terminal cells a string takes: East Asian wide letters and emoji take two. */
export const cells = (s: string) => {
  let n = 0
  for (const ch of s) n += /[\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\uf900-\ufaff\ufe30-\ufe4f\uff00-\uff60\uffe0-\uffe6\u{1f300}-\u{1faff}]/u.test(ch) ? 2 : 1
  return n
}

/** Per cell of a wire: 0 copper, 1 spark, 2 glow trailing it; sparks travel `dir`, one every `gap` cells. */
export function wireCells(len: number, dir: Dir | undefined, tick: number, gap = 7): number[] {
  const cells = new Array<number>(len).fill(0)
  if (!dir) return cells
  for (let i = 0; i < len; i++) {
    const k = (((dir === 'out' ? i - tick : i + tick) % gap) + gap) % gap
    cells[i] = k === 0 ? 1 : k === (dir === 'out' ? gap - 1 : 1) ? 2 : 0
  }
  return cells
}

/** Where a light sweeping over `len` characters of a busy name stands at `tick`; -1 while it rests between passes. */
export const shineAt = (len: number, tick: number, offset = 0) => {
  const p = (((tick + offset) % (len + 8)) + len + 8) % (len + 8)
  return p < len ? p : -1
}

/** A text split around the light at `at`: the spark itself (2), its glow on either side (1), the rest (0). */
export function shineRuns(text: string, at: number): { t: string; v: 0 | 1 | 2 }[] {
  const out: { t: string; v: 0 | 1 | 2 }[] = []
  ;[...text].forEach((ch, i) => {
    const d = Math.abs(i - at)
    const v = at < 0 ? 0 : d === 0 ? 2 : d === 1 ? 1 : 0
    const last = out[out.length - 1]
    if (last && last.v === v) last.t += ch
    else out.push({ t: ch, v })
  })
  return out
}

/** Runs of equal values, for drawing a wire as few Text spans. */
export function runs(cells: number[]): { v: number; n: number }[] {
  const out: { v: number; n: number }[] = []
  for (const v of cells) {
    const last = out[out.length - 1]
    if (last && last.v === v) last.n++
    else out.push({ v, n: 1 })
  }
  return out
}

export const upsert = (list: Member[], id: string, patch: Partial<Member> & Pick<Member, 'addedAt'>): Member[] => {
  const i = list.findIndex(m => m.id === id)
  if (i < 0) return [...list, { id, name: id, kind: 'subagent', engine: '', role: '', state: 'working', ...patch }]
  const next = list.slice()
  next[i] = { ...list[i]!, ...patch, addedAt: list[i]!.addedAt }
  return next
}

export const surge = (dir: Dir, now: number) => ({ burst: { dir, until: now + BURST_MS } })

/** The member a name, address or id points at. */
export const find = (list: Member[], ref: string) =>
  list.find(m => m.id === ref || m.name === ref || m.id === `herdr:${ref}` || m.pane === ref || m.id === `peer:${ref}`)

export const KIND_LABEL: Record<Member['kind'], string> = { subagent: 'subagent', teammate: 'teammate', herdr: 'herdr', peer: 'session' }

/** A duration as people say it: `8s`, `1m 20s`, `2h 5m`. */
export const dur = (ms: number) => {
  const s = Math.max(1, Math.round(ms / 1000))
  return s < 60 ? `${s}s` : s < 3600 ? `${Math.floor(s / 60)}m ${s % 60}s` : `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`
}

/**
 * What changed between two rosters: ACTIVITY lines, and the clocks to set on the members that moved
 * (`since` for work begun, `stateAt` for any change, `took` for work ended).
 */
export function chronicle(before: Member[], after: Member[], now: number, msgs: Msg[] = []): { beats: Beat[]; patches: Record<string, Partial<Member>> } {
  const beats: Beat[] = []
  const patches: Record<string, Partial<Member>> = {}
  const started: string[] = []
  const beat = (who: string, kind: Beat['kind'], text: string) => beats.push({ at: now, who, kind, text })
  for (const m of after) {
    const p = before.find(x => x.id === m.id)
    if (!p) {
      beat(m.id, 'join', `joined as ${KIND_LABEL[m.kind]}${m.engine ? ` · ${m.engine}` : ''}${m.state === 'working' ? ', working' : ''}`)
      if (m.state === 'working') started.push(m.id)
      patches[m.id] = { stateAt: now }
      continue
    }
    if (p.state === m.state) continue
    patches[m.id] = { stateAt: now, ...(p.state === 'working' && p.since !== undefined ? { took: now - p.since } : {}) }
    const took = p.since !== undefined ? dur(now - p.since) : undefined
    if (m.state === 'working') {
      beat(m.id, 'work', p.state === 'blocked' ? 'resumed' : 'took a new task')
      started.push(m.id)
      // What woke it is the lead's last word to it since it stopped; a protocol message (JSON) is no task.
      const brief = p.state === 'blocked' ? undefined : msgs.findLast(x => x.from === LEAD && x.to === m.id && x.at >= (p.stateAt ?? p.addedAt))
      if (brief && !/^\s*[{[]/.test(brief.text)) patches[m.id] = { ...patches[m.id], role: brief.text }
    } else if (m.state === 'reply') beat(m.id, 'reply', `finished${took ? ` in ${took}` : ''} · reply ready`)
    else if (m.state === 'done') beat(m.id, 'done', `done${took ? ` in ${took}` : ''}`)
    else if (m.state === 'failed') beat(m.id, 'fail', `failed${took ? ` after ${took}` : ''}`)
    else if (m.state === 'blocked') beat(m.id, 'block', 'needs you: an approval or question is open')
    else beat(m.id, p.state === 'reply' ? 'read' : 'idle', p.state === 'reply' ? 'answer read by lead' : `went idle${took ? ` after ${took}` : ''}`)
  }
  for (const id of started) patches[id] = { ...patches[id], since: now }
  return { beats, patches }
}

/** Members holding work: running, or stopped on a question. */
export const busyCount = (list: Member[]) => list.filter(m => m.state === 'working' || m.state === 'blocked').length

/**
 * The fan of wires out of the lead: member k branches off a rounded trunk on row 1 + 3k (its two info rows below),
 * and the lead's connector meets the trunk midway, so the lead sits at the centre of its team.
 */
export function fanout(n: number): { lead: number; rows: number; trunk: (r: number) => string } {
  const last = 1 + 3 * (n - 1)
  const lead = n === 1 ? 1 : 1 + Math.round(1.5 * (n - 1))
  const trunk = (r: number) => {
    if (n === 1) return r === 1 ? '─' : ' '
    if (r < 1 || r > last) return ' '
    const branch = (r - 1) % 3 === 0
    if (r === 1) return '╭'
    if (r === last) return '╰'
    if (r === lead) return branch ? '┼' : '┤'
    return branch ? '├' : '│'
  }
  // The lead's box spans lead-1 … lead+3: frame, name, model, context gauge, frame.
  return { lead, rows: Math.max(3 * n + 1, lead + 4), trunk }
}

/** A gauge of `w` cells for a fraction, and the colour it reads in: calm, filling, nearly full. */
export const gauge = (pct: number, w: number) => {
  const f = Math.max(0, Math.min(w, Math.round((pct / 100) * w)))
  return { on: '▰'.repeat(f), off: '▱'.repeat(w - f), level: pct >= 85 ? 'full' : pct >= 60 ? 'filling' : 'calm' } as const
}

/** Token counts as people read them: `840`, `42k`, `1.2M`. */
export const kTokens = (n: number) => (n >= 1e6 ? `${+(n / 1e6).toFixed(1)}M` : n >= 1e3 ? `${Math.round(n / 1e3)}k` : String(n))

export const ago = (ms: number) => (ms < 60_000 ? `${Math.max(0, Math.round(ms / 1000))}s` : ms < 3_600_000 ? `${Math.round(ms / 60_000)}m` : `${Math.round(ms / 3_600_000)}h`)
