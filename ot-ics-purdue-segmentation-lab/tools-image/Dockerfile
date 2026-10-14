# Shared base image for every custom node in the lab (firewall, PLC sim, HMI,
# historian, IT workstation, rogue device). One image keeps the lab easy to build.
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      iproute2 iptables iputils-ping curl nmap tcpdump netcat-openbsd procps bash \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir pymodbus==3.6.9

WORKDIR /opt/lab
CMD ["sleep", "infinity"]
