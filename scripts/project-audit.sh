#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

section() {
    echo
    echo "=================================================="
    echo " $1"
    echo "=================================================="
}

section "PROJECT INFORMATION"
echo "Project: $(basename "$ROOT")"
echo "Path: $ROOT"
echo "Date: $(date)"

section "PROJECT FILES"
find . -maxdepth 3 -type f \
    ! -path './.git/*' \
    ! -path './.venv/*' \
    ! -path './__pycache__/*' \
    ! -name '.env' | sort

section "GIT STATUS"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git status --short
    echo "Branch: $(git branch --show-current)"
    echo "Remote:"
    git remote -v
else
    echo "Git repository not initialized."
fi

section "AUTOMATED TESTS"
if [[ -d tests ]]; then
    grep -R -nE '^def test_' tests/ || true
    printf "Total test functions: "
    grep -R -hE '^def test_' tests/ 2>/dev/null | wc -l
else
    echo "Tests directory missing."
fi

section "DOCUMENTATION"
for file in README.md RUNBOOK.md DECISIONS.md ARCHITECTURE.md AI-USE.md; do
    if [[ -f "$file" ]]; then
        echo "[PRESENT] $file"
    else
        echo "[MISSING] $file"
    fi
done

section "CI WORKFLOWS"
if [[ -d .github/workflows ]]; then
    find .github/workflows -maxdepth 1 -type f -print
else
    echo "GitHub Actions workflow directory missing."
fi

section "SECURITY FILES"
for file in .dockerignore .gitignore requirements.txt requirements-dev.txt; do
    [[ -f "$file" ]] && echo "[PRESENT] $file" || echo "[MISSING] $file"
done

section "EVIDENCE"
if [[ -d evidence ]]; then
    find evidence -maxdepth 2 -type f -printf '%p (%s bytes)\n'
else
    echo "Evidence directory missing."
fi

section "DOCKER COMPOSE"
if docker info >/dev/null 2>&1; then
    docker compose ps -a
    echo
    echo "Configured images:"
    docker compose config --images 2>/dev/null || true
else
    echo "Docker Engine unavailable."
fi

section "DOCKER IMAGE INVENTORY"
docker image ls --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' 2>/dev/null || true

section "AUDIT COMPLETE"
echo "No files, containers, images or volumes were modified."
