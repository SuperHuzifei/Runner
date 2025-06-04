//
//  TimerView.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import SwiftUI
import AVFoundation

class TimerViewModel: ObservableObject {
    @Published var totalMinutes: Int = 4 {
        didSet {
            calculateLapTime()
            if !isRunning {
                updateRemainingTime()
            }
        }
    }
    @Published var totalSeconds: Int = 25 {
        didSet {
            calculateLapTime()
            if !isRunning {
                updateRemainingTime()
            }
        }
    }
    @Published var totalDistance: Int = 1000 {
        didSet {
            validateCurrentLap()
            calculateLapTime()
        }
    }
    @Published var lapDistance: Int = 200 {
        didSet {
            validateCurrentLap()
            calculateLapTime()
        }
    }
    @Published var lapTime: Int = 53
    
    @Published var isRunning: Bool = false
    @Published var remainingTime: Int = 0
    @Published var currentLapRemainingSeconds: Int = 0  // 修改为当前圈剩余秒数
    @Published var currentLap: Int = 0  // 修改初始圈数为0
    @Published var isTimerCompleted: Bool = false  // 添加标记表示计时已完成
    
    // 新增提前完成时间相关的属性
    @Published var savedExtraTime: Int = 0  // 已保存的提前完成时间（秒）
    @Published var isInExtraTime: Bool = false  // 是否在额外时间中
    @Published var lapSavedTimes: [Int] = []  // 存储每圈节省的时间
    
    // 新增正向计时相关属性
    @Published var isCountingUp: Bool = false  // 是否正在正向计时
    @Published var countUpSeconds: Int = 0  // 正向计时的秒数
    
    // 新增模式选择属性
    @Published var selectedMode: Int = 0 // 0: 计时模式, 1: 配置模式
    
    // 新增错误提示属性
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""
    
    private var timer: Timer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let audioSession = AVAudioSession.sharedInstance()
    private let settingsManager = SettingsManager.shared
    
    // 后台任务标识符
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init() {
        setupAudioSession()
        registerForNotifications()
        updateRemainingTime() // 初始化剩余时间
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
            // 当参数无效时，设置默认值，避免显示错误数据
            if totalDistance <= 0 || lapDistance <= 0 {
                lapTime = 0
            }
            return
        }
        
        // 计算总圈数
        let totalLaps = Double(totalDistance) / Double(lapDistance)
        
        // 计算总时间（秒）
        let totalTimeInSeconds = totalMinutes * 60 + totalSeconds
        
        // 防止总时间为0导致计算问题
        if totalTimeInSeconds <= 0 {
            lapTime = 0
            return
        }
        
        // 计算每圈时间 = 总时间 / 总圈数
        lapTime = Int(Double(totalTimeInSeconds) / totalLaps)
        
        // 验证当前圈数
        validateCurrentLap()
    }
    
    // 新增方法：更新剩余时间
    private func updateRemainingTime() {
        remainingTime = totalMinutes * 60 + totalSeconds
    }
    
    func startTimer() {
        if !isRunning && !isTimerCompleted {  // 添加对计时完成状态的检查
            isRunning = true
            remainingTime = totalMinutes * 60 + totalSeconds
            currentLapRemainingSeconds = lapTime  // 初始化为每圈总时间，从每圈时间开始倒数
            isCountingUp = false  // 重置正向计时状态
            countUpSeconds = 0  // 重置正向计时秒数
            
            // 确保音频会话处于活动状态
            setupAudioSession()
            
            // 如果应用在后台，开始后台任务
            if UIApplication.shared.applicationState == .background {
                beginBackgroundTask()
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                // 更新总剩余时间，但不低于0
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                }
                
                // 如果正在正向计时，不播报倒计时秒数
                if !self.isCountingUp {
                    // 播报当前圈内剩余秒数
                    self.speakCurrentSecond()
                }
                
                // 更新计时状态
                if self.isCountingUp {
                    // 如果已经在正向计时，增加正向计时秒数
                    self.countUpSeconds += 1
                } else {
                    // 正常倒计时
                    self.currentLapRemainingSeconds -= 1
                    if self.currentLapRemainingSeconds <= 0 {
                        // 当前圈倒计时结束
                        if self.shouldEnterExtraTime() {
                            // 进入额外时间模式
                            self.enterExtraTimeMode()
                        } else {
                            // 开始正向计时，而不是自动跳到下一圈
                            self.isCountingUp = true
                            self.countUpSeconds = 0
                            self.speakMessage("时间到，请尽快完成本圈")
                        }
                    }
                }
                
                // 只有在额外时间模式下且额外时间用完时才结束计时
                if self.isInExtraTime && self.currentLapRemainingSeconds <= 0 {
                    self.pauseTimer()
                    self.isTimerCompleted = true  // 标记计时已完成
                    self.speakMessage("额外时间用完，计时完成")
                }
            }
            
            // 确保计时器在后台运行
            RunLoop.current.add(timer!, forMode: .common)
        }
    }
    
    // 检查是否应该进入额外时间模式
    private func shouldEnterExtraTime() -> Bool {
        // 当前圈是最后一圈，且有额外时间可用
        return !isInExtraTime && currentLap == (totalLaps() - 1) && savedExtraTime > 0
    }
    
    // 进入额外时间模式
    private func enterExtraTimeMode() {
        isInExtraTime = true
        currentLapRemainingSeconds = savedExtraTime
        speakMessage("您提前完成了训练，获得额外\(savedExtraTime)秒时间")
    }
    
    // 计算总圈数
    func totalLaps() -> Int {
        guard lapDistance > 0 else { return 0 }
        // 总圈数至少为1
        return max(1, Int(ceil(Double(totalDistance) / Double(lapDistance))))
    }
    
    // 添加保存当前圈剩余时间的方法
    func saveCurrentLapRemainingTime() {
        if isRunning {
            var savedTime: Int = 0
            
            if isCountingUp {
                // 正在正向计时，表示超时了
                savedTime = -countUpSeconds  // 负数表示超时
                isCountingUp = false  // 重置正向计时状态
                countUpSeconds = 0  // 重置正向计时秒数
            } else {
                // 常规情况：还在倒计时中
                savedTime = currentLapRemainingSeconds
            }
            
            // 累加保存剩余时间
            savedExtraTime += savedTime
            
            // 添加到每圈节省时间数组
            lapSavedTimes.append(savedTime)
            
            // 开始下一圈
            currentLapRemainingSeconds = lapTime
            
            // 只有当当前圈数小于总圈数-1时才增加圈数
            if currentLap < totalLaps() - 1 {
                currentLap += 1
            } else {
                // 如果已经是最后一圈，则结束计时
                pauseTimer()
                isTimerCompleted = true
                
                // 播报总结果
                if savedExtraTime > 0 {
                    speakMessage("计时完成，总共节省\(savedExtraTime)秒")
                } else if savedExtraTime < 0 {
                    speakMessage("计时完成，总共超时\(abs(savedExtraTime))秒")
                } else {
                    speakMessage("计时完成")
                }
            }
        }
    }
    
    // 清空保存的额外时间
    func resetSavedExtraTime() {
        savedExtraTime = 0
        lapSavedTimes.removeAll()  // 清空每圈节省时间数组
        isInExtraTime = false
        isCountingUp = false  // 重置正向计时状态
        countUpSeconds = 0  // 重置正向计时秒数
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
        currentLap = 0  // 重置为0圈
        // 重置额外时间相关状态
        isInExtraTime = false
        savedExtraTime = 0  // 确保清空保存的额外时间
        lapSavedTimes.removeAll()  // 清空每圈节省时间数组
        isTimerCompleted = false  // 重置计时完成状态
        isCountingUp = false  // 重置正向计时状态
        countUpSeconds = 0  // 重置正向计时秒数
        // 重置为计时模式
        selectedMode = 0
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
    
    // 验证当前圈数是否有效
    private func validateCurrentLap() {
        // 如果不在运行状态，确保当前圈数不超过总圈数-1
        if !isRunning {
            let maxLaps = totalLaps() - 1
            if currentLap > maxLaps && maxLaps >= 0 {
                currentLap = maxLaps
            }
            // 确保圈数不小于0
            if currentLap < 0 {
                currentLap = 0
            }
        }
    }
    
    // 新增方法：尝试切换模式
    func tryChangeMode(to newMode: Int) -> Bool {
        if isRunning && newMode == 1 {
            showAlert = true
            alertMessage = "计时正在进行中，请先暂停计时后再切换到配置页面"
            return false
        }
        selectedMode = newMode
        return true
    }
}

struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 标签选择
                    Picker("模式", selection: Binding(
                        get: { self.viewModel.selectedMode },
                        set: { newValue in
                            // 尝试切换模式，如果失败则不更新选中值
                            let _ = self.viewModel.tryChangeMode(to: newValue)
                        }
                    )) {
                        Text("计时").tag(0)
                        Text("配置").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .disabled(viewModel.isRunning) // 当计时运行时禁用选择器
                    
                    if viewModel.selectedMode == 0 {
                        // 计时模式
                        // 倒计时显示
                        VStack(spacing: 10) {
                            Text("剩余时间")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 10) {
                                TimeDigitView(value: max(0, viewModel.remainingTime / 60))
                                Text(":")
                                    .font(.system(size: 40, weight: .bold))
                                TimeDigitView(value: max(0, viewModel.remainingTime % 60))
                            }
                            
                            HStack {
                                Text("当前圈数: \(viewModel.currentLap + 1)/\(viewModel.totalLaps())")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if viewModel.isCountingUp {
                                    // 显示正向计时
                                    Text("超时: +\(viewModel.countUpSeconds)秒")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                } else {
                                    // 显示倒计时
                                    Text("圈内倒计时: \(viewModel.currentLapRemainingSeconds)")
                                        .font(.headline)
                                }
                            }
                            
                            // 额外时间状态指示
                            if viewModel.isInExtraTime {
                                Text("正在使用额外时间")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        
                        // 完成当前圈按钮 - 固定在这个位置
                        if viewModel.isRunning && !viewModel.isInExtraTime && !viewModel.isTimerCompleted {
                            Button(action: {
                                viewModel.saveCurrentLapRemainingTime()
                            }) {
                                HStack {
                                    Image(systemName: "flag.checkered")
                                    if viewModel.isCountingUp {
                                        Text("完成本圈 (已超时)")
                                            .fontWeight(.semibold)
                                    } else {
                                        Text("完成本圈")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(viewModel.isCountingUp ? Color.red : Color.blue)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        
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
                                    .background(viewModel.isRunning ? Color.orange : (viewModel.isTimerCompleted ? Color.gray : Color.green))
                                    .clipShape(Circle())
                            }
                            .disabled(viewModel.isTimerCompleted) // 计时完成时禁用开始按钮
                            
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
                        .padding(.bottom, 10)
                        
                        // 已储存时间和每圈节省时间放在最下方
                        if viewModel.savedExtraTime != 0 || !viewModel.lapSavedTimes.isEmpty {
                            VStack(spacing: 8) {
                                HStack {
                                    if viewModel.savedExtraTime >= 0 {
                                        Image(systemName: "clock.badge.checkmark")
                                            .foregroundColor(.green)
                                        Text("已储存: \(viewModel.savedExtraTime)秒")
                                            .foregroundColor(.green)
                                            .fontWeight(.semibold)
                                    } else {
                                        Image(systemName: "clock.badge.exclamationmark")
                                            .foregroundColor(.red)
                                        Text("已超时: \(abs(viewModel.savedExtraTime))秒")
                                            .foregroundColor(.red)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        viewModel.resetSavedExtraTime()
                                    }) {
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.red)
                                    }
                                }
                                
                                // 显示每圈节省的时间
                                if !viewModel.lapSavedTimes.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(0..<viewModel.lapSavedTimes.count, id: \.self) { index in
                                            HStack {
                                                if viewModel.lapSavedTimes[index] >= 0 {
                                                    Image(systemName: "flag.checkered")
                                                        .foregroundColor(.green)
                                                    Text("第\(index + 1)圈节省: \(viewModel.lapSavedTimes[index])秒")
                                                        .foregroundColor(.green)
                                                        .fontWeight(.semibold)
                                                } else {
                                                    Image(systemName: "flag.checkered")
                                                        .foregroundColor(.red)
                                                    Text("第\(index + 1)圈超时: \(abs(viewModel.lapSavedTimes[index]))秒")
                                                        .foregroundColor(.red)
                                                        .fontWeight(.semibold)
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            )
                        }
                    } else {
                        // 配置模式 - 设置区域
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
                                        .onChange(of: viewModel.totalDistance) { newValue in
                                            // 防止负数或过大值
                                            if newValue <= 0 {
                                                viewModel.totalDistance = 1
                                            } else if newValue > 100000 { // 最大10万米
                                                viewModel.totalDistance = 100000
                                            }
                                        }
                                    
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
                                        .onChange(of: viewModel.lapDistance) { newValue in
                                            // 防止负数或过大值
                                            if newValue <= 0 {
                                                viewModel.lapDistance = 1
                                            } else if newValue > viewModel.totalDistance {
                                                viewModel.lapDistance = viewModel.totalDistance
                                            }
                                        }
                                    
                                    Text("米")
                                }
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
                    }
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
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("无法切换"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("确定"))
                )
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