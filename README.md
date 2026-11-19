# mongodb-no-avx

MongoDB 8.0.x built from source without AVX, for CPUs such as the Intel Celeron J4125
in a Synology DS920+. The official images need AVX since MongoDB 5.0.

```
ghcr.io/ptrmoor/mongodb-no-avx:8.0        # newest 8.0.x
ghcr.io/ptrmoor/mongodb-no-avx:8.0.38     # one release
```

The image starts `mongod --bind_ip_all` and includes `mongosh` and the database tools.
It has no `docker-entrypoint.sh`, so `MONGO_INITDB_*` variables and
`/docker-entrypoint-initdb.d` do nothing.

## How it is built

`.github/workflows/build.yml` runs daily. When `mongodb/mongo` has a newer `r8.0.x` tag
than the published images, it builds that release with the `Dockerfile`, runs
`test-no-avx.sh` (mongod on a QEMU-emulated Westmere CPU, which has no AVX) and pushes
`:<version>` and `:8.0`. Before the build it checks that the official `mongo:8.0` dies
with SIGILL under the same test, so the test can detect AVX. A manual run rebuilds the
newest release.

The `Dockerfile` is taken from [rnsc/mongodb-without-avx](https://github.com/rnsc/mongodb-without-avx)
(GPL-3.0). If a new MongoDB release breaks its patches, the build or the test fails and
nothing is pushed.
