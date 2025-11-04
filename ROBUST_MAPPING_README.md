# PACMAN Robust Spatial Mapping

## Overview
This is an enhanced spatial mapping script designed for hours-long operation on moving vehicles. It handles corrupted frames, network issues, and recovers automatically.

## Key Features

### 🛡️ Error Handling
- **Corrupted Frame Handling**: Skips corrupted frames instead of crashing
- **Automatic Recovery**: Attempts reconnection if connection drops
- **Graceful Degradation**: Continues running even if 3D viewer fails
- **Comprehensive Logging**: Timestamped logs for debugging

### 📊 Monitoring
- **Status Reports**: Prints statistics every 60 seconds
- **Frame Tracking**: Monitors successful vs corrupted frames
- **Uptime Tracking**: Shows how long the system has been running
- **Success Rate**: Calculates frame success percentage

### 🔄 Recovery Mechanisms
- **Connection Health Checks**: Monitors if connection is alive
- **Automatic Reconnection**: Tries to reconnect after failures
- **Error Counters**: Tracks consecutive errors to detect issues
- **Timeout Protection**: Won't hang on network issues

### 💾 Data Safety
- **Timestamped Saves**: Mesh files saved with timestamp (won't overwrite)
- **Manual Control**: Press SPACE to start/stop mapping anytime
- **Graceful Shutdown**: Ctrl+C saves state before exiting
- **Multiple Save Points**: Can save mesh multiple times during run

## Usage

### Quick Start
```bash
./run_robust_spatial_mapping.sh
```

### Manual Run
```bash
source ~/miniforge3/etc/profile.d/conda.sh
conda activate pacman
python3 streaming_receiver_spatial_mapping_robust.py --ip_address 10.0.0.31:30002
```

### With Options
```bash
# Build mesh instead of point cloud
python3 streaming_receiver_spatial_mapping_robust.py --ip_address 10.0.0.31:30002 --build_mesh

# Use different resolution
python3 streaming_receiver_spatial_mapping_robust.py --ip_address 10.0.0.31:30002 --resolution HD720
```

## Controls

- **SPACE**: Start/Stop spatial mapping (saves mesh when stopping)
- **q**: Quit gracefully
- **Ctrl+C**: Emergency shutdown (still saves state)

## Output Files

Mesh files are saved with timestamps to prevent overwriting:
- `pacman_mesh_20251022_143022.obj` (format: YYYYMMDD_HHMMSS)

## Status Reports

Every 60 seconds, you'll see a status report:
```
[2025-10-22 14:30:15] [INFO] Status Report:
[2025-10-22 14:30:15] [INFO]   Uptime: 300.5s (5.0 min)
[2025-10-22 14:30:15] [INFO]   Total frames: 9015
[2025-10-22 14:30:15] [INFO]   Successful: 8850 (98.2%)
[2025-10-22 14:30:15] [INFO]   Corrupted: 165
[2025-10-22 14:30:15] [INFO]   Consecutive errors: 0
```

## Differences from Original

| Feature | Original | Robust Version |
|---------|----------|----------------|
| Corrupted frames | Crashes | Skips and continues |
| Connection loss | Crashes | Auto-reconnects |
| Error tracking | None | Full statistics |
| Logging | Minimal | Comprehensive + timestamps |
| Recovery | None | Automatic |
| Shutdown | Abrupt | Graceful with cleanup |
| Status monitoring | None | Every 60s |
| File naming | Fixed | Timestamped |
| Long runs | Unstable | Designed for hours |

## Recovery Parameters

These can be adjusted in the code if needed:

```python
self.max_consecutive_errors = 50      # Max errors before reconnect attempt
self.reconnect_timeout = 5.0          # Seconds to wait before reconnect
self.max_frame_gap = 10.0             # Max seconds without successful frame
self.status_report_interval = 60.0    # Status report frequency
```

## Troubleshooting

### "No successful frames for X seconds"
- Check network connection
- Verify sender is running
- Script will auto-reconnect

### "Too many consecutive errors"
- Network may be unstable
- Script will attempt reconnection
- Check sender configuration

### Viewer window won't open
- Script continues without 3D view
- Camera feed still works in OpenCV window
- Check OpenGL drivers if needed

## For Vehicle Operation

### Before Starting
1. Test connection in stationary mode first
2. Verify network stability
3. Ensure adequate storage space
4. Consider reducing resolution if bandwidth limited

### During Operation
- Monitor status reports in terminal
- Watch success rate (should be >95%)
- Save mesh periodically (press SPACE twice)
- Keep terminal visible for monitoring

### After Operation
- Press 'q' or Ctrl+C to stop gracefully
- Check final status report
- Verify mesh files were saved
- Review logs for any issues

## Performance Tips

1. **Lower Resolution**: Use `--resolution HD720` or `VGA` for better stability
2. **Save Frequently**: Save mesh every 10-15 minutes during long runs
3. **Monitor Bandwidth**: Keep success rate above 95%
4. **Network Quality**: Use wired connection when possible

## Files Created

- `streaming_receiver_spatial_mapping_robust.py` - Main script
- `run_robust_spatial_mapping.sh` - Convenience launcher
- `pacman_mesh_TIMESTAMP.obj` - Saved mesh files

## Support

If issues persist:
1. Check the status reports for clues
2. Review error messages in logs
3. Verify network connection quality
4. Test with lower resolution
5. Ensure sender is properly configured






