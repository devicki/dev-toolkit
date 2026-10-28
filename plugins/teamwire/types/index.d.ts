/** Where a member's work stands, as the lead sees it. `reply`: finished, the lead has not picked the answer up yet. */
export type MemberState = 'working' | 'reply' | 'blocked' | 'idle' | 'done' | 'failed'

/** Which way current runs on a wire: `out` lead → member, `in` member → lead. */
export type Dir = 'out' | 'in'

export type Member = {
  /** agentId for Claude agents, `herdr:<target>` for herdr panes, `peer:<to>` for other sessions, `grok:<subagent id>` for a grok member's own subagents. */
  id: string
  name: string
  kind: 'subagent' | 'teammate' | 'herdr' | 'peer'
  /** Agent type (`Explore`) or CLI kind (`grok`, `codex`). */
  engine: string
  /** One line: what the lead handed it. */
  role: string
  /** The model it reasons with, as short as it is shown (`haiku 5.5`, `Grok 4.7 (xhigh)`); unknown until seen. */
  model?: string
  /** How hard it thinks (`low` … `max`), from its own model requests; Claude agents only. */
  effort?: string
  state: MemberState
  /** A short-lived surge on the wire after a message or a handoff. */
  burst?: { dir: Dir; until: number }
  /** When its current piece of work began, for the durations ACTIVITY reports. */
  since?: number
  /** When it entered its current state: a reply left this long goes stale. */
  stateAt?: number
  /** How long its last piece of work took. */
  took?: number
  /** Claude agents: tool calls made and output tokens spent. */
  tools?: number
  outTokens?: number
  /** A tool call of its own is waiting on the person's approval. */
  asking?: boolean
  /** peer: the status file (`<pid>.json` under the Claude config dir's `sessions/`) it was found in. */
  session?: string
  /** herdr: the pane it lives in, once resolved. */
  pane?: string
  /** herdr: when the lead last prompted it; idle reports just after are stale. */
  sentAt?: number
  /** herdr: it holds work this lead handed it. A pane busy with someone else's work leaves the member as it was. */
  owed?: boolean
  /** The Agent call behind a Claude agent, to match its return. */
  toolUseId?: string
  /** The member that spawned it (a grok member's own subagent): drawn under that member, not off the lead. */
  parent?: string
  /** A Claude agent the engine ran in the background: its Agent call returns at once. */
  bg?: boolean
  addedAt: number
}

export type Msg = { at: number; from: string; to: string; text: string }

/** A message between two members, drawn as a rail beside them while it is fresh. */
export type Link = { from: string; to: string; until: number }

export type BeatKind = 'join' | 'work' | 'reply' | 'done' | 'fail' | 'block' | 'read' | 'idle'

/** One line of ACTIVITY: a member joined or changed state. `who` is a member id. */
export type Beat = { at: number; who: string; kind: BeatKind; text: string }

export type Lead = {
  busy: boolean
  model: string
  effort?: string
  /** The lead's context window as the status line counts it, and the session's cost so far. */
  ctx?: { percent: number; tokens: number; window: number }
  usd?: number
  /** The member the lead is blocked on: a foreground agent, or a herdr wait. */
  waitingOn?: string
}

declare module 'claude-code' {
  interface PluginState {
    teamwire: { members: Member[]; msgs: Msg[]; beats: Beat[]; lead: Lead; tick: number; selected: string; link: Link | null }
  }
}
