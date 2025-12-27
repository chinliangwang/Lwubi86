# Lwubi86 依赖关系图

下面的图展示了仓库中主要 schema、dict、custom、lua 与外部依赖之间的关系，便于在 PR/文档中直观展示。

---

```mermaid
flowchart TB
  %% SUBGRAPHS
  subgraph Schemas
    W86["wubi86.schema.yaml"]
    WPY["wubi_pinyin.schema.yaml"]
    WTR["wubi_trad.schema.yaml"]
    PYS["pinyin_simp.schema.yaml"]
  end

  subgraph Dicts
    DW["wubi86.dict.yaml"]
    DP["pinyin_simp.dict.yaml"]
  end

  subgraph Customs
    CD["default.custom.yaml"]
    CW["wubi86.custom.yaml"]
    CWL["weasel.custom.yaml"]
  end

  subgraph LuaFiles
    R["rime.lua"]
    CM["lua/charset_mode.lua"]
    G2["lua/charset/gb2312.txt"]
    GK["lua/charset/gbk.txt"]
  end

  subgraph External["外部依赖 / 缺失项"]
    OPENCC["OpenCC (s2t.json)"]
    STROKE["stroke (external)"]
    PRISM_WP["prism: wubi_pinyin (未在仓库)"]
    PRISM_WT["prism: wubi_trad (未在仓库)"]
  end

  %% EDGES
  W86 -->|dictionary| DW
  W86 -->|depends on| PYS
  W86 -.->|reverse lookup uses| DP

  WPY -->|dictionary| DW
  WPY -->|depends on| PYS
  WPY -.->|reverse lookup uses| DP
  WPY -->|prism→| PRISM_WP

  WTR -->|dictionary| DW
  WTR -->|depends on| PYS
  WTR -->|simplifier→| OPENCC
  WTR -->|prism→| PRISM_WT

  PYS -->|dictionary| DP
  PYS -.->|reverse lookup→| STROKE

  CW -->|patch: engine/filters →| CM
  CW -->|charset/files →| G2
  R -->|require| CM
  CM -->|reads| G2
  CM -->|reads| GK
```

---

## 说明
- 虚线（-.->）表示逻辑引用或反查关系；实线（-->）表示文件/资源直接依赖或包含。
- `PRISM_*`、`OPENCC`、`STROKE` 是仓库引用但未在本仓库中发现的外部资源或表，建议在 PR 中标注并决定是否补齐。

## 验证清单（Acceptance）
1. 在 GitHub 上打开 `docs/dependency-mermaid.md`，确认 Mermaid 图能正确渲染且节点/连线与仓库当前状态一致。 
2. 在本地或 mermaid.live 粘贴上面的 mermaid 代码，确认无语法错误且布局清晰。

## 回滚方式
- 若需要回滚：删除分支 `docs/dependency-diagram` 或在合并后用 `git revert` 撤销相应 commit/PR。
