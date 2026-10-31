#!/bin/bash
set -e

# Скрывает сервер от ping: режет только входящий ICMP echo-request (IPv4 и IPv6).
# Остальной ICMP (destination-unreachable, time-exceeded, parameter-problem)
# остаётся открытым: без "fragmentation needed" ломается Path MTU Discovery
# и большие пакеты начинают теряться.
# Повторный запуск безопасен, в том числе после старой версии, резавшей весь ICMP.

echo "=== Блокировка ping (ICMP echo-request) в UFW ==="

if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите от root (sudo)"
   exit 1
fi

RULES="/etc/ufw/before.rules"
RULES6="/etc/ufw/before6.rules"

if [[ ! -f "$RULES" ]] \
        || ! grep -q '# ok icmp codes for INPUT' "$RULES" \
        || ! grep -q '# ok icmp code for FORWARD' "$RULES"; then
    echo "❌ В $RULES нет стандартных секций ICMP от UFW — ничего не меняю."
    exit 1
fi

# Бэкап
STAMP="$(date +%Y%m%d_%H%M%S)"
cp "$RULES" "$RULES.bak.$STAMP"
echo "✅ Бэкап создан: $RULES.bak.$STAMP"
if [[ -f "$RULES6" ]]; then
    cp "$RULES6" "$RULES6.bak.$STAMP"
    echo "✅ Бэкап создан: $RULES6.bak.$STAMP"
fi

# IPv4: убираем все ICMP-правила этих цепочек (в том числе DROP от старой версии)
# и ставим стандартный набор UFW, где отличается только echo-request.
sed -i '/^-A ufw-before-input -p icmp /d; /^-A ufw-before-forward -p icmp /d' "$RULES"

sed -i '/# ok icmp codes for INPUT/a\
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT\
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT\
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT\
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP' "$RULES"

sed -i '/# ok icmp code for FORWARD/a\
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j ACCEPT\
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j ACCEPT\
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j ACCEPT\
-A ufw-before-forward -p icmp --icmp-type echo-request -j DROP' "$RULES"

echo "✅ IPv4: ping закрыт, служебный ICMP открыт."

# IPv6: только echo-request; служебный ICMPv6 (в том числе neighbor discovery) не трогаем.
if [[ -f "$RULES6" ]]; then
    sed -i -E 's/^(-A ufw6-before-(input|forward) -p icmpv6 --icmpv6-type echo-request -j) ACCEPT$/\1 DROP/' "$RULES6"
    echo "✅ IPv6: ping закрыт."
fi

# Перечитываем правила. Выключенный UFW не включаем: без разрешённого
# SSH-порта это отрезало бы доступ к серверу.
if ufw status 2>/dev/null | grep -q '^Status: active'; then
    ufw reload >/dev/null
    echo "🔄 UFW перечитал правила."
else
    echo "ℹ️  UFW выключен: правила заработают после 'ufw enable' (сначала разрешите SSH-порт)."
fi

echo "🎉 Готово! Сервер не отвечает на ping."
echo "   Бэкап: $RULES.bak.$STAMP"

# Проверка
echo "Текущие ICMP правила:"
grep -hE '^-A ufw6?-before-(input|forward) -p icmp' "$RULES" "$RULES6" 2>/dev/null \
    | grep -E 'echo-request|destination-unreachable|time-exceeded|parameter-problem' \
    || echo "Правила не найдены"
