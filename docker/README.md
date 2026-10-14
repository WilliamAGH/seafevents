# Patched `seafile-pro-mc` image

A thin derived image over `seafileltd/seafile-pro-mc:13.0.19`
that includes the face-recognition and startup patches plus strict UTF-8-first
text extraction for SeaSearch.

## What it changes vs the stock image

| File | Change | Why |
|------|--------|-----|
| `pro/python/seafevents/face_recognition/face_recognition_manager.py` | **Loop fix**: add the missing `cluster_id_to_label[cluster_id] = label_id` ownership transfer + guard the `pop`; plus HDBSCAN logging, `min_samples`, duplicate-label merge | Upstream 13.0 crashes the cluster pass with `KeyError` before it persists → repo re-queued forever → host CPU saturation |
| `pro/python/seafevents/face_recognition/utils.py` | cap `get_min_cluster_size` at 50; add `merge_duplicate_cluster_labels`; guard `save_cluster_face`; logging | 1% heuristic explodes on large libraries (162k vectors → 1625) |
| `pro/python/seafevents/repo_metadata/seafile_ai_api.py` | embeddings timeout 90→420s; trailing-slash URL fix | large libraries time out |
| `seahub/seahub/ai/utils.py` | AI request timeout 30→90s | — |
| `seahub/seahub/repo_metadata/apis.py` | register the `_people` metadata view on enable (PRO-patched variant) | — |
| (image) | pre-install `scikit-learn` + `scipy` at build time | stock image omits them → clustering silently no-ops |
| `/scripts/enterpoint.sh` | clear stale runtime pidfiles before startup; run `start.py` in the foreground | host reboot can preserve stale `/opt/seafile/pids/seahub.pid`; the stock entrypoint backgrounds startup and leaves Docker stuck `running/unhealthy` instead of triggering restart policy |
| `pro/python/seafevents/seasearch/utils/extract.py` | decode complete UTF-8 text before detecting legacy encodings | an ASCII prefix must not hide Unicode later in a text file |

`face_cluster.py` is intentionally **unchanged** — the old boot-patch's
`LOCK_TIMEOUT` bump silently no-op'd and the lock-refresh thread already keeps
long fits alive, so shipping it pristine matches proven production behavior.

## Source-of-truth & verification

The 4 seafevents files live at their real repo paths (clean `git diff` vs
`haiwen/seafevents@13.0`). `apis.py` is vendored under `docker/seahub/` as the
**pro-patched** file because the CE `apis.py` diverges (pro-only org/invisible-repo
features) — copying the CE file would strip them. The Dockerfile's final `RUN`
`py_compile`s every shipped Python file and asserts the loop-fix, startup guard,
and ML deps are present, so a bad patch or a base bump fails the **build**, not
production.

## Build / push

```bash
make test-indexing BASE_REGISTRY=dockerhub.haiku.host
make image-build REGISTRY=registry.haiku.host BASE_REGISTRY=dockerhub.haiku.host
make image-publish REGISTRY=registry.haiku.host BASE_REGISTRY=dockerhub.haiku.host
```

Run these targets from the repository root. They use the host's compute admission
and a shared image lock. Build and publish use committed Git archive inputs.
The test target runs the decoder boundary tests in the packaged Seafile runtime.

Publication writes `seafile-pro-mc` at the selected registry with three tags:
`<branch>-latest`, `<branch>-<version>`, and `<branch>-<version>-<short-sha>`.
The full source revision is recorded in the image label. The metadata file
reported by Make contains the published manifest digest.

Select the published image through the existing deployment control plane and
verify its revision and decoder behavior after deployment.
