# macOS Rime 样式目标

当前使用鼠须管内置 **`native`（系统配色）**，便于对照官方维护者首推的 macOS 体验。

## 当前主题

- 文件：`rime/squirrel.custom.yaml`
- 浅色 / 深色：`style/color_scheme: native` + `style/color_scheme_dark: native`（**两者都要设**才有暗色）
- 归档 Dracula：`rime/style/dracula.squirrel.custom.yaml.example`

## 为什么用 native

`native` 不写 hex 色，走 AppKit 语义色（窗口背景、标签色、选中背景等），选中高亮跟**系统强调色 accent** 走；Squirrel 1.1+ 会随**当前 App 的浅/深界面**切换（见 PR #848）。

## 已采纳的贡献者 / 官方建议

| 建议来源 | 采纳 | 说明 |
|----------|------|------|
| LEO #449 / #934：`color_scheme_dark: native` | ✅ | 启用明暗自动切换 |
| 官方 `data/squirrel.yaml`：`border -2`、`memorize_size` | ✅ | 原生内边距、贴边宽度稳定 |
| 官方：`corner_radius 7`、`hilited_corner_radius 0` | ✅ | native 默认圆角策略 |
| 官方：`shadow_size 0`、`mutual_exclusive false` | ✅ | 不做额外阴影；语义色自然混合 |
| Squirrel 1.x：`candidate_format`、`inline_preedit` | ✅ | 新格式 + 行内预编辑 |
| 横排 `linear` | ✅ | 更接近现代 macOS 拼音候选栏（官方默认是 stacked） |
| `translucency` + flat-light/dark（LEO #589） | ❌ 暂不 | 与 native 语义色是两条路线；先试 pure native |
| `display_p3` 自定义色板 | ❌ 不适用 | native 不用 preset hex |
| SF Pro 序号字体 | ❌ 暂不 | native 用系统等宽数字标签；中文仍 PingFang SC |

## 试用与切换

1. 部署后切换系统外观或打开浅/深色 App，看候选窗是否跟随。
2. 系统设置 → 外观 → 强调色，观察选中候选是否变化。
3. 若要恢复 Dracula：用 `dracula.squirrel.custom.yaml.example` 覆盖 `squirrel.custom.yaml` 后重新部署。

## 可选下一步（未启用）

- **毛玻璃**：LEO 在 #589 分享的 `flat-light` / `flat-dark`（见 Rime_collections），需 `translucency: true` + 低 alpha 底色，会离开 pure native。
- **可视化调参**：https://github.com/LEOYoon-Tsaw/Squirrel-Designer
