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
            // 当语言改变时，重新加载可用语音
            loadAvailableVoices()
        }
    }
    
    @Published var speechRate: Double = 0.5 {
        didSet {
            UserDefaults.standard.set(speechRate, forKey: "speechRate")
        }
    }
    
    @Published var selectedVoice: String = "" {
        didSet {
            UserDefaults.standard.set(selectedVoice, forKey: "selectedVoiceIdentifier")
        }
    }
    
    @Published var timerHistory: [TimerHistory] = []
    @Published var availableVoices: [VoiceOption] = []
    @Published var allSupportedLanguages: [String] = []
    
    let voiceGenders = ["男声", "女声"]
    let languages = ["中文 (普通话)", "英语 (美国)", "英语 (英国)"]
    let languageCodes = ["zh-CN", "en-US", "en-GB"]
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let settingsManager = SettingsManager.shared
    
    init() {
        // 加载用户设置
        selectedVoiceGender = UserDefaults.standard.integer(forKey: "voiceGender")
        selectedLanguage = UserDefaults.standard.integer(forKey: "language")
        speechRate = UserDefaults.standard.double(forKey: "speechRate")
        
        if speechRate == 0 {
            speechRate = 0.5
        }
        
        // 加载选中的语音标识符
        if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") {
            selectedVoice = savedIdentifier
        }
        
        // 加载历史记录
        loadHistory()
        
        // 设置音频会话
        setupAudioSession()
        
        // 加载所有支持的语言
        loadSupportedLanguages()
        
        // 加载可用语音选项
        loadAvailableVoices()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    func getVoiceCode() -> String {
        return settingsManager.getLanguageCode()
    }
    
    func testVoice() {
        // 根据当前选择的语言，使用不同的测试文本
        let testText: String
        let languageCode = getVoiceCode()
        
        switch languageCode {
        case "zh-CN":
            testText = "这是一个测试"
        case "en-US":
            testText = "This is a test"
        case "en-GB":
            testText = "This is a test"
        default:
            testText = "This is a test"
        }
        
        let utterance = AVSpeechUtterance(string: testText)
        
        // 使用SettingsManager获取语音设置
        if let voice = settingsManager.getSelectedVoice() {
            utterance.voice = voice
            print("使用语音: \(voice.name), 语言: \(voice.language)")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            print("使用默认语音, 语言: \(languageCode)")
        }
        
        utterance.rate = Float(speechRate)
        utterance.volume = 1.0  // 设置最大音量
        
        // 确保音频会话处于活动状态
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("激活音频会话失败: \(error.localizedDescription)")
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    // 加载所有支持的语言
    private func loadSupportedLanguages() {
        allSupportedLanguages = settingsManager.getAllSupportedLanguages()
    }
    
    // 加载可用的语音选项
    func loadAvailableVoices() {
        // 获取当前语言代码
        let currentLanguageCode = getVoiceCode()
        print("正在加载语言代码为 \(currentLanguageCode) 的语音")
        
        // 使用SettingsManager获取可用语音
        let voices = settingsManager.getAvailableVoices(forLanguage: currentLanguageCode)
        
        if voices.isEmpty {
            print("警告：未找到语言为 \(currentLanguageCode) 的语音")
            // 尝试获取所有语音
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            print("系统总共有 \(allVoices.count) 个语音")
            
            // 打印所有可用的语言
            let languages = Set(allVoices.map { $0.language })
            print("可用语言: \(languages.joined(separator: ", "))")
        } else {
            print("找到 \(voices.count) 个语言为 \(currentLanguageCode) 的语音")
        }
        
        // 转换为VoiceOption模型
        availableVoices = voices.map { voice in
            return VoiceOption(
                id: UUID(),
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                gender: voice.gender == .male ? "男声" : "女声",
                quality: getQualityText(voice.quality)
            )
        }
        
        // 按质量和名称排序
        availableVoices.sort { (a, b) -> Bool in
            if a.quality == b.quality {
                return a.name < b.name
            }
            
            // 优先显示高质量语音
            let qualityOrder: [String: Int] = ["高级": 0, "增强": 1, "默认": 2, "未知": 3]
            return (qualityOrder[a.quality] ?? 3) < (qualityOrder[b.quality] ?? 3)
        }
        
        // 如果选中的语音不在当前语言的可用语音中，重置选中的语音
        if !availableVoices.isEmpty && !availableVoices.contains(where: { $0.identifier == selectedVoice }) {
            // 重置选中的语音为当前语言的第一个语音
            if let firstVoice = availableVoices.first {
                selectedVoice = firstVoice.identifier
                UserDefaults.standard.set(selectedVoice, forKey: "selectedVoiceIdentifier")
                print("重置选中的语音为: \(firstVoice.name)")
            }
        }
    }
    
    private func getQualityText(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .default: return "默认"
        case .enhanced: return "增强"
        case .premium: return "高级"
        @unknown default: return "未知"
        }
    }
    
    // 使用SettingsManager管理历史记录
    func addHistoryItem(totalTime: Int, lapDistance: Int, lapTime: Int, completedLaps: Int) {
        settingsManager.saveHistoryItem(totalTime: totalTime, lapDistance: lapDistance, lapTime: lapTime, completedLaps: completedLaps)
        loadHistory() // 重新加载历史记录以更新UI
    }
    
    func clearHistory() {
        settingsManager.clearHistory()
        loadHistory() // 重新加载历史记录以更新UI
    }
    
    private func loadHistory() {
        timerHistory = settingsManager.getHistory()
    }
}

// 语音选项模型
struct VoiceOption: Identifiable {
    let id: UUID
    let identifier: String
    let name: String
    let language: String
    let gender: String
    let quality: String
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("语音设置").tag(0)
                    Text("历史记录").tag(1)
                    Text("关于").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
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
            .navigationBarTitleDisplayMode(.inline) // 小屏幕设备使用内联标题
        }
    }
}

struct VoiceSettingsTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Form {
            Section(header: Text("语言选择").font(.subheadline)) {
                Picker("语言", selection: $viewModel.selectedLanguage) {
                    ForEach(0..<viewModel.languages.count) { index in
                        Text(viewModel.languages[index]).tag(index)
                    }
                }
            }
            
            Section(header: Text("可用语音").font(.subheadline)) {
                if viewModel.availableVoices.isEmpty {
                    Text("正在加载语音...")
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(viewModel.availableVoices) { voice in
                            VoiceRow(voice: voice, isSelected: viewModel.selectedVoice == voice.identifier) {
                                viewModel.selectedVoice = voice.identifier
                                UserDefaults.standard.set(voice.identifier, forKey: "selectedVoiceIdentifier")
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .frame(height: 250) // 使用固定高度
                }
            }
            
            Section(header: Text("语速设置").font(.subheadline)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("语速: \(Int(viewModel.speechRate * 100))%")
                    Slider(value: $viewModel.speechRate, in: 0.1...1.0, step: 0.1)
                }
                .padding(.vertical, 4)
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
        .onAppear {
            // 加载用户选择的语音
            if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") {
                viewModel.selectedVoice = savedIdentifier
            }
        }
    }
}

struct HistoryTabView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        Group {
            if viewModel.timerHistory.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无历史记录")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                VStack {
                    List {
                        ForEach(viewModel.timerHistory) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(item.date))
                                    .font(.headline)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("总时间: \(formatTime(item.totalTime))")
                                        Text("圈距离: \(item.lapDistance) 米")
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
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
                            .padding(8)
                    }
                    .padding(.bottom, 8)
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
        .listStyle(InsetGroupedListStyle()) // 使用更紧凑的列表样式
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 