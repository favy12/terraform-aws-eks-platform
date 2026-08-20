# Design decisions

Short notes on the choices that aren't obvious from reading the HCL.

---

### Why hand-written modules instead of `terraform-aws-modules/eks/aws`

The community module is the right answer for production at most companies — it's better tested than anything one person maintains. This repo is written out longhand because the point is to show the reasoning, and a 40-line call to someone else's module shows none of it.

If you're adopting this for real work, wrapping the upstream module is a defensible fork of this design.

---

### `ignore_changes = [scaling_config[0].desired_size]`

Cluster autoscaler adjusts `desired_size` continuously. Terraform holds a value from the last apply. Without this, every `terraform apply` resets the node group to whatever the tfvars said, which on a busy cluster means an unplanned scale-down in the middle of the day.

`min_size` and `max_size` stay managed by Terraform — those are policy, and policy should be in code.

---

### `resolve_conflicts_on_update = "PRESERVE"`

`OVERWRITE` on update reverts any field changed in-cluster. That's correct on create, where there's nothing to preserve, and wrong on update, where someone has usually patched a CoreDNS replica count or a CNI env var for a reason.

`PRESERVE` fails the update loudly on conflict instead of silently reverting. A failed apply you have to look at beats a successful one that undid a fix.

---

### Flow logs capture `REJECT` only

`ALL` on a moderately busy cluster generates enough CloudWatch ingest to become a line item somebody asks about. `REJECT` answers the question flow logs actually get opened for — "what's being blocked and by which rule" — at a fraction of the volume.

If you need `ALL` for a compliance requirement, change `traffic_type` and send it to S3 rather than CloudWatch.

---

### IRSA subject pinned to one service account

The trust policy condition is:

```
"${oidc_url}:sub" = "system:serviceaccount:${namespace}:${service_account}"
```

A wildcard here — `system:serviceaccount:kube-system:*` — means any pod in that namespace can assume the role. Namespaces usually hold more than one controller, so the wildcard version quietly grants the autoscaler's permissions to everything else in `kube-system`.

The `aud` condition matters too: without it, a token issued for a different audience can be replayed against this role.

---

### SSM instead of SSH

`AmazonSSMManagedInstanceCore` on the node role means node access happens through Session Manager: no port 22 open, no bastion to maintain, no key distribution, and every session logged to CloudTrail with the IAM identity attached.

The cost is that break-glass access depends on the SSM agent being healthy. Worth it.

---

### Spot node groups list multiple instance types

A spot node group pinned to one instance type is pinned to one capacity pool. When that pool dries up the group cannot scale, and the failure looks like a scheduling problem rather than a capacity one.

Listing `c6i.2xlarge`, `c6a.2xlarge`, `c5.2xlarge` gives the allocation strategy three pools in the same size class, so pods land on equivalent hardware regardless of which one has capacity.

---

### Native S3 state locking

The `use_lockfile = true` backend argument (Terraform 1.10+) replaces the DynamoDB lock table. One less resource to bootstrap, one less thing to pay for, and no chicken-and-egg problem where the lock table itself needs state.

On Terraform 1.5–1.9, swap it for `dynamodb_table`.

---

### Addon versions pinned in prod, floating in dev

Unpinned addons mean an upgrade can arrive on an unrelated apply — someone changes a node group, and CoreDNS moves a minor version in the same change.

Dev floats on purpose: it's where the new version gets discovered before it's a prod commit.
