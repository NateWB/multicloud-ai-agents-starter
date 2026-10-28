# Exercise: break and fix

**Answer key inside.** Do not open `break_it.py` or `GUIDE.md` before you try the diagnosis yourself, and keep
this folder out of the folder your AI agent works in (copy the repo without `exercises/`, or run the agent
from a clone that doesn't have it).

Goal: practice finding one missing route by comparing paths that work with the one that doesn't, with an agent
doing read-only evidence gathering and you making the decision.

Prerequisites: `terraform/network` applied and the spoke from `prompts/01-add-spoke.md` applied and verified.

1. Run `break_it.py status` to see the starting state.
2. Have a friend (or future you) run `break_it.py break`, without telling you what it did.
3. Run the connectivity test and diagnose, using `prompts/02-diagnose-readonly.md`.
4. Fix it in Terraform, then re-run the connectivity test. `GUIDE.md` has the walkthrough.
