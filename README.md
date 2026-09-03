# lightWubi86

`lightWubi86` 是一套 Rime 五笔 86 方案。方案选单显示为 **五笔字型**。

本仓库只发布 schema、Lua 和样式。完整词库在本地生成，不随仓库分发。

## 安装

1. 把 `rime/` 下的方案文件复制到 Rime 用户目录（macOS 鼠须管一般为 `~/Library/Rime`）。
2. 把 `light_wubi86` 写入你的 `default.custom.yaml` 的 `schema_list`。可参考 `rime/default.custom.light_wubi86.example.yaml`，不要整文件覆盖已有配置。
3. 重新部署。

完整词库需要在本机生成后再部署，生成物默认不提交。

## 方案

- `light_wubi86`：日常方案，选单名「五笔字型」。
- `light_wubi86_pinyin`：拼音反查依赖，不上选单。`z` + 拼音。
- `light_wubi86_phrases`：词组表依赖，不上选单。

状态菜单只保留：中/西文、全/半角、中/英文标点、简/繁、常用字/GBK/GB18030。

## 常用快捷键

- `Ctrl+M`：常用字 ↔ GBK（若当前是 GB18030，先回到常用字）
- `Ctrl+Shift+M`：切换到 GB18030
- `Ctrl+J`：简繁
- 单击右 Shift：中英文切换
- `date` / `time` / `week`：日期、时间、星期

## 目录

```text
rime/     方案、Lua、样式
```
