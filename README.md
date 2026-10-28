# Multicloud with AI agents: starter kit

Materials from the "AI-Driven Multicloud Engineering" session at the STG Career Transformation Expo (Oct 28, 2026).
The idea: AI coding agents make multicloud infrastructure faster to build, but you still need to know why the
architecture looks the way it does, review what the agent produces, and own the result.

> **Lab only.** This creates billable resources in three clouds (roughly tens of dollars per day with everything up).
> It is not production-ready. Use sandbox accounts, never an organization's management account, and tear it down
> when you finish (`scripts/teardown_checklist.md`). No warranty; see `LICENSE`.

## Start here, by how much you want to do

1. **Just take the pattern (no cloud accounts needed).** Copy `AGENTS.md`, adapt it to your environment, and
   use the prompts in `prompts/` and the checks in `docs/review-checklist.md`.
2. **Read the worked example.** `terraform/demo-spoke/main.tf` is what an agent should produce from
   `prompts/01-add-spoke.md`. `docs/architecture.md` explains the design and the address plan.
3. **Rebuild the lab.** `terraform/network/` builds the backbone: AWS Transit Gateway to Azure and GCP.
   Read its README first for prerequisites and cost. Then run the spoke prompt in your agent.
4. **Practice troubleshooting.** `exercises/break-and-fix/` breaks one route so you can diagnose it. It contains the
   answer key, so read its README before opening anything else.

## Layout
- `AGENTS.md` - context file for AI agents. `CLAUDE.md` and `GEMINI.md` import it, so one set of rules serves any tool.
- `prompts/` - tool-agnostic prompts
- `docs/` - architecture, review checklist, identity federation notes, tool notes
- `terraform/network/` - the backbone (apply once). `terraform/demo-spoke/` - the reference spoke (separate state)
- `scripts/` - connectivity test, VPN status, pre-flight, teardown checklist
- `exercises/break-and-fix/` - troubleshooting exercise (answer key inside)

## Before you run anything
- Replace `your-sandbox-profile` and `your-gcp-project` with your own sandbox values.
- Copy `terraform/network/example.tfvars` to `terraform.tfvars` (git-ignored) and fill it in.
- If you run an AI agent against this repo, keep `exercises/` and `terraform/demo-spoke/` out of the copy it works in.
- Never commit state files, keys, tenant or account IDs.
