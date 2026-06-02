This repository does not use a traditional source-package `debian/` tree yet.

The first implementation builds a binary runtime package with:

```bash
.xgc2/scripts/build_deb.sh --runtime-dir /path/to/extracted/runtime --output-dir debs
```

The generated package installs the PX4 runtime under the `install_prefix` from
`manifest/px4_runtime.yaml`.

