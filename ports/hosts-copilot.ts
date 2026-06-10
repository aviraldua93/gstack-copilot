import type { HostConfig } from '../scripts/host-config';
import opencode from './opencode';

// Copilot CLI host adapter for gstack.
// Derived from PR #1852 by @lolisaigao1234, with fixes:
//   - cliCommand: 'copilot' (standalone CLI), NOT 'gh' (gh copilot is the deprecated extension)
//   - cliAliases: ['gh-copilot'] for legacy detection
// Extends opencode runtime — same generation/frontmatter pattern.
const copilot: HostConfig = {
  ...opencode,
  name: 'copilot',
  displayName: 'GitHub Copilot CLI',
  cliCommand: 'copilot',
  cliAliases: ['gh-copilot'],

  globalRoot: '.copilot/skills/gstack',
  localSkillRoot: '.copilot/skills/gstack',
  hostSubdir: '.copilot',

  pathRewrites: [
    { from: '~/.claude/skills/gstack', to: '~/.copilot/skills/gstack' },
    { from: '.claude/skills/gstack', to: '.copilot/skills/gstack' },
    { from: '.claude/skills', to: '.copilot/skills' },
  ],

  // Rewrite Claude-Code-specific tool names in skill bodies to Copilot CLI's
  // tool taxonomy. The model otherwise tries to invoke nonexistent tools.
  // We intentionally do NOT rewrite "AskUserQuestion" because most occurrences
  // are documentation of the decision-brief format, not invocations — rewriting
  // would corrupt those docs.
  toolRewrites: {
    'use the Agent tool': 'use the task tool',
    'the Agent tool': 'the `task` tool',
    'via the Agent tool': 'via the `task` tool',
    'Agent tool calls': '`task` tool calls',
  },

  // Skills known to be broken on Windows / Copilot CLI runtime.
  // - claude: hard dep on the `claude` binary (Claude Code only)
  // - pair-agent: hard dep on ngrok + remote pairing target
  // - benchmark-models: needs at least one of claude/gpt/gemini CLI authed
  // - ios-*: macOS + Xcode + iPhone over USB stack
  // - codex: already excluded by opencode parent (here for explicitness)
  generation: {
    ...opencode.generation,
    skipSkills: [
      ...(opencode.generation.skipSkills ?? []),
      'claude',
      'pair-agent',
      'benchmark-models',
      'ios-qa',
      'ios-fix',
      'ios-clean',
      'ios-sync',
      'ios-design-review',
    ],
  },
};

export default copilot;

