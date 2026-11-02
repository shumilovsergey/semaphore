FROM python:3.12-slim

RUN pip install --no-cache-dir 'ansible-core>=2.17,<2.20' 'ruamel.yaml>=0.18,<0.19'

WORKDIR /workspace
COPY entrypoint.sh /usr/local/bin/inventory-entrypoint
RUN chmod +x /usr/local/bin/inventory-entrypoint
ENTRYPOINT ["/usr/local/bin/inventory-entrypoint"]
