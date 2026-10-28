# Tool notes: what we tested (October 2026)

The prompts and `AGENTS.md` are written to be tool-agnostic. We proved the pattern in one tool, not all of them.

| Tool | Status |
| --- | --- |
| Claude Code | Works as designed. Reads `AGENTS.md` through `CLAUDE.md`. Build prompt to verified spoke took about 4 to 4.5 minutes; diagnosing a broken route about 40 seconds; the fix about 1.5 minutes. |
| Gemini CLI | Loads the same context (`GEMINI.md` imports `AGENTS.md`), but we could not finish a run. Personal "Login with Google" stopped working after Google's June 2026 change (Antigravity CLI is the consumer successor). With Vertex AI auth, set `GOOGLE_CLOUD_LOCATION=global`; the models we tried produced no plan in the time we waited. |
| Antigravity CLI, Codex, Copilot | Not tested. |

If your organization licenses Gemini, confirm which product you have (Gemini CLI through Code Assist, or Antigravity CLI)
and pin a fast model.

## A finding that shaped the repo
An agent reads the whole repo while exploring, and an agent running as you can read anywhere on your laptop.
That is why `AGENTS.md` tells it to stay inside the repo, and why the answer keys are in folders it is told not to open.
For a clean exercise, keep `exercises/` and `terraform/demo-spoke/` out of the repo copy the agent works in.
