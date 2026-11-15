# compose-stack.service

Installed on LXC 103 as `/etc/systemd/system/compose-stack.service` (enabled).

**Problem:** at boot, dockerd starts every container with a restart policy at the same time. Containers using `network_mode: service:gluetun` sometimes start before Gluetun is up and fail with `cannot join network namespace of a non running container`. `restart: unless-stopped` does not retry that failure, so a few apps stayed down after every reboot.

**Fix:** a oneshot unit runs `docker compose up -d` ~20 s after Docker starts. Compose honours `depends_on: condition: service_healthy`, waits for Gluetun's health check and starts whatever is still stopped. Running containers are left alone.

Verified with a full Proxmox host reboot: all containers came back without intervention.
