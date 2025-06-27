import Foundation
import AVFoundation
import SwiftUI

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
    
    // 新增自动跳圈设置
    @Published var isAutoLapEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isAutoLapEnabled, forKey: "isAutoLapEnabled")
        }
    }
    
    @Published var isRunning: Bool = false
    @Published var remainingTime: Int = 0
    @Published var currentLapRemainingSeconds: Int = 0
    @Published var currentLap: Int = 0
    @Published var isTimerCompleted: Bool = false
    
    // 提前完成时间相关的属性
    @Published var savedExtraTime: Int = 0
    @Published var isInExtraTime: Bool = false
    @Published var lapSavedTimes: [Int] = []
    
    // 正向计时相关属性
    @Published var isCountingUp: Bool = false
    @Published var countUpSeconds: Int = 0
    
    private var timer: Timer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // WatchOS不支持后台任务API，故移除后台任务相关代码
    
    init() {
        updateRemainingTime()
        
        // 从SettingsManager加载默认值
        loadSettingsFromManager()
    }
    
    private func loadSettingsFromManager() {
        // 在watchOS上我们尝试从UserDefaults获取设置
        if let savedMinutes = UserDefaults.standard.object(forKey: "totalMinutes") as? Int {
            totalMinutes = savedMinutes
        }
        
        if let savedSeconds = UserDefaults.standard.object(forKey: "totalSeconds") as? Int {
            totalSeconds = savedSeconds
        }
        
        if let savedTotalDistance = UserDefaults.standard.object(forKey: "totalDistance") as? Int {
            totalDistance = savedTotalDistance
        }
        
        if let savedLapDistance = UserDefaults.standard.object(forKey: "lapDistance") as? Int {
            lapDistance = savedLapDistance
        }
        
        // 加载自动跳圈设置
        isAutoLapEnabled = UserDefaults.standard.bool(forKey: "isAutoLapEnabled")
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
    
    // 更新剩余时间
    private func updateRemainingTime() {
        remainingTime = totalMinutes * 60 + totalSeconds
    }
    
    func startTimer() {
        if !isRunning && !isTimerCompleted {
            isRunning = true
            remainingTime = totalMinutes * 60 + totalSeconds
            currentLapRemainingSeconds = lapTime
            isCountingUp = false
            countUpSeconds = 0
            
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
                    
                    // 如果开启了自动跳圈，超时3秒后自动跳转到下一圈
                    if self.isAutoLapEnabled && self.countUpSeconds >= 3 {
                        self.saveCurrentLapRemainingTime()
                    }
                } else {
                    // 正常倒计时
                    self.currentLapRemainingSeconds -= 1
                    if self.currentLapRemainingSeconds <= 0 {
                        // 当前圈倒计时结束
                        if self.shouldEnterExtraTime() {
                            // 进入额外时间模式
                            self.enterExtraTimeMode()
                        } else if self.isAutoLapEnabled {
                            // 如果启用了自动跳圈，则自动进入下一圈
                            self.saveCurrentLapRemainingTime()
                            self.speakMessage("自动进入下一圈")
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
                    self.isTimerCompleted = true
                    self.speakMessage("额外时间用完，计时完成")
                }
            }
            
            // 确保计时器在前台运行
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
    
    // 保存当前圈剩余时间
    func saveCurrentLapRemainingTime() {
        if isRunning {
            var savedTime: Int = 0
            
            if isCountingUp {
                // 正在正向计时，表示超时了
                savedTime = -countUpSeconds  // 负数表示超时
                isCountingUp = false
                countUpSeconds = 0
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
        lapSavedTimes.removeAll()
        isInExtraTime = false
        isCountingUp = false
        countUpSeconds = 0
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func resetTimer() {
        pauseTimer()
        remainingTime = totalMinutes * 60 + totalSeconds
        currentLapRemainingSeconds = lapTime
        currentLap = 0
        isInExtraTime = false
        savedExtraTime = 0
        lapSavedTimes.removeAll()
        isTimerCompleted = false
        isCountingUp = false
        countUpSeconds = 0
    }
    
    func speakCurrentSecond() {
        let utterance = AVSpeechUtterance(string: "\(currentLapRemainingSeconds)")
        configureUtterance(utterance)
        
        // 停止当前正在播放的语音
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    func speakMessage(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        configureUtterance(utterance)
        speechSynthesizer.speak(utterance)
    }
    
    private func configureUtterance(_ utterance: AVSpeechUtterance) {
        // 在watchOS中简化语音配置
        let languageCode = UserDefaults.standard.string(forKey: "languageCode") ?? "zh-CN"
        
        // 尝试获取保存的语音标识符
        if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier"),
           let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == savedIdentifier }) {
            utterance.voice = voice
        } else {
            // 使用默认语音
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        }
        
        // 获取语速
        utterance.rate = UserDefaults.standard.float(forKey: "speechRate")
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
} 