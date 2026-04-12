# Issue #104 需求规格说明书

## 1. 概述
- **Issue**: #104
- **标题**: test: pipeline全流程自动触发验证
- **描述**: 验证cron能自动触发所有阶段
- **处理时间**: 2026-03-22

## 2. 需求分析

### 背景
Issue #104 是 pipeline 全流程自动触发验证的测试阶段。在 Issue #102 pipeline方案B最终验证完成的基础上，进一步验证 cron 能否自动触发所有阶段，确保整个自动化闭环从触发到完成都能正常运转。

### 目标
- 验证 cron 能自动触发 Architect 阶段
- 验证 cron 能自动触发 Developer 阶段
- 验证 cron 能自动触发 Tester 阶段
- 验证 cron 能自动触发 Reviewer 阶段
- 确保状态文件正确更新，流程可追踪
- 飞书通知全流程送达

## 3. 功能点拆解

| 功能点 | 描述 | 验收标准 |
|--------|------|----------|
| Cron 触发 Architect | cron 时间到后自动触发 Architect 阶段 | Architect 阶段自动启动 |
| SPEC 生成 | Architect 阶段自动生成完整的 SPEC.md | SPEC.md 内容完整规范 |
| Cron 触发 Developer | Architect 完成后 cron 自动触发 Developer 阶段 | Developer 阶段自动启动 |
| 代码实现 | Developer 阶段完成代码实现 | 代码符合规范 |
| Cron 触发 Tester | Developer 完成后 cron 自动触发 Tester 阶段 | Tester 阶段自动启动 |
| 测试验证 | Tester 阶段进行测试验证 | 测试通过 |
| Cron 触发 Reviewer | Tester 完成后 cron 自动触发 Reviewer 阶段 | Reviewer 阶段自动启动 |
| 代码审查 | Reviewer 阶段进行代码审查 | PR 正确创建并合并 |
| 状态更新 | 每阶段正确更新 .pipeline-state/104_stage | 状态文件值符合阶段 |
| 飞书通知 | 各阶段完成后发送飞书通知 | 通知消息正确送达 |

## 4. 技术方案

### 4.1 文件结构
```
openclaw/104_pipeline_full_auto/
└── SPEC.md              # 本规格说明书
```

### 4.2 阶段定义

| 阶段 | Stage 值 | 说明 |
|------|----------|------|
| Architect | 1 | 需求分析，生成 SPEC.md |
| Developer | 2 | 代码实现 |
| Reviewer | 3 | 代码审查 |
| QA | 4 | 测试验证 |

### 4.3 状态文件
- 路径: `.pipeline-state/104_stage`
- 格式: JSON `{"issue_num":104,"stage":N,"started_at":"..."}`
- 更新时机: 每个阶段完成后

### 4.4 飞书通知
- 触发时机: 每个阶段完成后
- 消息格式: "✅ [角色] 完成 [产物] for Issue #104"

### 4.5 Cron 配置
- 触发间隔: 每 30 分钟检查一次
- 触发条件: Issue 分配给 pipeline 且状态为对应阶段

## 5. 验收标准
- [ ] SPEC.md 已生成，内容完整
- [ ] Cron 自动触发 Architect 阶段
- [ ] 状态文件 `.pipeline-state/104_stage` 正确更新为 1（Architect阶段）
- [ ] Architect 阶段完成后发送飞书通知
- [ ] Cron 自动触发 Developer 阶段
- [ ] Developer 阶段完成代码实现
- [ ] Cron 自动触发 Tester 阶段
- [ ] Tester 阶段完成测试验证
- [ ] Cron 自动触发 Reviewer 阶段
- [ ] Reviewer 阶段完成代码审查并创建 PR
- [ ] PR 正确合并
- [ ] 全流程飞书通知送达

## 6. 依赖项
- openclaw cron 配置正确
- pipeline agent 正常运行
- 飞书通知 channel 已配置
- 状态文件 `.pipeline-state/104_stage` 可写

## 7. 测试场景

### 场景1: Cron 自动触发验证
1. cron 时间到后检查 Issue #104 状态
2. 如果状态为 0（未开始），触发 Architect 阶段
3. Architect 生成 SPEC.md
4. 更新状态为 1
5. 发送飞书通知

### 场景2: 全流程自动贯通验证
1. Architect 完成后，cron 触发 Developer
2. Developer 完成代码实现
3. cron 触发 Tester
4. Tester 完成测试验证
5. cron 触发 Reviewer
6. Reviewer 审查并合并 PR
7. 全流程状态正确更新
8. 全流程飞书通知送达

### 场景3: 异常恢复验证
1. 如果某个阶段失败
2. cron 下次运行时检测到异常状态
3. 自动重试或标记错误
