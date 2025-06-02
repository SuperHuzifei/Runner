//
//  SettingsView.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI
import AVFoundation

struct TimerHistory: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var totalTime: Int
    var lapDistance: Int
    var lapTime: Int
    var completedLaps: Int
}

class SettingsViewModel: ObservableObject {
    @Published var selectedVoiceGender: Int = 0 {
        didSet {
            UserDefaults.standard.set(selectedVoiceGender, forKey: "voiceGender")
        }
    }
    
    @Published var selectedLanguage: Int = 0 {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "language")
        }
    }
    
    @Published var speechRate: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speechRate")
        }
    }
    
    @Published var timerHistory: [TimerHistory] = []
    
    let voiceGenders = ["男声", "女声"]
    let languages = ["中文 (普通话)", "英语 (美国)", "英语 (英国)"]
    let languageCodes = ["zh-CN", "en-US", "en-GB"]
    
    init() {
        // 加载用户设置
        selectedVoiceGender = UserDefaults.standard.integer(forKey: "voiceGender")
        selectedLanguage = UserDefaults.standard.integer(forKey: "language")
        speechRate = UserDefaults.standard.double(forKey: "speechRate")
        
        if speechRate == 0 {
            speechRate = 0.5
        }
        
        // 加载历史记录
        loadHistory()
    }
    
    func getVoiceCode() -> String {
        return languageCodes[selectedLanguage]
    }
    
    func testVoice() {
        let utterance = AVSpeechUtterance(string: "这是一个测试")
        utterance.voice = AVSpeechSynthesisVoice(language: getVoiceCode())
        utterance.rate = Float(speechRate)
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
    func addHistoryItem(totalTime: Int, lapDistance: Int, lapTime: Int, completedLaps: Int) {
        let newItem = TimerHistory(
            date: Date(),
            totalTime: totalTime,
            lapDistance: lapDistance,
            lapTime: lapTime,
            completedLaps: completedLaps
        )
        
        timerHistory.append(newItem)
        saveHistory()
    }
    
    func clearHistory() {
        timerHistory.removeAll()
        saveHistory()
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "timerHistory") {
            if let decoded = try? JSONDecoder().decode([TimerHistory].self, from: data) {
                timerHistory = decoded
            }
        }
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(timerHistory) {
            UserDefaults.standard.set(encoded, forKey: "timerHistory")
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("", selection: $selectedTab) {
                    Text("语音设置").tag(0)
                    Text("历史记录").tag(1)
                    Text("关于").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                TabView(selection: $selectedTab) {
                    VoiceSettingsTabView(viewModel: viewModel)
                        .tag(0)
                    
                    HistoryTabView(viewModel: viewModel)
                        .tag(1)
                    
                    AboutTabView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("设置")
        }
    }
}

struct VoiceSettingsTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section(header: Text("语音设置")) {
                Picker("声音性别", selection: $viewModel.selectedVoiceGender) {
                    ForEach(0..<viewModel.voiceGenders.count) { index in
                        Text(viewModel.voiceGenders[index]).tag(index)
                    }
                }
                
                Picker("语言", selection: $viewModel.selectedLanguage) {
                    ForEach(0..<viewModel.languages.count) { index in
                        Text(viewModel.languages[index]).tag(index)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("语速: \(Int(viewModel.speechRate * 100))%")
                    Slider(value: $viewModel.speechRate, in: 0.1...1.0, step: 0.1)
                }
            }
            
            Section {
                Button(action: {
                    viewModel.testVoice()
                }) {
                    Text("测试语音")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct HistoryTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack {
            if viewModel.timerHistory.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无历史记录")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.timerHistory) { item in
                        VStack(alignment: .leading) {
                            Text(formatDate(item.date))
                                .font(.headline)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("总时间: \(formatTime(item.totalTime))")
                                    Text("圈距离: \(item.lapDistance) 米")
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("每圈: \(item.lapTime) 秒")
                                    Text("完成圈数: \(item.completedLaps)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button(action: {
                    viewModel.clearHistory()
                }) {
                    Text("清除历史记录")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d分%02d秒", minutes, remainingSeconds)
    }
}

struct AboutTabView: View {
    var body: some View {
        Form {
            Section(header: Text("应用信息")) {
                HStack {
                    Text("应用名称")
                    Spacer()
                    Text("CountDownVoiceTimer")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Apple Watch")) {
                if #available(iOS 16.0, *) {
                    HStack {
                        Text("支持状态")
                        Spacer()
                        Text("已启用")
                            .foregroundColor(.green)
                    }
                } else {
                    HStack {
                        Text("支持状态")
                        Spacer()
                        Text("不可用 (需要iOS 16+)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("开发者信息")) {
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("胡云飞")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "mailto:support@example.com")!) {
                    HStack {
                        Text("联系我们")
                        Spacer()
                        Image(systemName: "envelope")
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 