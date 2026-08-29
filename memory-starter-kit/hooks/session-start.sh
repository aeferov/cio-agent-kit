#!/usr/bin/env bash
# Прогрев сессии: подсовывает агенту последнюю заметку-передачу и сверяет,
# не было ли чужих коммитов после неё.
#
# Ставится на событие SessionStart. Всё, что скрипт печатает в stdout,
# попадает агенту в контекст ДО первой реплики — он входит в работу
# уже зная, чем закончили в прошлый раз.
set -u

MEM_ROOT="${AGENT_MEMORY_ROOT:-$HOME/.claude/projects}"

# Каталог памяти проекта: имя = абсолютный путь, где каждый не-алфанумерик → дефис.
slug() { pwd -P | sed 's/[^a-zA-Z0-9]/-/g'; }
MEM="$MEM_ROOT/$(slug)/memory"

[ -d "$MEM" ] || exit 0        # проекта без памяти касаться нечего

if [ -f "$MEM/MEMORY.md" ]; then
  echo "— Память проекта (индекс):"
  sed 's/^/  /' "$MEM/MEMORY.md"
fi

last_handoff=$(ls -t "$MEM"/*handoff*.md 2>/dev/null | sed -n 1p)
[ -n "$last_handoff" ] || exit 0
echo "— Последняя передача дел: $(basename "$last_handoff")"

# Сверка: были ли чужие коммиты после хэндоффа.
# Смысл: иначе агент начнёт работать по устаревшей картине и предложит
# сделать то, что другая сессия уже сделала.
field() { sed -n "s/^$1: *//p" "$2" | sed -n 1p | tr -d '[]" '; }
href=$(field headRef "$last_handoff")
head_now=$(git rev-parse --short HEAD 2>/dev/null || true)

if [ -n "$href" ] && [ -n "$head_now" ] && [ "$href" != "$head_now" ]; then
  n=$(git rev-list --count "$href..HEAD" 2>/dev/null || echo '?')
  echo "  ⚠ HEAD сдвинулся: в передаче $href, сейчас $head_now ($n коммит.)."
  echo "    Это работа других сессий или другой машины — прочитай дельту"
  echo "    ДО утверждений о состоянии:  git log --oneline $href..HEAD"
fi

# Незакрытые сессии: транскрипт есть, отметки о сдаче дел нет.
orphans=0
for t in "$MEM_ROOT/$(slug)"/*.jsonl; do
  [ -e "$t" ] || continue
  [ -f "${t%.jsonl}.closed" ] || orphans=$((orphans + 1))
done
[ "$orphans" -gt 0 ] && echo "  ⚠ Сессий без записи о сдаче дел: $orphans — возможно, оборвались."
exit 0
