import cursorGrokBotAgents from "@cursor/bdk/extensions/cursor-grokbot-agents";

// Allowlist only. A misspelled name may create a new empty bot on first use.
export default cursorGrokBotAgents({
  agents: [
    { name: "helper", description: "General research and errands." },
    { name: "botkit", description: "Builds and fixes Grok Bot templates." },
    { name: "집순이", description: "Housing notice alerts." },
    { name: "Feedhand", description: "Drafts social posts. Request-only: the user approves in the Feedhand chat." },
    { name: "Watchless", description: "Turns videos into text summaries." },
  ],
});
