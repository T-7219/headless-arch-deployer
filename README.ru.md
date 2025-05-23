# Headless Arch Deployer

![Лицензия GitHub](https://img.shields.io/badge/license-MIT-blue.svg)
![Arch Linux](https://img.shields.io/badge/Arch_Linux-Latest-1793D1?logo=arch-linux&logoColor=white)
![Shell Script](https://img.shields.io/badge/Shell_Script-Bash-4EAA25?logo=gnu-bash&logoColor=white)

Надежный интерактивный скрипт для развертывания минималистичной установки Arch Linux с файловой системой BTRFS и правильной структурой подтомов. Скрипт автоматизирует весь процесс установки, сохраняя гибкость благодаря интерактивным параметрам конфигурации. Разработан специально для работы с режимом загрузки UEFI.

## 🚀 Возможности

- **Оптимизированная установка**: Полностью автоматизированная настройка Arch Linux из live-окружения
- **Оптимизация файловой системы**: BTRFS с оптимальной структурой подтомов (@, @home, @var, @snapshots)
- **Требуется UEFI**: Оптимизирован специально для систем с UEFI
- **Гибкость хранилища**: Интерактивный выбор диска с подтверждениями безопасности
- **Готовность к работе в сети**: Настройка DHCP и опциональная установка SSH-сервера
- **Удобство использования**: Интерактивные подсказки с разумными значениями по умолчанию
- **Улучшенная безопасность**: Правильное создание пользователя с привилегиями sudo
- **Обслуживание системы**: Автоматическая оптимизация зеркал с помощью reflector
- **Настройка производительности**: Сжатие BTRFS с опциями zstd и noatime

## 🔧 Использование

1. Загрузитесь в live-окружение Arch Linux в режиме UEFI
2. Скачайте скрипт:
```bash
curl -LO https://github.com/T-7219/headless-arch-deployer/raw/main/archinstall.sh
```

3. Сделайте его исполняемым:
```bash
chmod +x archinstall.sh
```

4. Запустите скрипт:
```bash
./archinstall.sh
```

5. Следуйте интерактивным подсказкам для настройки вашей установки

## ⚙️ Параметры конфигурации

- Выбор целевого диска
- Настройки часового пояса и локали
- Настройка имени хоста
- Настройка имени пользователя и пароля
- Включение SSH-сервера
- Установка дополнительных пакетов

## 🛠️ Технические детали

Скрипт реализует комплексный процесс установки:
- Проверка системных требований
- Подготовка хранилища с схемой разделов, совместимой с UEFI
- Создание подтомов BTRFS с сжатием
- Установка базовой системы с выбранными пакетами
- Настройка системы, включая локализацию и сеть
- Установка и оптимизация загрузчика для BTRFS
- Настройка пользователя и безопасности

## 🔒 Соображения безопасности

- Доступ Root через SSH включен по умолчанию для первоначальной настройки (может быть отключен вручную)
- Строгая проверка паролей с подтверждением
- Правильные привилегии пользователя через группу wheel

## 🤝 Содействие разработке

Вклады приветствуются! Не стесняйтесь отправлять Pull Request.

## 📝 Лицензия

Этот проект лицензирован под лицензией MIT - см. файл LICENSE для получения подробной информации.

---

Разработано с ❤️ для энтузиастов Arch Linux, предпочитающих минималистичные headless-установки.
