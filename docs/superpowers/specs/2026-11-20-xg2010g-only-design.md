# XG2010G-only 设计摘要

- 基线：`netrivo/ImmortalWrt-for-Gemtek-brightspeed` 的 `9a70b25731`（2026-11-13）快照，不导入历史。
  该 fork 当时与 `naoki66/ImmortalWrt-for-Gemtek-brightspeed` 一致；2026-11-23 起直接同步 naoki66。
- 目标：只保留 `gemtek_xg2010g` 和 `gemtek_xg2010g-ubi` 两个 profile。
- 精简：删除 an7581 其他 9 个 profile、an7583/en7523 设备、其他机型 DTS/board 分支、`uboot-airoha`、非 XG2010G 配置和 feeds。
- 同步：`scripts/sync-brightspeed.sh` 用 `git merge-tree --merge-base=<BASE>` 做三点合并，再执行 `scripts/apply-xg2010g-trim.sh`。
- 追踪：GitHub issue #1。
