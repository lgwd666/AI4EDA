#!/bin/bash
# 同步 docs 和 npc/vsrc 到共享盘 work

DOCS_SRC="/home/lgwd666/EDA/AI4EDA/AI4EDA-KIMI/docs/"
VSRC_SRC="/home/lgwd666/EDA/AI4EDA/AI4EDA-KIMI/ysyx-workbench/npc/vsrc/"
BACKUP_ROOT="/home/lgwd666/work/work/AI4EDA-backup"

mkdir -p "$BACKUP_ROOT/docs" "$BACKUP_ROOT/vsrc"

rsync -rlptD --delete "$DOCS_SRC" "$BACKUP_ROOT/docs/"
rsync -rlptD --delete "$VSRC_SRC" "$BACKUP_ROOT/vsrc/"
