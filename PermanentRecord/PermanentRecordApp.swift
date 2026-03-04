//
//  PermanentRecordApp.swift
//  应用入口
//

import SwiftUI

@main
struct PermanentRecordApp: App {
    @StateObject private var dataManager = DataManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                // Dashboard Tab
                NavigationView {
                    DashboardView()
                }
                .tabItem {
                    Label("首页", systemImage: "chart.bar.fill")
                }

                // Records Tab
                NavigationView {
                    RecordListView()
                }
                .tabItem {
                    Label("记录", systemImage: "list.bullet.rectangle")
                }

                // Charts Tab
                NavigationView {
                    ChartView()
                }
                .tabItem {
                    Label("图表", systemImage: "chart.xyaxis.line")
                }

                // Policy Tab
                NavigationView {
                    PolicyView()
                }
                .tabItem {
                    Label("策略", systemImage: "slider.horizontal.3")
                }

                // Add Record Tab
                NavigationView {
                    AddRecordView()
                }
                .tabItem {
                    Label("添加", systemImage: "plus")
                }
            }
            .environmentObject(dataManager)
        }
    }
}
