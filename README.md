# Cuefold CLI

Public distribution repository for the **Cuefold CLI**.

## What lives here

- GitHub Releases for cross-platform `cuefold` binaries
- SHA256 checksum files for release verification
- The `install.sh` bootstrap script for one-line installs

## Source code

The CLI source code lives in [`cuefold/webhooks`](https://github.com/cuefold/webhooks), primarily under [`cmd/cuefold/`](https://github.com/cuefold/webhooks/tree/main/cmd/cuefold).

Release automation is triggered from `cli/vX.Y.Z` tags in `cuefold/webhooks` and publishes public `vX.Y.Z` releases to this repository.

## Installing cuefold

Until `install.sh` is added, download the latest asset from the [Releases](https://github.com/cuefold/cli/releases) page and place the `cuefold` binary on your `PATH`.
