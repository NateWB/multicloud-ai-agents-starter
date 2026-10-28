#!/usr/bin/env python3
"""Prove cross-cloud connectivity: each test VM pings the other two.

Run from the repo root after `terraform apply` (needs aws, az, gcloud logged in):
  python3 scripts/connectivity_test.py --aws-profile your-sandbox-profile

How each VM is reached (none have public IPs):
  AWS   - SSM Run Command (via VPC interface endpoints)
  Azure - az vm run-command
  GCP   - gcloud compute ssh --tunnel-through-iap
Prints only ping loss/latency lines, never keys or account IDs.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

NETWORK_DIR = Path(__file__).resolve().parent.parent / "terraform" / "network"


def run(cmd: list[str], timeout: int = 240, cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd)


def ping_script(targets: dict[str, str]) -> str:
    parts = [f"echo '-> {name} ({ip})'; ping -c 3 -W 2 {ip} | grep -E 'packet loss|rtt'"
             for name, ip in targets.items()]
    return "; ".join(parts)


def first_error(proc: subprocess.CompletedProcess) -> str:
    lines = (proc.stderr or proc.stdout or "").strip().splitlines()
    return f"ERROR: {lines[-1]}" if lines else f"ERROR: exit {proc.returncode}"


def test_aws(vm: dict, profile: str | None, targets: dict[str, str]) -> str:
    base = ["aws"] + (["--profile", profile] if profile else []) + ["--region", vm["aws_region"]]
    sent = run(base + ["ssm", "send-command", "--instance-ids", vm["aws_instance_id"],
                       "--document-name", "AWS-RunShellScript",
                       "--parameters", json.dumps({"commands": [ping_script(targets)]}),
                       "--query", "Command.CommandId", "--output", "text"])
    if sent.returncode:
        return first_error(sent)
    command_id = sent.stdout.strip()
    for _ in range(40):
        time.sleep(3)
        inv = run(base + ["ssm", "get-command-invocation", "--command-id", command_id,
                          "--instance-id", vm["aws_instance_id"], "--output", "json"])
        if inv.returncode:
            continue  # invocation may not exist yet right after send-command
        data = json.loads(inv.stdout)
        if data["Status"] not in ("Pending", "InProgress", "Delayed"):
            return (data.get("StandardOutputContent") or data.get("StandardErrorContent") or data["Status"]).strip()
    return "ERROR: timed out waiting for SSM (is the instance registered? give it a few minutes)"


def test_azure(vm: dict, targets: dict[str, str]) -> str:
    proc = run(["az", "vm", "run-command", "invoke", "-g", vm["azure_rg"], "-n", vm["azure_vm_name"],
                "--command-id", "RunShellScript", "--scripts", ping_script(targets),
                "--query", "value[0].message", "-o", "tsv"])
    return proc.stdout.strip() if proc.returncode == 0 else first_error(proc)


def test_gcp(vm: dict, targets: dict[str, str]) -> str:
    proc = run(["gcloud", "compute", "ssh", vm["gcp_vm_name"], "--zone", vm["gcp_zone"],
                "--project", vm["gcp_project"], "--tunnel-through-iap", "--quiet",
                "--command", ping_script(targets)])
    return proc.stdout.strip() if proc.returncode == 0 else first_error(proc)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--aws-profile")
    ap.add_argument("--retry", type=int, default=0, metavar="N",
                    help="re-run a source up to N times (after 20s) if it shows 100%% loss, e.g. right after an apply")
    ap.add_argument("--extra", action="append", default=[], metavar="NAME=IP",
                    help="additional ping target, e.g. --extra spoke=10.11.1.10")
    args = ap.parse_args()
    extras = dict(item.split("=", 1) for item in args.extra)

    out = run(["terraform", "output", "-json", "test_vms"], cwd=NETWORK_DIR)
    if out.returncode:
        print("Could not read terraform outputs (run apply first):", first_error(out))
        return 1
    vm = json.loads(out.stdout)
    ips = vm["ips"]

    for source, fn in (("aws", lambda t: test_aws(vm, args.aws_profile, t)),
                       ("azure", lambda t: test_azure(vm, t)),
                       ("gcp", lambda t: test_gcp(vm, t))):
        targets = {name: ip for name, ip in ips.items() if name != source}
        targets.update(extras)
        print(f"\n=== from {source} ({ips[source]}) ===")
        result = fn(targets)
        for attempt in range(args.retry):
            if "100% packet loss" not in result:
                break
            print(f"(100% loss seen; routes may still be settling - retry {attempt + 1} of {args.retry} in 20s)")
            time.sleep(20)
            result = fn(targets)
        print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
