# PermanentRecord

一个基于 SwiftUI 的「永久投资组合」记录应用。  
用于记录股票 / 债券 / 黄金 / 现金四类资产的每日市值与本金，追踪收益、偏离目标配置、执行策略并导出历史数据。

## 功能概览

- 首页仪表板
  - 总资产、总收益、总收益率
  - 四类资产卡片（市值 / 本金 / 收益 / 收益率 / 当前占比）
  - 支持点击资产卡片编辑名称和代码
  - 支持金额隐私模式（眼睛按钮，默认隐藏金额）
- 状态监控
  - 可编辑再平衡阈值
  - 可编辑目标配置比例（股票/债券/黄金/现金）
  - 自动校验目标比例总和必须为 100%
  - 显示各资产偏差与状态（`✅ 正常` / `⚠️平衡`）
  - 点击状态可查看解释说明
- 添加记录
  - 录入某日四类资产市值与本金
  - 可选择“使用上一日本金”（留空自动继承）
  - 保存成功提示，防止重复点击
  - 数字键盘支持完成按钮收起
- 策略模块（Policy）
  - 按比例买入
  - 智能填坑/削峰
  - 强制再平衡
  - 智能买卖决策
  - 执行前先预览，再二次确认是否落库
- 图表模块
  - 收益率趋势
  - 资产市值趋势
  - 资产比例分布
  - 支持点选数据点查看具体数值，支持“还原”
- 历史记录
  - 列表查看与搜索
  - 详情查看（总收益率 + 各资产收益率）
  - 支持删除记录
  - 导出 CSV / JSON
- 每日/每周提醒
  - 本地通知提醒添加记录
  - 支持每天固定时间或每周指定星期+时间
  - 显示“下次提醒时间”用于校验是否生效

## 技术栈

- Swift 5
- SwiftUI
- Apple Charts
- UserNotifications（本地通知）
- UserDefaults（本地持久化）

## 项目结构

```text
PermanentRecord/
├── PermanentRecord/
│   ├── Models/
│   ├── Services/
│   ├── Views/
│   └── PermanentRecordApp.swift
├── PermanentRecordTests/
├── PermanentRecordUITests/
├── Policy.txt
└── PROGRESS.md
```

## 运行方式

1. 使用 Xcode 打开工程：`PermanentRecord/PermanentRecord.xcodeproj`
2. 选择 iOS Simulator 或真机
3. `⌘R` 运行
4. 如需提醒功能，请在系统弹窗中允许通知权限

## 数据说明

- 所有业务数据存储在本地 `UserDefaults`（资产、记录、阈值、目标比例、提醒配置）。
- 当前未接入云端同步，删除 App 会导致本地数据丢失。
- 可通过“历史记录 -> 导出”进行 CSV/JSON 备份。

## 使用建议

1. 首次使用先在首页确认四类资产名称/代码。
2. 每日通过“添加”录入市值，按需录入本金。
3. 通过“状态监控”观察偏差，必要时在“策略”页执行策略。
4. 开启提醒并确认“下次提醒时间”是否符合预期。
5. 定期导出 CSV/JSON 作为备份。

## 已知限制

- 提醒依赖系统通知权限；若权限关闭则不会触发通知。
- 数据目前仅本地存储，不支持跨设备自动同步。
- 项目里仍有部分模板文件（如 `ContentView.swift`、`Item.swift`）尚未用于主流程。

## 下一步改进方向（Roadmap）

- 数据层升级
  - 从 `UserDefaults` 迁移到 `SwiftData` / `Core Data`
  - 增加数据版本迁移机制
- 云端能力
  - iCloud/CloudKit 同步
  - 自动备份与恢复
- 交互与可视化
  - 记录编辑功能（不仅删除）
  - 图表区间统计与对比
  - 首页状态卡片更多可视化（趋势箭头、变化幅度）
- 策略能力
  - 增加策略参数自定义
  - 策略回测与结果对比
  - 执行日志与回滚机制
- 工程质量
  - 完善单元测试与 UI 自动化测试
  - 增加 CI（构建、测试、Lint）

## 备份到 GitHub（建议流程）

```bash
git init
git add .
git commit -m "init: permanent portfolio tracker"
git branch -M main
git remote add origin <your-repo-url>
git push -u origin main
```

建议再创建 `.gitignore`（Xcode/DerivedData/用户本地文件）并启用 GitHub 私有仓库进行云备份。

## 备注

- 策略实现参考了项目中的 `Policy.txt` 规则并已集成到应用 UI 与数据流程中。
- 变更历史和问题修复记录见 `PROGRESS.md`。
