# Rime 方案

把本目录中的方案文件复制到 Rime 用户目录后重新部署。macOS 鼠须管一般为：

```text
~/Library/Rime
```

- `light_wubi86`：日常方案，方案选单显示 **五笔字型**。
- `light_wubi86_pinyin`：拼音反查依赖，不要写进方案选单。
- `light_wubi86_phrases`：词组表依赖，不要写进方案选单。

启用方案时，把 `light_wubi86` 合并进已有的 `default.custom.yaml`，不要整文件覆盖。示例见 `default.custom.light_wubi86.example.yaml`。

完整词库不在本目录中。需要完整词库时，在本机生成后再部署。

## 状态快捷键

- `Ctrl+M`：常用字 ↔ GBK
- `Ctrl+Shift+M`：GB18030
- `Ctrl+J`：简繁

见 `lua/status_hotkeys.lua`。
