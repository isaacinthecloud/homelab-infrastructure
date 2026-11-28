#!/bin/bash
# Usage: ./homepage/set-key.sh UNIFI_KEY   -> sets HOMEPAGE_VAR_UNIFI_KEY in /root/docker/homepage.env
set -euo pipefail
name="HOMEPAGE_VAR_${1:?usage: set-key.sh NAME   e.g. set-key.sh UNIFI_KEY}"
f=/root/docker/homepage.env
grep -q "^$name=" "$f" || { echo "No line $name in $f"; exit 1; }
read -rp "Paste value for $name, then Enter: " v
V="$v" N="$name" python3 - <<"PY"
import os, re, sys
v = os.environ["V"].strip(); n = os.environ["N"]
if not v or not v.isprintable():
    sys.exit("Bad value (empty or contains control characters). Nothing saved.")
f = "/root/docker/homepage.env"; s = open(f).read()
open(f, "w").write(re.sub(r"(?m)^%s=.*$" % re.escape(n), lambda m: n + "=" + v, s))
print("Saved %s (length %d)" % (n, len(v)))
PY
cd /root/docker && docker compose up -d --force-recreate homepage >/dev/null 2>&1 && echo "Homepage restarted."
