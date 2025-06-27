//
//  RunnerWatchApp.swift
//  RunnerWatch Watch App
//
//  Created by 胡云飞 on 2025/6/24.
//

import SwiftUI
import AVFoundation
import WatchKit

@main
struct RunnerWatch_Watch_AppApp: App {
    // 添加应用生命周期管理
    @WKApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    // 创建共享的TimerViewModel实例
    @StateObject private var timerViewModel = TimerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerViewModel)
        }
    }
}

// 创建AppDelegate管理应用程序生命周期
class AppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        setupDefaultSettings()
        setupAudioSession()
    }
    
    // 设置默认值
    private func setupDefaultSettings() {
        // 如果没有设置语速，设置默认值
        if UserDefaults.standard.float(forKey: "speechRate") == 0 {
            UserDefaults.standard.set(0.5, forKey: "speechRate")
        }
        
        // 设置默认语言代码
        if UserDefaults.standard.string(forKey: "languageCode") == nil {
            UserDefaults.standard.set("zh-CN", forKey: "languageCode")
        }
    }
    
    // 设置音频会话
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
        }
    }
}
