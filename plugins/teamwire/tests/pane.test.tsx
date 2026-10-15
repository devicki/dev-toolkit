import { expect, test } from 'claude-code/testing'

const NOW = Date.parse('2026-10-15T09:00:00Z')
const PROPS = { title: 'Team', isFocused: true, bodyColumns: 110, placement: 'dock', scroll: { offset: 0, bodyRows: 40 }, view: {} }
const HERDR = JSON.stringify({
  result: { agents: [{ agent: 'grok', agent_status: 'working', pane_id: 'wN:p2' }, { agent: 'grok', agent_status: 'idle', pane_id: 'wN:p3' }] },
})

for (const surface of ['terminal', 'desktop'] as const) {
  test(`the lead's team is wired on ${surface}: a subagent, a herdr pane, and the message between`, async ($, on) => {
    let n = 0
    const opened: string[] = []
    on('clock.now', () => ({ value: NOW + n++ * 100 }) as never)
    on('clock.every', () => ({ value: undefined }) as never)
    on('ui.open', (_, e) => (opened.push((e as { id: string }).id), { value: { isPlaced: true } }) as never)
    on('session.model', () => ({ value: 'claude-opus-5-5[1m]' }) as never)
    on('agent.list', () => ({ value: [{ id: 'a1', description: 'Map callers', type: 'Explore', status: 'running' }] }) as never)
    on('agent.spawn', () => ({ model: 'claude-haiku-5-5', agentId: 'a1' }) as never)
    on('process.run', (_, e) => {
      const read = (e as { argv: string[] }).argv[2] === 'read'
      const stdout = read ? '  ╰──── Grok 4.7 (xhigh) · always-approve ─╯' : HERDR
      return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } } as never
    })
    on('tool.call', () => ({ result: 'ok', text: 'ok' }) as never)

    await $.agent.spawn({ prompt: 'find every caller of parse()', description: 'Map callers', subagentType: 'Explore', background: true } as never)
    await $.tool.call({ tool: 'Bash', command: `herdr agent prompt wN:p2 "Review the diff for bugs"` } as never)
    expect(opened).toContain('teamwire')

    const ui = await $.ui.mount({ plugin: 'teamwire', surface, component: 'Pane', requestId: 'teamwire', props: PROPS, viewport: { columns: 112, rows: 40 } } as never)
    const drawn = JSON.stringify(await ui.drawn())
    expect(drawn).toContain('TEAMWIRE')
    expect(drawn).toContain('LEAD')
    expect(drawn).toContain('Map callers')
    expect(drawn).toContain('grok·p2')
    expect(drawn).toContain('Review the diff for bugs')
    expect(drawn).toContain('WORKING')
    expect(drawn).toContain('subagent')
    expect(drawn).toContain('haiku 5.5')
    expect(drawn).toContain('Grok 4.7 (xhigh)')
    expect(drawn).toContain('┅')
    expect(drawn).toContain('━')
    expect(drawn).not.toContain('grok·p3')
    await ui.press({ key: 'clear' })
    await ui.unmount()
  })
}
