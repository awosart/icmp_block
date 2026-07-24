#!/bin/bash
set -e

echo "=== Блокировка всех ICMP запросов (UFW) ==="

if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите от root (sudo)"
   exit 1
fi

BACKUP="/etc/ufw/before.rules.bak.$(date +%Y%m%d_%H%M%S)"
cp /etc/ufw/before.rules "$BACKUP"
echo "✅ Бэкап создан: $BACKUP"

add_rules() {
    local section="$1"
    local chain="$2"
    if grep -q "echo-request -j DROP" /etc/ufw/before.rules; then
        echo "   Правила уже существуют."
        return
    fi
    sed -i "/# $section/a\\
-A $chain -p icmp --icmp-type destination-unreachable -j DROP\\
-A $chain -p icmp --icmp-type time-exceeded -j DROP\\
-A $chain -p icmp --icmp-type parameter-problem -j DROP\\
-A $chain -p icmp --icmp-type echo-request -j DROP\\
-A $chain -p icmp --icmp-type source-quench -j DROP" /etc/ufw/before.rules
}

add_rules "ok icmp codes for INPUT" "ufw-before-input"
add_rules "ok icmp codes for FORWARD" "ufw-before-forward"

echo "🔄 Перезапускаем UFW..."
ufw disable && ufw enable

echo "🎉 Готово! ICMP заблокирован."
echo "   Бэкап: $BACKUP"
