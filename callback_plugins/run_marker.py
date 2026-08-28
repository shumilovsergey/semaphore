# Одна строка в journald на каждый завершённый прогон — чтобы Alloy мог
# отобрать нужные плейбуки по имени, а Grafana строить по ним алерты.


import os
import syslog

from ansible.plugins.callback import CallbackBase


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = "notification"
    CALLBACK_NAME = "run_marker"
    CALLBACK_NEEDS_ENABLED = True

    MARKER = "ansible-run"

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.playbook = "unknown"

    def v2_playbook_on_start(self, playbook):
        # _file_name — приватный атрибут, но стабильный во всей ветке 2.x и
        # единственный способ узнать имя запущенного плейбука.
        name = getattr(playbook, "_file_name", "") or "unknown"
        self.playbook = os.path.splitext(os.path.basename(name))[0]

    def v2_playbook_on_stats(self, stats):
        bad = sorted(
            {h for h, n in stats.failures.items() if n}
            | {h for h, n in stats.dark.items() if n}
        )
        status = "failed" if bad else "ok"

        syslog.openlog(ident="ansible", facility=syslog.LOG_DAEMON)
        syslog.syslog(
            syslog.LOG_ERR if bad else syslog.LOG_INFO,
            "%s: playbook=%s status=%s hosts=%s"
            % (self.MARKER, self.playbook, status, ",".join(bad) or "-"),
        )
        syslog.closelog()
