#!/usr/bin/env bash
# Build the LaTeX manuscript and PDF proof from the Markdown sources.
# Usage: bash build.sh
set -euo pipefail

cd "$(dirname "$0")"

mkdir -p tex

# Convert each numbered section and appendix to a LaTeX body fragment.
# -f markdown+pipe_tables keeps the pipe tables; --top-level-division=chapter
# makes each H1 heading a \chapter and each H2 a \section.
convert() {
  local src="$1"
  local out="$2"
  pandoc "$src" \
    --from markdown+pipe_tables-tex_math_dollars \
    --to latex \
    --top-level-division=chapter \
    --no-highlight \
    --output "$out"
}

for f in ../chapters/*.md; do
  name="$(basename "$f" .md)"            # e.g. 01-executive-summary
  num="${name%%-*}"                       # leading number, e.g. 01
  convert "$f" "tex/${num}.tex"
done

for f in ../appendices/*.md; do
  name="$(basename "$f" .md)"            # e.g. A-master-table
  letter="${name%%-*}"                    # leading letter, e.g. A
  convert "$f" "tex/${letter}.tex"
done

# Post-process the generated LaTeX:
#  1. Replace the literal ballot-box (U+2610) with the \chkbox command.
#  2. In the appendices, strip the redundant "Appendix X:" prefix so that
#     LaTeX's own appendix numbering does not duplicate it.
python3 - <<'PY'
import glob, re
for f in glob.glob('tex/*.tex'):
    txt = open(f, encoding='utf-8').read()
    txt = txt.replace('\u2610', r'\chkbox{}')
    base = f.rsplit('/', 1)[-1]
    if re.fullmatch(r'[A-H]\.tex', base):
        txt = re.sub(r'\\chapter\{Appendix [A-H]:\s*', r'\\chapter{', txt)
    open(f, 'w', encoding='utf-8').write(txt)
print("post-processing complete")
PY

# Compile twice so the table of contents and page numbers settle.
xelatex -interaction=nonstopmode -halt-on-error -jobname=manuscript main.tex > xelatex.log 2>&1
xelatex -interaction=nonstopmode -halt-on-error -jobname=manuscript main.tex > xelatex.log 2>&1

echo "Build complete: build/manuscript.pdf"
