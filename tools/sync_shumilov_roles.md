[<- Назад ](../README.md)

## Описание sync_shumilov_roles.sh

Скрипт предназначен для синхронизации публичных ролей из [репозитория Сергея Шумилова](https://github.com/shumilovsergey/semaphore)

При запуске из ВАШЕГО репозитория скрипт:

1. Находит корень ВАШЕГО текущего git-репозитория.
2. Создаёт (или переписывает) каталог shumilov_roles.
3. Скачивает только содержимое каталога roles из МОЕГО публичного репозитория.
4. Копирует роли в shumilov_roles.
5. Не изменяет и не затрагивает ВАШ каталог roles.

Таким образом, в ВАШЕМ проекте всегда доступна актуальная копия публичных ролей. 


## Быстрый запуск

Перейдите в ВАШ репозиторий и запустите

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/tools/sync_shumilov_roles.sh | sudo bash
```