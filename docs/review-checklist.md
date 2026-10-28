# Review checklist: before you approve an agent's plan

The agent writes the code. You approve it and own it. Read the plan summary, then check:

1. **CIDRs.** The new range overlaps nothing: hub 10.10.0.0/16, Azure 10.20.0.0/16, GCP 10.30.0.0/20.
2. **Routes both ways.** Spoke to hub, Azure and GCP, and hub back to spoke. A missing return route gives one-way traffic.
3. **Security group.** ICMP only, only from the known ranges. No public IP, no 0.0.0.0/0 ingress.
4. **Cost.** One VPC attachment (roughly $0.05 per hour when this was written; check current pricing) plus one t3.micro. Nothing else.
5. **Blast radius.** The plan touches only new resources plus one added route in the hub route table. No destroys.

For this exercise a good plan reads: 11 to add, 0 to change, 0 to destroy.

Then ask: can I explain every line of the plan? If not, don't approve yet.

## Habits worth keeping
- Look up existing resources by tag. Never hard-code IDs.
- Keep the agent in normal permission mode so each command is visible and approvable.
- Verify after apply; a change isn't done until it is tested.
- Fix drift in Terraform, not in the console.
- Tear down what you built.
