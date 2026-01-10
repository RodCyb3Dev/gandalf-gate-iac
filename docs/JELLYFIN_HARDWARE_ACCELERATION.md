# Jellyfin Hardware Acceleration Setup

## Overview

This guide explains how to configure hardware acceleration for Jellyfin, even on virtualized servers.

## Current Setup

- **Server**: CPX21 (3 vCPU, 4GB RAM)
- **GPU**: Virtio GPU (virtualized)
- **Device**: `/dev/dri` mounted with `card0` and `renderD128`
- **Groups**: `video` (GID 44), `render` (GID 993)

## Configuration

### Docker Compose

The `/dev/dri` device is mounted in the Jellyfin container:

```yaml
devices:
  - /dev/dri:/dev/dri
```

### Jellyfin Settings

Even though the Virtio GPU may not support full hardware acceleration, it's worth trying VA-API:

1. **Navigate to**: Dashboard → Playback → Transcoding

2. **Hardware Acceleration Settings**:
   - **Hardware acceleration**: `Video Acceleration API (VA-API)`
   - **VA-API device**: `/dev/dri/renderD128`
   - **Enable hardware encoding**: `On` (if supported)
   - **Enable hardware decoding**: `On` (if supported)

3. **Test Hardware Acceleration**:
   - Try playing a video that requires transcoding
   - Check Dashboard → Dashboard → Active Devices
   - Look for "Hardware" indicator in transcoding status

### Verifying Device Access

Check if the device is accessible in the container:

```bash
docker exec jellyfin ls -la /dev/dri/
```

Should show:
```
card0
renderD128
```

### Testing VA-API Support

Test if VA-API works with the Virtio GPU:

```bash
docker exec jellyfin /usr/lib/jellyfin-ffmpeg/ffmpeg -hwaccels
```

This will list available hardware acceleration methods.

### Limitations

**Virtio GPU Limitations:**
- Virtio GPU is a virtualized GPU that may not support hardware acceleration
- Most virtualized GPUs don't have hardware encoders/decoders
- Software transcoding will likely still be used as fallback

**If Hardware Acceleration Doesn't Work:**
- The system will automatically fall back to software transcoding
- The tmpfs mount for transcoding cache will still provide performance benefits
- Optimized encoder presets will help with software transcoding

### Alternative: Software Transcoding Optimization

If hardware acceleration isn't available, focus on:
1. **tmpfs transcoding cache** (already configured)
2. **Faster encoder presets** (veryfast/ultrafast)
3. **Throttling** to prevent CPU overload
4. **Direct play** when possible to avoid transcoding

## References

- [Jellyfin Hardware Acceleration Docs](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/)
- [VA-API on Linux](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel#linux-setups)
