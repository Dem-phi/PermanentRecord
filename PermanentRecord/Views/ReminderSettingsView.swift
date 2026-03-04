//
//  ReminderSettingsView.swift
//  提醒设置
//

import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    private enum Frequency: String, CaseIterable, Identifiable {
        case daily = "daily"
        case weekly = "weekly"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily: return "每天"
            case .weekly: return "每周"
            }
        }
    }

    @AppStorage("reminder_enabled") private var isEnabled = false
    @AppStorage("reminder_frequency") private var frequencyRawValue = Frequency.daily.rawValue
    @AppStorage("reminder_hour") private var hour = 22
    @AppStorage("reminder_minute") private var minute = 0
    @AppStorage("reminder_weekday") private var weekday = 6 // 周五

    @State private var selectedTime = Date()
    @State private var statusMessage = ""
    @State private var showStatus = false
    @State private var nextReminderText = "未开启提醒"

    private let notificationIdentifier = "permanentrecord.daily.record.reminder"

    private var selectedFrequency: Frequency {
        Frequency(rawValue: frequencyRawValue) ?? .daily
    }

    var body: some View {
        Form {
            Section("提醒开关") {
                Toggle("启用提醒", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, enabled in
                        if enabled {
                            scheduleReminder()
                        } else {
                            removeReminder()
                        }
                    }
            }

            Section("提醒规则") {
                Picker("频率", selection: $frequencyRawValue) {
                    ForEach(Frequency.allCases) { item in
                        Text(item.title).tag(item.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: frequencyRawValue) { _, _ in
                    if isEnabled { scheduleReminder() }
                }

                if selectedFrequency == .weekly {
                    Picker("星期", selection: Binding(
                        get: { weekday },
                        set: { newValue in
                            weekday = newValue
                            if isEnabled { scheduleReminder() }
                        }
                    )) {
                        Text("周日").tag(1)
                        Text("周一").tag(2)
                        Text("周二").tag(3)
                        Text("周三").tag(4)
                        Text("周四").tag(5)
                        Text("周五").tag(6)
                        Text("周六").tag(7)
                    }
                }

                DatePicker(
                    "时间",
                    selection: $selectedTime,
                    displayedComponents: [.hourAndMinute]
                )
                .onChange(of: selectedTime) { _, newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    hour = components.hour ?? 22
                    minute = components.minute ?? 0
                    if isEnabled { scheduleReminder() }
                }
            }

            Section {
                Button("立即更新提醒") {
                    scheduleReminder()
                }
                .disabled(!isEnabled)
            } footer: {
                Text("示例：每天 22:00 提醒，或每周五 22:00 提醒。")
            }

            Section("下次提醒时间") {
                Text(nextReminderText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("提醒设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提醒状态", isPresented: $showStatus) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
        .onAppear {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            selectedTime = Calendar.current.date(from: components) ?? Date()
            refreshNextReminderDisplay()
        }
    }

    private func scheduleReminder() {
        Task {
            let center = UNUserNotificationCenter.current()
            let granted = try await requestPermissionIfNeeded(center: center)
            guard granted else {
                await MainActor.run {
                    isEnabled = false
                    statusMessage = "未获得通知权限，请在系统设置中允许通知后再启用提醒。"
                    showStatus = true
                }
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

            let content = UNMutableNotificationContent()
            content.title = "添加记录提醒"
            content.body = "现在是你设定的提醒时间，记得更新今日资产记录。"
            content.sound = .default

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            if selectedFrequency == .weekly {
                dateComponents.weekday = weekday
            }

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: notificationIdentifier,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                await MainActor.run {
                    statusMessage = currentRuleDescription()
                    showStatus = true
                }
                refreshNextReminderDisplay()
            } catch {
                await MainActor.run {
                    statusMessage = "提醒设置失败：\(error.localizedDescription)"
                    showStatus = true
                }
                refreshNextReminderDisplay()
            }
        }
    }

    private func removeReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        statusMessage = "已关闭提醒。"
        showStatus = true
        nextReminderText = "未开启提醒"
    }

    private func requestPermissionIfNeeded(center: UNUserNotificationCenter) async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func currentRuleDescription() -> String {
        if selectedFrequency == .daily {
            return String(format: "已设置每日提醒：每天 %02d:%02d。", hour, minute)
        } else {
            return String(format: "已设置每周提醒：%@ %02d:%02d。", weekdayTitle(weekday), hour, minute)
        }
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "周日"
        case 2: return "周一"
        case 3: return "周二"
        case 4: return "周三"
        case 5: return "周四"
        case 6: return "周五"
        case 7: return "周六"
        default: return "周五"
        }
    }

    private func refreshNextReminderDisplay() {
        Task {
            let center = UNUserNotificationCenter.current()
            let requests = await center.pendingNotificationRequests()
            guard isEnabled else {
                await MainActor.run {
                    nextReminderText = "未开启提醒"
                }
                return
            }
            guard let request = requests.first(where: { $0.identifier == notificationIdentifier }),
                  let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let nextDate = trigger.nextTriggerDate() else {
                await MainActor.run {
                    nextReminderText = "暂无待触发提醒"
                }
                return
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "yyyy-MM-dd EEEE HH:mm"
            let text = formatter.string(from: nextDate)

            await MainActor.run {
                nextReminderText = text
            }
        }
    }
}

#Preview {
    NavigationView {
        ReminderSettingsView()
    }
}
