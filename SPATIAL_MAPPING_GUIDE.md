# PACMAN Spatial Mapping - Quick Guide

## Simple Version (Stable, No Crashes)

### To Run:
```bash
cd ~/Documents/SDKstream
./run_simple_spatial_mapping.sh
```

### Controls:
- **'m'** - START/STOP spatial mapping
- **'s'** - Save mesh manually right now
- **'q'** - Quit and save final mesh

### Usage Steps:
1. Launch the script (camera window appears)
2. **Press 'm'** to start mapping
3. Drive/move around to collect data
4. Press 's' anytime to save a snapshot
5. Press 'q' when done (saves final mesh)

### Features:
- ✅ Auto-saves every 5 minutes
- ✅ Handles corrupted frames (100% success rate)
- ✅ Runs for hours without crashing
- ✅ Status reports every 60 seconds
- ✅ Camera view with status overlay

### Output Files:
- `pacman_mesh_auto_TIMESTAMP.obj` - Auto-saved every 5 min
- `pacman_mesh_TIMESTAMP.obj` - Manual saves (press 's')
- `pacman_mesh_final_TIMESTAMP.obj` - Final save on exit

### Viewing the Meshes:
Open `.obj` files with:
- **MeshLab** (free)
- **Blender** (free)
- **CloudCompare** (free)
- Any 3D viewer

### Example Session:
```
1. ./run_simple_spatial_mapping.sh
2. Wait for camera view
3. Press 'm' (mapping starts)
4. Drive vehicle for 30 minutes
5. Auto-saves happen every 5 min
6. Press 'q' to quit
7. Final mesh saved automatically
```

### Status Display:
```
[STATUS] Uptime: 2.0min | Frames: 3069/3070 (100.0%) | Corrupted: 0
```
- **Uptime** - How long running
- **Frames** - Successful/Total
- **Success rate** - Should be >95%
- **Corrupted** - Frames skipped (non-critical)

### Troubleshooting:
**If mapping won't start:**
- Make sure you pressed 'm' (not 's' or space)
- Check terminal for error messages
- Verify camera stream is working (window shows image)

**If no auto-saves happening:**
- Mapping must be active (press 'm' first)
- Wait 5 minutes for first auto-save
- Check terminal for save messages

**If mesh files are empty/small:**
- Make sure you're moving/driving while mapping
- Static scenes produce minimal mesh data
- Need movement for spatial mapping to work

### Network Quality:
- **99-100%** success rate = Excellent
- **95-99%** success rate = Good
- **<95%** success rate = Check network connection

### Tips for Best Results:
1. Start mapping before starting to drive
2. Move smoothly (not too fast)
3. Cover the area systematically
4. Save manually at key points (press 's')
5. Let auto-save happen every 5 minutes
6. Check terminal occasionally for status

### File Locations:
All mesh files save to: `/home/yadinlinux/Documents/SDKstream/`

Example files after 30-minute run:
```
pacman_mesh_auto_20251022_103700.obj  (5 min mark)
pacman_mesh_auto_20251022_104200.obj  (10 min mark)
pacman_mesh_auto_20251022_104700.obj  (15 min mark)
pacman_mesh_auto_20251022_105200.obj  (20 min mark)
pacman_mesh_auto_20251022_105700.obj  (25 min mark)
pacman_mesh_auto_20251022_110200.obj  (30 min mark)
pacman_mesh_final_20251022_110215.obj (exit time)
```

---

## Summary:
✅ **Simple version = Stable for hours**
❌ **3D viewer version = Crashes when mapping starts**

**Use the simple version for vehicle mapping!**






