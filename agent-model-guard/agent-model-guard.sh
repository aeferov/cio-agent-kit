#!/usr/bin/env bash
# agent-model-guard.sh — PreToolUse-хук (matcher: Agent).
#
# Класс ошибки: субагент без явной модели НАСЛЕДУЕТ модель родителя. Замер на живой
# работе: из 71 запуска только 2 имели явную модель, остальные 69 ушли на модели
# родителя — около 6,5 млн токенов старшей модели там, где механике хватило бы дешёвой.
#
# Контракт: у catch-all субагента (general-purpose / claude) модель указывается ЯВНО.
# Хук НЕ выбирает модель за вас — он запрещает молчаливое наследование.
# Форк (subagent_type: fork) исключён: он по определению наследует родителя.
set -u
payload=$(cat)
read -r stype model <<<"$(printf '%s' "$payload" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin).get('tool_input', {}) or {}
except Exception:
    d = {}
print((d.get('subagent_type') or '-'), (d.get('model') or '-'))
" 2>/dev/null)"

case "$stype" in
  general-purpose|claude) ;;   # catch-all: наследуют родителя — требуем явности
  *) exit 0 ;;                 # fork и типы со своим определением модели — мимо
esac
[ "$model" != "-" ] && exit 0

echo "agent-model-guard: субагент '$stype' запущен без явной model — он унаследует модель родителя (дорогую). Укажи model осознанно: 'sonnet' для механики (чтение корпусов, выборка, парсинг, заполнение схемы), 'opus'/'fable' — только когда нужна глубина суждения. Молчаливое наследование дорого обходится: замер показал 69 таких запусков из 71." >&2
exit 2
