#!/usr/bin/env bash
# Runs an image's mongod on an emulated CPU without AVX (QEMU user mode, Westmere:
# SSE4.2, no AVX, like the Celeron J4125) and does a replica-set init, a write, an
# index build and a server-side JavaScript query (mozjs). An AVX instruction on
# these paths kills mongod with SIGILL; the script then exits with mongod's code (132).
# Needs a static qemu-x86_64 on the host (Ubuntu: qemu-user). Usage: test-no-avx.sh <image>
set -euo pipefail

image=$1
qemu=$(command -v qemu-x86_64-static || command -v qemu-x86_64)
name=mongo-no-avx-test
mongod=$(docker run --rm --entrypoint sh "$image" -c 'command -v mongod')

docker rm -f "$name" >/dev/null 2>&1 || true
trap 'docker logs "$name" 2>&1 | tail -30; docker rm -f "$name" >/dev/null' EXIT
# No core dumps: QEMU writing one for a SIGILL took minutes.
docker run -d --name "$name" --ulimit core=0 -v "$qemu:/qemu:ro" --entrypoint /qemu "$image" \
  -cpu Westmere "$mongod" --bind_ip_all --replSet rs0 >/dev/null

exit_if_dead() {
  if [[ $(docker inspect -f '{{.State.Running}}' "$name") != true ]]; then
    rc=$(docker inspect -f '{{.State.ExitCode}}' "$name")
    echo "mongod exited with code $rc"
    exit "$rc"
  fi
}

# Emulation is slow; give mongod up to 5 minutes to start.
for _ in $(seq 60); do
  exit_if_dead
  docker exec "$name" mongosh --quiet --eval 'db.runCommand({ping: 1}).ok' 2>/dev/null | grep -qx 1 && break
  sleep 5
done
sleep 2
exit_if_dead

docker exec "$name" mongosh --quiet --eval '
  rs.initiate();
  while (!db.hello().isWritablePrimary) sleep(500);
  const t = db.getSiblingDB("smoke").t;
  t.insertOne({a: 1, s: "x".repeat(100000)});
  t.createIndex({a: 1});
  if (t.find({$where: "this.a === 1"}).count() !== 1) throw new Error("query failed");
  print("ok");
' | grep -x ok
echo "mongod works without AVX"
