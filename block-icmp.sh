#!/bin/bash
set -e

echo "=== Блокировка всех ICMP запросов (UFW) ==="

if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите от root (sudo)"
   exit 1
fi

# Бэкап
BACKUP="/etc/ufw/before.rules.bak.$(date +%Y%m%d_%H%M%S)"
cp /etc/ufw/before.rules "$BACKUP"
echo "✅ Бэкап создан: $BACKUP"

# Удаляем все старые ICMP правила
sed -i '/ufw-before-input.*icmp.*-j /d' /etc/ufw/before.rules
sed -i '/ufw-before-forward.*icmp.*-j /d' /etc/ufw/before.rules

# Добавляем чистые DROP правила в нужные блоки
sed -i '/# ok icmp codes for INPUT/a\
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j DROP\
-A ufw-before-input -p icmp --icmp-type time-exceeded -j DROP\
-A ufw-before-input -p icmp --icmp-type parameter-problem -j DROP\
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP\
-A ufw-before-input -p icmp --icmp-type source-quench -j DROP' /etc/ufw/before.rules

sed -i '/# ok icmp code for FORWARD/a\
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j DROP\
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j DROP\
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j DROP\
-A ufw-before-forward -p icmp --icmp-type echo-request -j DROP' /etc/ufw/before.rules

echo "✅ Чистые DROP правила добавлены."

# Перезапускаем UFW без вопросов
echo "🔄 Перезапускаем UFW..."
echo "y" | ufw disable > /dev/null 2>&1
ufw --force enable

echo "🎉 Готово! ICMP полностью заблокирован."
echo "   Бэкап: $BACKUP"

# Проверка
echo "Текущие ICMP правила:"
grep -E "icmp.*(DROP|ACCEPT)" /etc/ufw/before.rules || echo "Правила не найдены"
