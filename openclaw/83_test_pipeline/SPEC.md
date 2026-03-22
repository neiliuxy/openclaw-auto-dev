# Issue #83 需求规格说明书

## 1. 概述
- **Issue**: #83
- **标题**: test: 验证 4-session pipeline 通知
- **处理时间**: 2026-03-22

## 2. 需求分析

### 背景
本 Issue 是一个元测试（meta-test），用于验证四阶段代理流水线（Architect → Developer → Tester → Reviewer）中每个阶段能否独立发送消息通知。

### 功能范围
**包含：**
- 验证 Architect 阶段能独立发送通知消息
- 验证 Developer 阶段能独立发送通知消息
- 验证 Tester 阶段能独立发送通知消息
- 验证 Reviewer 阶段能独立发送通知消息
- 验证通知消息内容区分各阶段

**不包含：**
- 不实现具体的业务功能代码（本 Issue 本身就是测试）

## 3. 功能点拆解

| ID | 功能点 | 描述 | 验收标准 |
|----|--------|------|----------|
| F01 | Architect 阶段独立通知 | Architect 完成后发送阶段通知 | 飞书通知包含 "Architect 完成" 或类似标识 |
| F02 | Developer 阶段独立通知 | Developer 完成后发送阶段通知 | 飞书通知包含 "Developer 完成" 或类似标识 |
| F03 | Tester 阶段独立通知 | Tester 完成后发送阶段通知 | 飞书通知包含 "Tester 完成" 或类似标识 |
| F04 | Reviewer 阶段独立通知 | Reviewer 完成后发送阶段通知 | 飞书通知包含 "Reviewer 完成" 或类似标识 |
| F05 | 通知消息可区分 | 每个阶段的通知消息能被明确区分 | 消息内容包含阶段名称和 Issue 编号 |

## 4. 技术方案

### 4.1 文件结构
```
openclaw/83_test_pipeline/
  ├── SPEC.md          # 本文档
  └── TEST_REPORT.md   # Tester 阶段生成（记录各阶段通知情况）
```

### 4.2 流水线说明
四阶段代理流水线通过独立子会话顺序执行，每个阶段在完成后发送飞书通知：

1. **Architect**：分析 Issue #83，生成 SPEC.md，发送通知
2. **Developer**：读取 SPEC.md，执行开发任务，发送通知
3. **Tester**：读取 SPEC.md，运行测试验证，发送通知并生成 TEST_REPORT.md
4. **Reviewer**：检查测试结果，执行最终审核，发送通知

### 4.3 通知机制
- 每个阶段通过 `message` 工具发送飞书消息
- 消息格式：`{阶段名称} 完成，{关键产物} for Issue #{issue_number}`
- 示例：`✅ Architect 完成，SPEC.md 已生成 for Issue #83`

### 4.4 依赖
- openclaw >= 2026.3.3
- 飞书消息渠道配置
- 消息发送工具（message tool）

## 5. 验收标准

| ID | 标准 | 测试方法 |
|----|------|----------|
| V01 | Architect 阶段发送通知 | 检查飞书消息记录，验证包含 Architect 标识 |
| V02 | Developer 阶段发送通知 | 检查飞书消息记录，验证包含 Developer 标识 |
| V03 | Tester 阶段发送通知 | 检查飞书消息记录，验证包含 Tester 标识 |
| V04 | Reviewer 阶段发送通知 | 检查飞书消息记录，验证包含 Reviewer 标识 |
| V05 | 通知消息包含 Issue 编号 | 检查飞书消息记录，验证包含 "#83" |
| V06 | 各阶段通知相互独立 | 确认每个阶段的通知消息是独立发送的（非批量） |

## 6. 测试用例

### TC01: 验证 Architect 阶段通知
- **输入**: Issue #83
- **预期**: Architect 阶段完成后收到飞书通知，消息包含 "Architect 完成" 和 "Issue #83"

### TC02: 验证 Developer 阶段通知
- **输入**: Issue #83
- **预期**: Developer 阶段完成后收到飞书通知，消息包含 "Developer 完成" 和 "Issue #83"

### TC03: 验证 Tester 阶段通知
- **输入**: Issue #83
- **预期**: Tester 阶段完成后收到飞书通知，消息包含 "Tester 完成" 和 "Issue #83"

### TC04: 验证 Reviewer 阶段通知
- **输入**: Issue #83
- **预期**: Reviewer 阶段完成后收到飞书通知，消息包含 "Reviewer 完成" 和 "Issue #83"
