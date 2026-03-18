# OpenClaw Auto Dev - 部署指南

## 📋 前置条件

1. **OpenClaw 已安装并配置**
   ```bash
   openclaw status
   ```

2. **GitHub CLI 已安装并认证**
   ```bash
   gh auth status
   ```

3. **opencode CLI 已安装**（可选，用于自动开发）
   ```bash
   opencode --version
   ```

---

## 🔧 配置步骤

### 步骤 1：克隆项目

```bash
git clone https://github.com/neiliuxy/openclaw-auto-dev.git
cd openclaw-auto-dev
```

### 步骤 2：配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

1. 访问：https://github.com/neiliuxy/openclaw-auto-dev/settings/secrets/actions

2. 添加 `GH_TOKEN`：
   - 生成 Personal Access Token：https://github.com/settings/tokens
   - 权限要求：`repo` (完全控制)
   - 复制 Token 并添加到 Secrets

3. 添加 `OPENCLAW_WEBHOOK_URL`（可选）：
   - OpenClaw 消息推送地址

### 步骤 3：启用 GitHub Actions

1. 访问：https://github.com/neiliuxy/openclaw-auto-dev/actions
2. 点击 "I understand my workflows, go ahead and enable them"

### 步骤 4：配置 OpenClaw 心跳

确保 `HEARTBEAT.md` 配置正确。

### 步骤 5：测试工作流

#### 创建测试 Issue

1. 访问：https://github.com/neiliuxy/openclaw-auto-dev/issues/new
2. 标题：`[Test] 测试自动开发流程`
3. 添加标签：`openclaw-new`
4. 创建 Issue

#### 等待 OpenClaw 处理

- 30 分钟内 OpenClaw 会自动检测并处理
- 或手动触发：
  ```bash
  ./scripts/process-issue.sh <issue_number>
  ```

---

## 📊 监控与调试

### 查看 GitHub Actions 日志

```bash
# 查看最近的工作流运行
gh run list --limit 5

# 查看特定运行的日志
gh run view <run_id> --log
```

### 查看 OpenClaw 会话

```bash
# 列出会话
openclaw sessions list
```

### 查看 Issue 状态

```bash
# 列出所有 openclaw 相关的 Issue
gh issue list --label "openclaw-new"
gh issue list --label "openclaw-processing"
gh issue list --label "openclaw-completed"
```

---

## 🔍 故障排除

### Issue 没有被自动处理

**检查项：**
- GitHub Actions 是否启用
- `GH_TOKEN` Secret 是否正确配置
- Issue 是否有 `openclaw-new` 标签
- OpenClaw 心跳是否正常运行

**解决方案：**
```bash
# 手动触发工作流
gh workflow run issue-check.yml

# 手动处理 Issue
./scripts/process-issue.sh <issue_number>
```

### PR 创建失败

**检查项：**
- 分支是否已推送
- GitHub Token 权限是否足够
- 是否有同名的现有分支

**解决方案：**
```bash
# 清理旧分支
git branch -D feature/issue-<number>
git push origin --delete feature/issue-<number>

# 重新处理
./scripts/process-issue.sh <issue_number>
```

---

## 🎯 最佳实践

1. **Issue 描述要清晰** - 明确的需求和验收标准
2. **定期清理已完成 Issue** - 关闭已完成的 Issue
3. **配置自动合并**（可选）- 测试通过后自动合并
4. **添加通知** - 状态变更时通知团队

---

**详细设计**: [DESIGN.md](../DESIGN.md)
