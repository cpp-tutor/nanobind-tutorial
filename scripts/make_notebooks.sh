#!/bin/bash

srcdir="$(dirname "$(readlink -f "$0")")/.."
destdir="$srcdir/jupyter-notebooks"
for f in "$srcdir"/??-*.md ; do
  [ -e "$f" ] || continue
  out="$destdir/$(basename "$f")"
  rm -f "${out%%.md}.ipynb"
  cat "$f" \
    | sed '/```bash/{N; s/```bash\n/```python\n!/}' \
    | sed '/```cpp/{N; s/```cpp\n\/\/ /```python\n%%writefile /}' \
    | sed '/```cmake/{N; s/```cmake\n/```python\n%%writefile CMakeLists.txt\n/}' \
    | jupytext --from md --to notebook -k python3 -o "${out%%.md}.ipynb"
done
