# Qwen Image 2.1 — Target Locked / Source Identity Face Swap

This repo gives you a **one-command setup** for a Qwen Image 2.1 face-swap workflow in ComfyUI.

## What it does
- Installs or updates **ComfyUI**
- Downloads the required **Qwen Image 2.1** model files
- Copies the bundled workflow into ComfyUI
- Optionally preloads:
  - **Image 1 = source identity**
  - **Image 2 = target geometry anchor**
- Optionally launches ComfyUI

## Included files
- `qwen_faceswap_oneclick_setup.sh`
- `Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json`
- `.gitignore`
- `README.md`

## Quick start
```bash
git clone <your-repo-url>
cd <your-repo-folder>
chmod +x qwen_faceswap_oneclick_setup.sh

bash qwen_faceswap_oneclick_setup.sh \
  --install-dir /workspace/ComfyUI \
  --launch
```

## Quick start with images
```bash
bash qwen_faceswap_oneclick_setup.sh \
  --install-dir /workspace/ComfyUI \
  --source-image /workspace/assets/source.png \
  --target-image /workspace/assets/target.png \
  --launch
```

## Meaning of the two images
- **Image 1** → source identity / whose face you want
- **Image 2** → target image / whose pose, body, gaze, hair, outfit, framing, and background should stay locked

## Useful options
```bash
--install-dir /workspace/ComfyUI
--workflow /path/to/custom_workflow.json
--source-image /path/to/source.png
--target-image /path/to/target.png
--output-prefix Qwen_TargetLocked_SourceIdentity
--port 8188
--launch
--force-download
--skip-pip
--no-update
```

## Notes
- The script expects a Linux/VastAI-style environment.
- If ComfyUI already exists, it updates it unless you pass `--no-update`.
- If the images are provided, the workflow JSON is patched automatically.
- The workflow is **two-pass**:
  - **Pass 1:** conservative identity transfer
  - **Pass 2:** eye / expression / blend stabilization
