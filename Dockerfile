# Service image. Repository code never runs here: every build/test command is sent to
# sibling containers of the acceptance image through the host Docker daemon.
# Ubuntu 24.04 gives the same git (2.43) and Python (3.12) as the acceptance image.
# Base images are pinned by digest so rebuilds use the exact same layers (TASK-007).
FROM docker:29.4.0-cli@sha256:2efe7c8e806b35050def6ba1ba0ddad67b521a0a6d37f4910b3d88f11b495d03 AS dockercli

FROM ubuntu:24.04@sha256:008173c23f95b170204355c12626cb5a965d779a7e1283b09e9cffbb1bf33ca3
ENV DEBIAN_FRONTEND=noninteractive PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PATH=/opt/venv/bin:$PATH
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv git ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m venv /opt/venv
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
WORKDIR /srv
COPY requirements.lock .
RUN pip install --no-cache-dir --no-deps --require-hashes -r requirements.lock
COPY app ./app
# root is required to use the Docker socket and to hand workspaces to UID 65534
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=10s --start-period=10s CMD python3 -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=8).status == 200 else 1)"
CMD ["uvicorn", "app.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--timeout-keep-alive", "650", "--no-server-header"]
