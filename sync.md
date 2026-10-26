# Sync blocked: upstream 9024fb6 + main 5e0f5ab

Nothing was published: `main` and the releases stay as they were. [Run log](https://github.com/sylvarg/tinycast-history/actions/runs/40283441543).

Failed checks: `upstream-build-broken`

```
Upstream 9024fb6 does not build on its own either with Xcode 26.6, so this is upstream's
break, not this edition's: the sync waits for upstream to fix it.

/Users/runner/work/tinycast-history/tinycast-history/Tinycast/Features/HotKeys/Service/HyperKeyTap.swift:59:36: error: argument passed to call that takes no arguments
```

<!-- cause: upstream-build-broken 7443717fc859 -->
