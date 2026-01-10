# Jellyfin Performance Optimization Guide

## Overview

This guide optimizes Jellyfin performance on virtualized servers (like Hetzner Cloud) without hardware GPU acceleration.

## Current Server Configuration

- **Server**: CPX21 (3 vCPU, 4GB RAM)
- **GPU**: Virtio GPU (virtualized, no hardware acceleration support)
- **Storage**: Hetzner Storage Box (network-mounted via WebDAV)

## Performance Optimizations Applied

### 1. Transcoding Cache in RAM (tmpfs)

Transcoding temporary files are stored in RAM instead of disk, providing:
- **10-100x faster I/O** compared to network storage
- Reduced latency during transcoding
- Better performance for multiple concurrent streams

**Configuration:**
```yaml
tmpfs:
  - /config/data/transcodes:size=2G  # 2GB RAM for transcoding cache
```

### 2. Software Transcoding Settings

Since hardware acceleration is not available on virtualized servers, we optimize software transcoding:

**Key Settings:**
- **Encoder Preset**: `veryfast` (faster encoding, lower CPU usage)
- **Hardware Acceleration**: Disabled (not available on Virtio GPU)
- **Throttling**: Enabled (prevents CPU overload)
- **Segment Deletion**: Enabled (saves disk space)

### 3. Jellyfin Dashboard Settings

After deploying, configure these settings in Jellyfin Web UI:

1. **Navigate to**: Dashboard → Playback → Transcoding

2. **Recommended Settings:**
   - **Hardware acceleration**: `None` (or `VideoToolbox` if available)
   - **Enable hardware encoding**: `Off`
   - **Enable hardware decoding**: `Off`
   - **Transcoding temporary path**: `/config/data/transcodes`
   - **Encoder preset**: `Very Fast`
   - **Enable throttling**: `On`
   - **Throttle delay**: `60 seconds`
   - **Enable segment deletion**: `On`
   - **Segment keep time**: `5 minutes`

3. **Playback Settings:**
   - **Enable video encoding**: `On`
   - **Allow HEVC encoding**: `On` (better compression)
   - **Allow AV1 encoding**: `Off` (not supported on virtualized servers)
   - **Enable subtitle extraction**: `On`

### 4. Additional Performance Tips

#### Direct Play When Possible

To avoid transcoding entirely:
- Use clients that support your media formats (e.g., MP4/H.264)
- Pre-encode media to compatible formats
- Use Jellyfin clients that support direct play

#### Reduce Transcoding Load

1. **Pre-transcode media** to common formats:
   - Container: MP4
   - Video: H.264 (AVC)
   - Audio: AAC
   - Resolution: 1080p or lower for mobile devices

2. **Limit concurrent transcodes**:
   - Set maximum concurrent transcodes in Dashboard → Playback
   - Recommended: 2-3 concurrent transcodes for CPX21 server

3. **Use lower bitrate profiles**:
   - Configure quality profiles in Dashboard → Playback → Quality
   - Lower bitrates = faster transcoding

#### Monitor Performance

1. **Check transcoding status**:
   - Dashboard → Dashboard → Active Devices
   - Look for "Transcoding" indicator

2. **Monitor CPU usage**:
   - Use `htop` or `docker stats jellyfin`
   - CPU should stay below 80% during transcoding

3. **Check transcoding cache**:
   - `docker exec jellyfin df -h /config/data/transcodes`
   - Should show tmpfs mount with available space

## Deployment

### Automatic Optimization Script

Run the optimization script to apply all settings:

```bash
./scripts/optimize-jellyfin-transcoding.sh
```

### Manual Configuration

1. **Deploy updated docker-compose**:
   ```bash
   make ansible-deploy-arr
   ```

2. **Configure Jellyfin via Web UI**:
   - Access Jellyfin at `https://jellyfin.kooka-lake.ts.net`
   - Navigate to Dashboard → Playback → Transcoding
   - Apply settings from section 3 above

3. **Restart Jellyfin**:
   ```bash
   docker restart jellyfin
   ```

## Troubleshooting

### Slow Playback Still Occurs

1. **Check if transcoding is happening**:
   - Dashboard → Dashboard → Active Devices
   - If transcoding, check CPU usage

2. **Verify tmpfs mount**:
   ```bash
   docker exec jellyfin df -h /config/data/transcodes
   ```
   Should show tmpfs, not a regular filesystem

3. **Check network speed**:
   - Storage Box is network-mounted, may be slow
   - Consider pre-transcoding media to reduce load

### High CPU Usage

1. **Reduce concurrent transcodes**:
   - Dashboard → Playback → Transcoding
   - Set "Maximum concurrent transcodes" to 2

2. **Use faster encoder preset**:
   - Change from "veryfast" to "ultrafast" (lower quality, faster)

3. **Enable throttling**:
   - Already enabled, but verify in settings

### Out of Memory Errors

1. **Reduce tmpfs size**:
   - Edit `docker-compose.arr-stack.yml`
   - Change `size=2G` to `size=1G`

2. **Limit concurrent transcodes**:
   - Reduce to 1-2 concurrent transcodes

## References

- [Jellyfin Hardware Acceleration Docs](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/)
- [Maximizing Jellyfin Performance](https://www.oreateai.com/blog/maximizing-jellyfin-performance-a-guide-to-hardware-acceleration-and-tuning/b170e22857273f989c3299afd1129e5c)
