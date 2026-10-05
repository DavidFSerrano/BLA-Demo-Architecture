# syntax=docker/dockerfile:1

FROM python:3.13-slim@sha256:3dd7cc108ec1493442514f5c2a871af6af0ec31d768ff6e378a93340c3b3db5f

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends --only-upgrade libpcre2-8-0 \
    && rm -rf /var/lib/apt/lists/* \
    && python -m pip uninstall -y pip setuptools wheel urllib3 msgpack || true \
    && rm -rf /usr/local/lib/python3.13/site-packages/pip* \
              /usr/local/lib/python3.13/site-packages/setuptools* \
              /usr/local/lib/python3.13/site-packages/wheel* \
              /usr/local/lib/python3.13/site-packages/urllib3* \
              /usr/local/lib/python3.13/site-packages/msgpack* \
              /usr/local/bin/pip* \
    && groupadd --system --gid 65532 app \
    && useradd --system --uid 65532 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --chown=65532:65532 app.py /app/app.py

USER 65532:65532

EXPOSE 8080

ENTRYPOINT ["python", "-u", "/app/app.py"]
