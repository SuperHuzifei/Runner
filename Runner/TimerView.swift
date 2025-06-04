//
//  TimerView.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI
import AVFoundation

class TimerViewModel: ObservableObject {
    @Published var totalMinutes: Int = 4
    @Published var totalSeconds: Int = 25
    @Published var totalDistance: Int = 1000  // 新增总距离，默认1000米
    @Published var lapDistance: Int = 200
    @Published var lapTime: Int = 53
    
    @Published var isRunning: Bool = false
    @Published var remainingTime: Int = 0
    @Published var currentLapRemainingSeconds: Int = 0  // 修改为当前圈剩余秒数
    @Published var currentLap: Int = 1
    
    private var timer: Timer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()
    private let settingsManager = SettingsManager.shared
    
    // 后台任务标识符
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        setupAudioSession()
        registerForNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        endBackgroundTask()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
        }
    }
    
    private func registerForNotifications() {
        // 监听应用进入后台的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // 监听应用进入前台的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // 监听音频会话中断的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        beginBackgroundTask()
        
        // 确保音频会话在后台仍然活跃
        do {
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("在后台激活音频会话失败: \(error.localizedDescription)")
        }
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundTask()
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            // 中断开始，可能需要暂停计时器
            if isRunning {
                pauseTimer()
            }
        } else if type == .ended {
            // 中断结束，检查是否应该恢复
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // 尝试重新激活音频会话
                    do {
                        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                        // 如果之前是运行状态，可以选择恢复
                        // startTimer()
                    } catch {
                        print("中断后重新激活音频会话失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func beginBackgroundTask() {
        // 结束之前的后台任务（如果有）
        endBackgroundTask()
        
        // 开始一个新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    func calculateLapTime() {
        // 确保总距离和每圈距离都大于0
        guard totalDistance > 0 && lapDistance > 0 else {
            return
        }
        
        // 计算总圈数
        let totalLaps = Double(totalDistance) / Double(lapDistance)
        
        // 计算总时间（秒）
        let totalTimeInSeconds = totalMinutes * 60 + totalSeconds
        
        // 计算每圈时间 = 总时间 / 总圈数
        lapTime = Int(Double(totalTimeInSeconds) / totalLaps)
    }
    
    func startTimer() {
        if !isRunning {
            isRunning = true
            remainingTime = totalMinutes * 60 + totalSeconds
            currentLapRemainingSeconds = lapTime  // 初始化为每圈总时间，从每圈时间开始倒数
            
            // 确保音频会话处于活动状态
            setupAudioSession()
            
            // 如果应用在后台，开始后台任务
            if UIApplication.shared.applicationState == .background {
                beginBackgroundTask()
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                    
                    // 播报当前圈内剩余秒数
                    self.speakCurrentSecond()
                    
                    // 更新当前圈内剩余秒数
                    self.currentLapRemainingSeconds -= 1
                    if self.currentLapRemainingSeconds <= 0 {
                        // 当前圈结束，开始下一圈
                        self.currentLapRemainingSeconds = self.lapTime
                        self.currentLap += 1
                    }
                } else {
                    self.pauseTimer()
                    // 播报完成提示
                    self.speakMessage("计时完成")
                }
            }
            
            // 确保计时器在后台运行
            RunLoop.current.add(timer!, forMode: .common)
        }
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        
        // 如果是在后台暂停的，结束后台任务
        endBackgroundTask()
    }
    
    func resetTimer() {
        pauseTimer()
        remainingTime = totalMinutes * 60 + totalSeconds
        currentLapRemainingSeconds = lapTime  // 重置为每圈总时间
        currentLap = 1
    }
    
    func speakCurrentSecond() {
        let utterance = AVSpeechUtterance(string: "\(currentLapRemainingSeconds)")
        
        // 使用设置中的语音配置
        configureUtterance(utterance)
        
        // 停止当前正在播放的语音
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    func speakMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        
        // 使用设置中的语音配置
        configureUtterance(utterance)
        
        speechSynthesizer.speak(utterance)
    }
    
    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        // 获取当前语言代码
        let languageCode = settingsManager.getLanguageCode()
        
        // 获取选择的语音
        if let voice = settingsManager.getSelectedVoice() {
            // 确保语音与当前语言匹配
            if voice.language.hasPrefix(languageCode) {
            utterance.voice = voice
                print("使用语音: \(voice.name), 语言: \(voice.language)")
            } else {
                // 如果选择的语音与当前语言不匹配，尝试找到匹配的语音
                print("选择的语音(\(voice.language))与当前语言(\(languageCode))不匹配，尝试查找匹配的语音")
                let matchingVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == languageCode }
                if let firstMatch = matchingVoices.first {
                    utterance.voice = firstMatch
                    print("找到匹配的语音: \(firstMatch.name)")
                } else {
                    // 如果没有找到匹配的语音，使用默认语音
                    utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
                    print("未找到匹配的语音，使用默认语音")
                }
            }
        } else {
            // 如果没有选择语音，使用默认语音
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
            print("未选择语音，使用默认语音，语言: \(languageCode)")
        }
        
        // 获取语速
        utterance.rate = settingsManager.getSpeechRate()
        utterance.volume = 1.0
    }
}

struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 设置区域
                    VStack(spacing: 20) {
                        HStack {
                            Text("总时间:")
                                .font(.headline)
                            
                            Spacer()
                            
                            HStack {
                                Picker("分钟", selection: $viewModel.totalMinutes) {
                                    ForEach(0..<60) { minute in
                                        Text("\(minute)").tag(minute)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 60)
                                .clipped()
                                
                                Text("分")
                                
                                Picker("秒钟", selection: $viewModel.totalSeconds) {
                                    ForEach(0..<60) { second in
                                        Text("\(second)").tag(second)
                                    }
                                }
                                .pickerStyle(WheelPickerStyle())
                                .frame(width: 60)
                                .clipped()
                                
                                Text("秒")
                            }
                        }
                        
                        HStack {
                            Text("总距离:")
                                .font(.headline)
                            
                            Spacer()
                            
                            HStack {
                                TextField("总距离", value: $viewModel.totalDistance, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                
                                Text("米")
                            }
                        }
                        
                        HStack {
                            Text("每圈距离:")
                                .font(.headline)
                            
                            Spacer()
                            
                            HStack {
                                TextField("距离", value: $viewModel.lapDistance, formatter: NumberFormatter())
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                
                                Text("米")
                            }
                        }
                        
                        Button(action: {
                            viewModel.calculateLapTime()
                        }) {
                            Text("计算每圈时间")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        HStack {
                            Text("每圈时间:")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("\(viewModel.lapTime) 秒")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        // 显示总圈数
                        if viewModel.totalDistance > 0 && viewModel.lapDistance > 0 {
                            HStack {
                                Text("总圈数:")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f", Double(viewModel.totalDistance) / Double(viewModel.lapDistance)))
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // 倒计时显示
                    VStack(spacing: 10) {
                        Text("剩余时间")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            TimeDigitView(value: viewModel.remainingTime / 60)
                            Text(":")
                                .font(.system(size: 40, weight: .bold))
                            TimeDigitView(value: viewModel.remainingTime % 60)
                        }
                        
                        HStack {
                            Text("当前圈数: \(viewModel.currentLap)")
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("圈内倒计时: \(viewModel.currentLapRemainingSeconds)")
                                .font(.headline)
                        }
                        .padding(.top)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    
                    // 控制按钮
                    HStack(spacing: 20) {
                        Button(action: {
                            if viewModel.isRunning {
                                viewModel.pauseTimer()
                            } else {
                                viewModel.startTimer()
                            }
                        }) {
                            Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(viewModel.isRunning ? Color.orange : Color.green)
                                .clipShape(Circle())
                        }
                        
                        Button(action: {
                            viewModel.resetTimer()
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("计时")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "speaker.wave.2")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                VoiceSettingsView()
            }
        }
    }
}

struct TimeDigitView: View {
    let value: Int
    
    var body: some View {
        Text(String(format: "%02d", value))
            .font(.system(size: 60, weight: .bold, design: .rounded))
            .frame(width: 100)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
    }
}

struct VoiceSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var searchText = ""
    
    var filteredVoices: [VoiceOption] {
        if searchText.isEmpty {
            return viewModel.availableVoices
        } else {
            return viewModel.availableVoices.filter {
                $0.name.lowercased().contains(searchText.lowercased()) ||
                $0.gender.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
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
                        // 添加一个搜索栏
                        if #available(iOS 15.0, *) {
                            List {
                                ForEach(filteredVoices) { voice in
                                    VoiceRow(voice: voice, isSelected: viewModel.selectedVoice == voice.identifier) {
                                        viewModel.selectedVoice = voice.identifier
                                        UserDefaults.standard.set(voice.identifier, forKey: "selectedVoiceIdentifier")
                                    }
                                }
                            }
                            .listStyle(PlainListStyle())
                            .searchable(text: $searchText, prompt: "搜索语音")
                            .frame(height: 250) // 使用固定高度
                        } else {
                            TextField("搜索语音", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.vertical, 4) // 减小垂直内边距
                            
                            List {
                                ForEach(filteredVoices) { voice in
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
                }
                
                Section(header: Text("语速设置").font(.subheadline)) {
                    VStack(alignment: .leading) {
                        Text("语速: \(Int(viewModel.speechRate * 100))%")
                        Slider(value: $viewModel.speechRate, in: 0.1...1.0, step: 0.1)
                    }
                    .padding(.vertical, 4) // 减小垂直内边距
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
            .navigationTitle("语音设置")
            .onAppear {
                // 加载用户选择的语音
                if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier") {
                    viewModel.selectedVoice = savedIdentifier
                }
            }
        }
    }
}

struct VoiceRow: View {
    let voice: VoiceOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) { // 减小间距
                    Text(voice.name)
                        .fontWeight(isSelected ? .bold : .regular)
                        .font(.system(size: 15)) // 减小字体大小
                    
                    Text("\(voice.gender) • \(getLanguageName(voice.language)) • \(voice.quality)")
                        .font(.caption2) // 使用更小的字体
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2) // 减小垂直内边距
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getLanguageName(_ code: String) -> String {
        switch code {
        case "zh-CN": return "中文 (普通话)"
        case "en-US": return "美式英语"
        case "en-GB": return "英式英语"
        case "en-AU": return "澳式英语"
        case "en-IE": return "爱尔兰英语"
        case "en-ZA": return "南非英语"
        case "en-IN": return "印度英语"
        default: return code
        }
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
} 