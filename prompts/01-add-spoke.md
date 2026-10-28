# Prompt 1: add an AWS spoke to the multicloud hub

Works in Claude Code, Gemini CLI, Codex, or Copilot. Each tool picks up repo context from
`AGENTS.md` (`CLAUDE.md` and `GEMINI.md` just import it). Tested end to end in Claude Code only.

## Short prompt (AGENTS.md carries the environment and the rules)

> Add a second AWS spoke to our multicloud hub, in a new Terraform root at `terraform/demo-live/`.
> VPC 10.11.0.0/16 with one private subnet and a t3.micro test VM at 10.11.1.10 (no public IP),
> attached to the existing Transit Gateway, with routes to the hub, Azure, and GCP and a return
> route from the hub, and allowing ICMP from the other clouds. Validate, plan, show me the summary,
> and wait for my approval before applying.

## Full prompt (more explicit; use it if the short one comes out too loose)

> Add a second AWS spoke to our multicloud hub. Create a new Terraform root in
> `terraform/demo-live/` (don't touch `terraform/network`). It should: look up the existing
> Transit Gateway and hub route table by their Name tags; create a VPC 10.11.0.0/16 with one
> private subnet and a t3.micro Amazon Linux 2023 test VM at 10.11.1.10 with no public IP;
> attach the VPC to the Transit Gateway; add routes from the spoke to the hub, Azure, and GCP
> CIDRs, plus a route back from the hub VPC to the spoke; and allow ICMP from the other clouds.
> Run `terraform validate` and `terraform plan`, show me the plan summary, and wait for my
> approval before applying.

## What you check before approving
See `docs/review-checklist.md`. The five checks: CIDRs, routes both ways, security group, cost, blast radius.

## Verify

    python3 scripts/connectivity_test.py --aws-profile your-sandbox-profile --extra spoke=10.11.1.10 --retry 1

Expected: 0% loss from the AWS, Azure, and GCP VMs to the spoke VM. The first ping can fail once
while the new routes settle; `--retry 1` handles it.

## Tear down when you are done

    cd terraform/demo-live && terraform destroy
