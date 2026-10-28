# Demo spoke (known-good reference)

Separate root and state from `terraform/network`. Adds a second AWS VPC (10.11.0.0/16) with a
test VM, attached to the existing Transit Gateway, then proves reachability to Azure and GCP.

    terraform init && terraform apply          # ~3-5 min
    cd ../.. && python3 scripts/connectivity_test.py --aws-profile your-sandbox-profile --extra spoke=10.11.1.10
    cd terraform/demo-spoke && terraform destroy   # reset for the next run

Prerequisite: `terraform/network` applied with `aws_summary_cidr = 10.10.0.0/15` so Azure and
GCP already cover 10.11.0.0/16 (summary route). GCP learns the new prefix over BGP automatically.

In the session, the AI agent writes the equivalent code in a new root (`terraform/demo-live/`) from `prompts/01-add-spoke.md`.
This folder is the answer key. Keep it out of the agent's reach when you run the exercise (see the top-level README).
