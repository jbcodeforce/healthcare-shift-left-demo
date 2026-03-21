#!/usr/bin/env bash
# Merge Terraform output `backend_env` into backend/.env.
# Only rewrites the file when at least one managed key's value changes (or a managed key is missing).
#
# Usage (from repo root):
#   ./scripts/update_backend_env_from_terraform.sh
#   ./scripts/update_backend_env_from_terraform.sh path/to/.env
#   ./scripts/update_backend_env_from_terraform.sh --dry-run
#
# Requires: terraform (initialized in IaC/), python3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IAC_DIR="$REPO_ROOT/IaC"
DEFAULT_ENV_FILE="$REPO_ROOT/backend/.env"

DRY_RUN=0
ENV_FILE="$DEFAULT_ENV_FILE"
for arg in "$@"; do
  case "$arg" in
    --dry-run | -n) DRY_RUN=1 ;;
    *) ENV_FILE="$arg" ;;
  esac
done

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: .env file not found: $ENV_FILE" >&2
  exit 1
fi

if [[ ! -d "$IAC_DIR" ]]; then
  echo "error: IaC directory not found: $IAC_DIR" >&2
  exit 1
fi

TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT

if ! (cd "$IAC_DIR" && terraform output -json backend_env >"$TMP_JSON"); then
  echo "error: terraform output -json backend_env failed (run: cd IaC && terraform init && apply)" >&2
  exit 1
fi

export DRY_RUN="$DRY_RUN"
export TF_BACKEND_ENV_JSON_FILE="$TMP_JSON"
export TARGET_ENV_FILE="$ENV_FILE"

python3 <<'PY'
import json
import os
import sys
import tempfile

dry = os.environ.get("DRY_RUN", "0") == "1"
json_path = os.environ["TF_BACKEND_ENV_JSON_FILE"]
env_path = os.environ["TARGET_ENV_FILE"]

with open(json_path, encoding="utf-8") as f:
    wrapper = json.load(f)


tf = {k: str(v) if v is not None else "" for k, v in wrapper.items()}
tf_key_order = list(tf.keys())

with open(env_path, encoding="utf-8") as f:
    original = f.read()

lines = original.splitlines()


def parse_value(raw: str) -> str:
    raw = raw.strip()
    if len(raw) >= 2 and raw[0] == '"' and raw[-1] == '"':
        inner = raw[1:-1]
        return inner.replace("\\\\", "\0").replace('\\"', '"').replace("\0", "\\")
    if len(raw) >= 2 and raw[0] == "'" and raw[-1] == "'":
        return raw[1:-1].replace("\\'", "'")
    return raw


def fmt_line(key: str, val: str) -> str:
    esc = val.replace("\\", "\\\\").replace('"', '\\"')
    return f'{key}="{esc}"'


seen: set[str] = set()
out: list[str] = []
changed = False

for line in lines:
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        out.append(line)
        continue
    if "=" not in stripped:
        out.append(line)
        continue
    key, _, rest = stripped.partition("=")
    key = key.strip()
    if key not in tf:
        out.append(line)
        continue
    if key in seen:
        # Drop duplicate assignment for a Terraform-managed key (keep first updated line only).
        changed = True
        continue
    new_val = tf[key]
    old_val = parse_value(rest)
    if old_val != new_val:
        out.append(fmt_line(key, new_val))
        changed = True
    else:
        out.append(line)
    seen.add(key)

for key in tf_key_order:
    if key not in seen:
        out.append(fmt_line(key, tf[key]))
        changed = True

if not changed:
    print("No changes (all backend_env keys already match Terraform).")
    sys.exit(0)

if dry:
    print("Dry run: would write updates for keys whose values differ or were missing:")
    for key in tf_key_order:
        new_v = tf[key]
        old_lines = [
            ln
            for ln in lines
            if (m := ln.strip()) and not m.startswith("#") and m.partition("=")[0].strip() == key
        ]
        if not old_lines:
            print(f"  + {key} (new)")
            continue
        last = old_lines[-1]
        _, _, rest = last.strip().partition("=")
        old_v = parse_value(rest)
        if old_v != new_v:
            print(f"  ~ {key} (value change)")
    sys.exit(0)

new_body = "\n".join(out)
if original.endswith("\n") or not original:
    new_body += "\n"

fd, tmp_path = tempfile.mkstemp(prefix=".env.", dir=os.path.dirname(os.path.abspath(env_path)), text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as wf:
        wf.write(new_body)
    os.replace(tmp_path, env_path)
finally:
    if os.path.exists(tmp_path):
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

print(f"Updated {env_path} from Terraform backend_env ({len(tf_key_order)} keys).")
PY
