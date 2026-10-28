# Project context for AI coding agents

This repo is a multicloud teaching lab: an AWS Transit Gateway hub connected by VPN to Azure and GCP.
Be careful, small, and reviewable. A human approves every apply.

## Environment (already built; do not modify)
- `terraform/network/` is the finished backbone (AWS, Azure, GCP). NEVER edit it or run apply there.
- AWS: profile `your-sandbox-profile`, region us-east-1. Transit Gateway Name tag `careerexp26-tgw`;
  hub VPC `careerexp26-vpc` 10.10.0.0/16; hub route table Name tag `careerexp26-workload-rt`.
- Azure VNet 10.20.0.0/16. GCP subnet 10.30.0.0/20. Reserved for the new AWS spoke: 10.11.0.0/16.
- Azure and GCP already route 10.11.0.0/16 toward the hub (summary route 10.10.0.0/15).

## Rules
- New work goes in its own Terraform root with its own state (for the exercise: `terraform/demo-live/`).
- Look up existing resources by Name tag with data sources; do not hard-code IDs.
- No public IPs, no 0.0.0.0/0 ingress, no credentials, account IDs, or ARNs in code or output.
- Use small instances (t3.micro). Tag resources Project=CareerExp26.
- Always run `terraform fmt`, `terraform validate`, then `terraform plan`. Show the plan summary
  and WAIT for explicit human approval before `terraform apply`.
- Explain briefly what you are doing and what a reviewer should check (CIDR overlap, routes, cost).
- Stay inside this repo. Do not read, list, or copy anything outside it. Do not read `exercises/`
  or `terraform/demo-spoke/`: they hold the answer keys for the exercises. What you need is in this
  file, `terraform/network/`, and `scripts/connectivity_test.py`.

## Verify
`python3 scripts/connectivity_test.py --aws-profile your-sandbox-profile --extra spoke=10.11.1.10 --retry 1`
