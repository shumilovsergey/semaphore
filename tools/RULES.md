# Rules

1. Все сервисы запускаются от пользователя `service_ansible`
2. Переменная порта называется `<servicename>_port` — никогда просто `port`
3. После создания рабочей директории сервиса — всегда устанавливать рекурсивное владение (`recurse: yes`) на `service_ansible`
4. Роли, которые нельзя запускать на нескольких хостах одновременно (например `prometheus`), должны начинаться с guard-таска:
   ```yaml
   - name: Guard — only one host allowed
     fail:
       msg: "This role must target exactly one host, got: {{ ansible_play_hosts | join(', ') }}"
     when: ansible_play_hosts | length > 1
     run_once: true
   ```
