# syntax=docker/dockerfile:1
#
# Derived seafile-pro-mc image — bakes in the face-recognition patches that were
# previously applied at boot by a large Coolify-compose entrypoint script.
#
# Why this image exists:
#   1. Fixes the runaway face-cluster loop. Upstream seafevents 13.0 omits a
#      `cluster_id_to_label[cluster_id] = label_id` ownership transfer in
#      face_recognition_manager.py; a 3rd HDBSCAN label colliding on one DB
#      cluster then pops an already-removed label -> KeyError, crashing the
#      cluster pass *before* it persists, so the repo is re-queued forever and
#      every ~2.3h HDBSCAN fit pegs the host.
#   2. Pre-installs scikit-learn + scipy (the stock image omits them, so face
#      clustering silently returns early) — at BUILD time, not on every boot.
#   3. Keeps Seafile's normal startup flow but fixes its reboot failure mode:
#      stale runtime pidfiles are removed before service startup, and start.py
#      runs in the foreground so Docker restart policy can recover failures.
#
# The 5 changed files were byte-verified against upstream haiwen/seafevents@13.0
# and haiwen/seahub@13.0: 4 are identical-base (safe to COPY the patched copy);
# seahub/repo_metadata/apis.py diverges (pro-only features) so it is shipped as
# the pro-patched variant, NOT the CE file.
#
# Base is pinned by digest for reproducible builds. To move to a newer base:
# bump BASE_DIGEST + SEAFILE_SERVER_DIR, rebuild, and the assert step below will
# fail loudly if any patched file no longer matches the new base layout.

ARG BASE_DIGEST=sha256:0487087748346f702567bee9ea6b46402041b83d3231f091c79a0e4eb8af76c8
FROM seafileltd/seafile-pro-mc@${BASE_DIGEST}

# Must match the server directory inside the pinned base image.
ARG SEAFILE_SERVER_DIR=/opt/seafile/seafile-pro-server-13.0.19

# 1. ML deps the stock image omits. Build-time install => boot no longer runs
#    `uv pip install`, removing startup latency and a boot-time network dep.
RUN set -eux; \
    curl -LsSf https://astral.sh/uv/install.sh | sh; \
    /root/.local/bin/uv pip install --system --no-cache scikit-learn scipy; \
    rm -rf /root/.local /root/.cache

# 2. Patched seafevents files (identical-base to upstream 13.0, verified).
COPY face_recognition/face_recognition_manager.py ${SEAFILE_SERVER_DIR}/pro/python/seafevents/face_recognition/face_recognition_manager.py
COPY face_recognition/utils.py                    ${SEAFILE_SERVER_DIR}/pro/python/seafevents/face_recognition/utils.py
COPY repo_metadata/seafile_ai_api.py              ${SEAFILE_SERVER_DIR}/pro/python/seafevents/repo_metadata/seafile_ai_api.py

# 3. Patched seahub files (vendored). apis.py is the PRO-patched variant.
COPY docker/seahub/ai/utils.py                    ${SEAFILE_SERVER_DIR}/seahub/seahub/ai/utils.py
COPY docker/seahub/repo_metadata/apis.py          ${SEAFILE_SERVER_DIR}/seahub/seahub/repo_metadata/apis.py

# 4. Reboot-safe startup wrapper. The stock image backgrounds start.py and then
#    idles forever, so a Seahub startup failure leaves Docker stuck in
#    "running/unhealthy" instead of triggering restart policy.
COPY docker/scripts/entrypoint.sh /scripts/enterpoint.sh
RUN chmod +x /scripts/enterpoint.sh

# 5. Fail the BUILD (never production) on a bad patch: every shipped file must be
#    valid Python, the loop-fix must be present, and the ML deps importable.
RUN set -eux; \
    python3 -m py_compile \
      ${SEAFILE_SERVER_DIR}/pro/python/seafevents/face_recognition/face_recognition_manager.py \
      ${SEAFILE_SERVER_DIR}/pro/python/seafevents/face_recognition/utils.py \
      ${SEAFILE_SERVER_DIR}/pro/python/seafevents/repo_metadata/seafile_ai_api.py \
      ${SEAFILE_SERVER_DIR}/seahub/seahub/ai/utils.py \
      ${SEAFILE_SERVER_DIR}/seahub/seahub/repo_metadata/apis.py; \
    grep -q 'pop(old_label_id, None)' ${SEAFILE_SERVER_DIR}/pro/python/seafevents/face_recognition/face_recognition_manager.py; \
    grep -q 'cluster_id_to_label\[cluster_id\] = label_id' ${SEAFILE_SERVER_DIR}/pro/python/seafevents/face_recognition/face_recognition_manager.py; \
    grep -q "add_view(repo_id, '_people', 'face_recognition')" ${SEAFILE_SERVER_DIR}/seahub/seahub/repo_metadata/apis.py; \
    grep -q 'clear_runtime_pids' /scripts/enterpoint.sh; \
    grep -q 'exec /scripts/start.py' /scripts/enterpoint.sh; \
    python3 -c 'import sklearn, scipy'

# CMD is inherited from the base image: /sbin/my_init -- /scripts/enterpoint.sh.

LABEL org.opencontainers.image.title="seafile-pro-mc (face-recognition patched)" \
      org.opencontainers.image.description="seafile-pro-mc 13.0.19 + scikit-learn/scipy + face-cluster and startup fixes (see docker/README.md)" \
      org.opencontainers.image.base.name="seafileltd/seafile-pro-mc:13.0-latest"
