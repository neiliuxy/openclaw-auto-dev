# Issue #93 需求规格说明书

## 1. 概述
- **Issue**: #93
- **标题**: test: 验证心跳自动续跑
- **处理时间**: 2026-03-22

## 2. 需求分析

### 背景
心跳机制（cron-heartbeat.sh）每 30 分钟扫描 GitHub Issue 状态，当发现 pipeline 异常中断时，需要能够自动从断点续跑（resume）。本 Issue 是一个元测试（meta-test），用于验证心跳触发后 pipeline 能自动启动和续跑。

### 功能范围
**包含：**
- 验证心跳能检测到处于 `openclaw-processing` 等中间状态的 Issue
- 验证心跳触发后能正确调用 pipeline-runner.sh
- 验证 pipeline 可从 `.pipeline-state/<issue>_stage` 断点续跑
- 验证心跳在 pipeline 运行期间不会重复触发

**不包含：**
- 不实现具体的业务功能代码（本 Issue 本身就是测试）

## 3. 功能点拆解

| ID | 功能点 | 描述 | 验收标准 |
|----|--------|------|----------|
| F01 | 心跳检测中间状态 Issue | cron-heartbeat.sh 能识别 openclaw-processing/openclaw-architecting 等状态 | scan-issues.sh 能检测到处于中间状态的 Issue |
| F02 | 心跳触发 pipeline | 发现需要续跑的 Issue 时调用 pipeline-runner.sh | cron-heartbeat.sh 日志包含调用 pipeline-runner.sh 的记录 |
| F03 | 断点续跑机制 | pipeline-runner.sh 支持 --continue 参数从断点恢复 | 状态文件 .pipeline-state/<issue>_stage 存在时能正确读取并续跑 |
| F04 | 避免重复触发 | pipeline 运行期间心跳不会创建重复任务 | scan-issues.sh 检测到 openclaw-processing 时返回 idle |

## 4. 技术方案

### 4.1 文件结构
```
openclaw/93_test_pipeline/
  ├── SPEC.md          # 本文档（Architect 阶段生成）
  └── TEST_REPORT.md   # Tester 阶段生成（记录各验证结果）
```

### 4.2 心跳自动续跑流程
```
cron (*/30 * * * *)
    ↓
cron-heartbeat.sh
    ↓
scan-issues.sh
    ├── 检测 openclaw-processing/openclaw-architecting 等状态 → 已有任务，跳过
    └── 检测 openclaw-new 状态 → 发现新 Issue，报告 new_issue
    ↓
pipeline-runner.sh <issue_number> [--continue]
    ↓
读取 .pipeline-state/<issue>_stage 确定断点
    ↓
从断点恢复执行
```

### 4.3 状态文件机制
Pipeline 使用 `.pipeline-state/<issue>_stage` 文件记录进度：

| 状态值 | 含义 | 说明 |
|--------|------|------|
| 0 | 未开始 | Issue 刚被发现 |
| 1 | Architect 完成 | SPEC.md 已生成 |
| 2 | Developer 完成 | 代码已实现 |
| 3 | Tester 完成 | 测试已验证 |
| 4 | Pipeline 完成 | 可合并 PR |

### 4.4 关键脚本
- `scripts/cron-heartbeat.sh` - 定时心跳入口
- `scripts/scan-issues.sh` - Issue 状态扫描
- `pipeline-runner.sh` - Pipeline 执行器（位于 skills/openclaw-pipeline/）

### 4.5 依赖
- cron 配置（每 30 分钟执行）
- GitHub CLI（gh）已认证
- 飞书消息渠道配置
- openclaw-pipeline skill

## 5. 验收标准

| ID | 标准 | 测试方法 |
|----|------|----------|
| V01 | scan-issues.sh 能检测中间状态 | 运行脚本，检查对 openclaw-processing 状态的响应 |
| V02 | 心跳不重复触发 | 验证 openclaw-processing 状态时返回 idle |
| V03 | pipeline-runner.sh 支持 --continue | 检查脚本帮助信息或源码 |
| V04 | 状态文件格式正确 | 检查 .pipeline-state/ 目录和文件格式 |
| V05 | cron-heartbeat.sh 正确调用 pipeline | 检查日志文件中 pipeline-runner.sh 调用记录 |

## 6. 测试用例

### TC01: 验证心跳检测中间状态 Issue
- **输入**: 运行 scan-issues.sh，当存在 openclaw-architecting 状态 Issue
- **预期**: 返回 processing 状态，不触发新 pipeline

### TC02: 验证心跳对新 Issue 触发 pipeline
- **输入**: 运行 cron-heartbeat.sh，当存在 openclaw-new 状态 Issue
- **预期**: 日志包含 "发现新 Issue" 和 pipeline-runner.sh 调用

### TC03: 验证断点续跑
- **输入**: 创建 .pipeline-state/93_stage 文件，内容为 "1"
- **预期**: pipeline-runner.sh 读取后从 Architect 之后阶段开始

### TC04: 验证状态文件不存在时从头开始
- **输入**: 删除 .pipeline-state/93_stage，运行 pipeline-runner.sh
- **预期**: pipeline 从 stage 0 开始处理
