#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
services_dir="$HOME/Library/Services"

/bin/mkdir -p "$services_dir"

for name in 拷贝路径 隐藏已选项目 取消隐藏文件夹内项目; do
  /usr/bin/ditto --rsrc --extattr --acl \
    "$project_dir/Workflows/$name.workflow" \
    "$services_dir/$name.workflow"
done

service_modes='{ presentation_modes = { ContextMenu = 1; FinderPreview = 1; ServicesMenu = 1; TouchBar = 1; }; }'
for name in 拷贝路径 隐藏已选项目 取消隐藏文件夹内项目; do
  /usr/bin/defaults write pbs NSServicesStatus -dict-add \
    "\"(null) - $name - runWorkflowAsService\"" \
    "$service_modes"
done

/usr/bin/killall pbs 2>/dev/null || true
/usr/bin/killall Finder 2>/dev/null || true

echo "超级右键的三个 Finder 快速操作已安装。"
