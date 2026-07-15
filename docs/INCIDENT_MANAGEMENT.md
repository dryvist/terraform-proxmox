# Incident Management

This repository handles incident management configuration and orchestration. Zammad is our ITSM solution used by AI agents and operators alike.

## Architecture
- Active-Active High Availability across Proxmox nodes
- Managed by OpenTofu + Terrakube
- Proxied via Traefik Ingress with Sticky Sessions

## Integration
AI agents authenticate securely via OpenBao and interact with the Zammad API for incident resolution, tracking, and orchestration.
