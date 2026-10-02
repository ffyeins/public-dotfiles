@~/dotfiles/ai/AGENTS.md

## Search and Research Policy

Minimize searches. Default to trying the obvious fix first, not exhaustive research.

- **Try first, search later** — if answer is likely from standard knowledge (CSS, common APIs, well-known patterns), write the solution directly. Ask user to verify.
- **1-2 searches max** for most questions. If first search doesn't answer it, refine query — don't broaden.
- **No agent for simple lookups** — use direct WebSearch from main conversation. Only spawn research agents for genuinely complex, multi-source questions.
- **If agent needed** — use tight scope with Explore subagent and word limit. Never open-ended research.
- **Never read more than 3 web pages** for a single question unless user explicitly asks for exhaustive research.

## Git Commit Policy enforcement

The Git Commit Policy (in the imported AGENTS.md) is enforced by
`~/.claude/hooks/git-guard.sh`, which denies commit/push/pull outside the
throwaway-repo exception, in any form. Don't work around it.
