#!/usr/bin/env bash
# Маркер штатного завершения сессии.
#
# Ставится на SessionEnd. Смысл: событие НЕ срабатывает при крахе, перезагрузке
# или убийстве процесса. Поэтому «свежий транскрипт без маркера» — надёжный
# признак оборванной сессии, работу которой никто не записал.
set -u

MEM_ROOT="${AGENT_MEMORY_ROOT:-$HOME/.claude/projects}"
slug() { pwd -P | sed 's/[^a-zA-Z0-9]/-/g'; }
DIR="$MEM_ROOT/$(slug)"
[ -d "$DIR" ] || exit 0

last=$(ls -t "$DIR"/*.jsonl 2>/dev/null | sed -n 1p)
[ -n "$last" ] && : > "${last%.jsonl}.closed"
exit 0
