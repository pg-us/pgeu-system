#!/bin/bash
# Pod and containers are up.
. "$(dirname "$0")/lib.sh"
echo "20-pod"

check "pod $POD exists" podman pod exists "$POD"
check "pod $POD is running" sh -c "podman pod inspect $POD --format '{{.State}}' | grep -qi running"

for c in "$DB" "$APP"; do
    if [ "$(podman inspect --format '{{.State.Running}}' "$c" 2>/dev/null)" = "true" ]; then
        ok "container $c running"
    else
        fail "container $c running"
    fi
done

# Rootless mapping: the app process must own the bind-mounted tree (container
# root == host user in default rootless mode), or edits/migrations break.
uid_proc="$(podman exec "$APP" id -u 2>/dev/null)"
uid_tree="$(podman exec "$APP" stat -c %u /app/manage.py 2>/dev/null)"
if [ -n "$uid_proc" ] && [ "$uid_proc" = "$uid_tree" ]; then
    ok "app process owns bind-mounted tree (uid $uid_proc)"
else
    fail "app process owns bind-mounted tree (proc=$uid_proc tree=$uid_tree)"
fi

check "port 8012 published on pod" sh -c "podman pod inspect $POD --format '{{.InfraConfig.PortBindings}}' | grep -q 8012"

finish
