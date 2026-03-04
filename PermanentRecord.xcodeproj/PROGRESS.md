# PROGRESS

## 2026-03-04

### Scope
- Project: `PermanentRecord`
- Goal: fix all current compile errors and leave a traceable error/solution log.

### Errors Fixed
1. `Views/ChartView.swift`
- Error patterns:
  - `Unexpected initializer in pattern; did you mean to use '='?`
  - `Expected ')' in expression list`
  - `Extraneous '}' at top level`
  - Multiple Charts API misuse errors from invalid mark syntax.
- Root causes:
  - Used `let value: ...` / `let avg: ...` instead of assignment.
  - Parentheses and braces mismatched.
  - Incorrect `Charts` API usage (`LineMark`/`BarMark` parameter structure, invalid `RectangleFill`, invalid closures).
  - Incorrect `Calendar.date(byAdding:)` signature usage.
- Fix:
  - Rebuilt `ChartView` with valid SwiftUI Charts patterns for:
    - return rate line chart
    - asset value multi-line chart
    - average allocation bar chart
  - Added stable helpers for return rate and allocation/value lookup.
  - Ensured all axis labels and styles use valid APIs.

2. `Services/DataManager.swift`
- Error patterns:
  - `Type 'DataManager' does not conform to protocol 'ObservableObject'`
  - `@Published ... missing import of defining module 'Combine'`
  - `Cast from 'Data?' to unrelated type '[[String: Any]]' always fails`
  - invalid fallback object construction inside `compactMap`.
- Root causes:
  - Missing `import Combine`.
  - Wrong UserDefaults API: reading array data via `data(forKey:)` cast.
  - `compactMap` closure returned concrete invalid defaults instead of `nil` on bad rows.
- Fix:
  - Added `import Combine`.
  - Switched reads to `userDefaults.array(forKey:) as? [[String: Any]]`.
  - Changed closures to return optional (`Asset?` / `Record?`) and return `nil` on invalid payload.

3. `Views/AddRecordView.swift`
- Error patterns:
  - `Cannot assign to immutable expression of type 'Date.Type'`
  - `Cannot find 'NumberField' in scope`
- Root causes:
  - Typo: `@State private var selectedDate = Date = Date()`.
  - Used custom component `NumberField` not defined in project.
- Fix:
  - Corrected to `@State private var selectedDate = Date()`.
  - Replaced `NumberField` usage with local helper `amountField(...)` built from `TextField` + `.decimalPad`.

4. `Views/DashboardView.swift`
- Error patterns:
  - `Extra trailing closure passed in call`
  - `Asset must conform to Identifiable`
  - Several `() -> View cannot conform to View` builder issues
  - String index type mismatches in `Color(hex:)`.
- Root causes:
  - Invalid `LazyVGrid` `GridItem` syntax with trailing closure.
  - `Card` container lacked `@ViewBuilder` initializer.
  - `Asset` not declared `Identifiable`.
  - Hex parsing implementation used invalid index math.
- Fix:
  - Replaced grid column definition with valid `GridItem(.adaptive(minimum: 150), spacing: 15)`.
  - Added `Card` init: `init(@ViewBuilder content: () -> Content)`.
  - Updated `Asset` to `struct Asset: Identifiable`.
  - Rewrote `Color(hex:)` parsing using `UInt64(hex, radix: 16)` with guard fallback.

5. `Views/RecordListView.swift`
- Error patterns:
  - `ForEach ... requires Record conform to Identifiable`
  - Toolbar builder type mismatch (`ToolbarItem` nested inside `ToolbarItemGroup`).
- Root causes:
  - `Record` did not declare `Identifiable`.
  - Incorrect toolbar composition.
- Fix:
  - Updated `Record` to `struct Record: Identifiable`.
  - Rewrote toolbar to a single valid `ToolbarItem(placement: .primaryAction)`.

### Final Validation
- Action: Xcode `BuildProject`
- Result: **Success** (no compile errors)

### Runtime Error Fixed
6. `SwiftUICore/EnvironmentObject.swift:93`
- Error pattern:
  - `Fatal error: No ObservableObject of type DataManager found`
- Root cause:
  - `PermanentRecordApp` created `@StateObject private var dataManager = DataManager()`, but did not inject it with `.environmentObject(dataManager)` into the root view tree.
- Fix:
  - Added `.environmentObject(dataManager)` to root `TabView` in `PermanentRecordApp`.

7. `String(format:locale:arguments:)` format-specifier mismatch
- Error pattern:
  - `Format '%s%.2f%%' does not match expected '%@%lf'`
- Root cause:
  - Used C char* specifier `%s` with a Swift `String` argument.
- Fix:
  - Replaced `%s` with `%@` in:
    - `Models/Asset.swift` (`formattedReturnRate`)
    - `Models/Portfolio.swift` (`formattedReturnRate`)

8. `AddRecordView` numeric keyboard cannot be dismissed
- Error pattern:
  - After entering values with `.decimalPad`, keyboard had no way to close.
- Root cause:
  - Decimal keypad has no return key by default, and the view did not provide a keyboard toolbar action.
- Fix:
  - Added `@FocusState` with explicit field tracking for all numeric inputs.
  - Added keyboard toolbar button `完成` that clears focus (`focusedField = nil`) to dismiss keyboard.

9. Homepage values not updating after adding record + principal input behavior incorrect
- Error pattern:
  - After entering today's market values, home page cards did not reflect current values.
  - Principal fields were not practically editable when "use previous day principal" was enabled.
- Root causes:
  - `addRecord`/`updateRecord`/`deleteRecord` only updated `records`, while dashboard reads from `assets`.
  - Principal fallback logic always overwrote manual input when toggle was on.
- Fix:
  - Added `syncAssetsWithLatestRecord()` in `DataManager` and called it on load/add/update/delete.
  - Persisted synced assets via `saveAssets()` after record mutations.
  - Updated `portfolio.lastUpdateDate` to use max record date.
  - Changed AddRecord principal logic to: when toggle is on, only fill from previous record if current field is empty.
  - Made principal section always visible so values can always be entered manually.

10. Recurring keyboard dismissal issue + principal parsing robustness + record detail screen
- Error patterns:
  - Numeric keyboard could still block interaction after input.
  - After entering principal, home page principal stayed `0` in some user inputs.
  - Record list lacked a detailed drill-down screen.
- Root causes:
  - Keyboard dismissal relied on a single path and could remain focused.
  - `Double(text)` fails for formatted numeric text (e.g. with `,` / `¥` / `￥`), resulting in `0`.
  - List row was not linked to a dedicated detail view.
- Fix:
  - In `AddRecordView`:
    - dismiss keyboard on save (`focusedField = nil`)
    - enable interactive scroll keyboard dismissal (`.scrollDismissesKeyboard(.interactively)`)
    - added `parseAmount(_:)` to sanitize formatted input before parsing.
  - In `RecordListView`:
    - rows now navigate to `RecordDetailView`
    - detail page shows each asset's market value, principal, and return, plus totals.
  - Kept delete actions via swipe/context menu on list rows.

11. Save action had weak feedback + keyboard should dismiss on blank tap
- Error patterns:
  - Users may tap save multiple times because no clear success feedback is visible.
  - Numeric keyboard should dismiss when tapping blank area.
- Root causes:
  - Save action had no explicit success cue and no anti-repeat guard.
  - Keyboard dismissal depended on toolbar/scroll interaction only.
- Fix:
  - In `AddRecordView`:
    - added save-state guard (`isSaving`) to prevent repeat taps during save action.
    - added animated top hint `已保存` after successful save.
    - added form-wide tap gesture to clear focus (`focusedField = nil`) for blank-area dismissal.
    - kept keyboard toolbar `完成` and interactive scroll dismissal.

12. "Saved but no reaction" UX bug on AddRecord page
- Error pattern:
  - User taps save and feels no effective response.
- Root causes:
  - `dismiss()` in tab context does not provide clear completion feedback.
  - Existing hint alone was not strong enough as completion confirmation.
- Fix:
  - In `AddRecordView`:
    - removed post-save `dismiss()` behavior and keep user on current page.
    - added explicit success alert (`已保存`) after save.
    - clear all input fields after successful save, so completion is visually obvious.

13. `Gesture: System gesture gate timed out` when tapping save
- Error pattern:
  - Save button occasionally feels delayed and logs `System gesture gate timed out`.
- Root causes:
  - A form-wide `simultaneousGesture` competed with button/system gestures.
  - Save action executed in the same tap cycle as keyboard/gesture state transitions.
- Fix:
  - Removed form-wide `simultaneousGesture` from `AddRecordView`.
  - Changed save flow to run on next main-actor cycle (`await Task.yield()`) after focus clear.
  - Kept lightweight non-blocking "已保存" top hint and removed blocking save alert.

14. Add page cancel button visibility + dashboard card contrast in dark mode
- Error patterns:
  - "添加"页面左上角一直显示“取消”按钮。
  - 黑夜主题下首页卡片边界不明显，视觉上像“看不到框”。
- Root causes:
  - Add page was in a tab context but still used modal-style cancellation toolbar item.
  - Card used `systemBackground` with weak separation from page background in dark mode.
- Fix:
  - Removed cancellation toolbar item from `AddRecordView`.
  - Updated `Card` style in `DashboardView`:
    - background uses `secondarySystemBackground`
    - added subtle 1pt border overlay
    - slightly stronger shadow for dark-mode depth.

15. Tap asset card on dashboard to edit name/code
- Requirement:
  - Tap stock/bond/gold/cash card on home page and open a page to edit asset name and code.
- Implementation:
  - Wrapped each asset card with `NavigationLink` in `DashboardView`.
  - Added `AssetEditView`:
    - shows asset type (read-only)
    - editable fields for asset name and asset code
    - save button updates model through `dataManager.updateAsset(updated)` and pops page.
- Scope:
  - Works for all asset types because editing is driven by the shared `assets` list.

16. RTIInputSystemClient session warnings during text input
- Error pattern:
  - `perform input operation requires a valid sessionID ... dismissAutoFillPanel`
- Root cause:
  - iOS text input/autofill session logs can appear when keyboard/autofill state changes quickly.
- Mitigation applied:
  - Disabled autofill/autocorrection hints on numeric and asset edit text fields.
  - Set asset code field keyboard to `.asciiCapable`.
  - Added keyboard toolbar `完成` in asset edit page to dismiss focus cleanly.
- Note:
  - This is typically a system-level warning and may still appear occasionally without functional impact.

17. Integrated `Policy.txt` macro logic into app
- Source:
  - `PermanentRecord/Policy.txt` (Excel VBA macros for permanent portfolio operations)
- Implemented in app:
  - Added policy engine to `DataManager` with 4 actions:
    - `按比例买入` (ConfirmEqualBuy)
    - `智能填坑/削峰` (ConfirmSmartInjection)
    - `强制再平衡` (ExecuteFullRebalance)
    - `智能买卖决策` (SmartAutoTrade)
  - Added strategy calculation and execution pipeline:
    - compute per-asset adjustment
    - apply adjustment to both market value and principal
    - write a new `Record` and refresh dashboard state
- UI integration:
  - Added `Policy 策略交易` section in `AddRecordView`:
    - input fund (`+` deposit / `-` withdrawal)
    - choose strategy
    - execute and show result summary per asset
- Current assumptions:
  - Target allocation uses permanent-portfolio default 25%/25%/25%/25%.
  - Fund must be non-zero.

18. Split policy execution into dedicated strategy screen
- Requirement:
  - Separate four policy operations in a new UI, because not all strategies require new fund input.
- Changes:
  - Added new tab page `PolicyView`:
    - 1) 按比例买入: requires positive fund
    - 2) 智能填坑/削峰: requires non-zero fund
    - 3) 强制再平衡: no fund input required
    - 4) 智能买卖决策: requires non-zero fund
  - Added date selector for policy execution date.
  - Kept result summary alert after each execution.
  - Removed policy section from `AddRecordView`; it now focuses on manual daily record entry only.
- Added `策略` tab in app entry (`PermanentRecordApp`).

19. Same-day multiple records could show stale state
- Error pattern:
  - After executing policy on the same day, dashboard could appear to show an earlier record.
- Root cause:
  - Current-state sync used date comparison (`max by date`), which can be ambiguous with same-day/manual-date records.
- Fix:
  - Switched current-state source to insertion order:
    - `syncAssetsWithLatestRecord()` now uses `records.first`
    - `portfolio.lastUpdateDate` now uses `records.first?.date`
    - previous-principal fallback in `AddRecordView` now uses `dataManager.records.first`
- Result:
  - Dashboard always reflects the most recently added record, including multiple operations on the same date.

20. Policy execution now requires explicit Yes/No confirmation after preview
- Requirement:
  - Clicking strategy execution should first preview, then require user confirmation to decide whether to add record.
- Changes:
  - `DataManager`:
    - added `previewPolicyTrade(action:fund:)` (compute only, no write)
    - added `applyPolicyTrade(_:date:)` (apply confirmed preview and write record)
    - `executePolicyTrade` now delegates to preview + apply.
  - `PolicyView`:
    - execute button now produces preview first
    - shows confirmation dialog with preview details
    - only when user taps “是，执行并添加记录” does it actually write the record
    - tapping “否，取消” aborts without data change.

21. Reduce input-method warnings on policy amount fields
- Error pattern:
  - Frequent logs while typing in policy page:
    - `Received external candidate resultset...`
    - `containerToPush is nil...`
- Root cause:
  - Signed amount entry with symbol-capable keyboard (`numbersAndPunctuation`) can trigger IME candidate-session noise.
- Mitigation:
  - Refactored policy fund input to structured form:
    - amount field uses `.decimalPad` only
    - direction is selected via segmented control (`存入` / `取出`)
  - Internal execution fund is computed as signed value from amount + direction.

22. Added rebalance threshold monitor on dashboard
- Requirement:
  - Show rebalance threshold (default 10%), target allocation display, and per-asset deviation/status above recent records.
  - Threshold must be editable.
- Implementation:
  - `DataManager`:
    - added persisted `rebalanceThresholdPercent` (UserDefaults)
    - added helpers for target/current allocation, deviation, and status text
  - `DashboardView`:
    - added `rebalanceMonitorSection` above recent records
    - displays:
      - editable threshold via `Stepper`
      - fixed target config text: 股票25% 债券25% 黄金25% 现金25%
      - per-asset deviation and status (`⚠ 平衡` / `✅ 正常`)
    - status switches to warning when absolute deviation exceeds threshold.

23. Upgraded monitor to editable status monitor + fixed deviation source
- Requirement:
  - Home page asset status should show current allocation.
  - Rename "再平衡监控" to "状态监控".
  - Target allocation should be editable.
  - Deviation display should be corrected.
- Changes:
  - `DashboardView`:
    - each asset card now shows current allocation (`占比`).
    - monitor section renamed to `状态监控`.
    - target allocation is now editable for stock/bond/gold/cash.
    - monitor row now shows current allocation + deviation + status.
  - `DataManager`:
    - target allocation moved from fixed constants to persisted editable values:
      - `targetStockPercent`, `targetBondPercent`, `targetGoldPercent`, `targetCashPercent`
    - deviation now compares current allocation against those editable targets.
    - policy engine now uses normalized target fractions derived from editable targets.

24. Fixed allocation chart source + strict 100% target validation + monitor visual upgrade
- Requirement:
  - Fix incorrect allocation display in charts.
  - Ensure target allocation sum is 100%; otherwise show configuration error.
  - Add icons in target configuration rows and improve monitor aesthetics.
- Changes:
  - `ChartView`:
    - allocation chart now uses latest record in selected range (current state), not average over history.
    - fallback uses current allocation from `DataManager` when no filtered records are available.
  - `DataManager`:
    - added `targetTotalPercent`, `isTargetAllocationValid`, `targetAllocationValidationMessage`.
  - `DashboardView` status monitor:
    - improved card layout/sections/chips for readability.
    - target ratio rows now include asset icons.
    - explicit validation error banner shown when target sum != 100%.
    - status row uses `⚠ 配置` when target config invalid.
  - `PolicyView`:
    - all strategy execution buttons disabled when target config is invalid.
    - shows the same target-config error message at top of strategy page.

25. Status explanation on tap (`✅ 正常` / `⚠ 平衡` / `⚠ 配置`)
- Requirement:
  - In status monitor, tapping status should explain why it is normal and when it becomes `⚠ 平衡`.
- Implementation:
  - `DashboardView`:
    - status label is now tappable.
    - tapping opens alert with dynamic explanation using:
      - current allocation
      - target allocation
      - deviation
      - threshold
    - when target config invalid, explanation explicitly indicates target total must equal 100%.

26. Unified warning label to `⚠️平衡` + dashboard card layout refinement
- Requirement:
  - Replace `⚠ 平衡` with `⚠️平衡`.
  - Improve home UI where one asset card (e.g., gold) appears longer.
- Changes:
  - `DataManager.rebalanceStatus` now returns `⚠️平衡`.
  - Updated status explanation text in `DashboardView` to the same wording.
  - `DashboardView` asset cards:
    - added single-line truncation for asset name and code
    - enforced consistent card min height to keep grid cards visually aligned.

27. Fixed return line wrapping causing uneven asset card heights
- Error pattern:
  - Gold card could become taller because return text wrapped into two lines.
- Fix:
  - In `DashboardView` return row:
    - set `lineLimit(1)` for return amount and return rate
    - added `minimumScaleFactor(0.75)` to avoid wrapping under larger values
    - increased layout priority of return amount text.

28. Added privacy eye toggle on dashboard to hide monetary values
- Requirement:
  - Add eye icon on home page to hide all asset/return amount numbers.
  - Percentage-related numbers should remain visible.
- Implementation:
  - Added `eye / eye.slash` toggle in `DashboardView` toolbar.
  - Added local state `hideSensitiveNumbers`.
  - Masked currency amounts as `¥****` in:
    - total assets
    - total return amount
    - asset current value / principal / return amount
  - Kept percentage values visible (allocation %, return rate %, deviation %).

29. Top summary cards aligned in one row + fixed duplicate value under privacy mode
- Requirement:
  - Place total assets and total return cards in the same row.
  - Fix bug where current value could show both real number and `****` after tapping eye icon.
- Fix:
  - In `DashboardView`:
    - wrapped `totalAssetsCard` and `totalReturnCard` in one `HStack`.
    - tuned summary font sizes and scaling for side-by-side readability.
    - replaced current-value masking overlay with single source rendering via `displayCurrency(...)` to avoid duplicated text.

30. Summary-card polish + interactive chart values + return-rate display in records
- Requirement:
  - Make total assets / total return cards visually aligned with lower cards.
  - In chart screen, tapping data points should show exact values.
  - In records, show total return rate and per-asset return rates.
- Changes:
  - `DashboardView`:
    - summary cards now use consistent min height and improved typography scaling.
  - `ChartView`:
    - added point interaction via chart overlay (tap/drag).
    - added date-aligned `RuleMark` with annotation showing exact values.
    - return-rate chart shows selected date + exact return rate.
    - asset-value chart shows selected date + stock/bond/gold/cash exact values.
  - `RecordListView`:
    - list summary row now includes total return rate.
    - detail page now includes:
      - total return rate
      - each asset's return rate.

31. Reverted top-summary visual tweak + chart blank-tap reset behavior
- Requirement:
  - Restore total assets/total return cards to previous appearance.
  - After selecting chart point details, tapping blank area should restore default chart state.
- Changes:
  - `DashboardView`:
    - reverted top summary card typography/height tweak to previous style.
  - `ChartView`:
    - added selection hit-distance check against nearest data point.
    - taps/drags outside plot area or far from points now clear `selectedRecord`.
    - chart returns to default appearance when no point is selected.

32. Chart selection reset changed to explicit button-only action
- Requirement:
  - Do not reset chart selection by blank-area tap; only reset when user taps a restore button.
- Changes:
  - `ChartView`:
    - removed blank-area auto-clear behavior.
    - keeps current selection when tapping outside points/plot area.
    - added `还原` button below chart (visible when a point is selected).
    - only tapping `还原` clears selected point and restores default view.

33. Default privacy mode on every app open
- Requirement:
  - Asset amounts should be hidden by default each time app opens.
- Changes:
  - `DashboardView`:
    - initialized `hideSensitiveNumbers` as `true`.
    - added `.onAppear { hideSensitiveNumbers = true }` to enforce default hidden state whenever dashboard appears.

34. Added configurable record reminder (daily / weekly)
- Requirement:
  - Add a reminder button so user can set daily reminder (e.g. every day 10:00) or weekly reminder (e.g. Friday 22:00), not mandatory every day.
- Changes:
  - Added new view: `Views/ReminderSettingsView.swift`
    - local notification toggle (`启用提醒`)
    - frequency selection (`每天` / `每周`)
    - weekly weekday selection
    - custom reminder time selection
    - immediate update button for manual re-schedule
    - persistent settings via `@AppStorage`:
      - enable state, frequency, hour, minute, weekday
    - requests notification permission when enabling
    - creates repeating `UNCalendarNotificationTrigger` based on chosen rule
    - disables reminder and shows message when permission is denied
  - `DashboardView`:
    - added `记录提醒` entry card above recent records
    - tap to navigate to reminder settings page.

35. Added "next reminder time" display in reminder settings
- Requirement:
  - Show next scheduled trigger time so user can verify reminder rule is effective.
- Changes:
  - `ReminderSettingsView`:
    - added `下次提醒时间` section.
    - reads pending notification requests and resolves `UNCalendarNotificationTrigger.nextTriggerDate()` for app reminder identifier.
    - updates display on page appear and after schedule/update/remove operations.
    - status text fallback:
      - `未开启提醒`
      - `暂无待触发提醒`

36. Added project README for GitHub backup and onboarding
- Requirement:
  - Create a summary document describing app features and next improvement directions for GitHub upload/cloud backup.
- Changes:
  - Added `README.md` at project root, including:
    - app overview and feature list
    - tech stack and project structure
    - run instructions
    - local data/persistence notes
    - usage guidance
    - known limitations
    - roadmap items
    - suggested GitHub backup workflow.

### Anti-Regression Checklist
- Before commit, run project build and file diagnostics for edited Swift files.
- For all `ForEach(data)` usage, ensure element type conforms to `Identifiable` or pass explicit `id:`.
- In `@Published`/`ObservableObject` classes, ensure `Combine` is imported when required by compiler settings.
- For every view using `@EnvironmentObject`, verify its app entry root injects the object via `.environmentObject(...)`.
- In `String(format:)`, use `%@` for Swift `String` and `%f`/`%lf` for floating-point numbers; never use `%s` with Swift `String`.
- For `.decimalPad` inputs, always provide a keyboard dismissal path (e.g., toolbar `Done` button + `FocusState`).
- Parse user-entered amounts defensively (strip separators/currency symbols before `Double(...)`).
- For critical actions like save, provide immediate success feedback and prevent accidental repeated taps.
- On tab-based pages, avoid relying on `dismiss()` as the only success signal.
- In tab-root pages, avoid modal-only controls like cancellation actions unless the view is actually presented modally.
- Avoid attaching broad `simultaneousGesture` to `Form`/container views if primary controls feel delayed.
- For save actions in keyboard-heavy forms, clear focus first and run save on next UI cycle.
- For numeric input screens, support multiple keyboard-dismiss paths: done button + blank tap + scroll.
- Validate card contrast in both light and dark appearance (background + border + shadow).
- For editable list/grid items, prefer in-place navigation to detail editors and persist changes via a single data manager path.
- For custom numeric/code input fields, explicitly configure keyboard/autofill behavior to minimize RTI session noise.
- If UI reads summary from `assets` but edits happen in `records`, add explicit synchronization after record mutations.
- For "default from previous value" toggles, never blindly overwrite user-entered values.
- For `UserDefaults`:
  - `array(forKey:)` for array payloads
  - `data(forKey:)` only for encoded `Data`
- For SwiftUI builder APIs (`Chart`, `Toolbar`, `LazyVGrid`), avoid custom/imagined signatures; use compiler-valid initializers.
- Prefer small reusable local helpers (e.g., `amountField`) when custom UI components are missing.
