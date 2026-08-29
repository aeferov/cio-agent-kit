#!/usr/bin/env bash
# SessionStart-хук: подсунуть агенту записку от прошлой сессии и сверить её с репозиторием.
#
# Зачем: новая сессия стартует с нуля. Записка отвечает «на чём остановились», а сверка
# хеша — «не менялось ли что-то без меня». Второе важнее, чем кажется: если между сессиями
# были чужие коммиты, агент должен прочитать дельту ДО того, как начнёт работать по
# устаревшей картине.
set -uo pipefail

MEM_ROOT="${CC_MEM_ROOT:-$HOME/.claude/projects}"
# слаг проекта = абсолютный путь, где каждый не-алфанумерик заменён на дефис
slug="$(pwd -P | sed 's/[^A-Za-z0-9]/-/g')"
memdir="$MEM_ROOT/$slug/memory"
[ -d "$memdir" ] || exit 0

# самая свежая записка по имени файла (handoff_ГГГГ_ММ_ДД.md сортируется хронологически)
last="$(ls -1 "$memdir"/handoff_*.md 2>/dev/null | sort | sed -n '$p')"
[ -n "$last" ] || exit 0

echo "— записка прошлой сессии: $(basename "$last")"
sed -n 's/^description: *//p' "$last" | sed -n '1p'

# сверка состояния репозитория: что менялось с момента записи
ref="$(sed -n 's/^headRef: *//p' "$last" | sed -n '1p')"
if [ -n "$ref" ] && git rev-parse --git-dir >/dev/null 2>&1; then
  head_now="$(git rev-parse --short HEAD 2>/dev/null)"
  if [ -n "$head_now" ] && [ "$ref" != "$head_now" ]; then
    echo "⚠ HEAD сдвинулся с прошлой сессии: $ref → $head_now"
    echo "  Что изменилось:"
    git log --oneline "$ref..HEAD" 2>/dev/null | sed 's/^/    /'
  fi
fi
