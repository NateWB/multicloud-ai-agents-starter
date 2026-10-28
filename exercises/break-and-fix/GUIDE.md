# Walkthrough: break and fix (about 8 minutes, mostly discussion)

Typical machine time: diagnose about 40 seconds, fix (plan, apply, verify) about 1.5 minutes.
Run after the spoke is applied and the connectivity test passes (0% loss everywhere).

## 1. Break it (say nothing about what you did)

    python3 exercises/break-and-fix/break_it.py break --aws-profile your-sandbox-profile
    python3 scripts/connectivity_test.py --aws-profile your-sandbox-profile --extra spoke=10.11.1.10

(no `--retry`, so the failure shows immediately)

Expected: Azure to spoke and GCP to spoke still 0% loss; AWS hub VM to spoke 100% loss.

## 2. Ask: where would you look?
Let people guess: security group, tunnel, route, Transit Gateway. Use the symptom: only the hub's path fails.
The hub subnet has no route to 10.11.0.0/16, so traffic from the hub VM to the spoke never leaves the subnet.
Azure and GCP never touch that route table: their traffic goes from the Transit Gateway straight to the spoke.

## 3. Hand it to the agent (read-only diagnosis)
Use `prompts/02-diagnose-readonly.md`.

Expected finding: the hub route table (Name tag `careerexp26-workload-rt`) has no 10.11.0.0/16 route.

## 4. Fix it the right way (this is drift)

    cd terraform/demo-live && terraform plan     # shows 1 to add: the hub-to-spoke route
    terraform apply

The fix is a Terraform apply, not a console click. The plan explains the drift. Then re-run the connectivity test:
0% loss from all three clouds.

## Emergency restore (if Terraform is slow or stuck)

    python3 exercises/break-and-fix/break_it.py restore --aws-profile your-sandbox-profile

## Check state any time

    python3 exercises/break-and-fix/break_it.py status --aws-profile your-sandbox-profile

## The lesson
One-way traffic usually means a missing return route. Compare working and failing paths first; the difference
points at the cause. And check the agent's explanation, not only its answer.
