#!/bin/bash
set -e

echo "=== Блокировка всех ICMP запросов (UFW) ==="

if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите от root (sudo)"
   exit 1
fi

# Создаём бэкап
BACKUP="/etc/ufw/before.rules.bak.$(date +%Y%m%d_%H%M%S)"
cp /etc/ufw/before.rules "$BACKUP"
echo "✅ Бэкап создан: $BACKUP"

# === Заменяем блок INPUT ===
sed -i '/# ok icmp codes for INPUT/,/^# ok icmp code for FORWARD/{
  /# ok icmp codes for INPUT/a\
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP\
-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP\
-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP\
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP\
-A ufw-before-input -p icmp --icmp-type source-quench -j DROP
  /# ok icmp codes for INPUT/,/^# ok icmp code for FORWARD/d
}' /etc/ufw/before.rules

# === Заменяем блок FORWARD ===
sed -i '/# ok icmp code for FORWARD/,/^# ok icmp codes for/{
  /# ok icmp code for FORWARD/a\
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j DROP\
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j DROP\
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j DROP\
-A ufw-before-forward -p icmp --icmp-type echo-request -j DROP
  /# ok icmp code for FORWARD/,/^# ok icmp codes for/d
}' /etc/ufw/before.rules

echo "✅ Правила ICMP DROP успешно применены."

# Перезапускаем UFW
echo "🔄 Перезапускаем UFW..."
ufw disable && ufw enable

echo "🎉 Готово! ICMP полностью заблокирован."
echo "   Бэкап: $BACKUP"
