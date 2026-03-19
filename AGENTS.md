# AGENTS.md - AI 开发指南

**OpenClaw Auto Dev 项目** - 自动化 GitHub Issue 处理系统

---

## 🎯 核心原则

### 1. 信任但要验证 (Trust but Verify)
- **永远不要假设**你的操作正确执行了
- **始终运行验证**: `./scripts/validate-changes.sh <issue_number>`
- 验证失败 = 回滚更改，不要提交

### 2. 执行优于文档
- 创建 SOLUTION.md 文档 **之前** 先执行实际变更
- 文档是记录，不是替代品
- 验收标准：代码能编译、测试能通过

### 3. 小步提交
- 每个 issue 一个分支：`openclaw/issue-{num}`
- 提交信息包含 issue 引用：`fix: move hello.cpp to src/ (closes #4)`
- 验证通过后才提交

---

## 📋 工作流程

### 处理 Issue

```bash
# 1. 获取 issue 详情
gh issue view <num> --json title,body,labels

# 2. 创建分支
git checkout -b openclaw/issue-<num>

# 3. 执行变更
# (根据 issue 内容移动/创建/修改文件)

# 4. 🔍 验证变更 (关键步骤!)
./scripts/validate-changes.sh <num>

# 5. 提交 (仅当验证通过)
git add -A
git commit -m "fix: description (closes #<num>)"

# 6. 推送并创建 PR
git push -u origin openclaw/issue-<num>
gh pr create --fill

# 7. 合并 PR
gh pr merge <num> --merge

# 8. 关闭 issue
gh issue close <num>
```

---

## ✅ 验证清单

提交前必须确认：

- [ ] 文件操作已验证（移动/创建/删除）
- [ ] 编译成功（`make clean && make`）
- [ ] 程序运行正常（如有可执行文件）
- [ ] 配置文件语法正确（JSON/YAML）
- [ ] 解决方案文档已创建
- [ ] 提交信息规范

---

## 🚫 常见错误

### ❌ 只创建文档，不执行变更
```
错误：只创建 SOLUTION-4.md，没有移动 hello.cpp
正确：先移动文件，验证，再创建文档
```

### ❌ 不验证就提交
```
错误：假设 AI 执行正确，直接提交
正确：运行 ./scripts/validate-changes.sh 确认
```

### ❌ 忽略编译测试
```
错误：修改代码后不编译
正确：make clean && make && ./hello
```

---

## 📁 项目结构

```
openclaw-auto-dev/
├── src/                    # C++ 源文件
│   └── hello.cpp
├── scripts/                # 自动化脚本
│   ├── process-issue.sh    # Issue 处理主流程
│   └── validate-changes.sh # 智能验证系统
├── Makefile                # 构建配置
├── opencode.json           # AI 规则配置
├── AGENTS.md               # 本文件
├── POST-MORTEM.md          # 事后分析
└── SOLUTION-*.md           # 解决方案文档
```

---

## 🛠️ 工具

### 验证脚本
```bash
# 智能验证 - 根据 issue 内容自动选择验证策略
./scripts/validate-changes.sh <issue_number>
```

### Issue 处理
```bash
# 自动化处理完整流程
./scripts/process-issue.sh <issue_number>
```

### GitHub CLI
```bash
# 查看 issue
gh issue view <num>

# 创建 PR
gh pr create --title "Fix: ..." --body "Closes #<num>"

# 合并 PR
gh pr merge <num> --merge
```

---

## 📖 参考

- **POST-MORTEM.md** - Issue #4 的事后分析（为什么需要验证）
- **opencode.json** - AI 行为规则配置
- **scripts/validate-changes.sh** - 验证系统实现

---

**最后更新**: 2026-03-19  
**核心教训**: 验证是质量的生命线
