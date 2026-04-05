# Issue #95 需求规格说明书

## 1. 概述
- **Issue**: #95
- **标题**: test: 主会话顺序 spawn 验证
- **处理时间**: 2026-03-22

## 2. 需求分析

### 背景
验证主会话按顺序 spawn 四个阶段，每个阶段完成后自动继续下一阶段。

### 核心目标
确保 OpenClaw 的主会话能够：
1. 按顺序 spawn 四个阶段（Stage 1-4）
2. 每个阶段完成后自动触发下一阶段
3. 验证顺序执行的正确性

## 3. 功能点拆解

根据 Issue 描述提取功能点：

| 功能点 | 描述 |
|--------|------|
| Stage 1 | 初始阶段，读取 OPENCLAW.md |
| Stage 2 | 分析 Issue 需求 |
| Stage 3 | 创建目录和 SPEC.md |
| Stage 4 | 提交到分支并更新状态 |

### 阶段流转
```
Stage 1 → Stage 2 → Stage 3 → Stage 4 → 完成
```

每个阶段完成后自动触发下一阶段，无需手动干预。

## 4. 技术方案

### 4.1 文件结构
```
openclaw/95_spawn_test/
└── SPEC.md
```

### 4.2 核心验证逻辑
- 验证主会话按顺序 spawn 四个 subagent
- 每个阶段通过状态文件 `.pipeline-state/95_stage` 记录当前进度
- 状态值含义：
  - `1`: Stage 1 完成
  - `2`: Stage 2 完成
  - `3`: Stage 3 完成
  - `4`: Stage 4 完成

## 5. 验收标准

- [ ] 主会话按顺序 spawn 四个阶段
- [ ] 每个阶段完成后自动继续下一阶段
- [ ] 状态文件 `.pipeline-state/95_stage` 正确更新
- [ ] 分支 `openclaw/issue-95` 已创建并包含 SPEC.md
