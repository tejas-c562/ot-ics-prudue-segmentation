# Mapping the Docker lab to GNS3 (VLAN-style segmentation)

The Docker lab is the fast, reproducible version. In GNS3 the same design can be built
with real network devices to practise VLANs / inter-VLAN ACLs.

## Topology
```
 [IT-PC]---+                      +---[Historian]
           |                      |
        (Access VLAN 10)     (Access VLAN 20)
           |                      |
        [ L2 switch SW1 (802.1Q trunk) ]------[ Firewall / L3 router ]------[ L2 switch SW2 ]---+--[PLC / OpenPLC]
                                   VLAN 10/20 on sub-interfaces          (Access VLAN 30)      +--[SCADA / ScadaBR]
```

| VLAN | Name | Subnet | Gateway (firewall sub-if) |
|------|------|--------|---------------------------|
| 10 | IT  | 10.10.10.0/24 | 10.10.10.254 |
| 20 | DMZ | 10.10.20.0/24 | 10.10.20.254 |
| 30 | OT  | 10.10.30.0/24 | 10.10.30.254 |

## Suggested appliances
* Firewall/router: **OPNsense/pfSense** QEMU appliance, or a Linux VM running `firewall/rules.sh`
  (it matches by subnet, so it works unchanged on VLAN sub-interfaces).
* Switch: GNS3 built-in Ethernet switch (set port type = access/dot1q + VLAN id).
* Nodes: Docker appliances using the same `ot-lab-node` image, or the real OpenPLC / ScadaBR images.

## Equivalent Cisco-style ACL (for write-ups / interviews)
```
ip access-list extended TO-OT
 permit tcp host 10.10.20.10 host 10.10.30.10 eq 502
 deny   ip any 10.10.30.0 0.0.0.255 log
ip access-list extended FROM-IT
 permit tcp 10.10.10.0 0.0.0.255 host 10.10.20.10 eq 8081
 deny   ip any any log
```
