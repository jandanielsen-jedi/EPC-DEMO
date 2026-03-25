#!/bin/bash
# ─────────────────────────────────────────────
# EPC-DEMO deploy script
# Usage:
#   ./deploy.sh              → push all projects
#   ./deploy.sh package-engineer  → push one project
#   ./deploy.sh --new "my-demo"   → scaffold a new project folder
# ─────────────────────────────────────────────

source ~/.epc-deploy.env
REPO="jandanielsen-jedi/EPC-DEMO"
BRANCH="main"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

push_file() {
  local local_path="$1"
  local remote_path="$2"
  local filename=$(basename "$local_path")

  CONTENT=$(base64 -i "$local_path")
  SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/contents/$remote_path" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null)

  if [ -z "$SHA" ]; then
    MSG="Add $remote_path"
  else
    MSG="Update $remote_path"
  fi

  RESULT=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/$REPO/contents/$remote_path" \
    -d "{\"message\":\"$MSG\",\"content\":\"$CONTENT\",\"sha\":\"$SHA\",\"branch\":\"$BRANCH\"}")

  if [ "$RESULT" = "200" ] || [ "$RESULT" = "201" ]; then
    echo "  ✓ $remote_path"
  else
    echo "  ✗ $remote_path (HTTP $RESULT)"
  fi
}

push_project() {
  local project="$1"
  local dir="$BASE_DIR/$project"

  if [ ! -d "$dir" ]; then
    echo "✗ Project folder not found: $project"
    return
  fi

  echo ""
  echo "── $project ──────────────────────────"

  # Push root-level index for this project if exists
  for f in "$dir"/*.html; do
    [ -f "$f" ] || continue
    filename=$(basename "$f")
    if [ "$project" = "." ] || [ "$project" = "" ]; then
      push_file "$f" "$filename"
    else
      push_file "$f" "$project/$filename"
    fi
  done
}

scaffold_project() {
  local name="$1"
  local dir="$BASE_DIR/$name"
  mkdir -p "$dir"
  cat > "$dir/index.html" << TMPL
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$name</title>
<style>
  body{font-family:sans-serif;padding:40px;background:#f1efe8;color:#2c2c2a}
  h1{font-size:24px;font-weight:500}
  a{color:#185FA5}
</style>
</head>
<body>
<h1>$name</h1>
<p>Demo placeholder — replace this file with your content.</p>
<p><a href="../index.html">← Back to all demos</a></p>
</body>
</html>
TMPL
  echo "✓ Scaffolded: $dir"
  echo "  Add your HTML files there, then run: ./deploy.sh $name"
}

# ── Main logic ──────────────────────────────

# --new flag: scaffold a new project
if [ "$1" = "--new" ]; then
  if [ -z "$2" ]; then
    echo "Usage: ./deploy.sh --new \"project-name\""
    exit 1
  fi
  scaffold_project "$2"
  exit 0
fi

echo "EPC-DEMO deploy"
echo "Repo: https://github.com/$REPO"
echo "────────────────────────────────────────"

# Push root-level HTML files (index.html etc.)
for f in "$BASE_DIR"/*.html; do
  [ -f "$f" ] || continue
  push_file "$f" "$(basename "$f")"
done

# If a specific project is given, push only that
if [ -n "$1" ]; then
  push_project "$1"
else
  # Push all project subfolders
  for dir in "$BASE_DIR"/*/; do
    [ -d "$dir" ] || continue
    project=$(basename "$dir")
    # Skip hidden folders and node_modules
    [[ "$project" == .* ]] && continue
    [[ "$project" == "node_modules" ]] && continue
    push_project "$project"
  done
fi

echo ""
echo "────────────────────────────────────────"
echo "Live at: https://jandanielsen-jedi.github.io/EPC-DEMO/"
echo ""
