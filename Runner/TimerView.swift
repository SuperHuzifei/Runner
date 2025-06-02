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
    @Published var lapDistance: Int = 200
    @Published var lapTime: Int = 53
    
    @Published var isRunning: Bool = false
    @Published var remainingTime: Int = 0
    @Published var currentLapSeconds: Int = 0
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
        let totalTimeInSeconds = totalMinutes * 60 + totalSeconds
        let numberOfLaps = Double(totalTimeInSeconds) / Double(lapTime)
        lapTime = Int(Double(totalTimeInSeconds) / round(numberOfLaps))
    }
    
    func startTimer() {
        if !isRunning {
            isRunning = true
            remainingTime = totalMinutes * 60 + totalSeconds
            currentLapSeconds = 1
            
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
                    
                    // 播报当前秒数
                    self.speakCurrentSecond()
                    
                    // 更新当前圈内秒数
                    self.currentLapSeconds += 1
                    if self.currentLapSeconds > self.lapTime {
                        self.currentLapSeconds = 1
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
        currentLapSeconds = 1
        currentLap = 1
    }
    
    func speakCurrentSecond() {
        let utterance = AVSpeechUtterance(string: "\(currentLapSeconds)")
        
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
        // 获取保存的设置
        let languageCode = settingsManager.getLanguageCode()
        let speechRate = settingsManager.getSpeechRate()
        
        // 设置语音参数
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = speechRate
        utterance.volume = 1.0
    }
}

// 单例管理器，用于在视图模型之间共享设置
class SettingsManager {
    static let shared = SettingsManager()
    
    private init() {}
    
    func getLanguageCode() -> String {
        let languages = ["zh-CN", "en-US", "en-GB"]
        let selectedLanguage = UserDefaults.standard.integer(forKey: "language")
        return selectedLanguage < languages.count ? languages[selectedLanguage] : "zh-CN"
    }
    
    func getSpeechRate() -> Float {
        let rate = UserDefaults.standard.double(forKey: "speechRate")
        return rate > 0 ? Float(rate) : 0.5
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
                            
                            Text("当前秒数: \(viewModel.currentLapSeconds)")
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
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("语音设置")
        }
    }
}

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        TimerView()
    }
} 