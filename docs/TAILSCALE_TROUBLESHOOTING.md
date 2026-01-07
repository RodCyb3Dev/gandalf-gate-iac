# Tailscale Troubleshooting Guide

## Issue: Machine Not Showing in Tailscale Admin Console

If your `homelab-gateway` machine is running but not appearing in the Tailscale admin console, follow these steps:

### 1. Verify Machine is Connected

Check if the machine is actually connected:

```bash
docker compose -f docker-compose.yml exec tailscale tailscale status
```

You should see:
- Your machine listed with its Tailscale IP
- Status showing it's connected
- Other machines in your tailnet

### 2. Check Authentication Status

Verify the machine is authenticated:

```bash
docker compose -f docker-compose.yml exec tailscale tailscale status --json | grep -E "(AuthURL|BackendState|HaveNodeKey)"
```

Expected output:
- `"AuthURL": ""` (empty means authenticated)
- `"BackendState": "Running"`
- `"HaveNodeKey": true`

### 3. Verify in Admin Console

1. Go to https://login.tailscale.com/admin/machines
2. Look for machine named: **homelab-gateway**
3. Check the machine ID matches: `nY3Zs2QLbh11CNTRL` (from status output)

### 4. Common Issues and Solutions

#### Issue: Machine shows as "Offline" in console but status shows connected

**Solution**: This is often a display delay. The machine is actually connected. Try:
- Refresh the admin console page
- Wait a few minutes for the console to update
- Check if you can ping the machine from another device: `ping 100.91.10.19`

#### Issue: Machine not appearing at all in console

**Possible causes**:
1. **Wrong Tailscale account**: Ensure the `TAILSCALE_AUTH_KEY` is for the correct Tailscale account
2. **Expired auth key**: Generate a new auth key from https://login.tailscale.com/admin/settings/keys
3. **State file corruption**: Reset the state file (see below)

#### Issue: "You are logged out" errors in logs

**Solution**: The machine needs to re-authenticate:
1. Generate a new auth key: https://login.tailscale.com/admin/settings/keys
2. Update `.env` file with new `TAILSCALE_AUTH_KEY`
3. Restart the container: `docker compose -f docker-compose.yml restart tailscale`

### 5. Reset Tailscale State (Last Resort)

If the machine is completely stuck, you can reset the state:

```bash
# Stop the container
docker compose -f docker-compose.yml stop tailscale

# Backup the old state (optional)
cp config/tailscale/tailscaled.state config/tailscale/tailscaled.state.backup

# Remove the state file
rm config/tailscale/tailscaled.state

# Generate a new auth key from admin console
# Update .env with new TAILSCALE_AUTH_KEY

# Start the container
docker compose -f docker-compose.yml up -d tailscale
```

### 6. Verify Machine Details

Get full machine information:

```bash
docker compose -f docker-compose.yml exec tailscale tailscale status --json | python3 -m json.tool | grep -A 15 '"Self"'
```

This shows:
- Machine ID
- Hostname
- DNS name
- Tailscale IPs
- User account
- OS type

### 7. Check Network Connectivity

Verify the machine can communicate with other Tailscale devices:

```bash
# From another Tailscale device, ping the gateway
ping 100.91.10.19

# Or from the gateway, ping another device
docker compose -f docker-compose.yml exec tailscale ping <other-device-ip>
```

### 8. Verify Routes are Advertised

Check if routes are being advertised:

```bash
docker compose -f docker-compose.yml exec tailscale tailscale status --json | python3 -c "import sys, json; d=json.load(sys.stdin); print('Routes:', d['Self'].get('PrimaryRoutes', []))"
```

Should show: `['172.21.0.0/24']`

### 9. Check Logs for Errors

Review recent logs for any errors:

```bash
docker compose -f docker-compose.yml logs tailscale --tail 50 | grep -iE "(error|Error|ERROR|auth|login|expired|invalid)"
```

### 10. Verify Environment Variables

Ensure the auth key is set correctly:

```bash
# Check if auth key is in .env
grep TAILSCALE_AUTH_KEY .env

# Verify it's being passed to container
docker compose -f docker-compose.yml exec tailscale env | grep TS_AUTHKEY
```

## Current Machine Status

Based on the latest check, your machine should be visible in the console with:

- **Name**: homelab-gateway
- **Machine ID**: nY3Zs2QLbh11CNTRL
- **Tailscale IP**: 100.91.10.19
- **DNS Name**: homelab-gateway.kooka-lake.ts.net
- **Status**: Connected and authenticated
- **User**: RodCyb3Dev@github

If you still don't see it in the console:
1. Check you're logged into the correct Tailscale account
2. Look for the machine ID `nY3Zs2QLbh11CNTRL` in the console
3. Try filtering/searching for "homelab-gateway" in the machines list

