# Architecture

An AWS Transit Gateway is the hub. Azure connects over one static VPN tunnel and GCP over HA VPN with BGP
(Cloud Router). Workloads in any cloud reach the others over private addresses.

```
            Azure VNet 10.20.0.0/16          GCP VPC 10.30.0.0/20
                  | static (1 tunnel)              | BGP (4 tunnels, 2 AWS VPNs)
                  +-----------> AWS Transit Gateway <-----------+
                                       |
                        +--------------+--------------+
                 Hub VPC 10.10.0.0/16          Spoke VPC 10.11.0.0/16
                 (built with the backbone)     (added by the exercise)
```

## Address plan

| Network | CIDR | Notes |
| --- | --- | --- |
| AWS hub VPC | 10.10.0.0/16 | Built by `terraform/network` |
| AWS spoke VPC | 10.11.0.0/16 | Reserved; added by the exercise. Test VM at 10.11.1.10 |
| AWS summary route | 10.10.0.0/15 | Azure and GCP use this one route to cover both AWS VPCs |
| Azure VNet | 10.20.0.0/16 | One test VM, private IP only |
| GCP subnet | 10.30.0.0/20 | One test VM, private IP only |

The summary route is why adding a spoke needs no change in Azure or GCP.

## Why a hub

One place for routing and inspection, and fewer point-to-point links. Adding a network is one attachment
plus routes, not a new link to every other network.

## Identity

Entra ID as the single identity plane: native in Azure, SAML into AWS IAM Identity Center, and Workforce
Identity Federation into GCP (`docs/identity-gcp-federation.md`; the AWS steps are in
`docs/identity-aws-identity-center.md`). Entra handles authentication. Each cloud
still owns its own authorization (roles and policies).

## What this lab leaves out

Lab scale, small instances, static test routes. A production version adds redundant and higher-capacity links,
inspection and security controls, central logging, and a landing-zone structure for accounts and identity.
