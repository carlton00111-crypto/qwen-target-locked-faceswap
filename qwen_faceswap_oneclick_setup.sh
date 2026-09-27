#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Qwen Image 2.1 - Target Locked / Source Identity Face Swap
# One-click installer + workflow deployer for VastAI / Linux
# ============================================================
# What this script does:
# 1) Clones or updates ComfyUI
# 2) Installs Python dependencies
# 3) Downloads the required Qwen Image 2.1 models
# 4) Copies the workflow into ComfyUI workflow folders
# 5) Optionally copies source/target images into ComfyUI/input
# 6) Optionally patches the workflow with those image names
# 7) Optionally launches ComfyUI
#
# Repo files expected next to this script:
# - Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json
#
# Usage example:
#   bash qwen_faceswap_oneclick_setup.sh \
#     --install-dir /workspace/ComfyUI \
#     --source-image /workspace/assets/source.png \
#     --target-image /workspace/assets/target.png \
#     --launch
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_WORKFLOW="$SCRIPT_DIR/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"

INSTALL_DIR="/workspace/ComfyUI"
PORT="8188"
WORKFLOW_JSON="$DEFAULT_WORKFLOW"
SOURCE_IMAGE=""
TARGET_IMAGE=""
OUTPUT_PREFIX="Qwen_TargetLocked_SourceIdentity"
LAUNCH_COMFY="false"
FORCE_DOWNLOAD="false"
SKIP_PIP="false"
UPDATE_IF_EXISTS="true"

log()  { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*"; }
die()  { echo -e "[ERROR] $*" >&2; exit 1; }

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [options]

Options:
  --install-dir PATH      ComfyUI install path (default: /workspace/ComfyUI)
  --workflow PATH         Workflow JSON path (default: bundled file in repo)
  --source-image PATH     Image 1 = source identity (optional)
  --target-image PATH     Image 2 = target geometry anchor (optional)
  --output-prefix NAME    Output filename prefix in workflow
  --port N                ComfyUI port (default: 8188)
  --launch                Launch ComfyUI after setup
  --force-download        Re-download model files even if they exist
  --skip-pip              Skip pip install -r requirements.txt
  --no-update             Do not git pull if ComfyUI already exists
  -h, --help              Show this help

Examples:
  # Install everything and launch
  bash $(basename "$0") --install-dir /workspace/ComfyUI --launch

  # Install + prefill source/target images
  bash $(basename "$0") \
    --install-dir /workspace/ComfyUI \
    --source-image /workspace/assets/source.png \
    --target-image /workspace/assets/target.png \
    --launch
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir) INSTALL_DIR="$2"; shift 2 ;;
    --workflow) WORKFLOW_JSON="$2"; shift 2 ;;
    --source-image) SOURCE_IMAGE="$2"; shift 2 ;;
    --target-image) TARGET_IMAGE="$2"; shift 2 ;;
    --output-prefix) OUTPUT_PREFIX="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --launch) LAUNCH_COMFY="true"; shift ;;
    --force-download) FORCE_DOWNLOAD="true"; shift ;;
    --skip-pip) SKIP_PIP="true"; shift ;;
    --no-update) UPDATE_IF_EXISTS="false"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required"
command -v python3 >/dev/null 2>&1 || die "python3 is required"
command -v curl >/dev/null 2>&1 || die "curl is required"
[[ -f "$WORKFLOW_JSON" ]] || die "Workflow JSON not found: $WORKFLOW_JSON"

mkdir -p "$(dirname "$INSTALL_DIR")"

clone_or_update_comfyui() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    log "ComfyUI already exists at $INSTALL_DIR"
    if [[ "$UPDATE_IF_EXISTS" == "true" ]]; then
      log "Updating ComfyUI..."
      git -C "$INSTALL_DIR" pull --ff-only || warn "git pull failed; continuing with existing checkout"
    fi
  else
    log "Cloning ComfyUI into $INSTALL_DIR ..."
    git clone https://github.com/comfyanonymous/ComfyUI.git "$INSTALL_DIR"
  fi
}

install_python_deps() {
  if [[ "$SKIP_PIP" == "true" ]]; then
    warn "Skipping pip install as requested"
    return
  fi

  log "Installing ComfyUI Python dependencies..."
  if [[ -f "$INSTALL_DIR/venv/bin/python" ]]; then
    "$INSTALL_DIR/venv/bin/python" -m pip install --upgrade pip
    "$INSTALL_DIR/venv/bin/python" -m pip install -r "$INSTALL_DIR/requirements.txt"
  else
    python3 -m pip install --upgrade pip
    python3 -m pip install -r "$INSTALL_DIR/requirements.txt"
  fi
}

download_if_missing() {
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"

  if [[ -f "$out" && "$FORCE_DOWNLOAD" != "true" ]]; then
    log "Already exists: $out"
    return
  fi

  log "Downloading: $(basename "$out")"
  curl -L --fail --retry 3 "$url" -o "$out"
}

download_models() {
  log "Downloading required Qwen models..."

  download_if_missing \
    "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/diffusion_models/qwen_image_2.1_int8_convrot.safetensors" \
    "$INSTALL_DIR/models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors"

  download_if_missing \
    "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors" \
    "$INSTALL_DIR/models/text_encoders/qwen3vl_8b_int8_convrot.safetensors"

  download_if_missing \
    "https://huggingface.co/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors" \
    "$INSTALL_DIR/models/vae/qwen_image_2.1_vae_bf16.safetensors"
}

copy_workflow() {
  local workflows_dir="$INSTALL_DIR/workflows"
  local user_workflows_dir="$INSTALL_DIR/user/default/workflows"
  mkdir -p "$workflows_dir" "$user_workflows_dir"

  cp -f "$WORKFLOW_JSON" "$workflows_dir/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"
  cp -f "$WORKFLOW_JSON" "$user_workflows_dir/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"

  log "Workflow copied to:"
  log "  $workflows_dir/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"
  log "  $user_workflows_dir/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"
}

patch_workflow_with_images() {
  [[ -n "$SOURCE_IMAGE" ]] || return 0
  [[ -n "$TARGET_IMAGE" ]] || return 0
  [[ -f "$SOURCE_IMAGE" ]] || die "Source image not found: $SOURCE_IMAGE"
  [[ -f "$TARGET_IMAGE" ]] || die "Target image not found: $TARGET_IMAGE"

  local input_dir="$INSTALL_DIR/input"
  local workflows_dir="$INSTALL_DIR/workflows"
  local user_workflows_dir="$INSTALL_DIR/user/default/workflows"
  mkdir -p "$input_dir"

  local source_name="$(basename "$SOURCE_IMAGE")"
  local target_name="$(basename "$TARGET_IMAGE")"

  cp -f "$SOURCE_IMAGE" "$input_dir/$source_name"
  cp -f "$TARGET_IMAGE" "$input_dir/$target_name"

  export WF1="$workflows_dir/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"
  export WF2="$user_workflows_dir/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json"
  export SRC_NAME="$source_name"
  export TGT_NAME="$target_name"
  export OUTPUT_PREFIX

  python3 <<'PY'
import json, os

for wf_path in [os.environ["WF1"], os.environ["WF2"]]:
    with open(wf_path, "r", encoding="utf-8") as f:
        wf = json.load(f)

    for node in wf.get("nodes", []):
        nid = node.get("id")
        if nid == 475:
            if isinstance(node.get("widgets_values"), list) and node["widgets_values"]:
                node["widgets_values"][0] = os.environ["SRC_NAME"]
            node.setdefault("widgets_values_named", {})["image"] = os.environ["SRC_NAME"]
            node["title"] = "IMAGE 1 — SOURCE IDENTITY ONLY"
        elif nid == 510:
            if isinstance(node.get("widgets_values"), list) and node["widgets_values"]:
                node["widgets_values"][0] = os.environ["TGT_NAME"]
            node.setdefault("widgets_values_named", {})["image"] = os.environ["TGT_NAME"]
            node["title"] = "IMAGE 2 — TARGET / ABSOLUTE GEOMETRY ANCHOR"
        elif nid == 508:
            if isinstance(node.get("widgets_values"), list) and node["widgets_values"]:
                node["widgets_values"][0] = os.environ["OUTPUT_PREFIX"]
            node.setdefault("widgets_values_named", {})["filename_prefix"] = os.environ["OUTPUT_PREFIX"]

    with open(wf_path, "w", encoding="utf-8") as f:
        json.dump(wf, f, ensure_ascii=False, indent=2)
PY

  log "Source and target images copied into: $input_dir"
  log "Workflow patched with image filenames."
}

launch_comfy() {
  log "Launching ComfyUI on port $PORT ..."
  cd "$INSTALL_DIR"

  if [[ -f "$INSTALL_DIR/venv/bin/python" ]]; then
    exec "$INSTALL_DIR/venv/bin/python" main.py --listen 0.0.0.0 --port "$PORT"
  else
    exec python3 main.py --listen 0.0.0.0 --port "$PORT"
  fi
}

print_summary() {
  cat <<MSG

============================================================
SETUP COMPLETE
============================================================
ComfyUI path:
  $INSTALL_DIR

Workflow installed at:
  $INSTALL_DIR/workflows/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json
  $INSTALL_DIR/user/default/workflows/Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json

Models expected at:
  $INSTALL_DIR/models/diffusion_models/qwen_image_2.1_int8_convrot.safetensors
  $INSTALL_DIR/models/text_encoders/qwen3vl_8b_int8_convrot.safetensors
  $INSTALL_DIR/models/vae/qwen_image_2.1_vae_bf16.safetensors

How to run manually later:
  cd $INSTALL_DIR
  python3 main.py --listen 0.0.0.0 --port $PORT

How to use in ComfyUI:
  1) Open ComfyUI in browser
  2) Load workflow: Qwen_Image_2.1_Target_Locked_Source_Identity_TWO_PASS.json
  3) If not prefilled, set:
     - IMAGE 1 = source identity
     - IMAGE 2 = target geometry anchor
  4) Queue / Run

Workflow behavior:
  - Pass 1 = conservative identity transfer
  - Pass 2 = eye / expression / blend stabilization
============================================================
MSG
}

clone_or_update_comfyui
install_python_deps
download_models
copy_workflow
patch_workflow_with_images
print_summary

if [[ "$LAUNCH_COMFY" == "true" ]]; then
  launch_comfy
fi
