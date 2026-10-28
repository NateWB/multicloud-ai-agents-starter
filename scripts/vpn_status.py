#!/usr/bin/env python3
"""Show tunnel health across AWS, Azure and GCP without printing IDs or secrets.

Needs the aws, az and gcloud CLIs logged in.
Usage: python3 scripts/vpn_status.py --resource-group careerexp26-rg [--prefix careerexp26]
"""
import argparse
import json
import subprocess
import sys


def run_json(cmd: list[str]):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=60, check=True)
        return json.loads(out.stdout or "null")
    except subprocess.CalledProcessError as exc:
        first = (exc.stderr or "").strip().splitlines()[:1]
        print(f"  (could not run {cmd[0]}: {first[0] if first else 'exit ' + str(exc.returncode)})")
        return None
    except Exception as exc:  # noqa: BLE001
        print(f"  (could not run {cmd[0]}: {type(exc).__name__})")
        return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--prefix", default="careerexp26")
    ap.add_argument("--resource-group", default="careerexp26-rg")
    ap.add_argument("--aws-profile")
    ap.add_argument("--gcp-project", default="your-gcp-project")
    args = ap.parse_args()

    print("AWS VPN connections")
    cmd = ["aws", "ec2", "describe-vpn-connections", "--output", "json",
           "--filters", "Name=tag:Project,Values=CareerExp26", "Name=state,Values=available"]
    if args.aws_profile:
        cmd += ["--profile", args.aws_profile]
    data = run_json(cmd)
    for conn in (data or {}).get("VpnConnections", []):
        name = next((t["Value"] for t in conn.get("Tags", []) if t["Key"] == "Name"), "unnamed")
        for i, t in enumerate(conn.get("VgwTelemetry", []), start=1):
            print(f"  {name} tunnel{i}: {t.get('Status')} routes={t.get('AcceptedRouteCount')}")

    print("Azure connections")
    data = run_json(["az", "network", "vpn-connection", "list", "-g", args.resource_group, "-o", "json"])
    for c in data or []:
        one = run_json(["az", "network", "vpn-connection", "show", "-g", args.resource_group,
                        "-n", c["name"], "-o", "json"])
        status = (one or {}).get("connectionStatus") or c.get("connectionStatus")
        print(f"  {c.get('name')}: {status}")

    print("GCP tunnels")
    data = run_json(["gcloud", "compute", "vpn-tunnels", "list", "--project", args.gcp_project,
                     f"--filter=name~^{args.prefix}", "--format=json"])
    for t in data or []:
        print(f"  {t.get('name')}: {t.get('status')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
