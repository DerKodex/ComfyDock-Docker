# ComfyDock Image Versioning

## Tag Format

Images are tagged with the following format:
```
{comfyui_version}-{image_version}-py{python}-cuda{cuda}-pt{pytorch}
```

### Examples
- `v1.3.0-v1.0.0-py3.12-cuda12.4-ptstable` - ComfyUI v1.3.0, first image version
- `v1.3.0-v1.1.0-py3.12-cuda12.4-ptstable` - ComfyUI v1.3.0, updated dockerfile
- `master-v1.0.0-py3.12-cuda12.4-ptstable` - ComfyUI master branch

## Version Components

### ComfyUI Version
- Uses ComfyUI's release tags (e.g., `v1.3.0`) or branch names (e.g., `master`)
- Automatically detected for scheduled builds
- Can be manually specified for workflow_dispatch

### Image Version
- Tracks changes to the Dockerfile, dependencies, or security fixes
- Follows semantic versioning (e.g., `v1.0.0`, `v1.1.0`, `v2.0.0`)
- **Always moves forward** - never revert to older versions for new ComfyUI releases
- Current version is tracked in the `VERSION` file and used for all builds
- Increment when making changes that don't require a new ComfyUI version

### Python/CUDA/PyTorch
- Matrix build parameters for different environment combinations
- `py{version}` - Python version (3.10, 3.12)
- `cuda{version}` - CUDA version (12.4, 12.8)
- `pt{version}` - PyTorch version (stable)

## Workflow Usage

### Automatic Builds (Weekly)
- Runs every Monday at 11:30 UTC
- Checks for new ComfyUI releases
- Uses current image version from `VERSION` file
- Skips if tag already exists

### Manual Builds
```yaml
# Build with specific versions
workflow_dispatch:
  inputs:
    comfyui_version: "v1.3.0"
    image_version: "v1.1.0"
    force_build: false

# Force rebuild existing tags
workflow_dispatch:
  inputs:
    force_build: true
```

## Release Process

### For Dockerfile Changes
1. Update the `VERSION` file with new image version (always increment)
2. Commit changes
3. Run workflow_dispatch with:
   - `comfyui_version`: Current ComfyUI version
   - `image_version`: New version from VERSION file (or leave blank to use VERSION file)
   - `force_build`: false (unless rebuilding)

### For New ComfyUI Releases
1. Wait for automatic build (uses current VERSION file), or
2. Run workflow_dispatch with new `comfyui_version`
3. **No need to change image version** - uses current VERSION file automatically

### Version Progression Example
```
v1.0.0 -> Initial release
v1.1.0 -> Security fix (applies to all future ComfyUI versions)
v1.2.0 -> Dependency update (applies to all future ComfyUI versions)
v2.0.0 -> Major Dockerfile restructure (applies to all future ComfyUI versions)
```

When ComfyUI v1.4.0 releases after you're on image v2.0.0:
- ✅ `v1.4.0-v2.0.0-py3.12-cuda12.4-ptstable` (correct)
- ❌ `v1.4.0-v1.0.0-py3.12-cuda12.4-ptstable` (wrong - loses improvements)

## Version History

- `v1.0.0` - Initial versioned release 