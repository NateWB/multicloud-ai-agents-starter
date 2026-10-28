#!/usr/bin/env python3
"""Break-and-fix helper for the live demo (needs the demo spoke applied).

  python3 exercises/break-and-fix/break_it.py status    # is the hub -> spoke return route there?
  python3 exercises/break-and-fix/break_it.py break     # delete ONLY that route (the spoke stays up)
  python3 exercises/break-and-fix/break_it.py restore   # emergency CLI restore; normally the fix is
                                        #   terraform apply in your demo root (drift)

Effect of `break`: the AWS hub VM can no longer reach the spoke, while Azure and GCP still can.
Prints no IDs or account numbers.
"""
import argparse
import subprocess
import sys

HUB_RT_NAME = "careerexp26-workload-rt"
TGW_NAME = "careerexp26-tgw"
SPOKE_CIDR = "10.11.0.0/16"


def aws(args: list[str], profile: str, region: str) -> str:
    cmd = ["aws"] + (["--profile", profile] if profile else []) + ["--region", region] + args + ["--output", "text"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    if proc.returncode:
        lines = (proc.stderr or "").strip().splitlines()
        sys.exit(f"ERROR: {lines[-1] if lines else 'aws command failed'}")
    return proc.stdout.strip()


def hub_route_table(profile: str, region: str) -> str:
    rt = aws(["ec2", "describe-route-tables", "--filters", f"Name=tag:Name,Values={HUB_RT_NAME}",
              "--query", "RouteTables[0].RouteTableId"], profile, region)
    if not rt or rt == "None":
        sys.exit("ERROR: hub route table not found (is terraform/network applied?)")
    return rt


def route_state(profile: str, region: str, rt: str) -> str:
    out = aws(["ec2", "describe-route-tables", "--route-table-ids", rt, "--query",
               f"RouteTables[0].Routes[?DestinationCidrBlock=='{SPOKE_CIDR}'].State | [0]"], profile, region)
    return "missing" if out in ("", "None") else out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("action", choices=["status", "break", "restore"])
    ap.add_argument("--aws-profile", default=None, help="AWS CLI profile for the sandbox account")
    ap.add_argument("--region", default="us-east-1")
    args = ap.parse_args()

    rt = hub_route_table(args.aws_profile, args.region)
    state = route_state(args.aws_profile, args.region, rt)

    if args.action == "status":
        print(f"hub -> spoke route ({SPOKE_CIDR}): {state}")
    elif args.action == "break":
        if state == "missing":
            sys.exit("Route is already missing (or the spoke is not applied). Nothing to break.")
        aws(["ec2", "delete-route", "--route-table-id", rt, "--destination-cidr-block", SPOKE_CIDR],
            args.aws_profile, args.region)
        print("Deleted the hub -> spoke return route. The spoke itself is untouched.")
    else:
        if state != "missing":
            sys.exit(f"Route already present ({state}). Nothing to restore.")
        tgw = aws(["ec2", "describe-transit-gateways", "--filters", f"Name=tag:Name,Values={TGW_NAME}",
                   "Name=state,Values=available", "--query", "TransitGateways[0].TransitGatewayId"],
                  args.aws_profile, args.region)
        aws(["ec2", "create-route", "--route-table-id", rt, "--destination-cidr-block", SPOKE_CIDR,
             "--transit-gateway-id", tgw], args.aws_profile, args.region)
        print("Restored the hub -> spoke route via the CLI (terraform state will show no drift).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
