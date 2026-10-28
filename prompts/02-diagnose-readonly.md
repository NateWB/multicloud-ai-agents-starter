# Prompt 2: diagnose a connectivity problem (read-only)

Use after something breaks. The point is to let the agent gather evidence without letting it change anything.

> The AWS hub VM (10.10.1.10) can't ping the spoke VM (10.11.1.10), but the Azure and GCP VMs can.
> Diagnose using read-only AWS CLI commands only. Do not change anything. Tell me what you
> found and what you would do to fix it.

## How to use the answer
- Check its reasoning, not only its conclusion. A correct fix can come with a wrong explanation.
- Compare a path that works with the one that fails; the difference points at the cause.
- Make the fix in Terraform (plan, review, apply), not by hand in a console.
