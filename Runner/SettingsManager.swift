//
//  SettingsManager.swift
//  Runner
//
//  Created by 胡云飞 on 2025/6/2.
//

import Foundation
import AVFoundation

// 单例管理器，用于在视图模型之间共享设置
class SettingsManager {
    static let shared = SettingsManager()
    
    private init() {}
    
    // MARK: - 语音设置
    
    func getLanguageCode() -> String {
        let languages = ["zh-CN", "en-US", "en-GB"]
        let selectedLanguage = UserDefaults.standard.integer(forKey: "language")
        return selectedLanguage < languages.count ? languages[selectedLanguage] : "zh-CN"
    }
    
    func getSpeechRate() -> Float {
        let rate = UserDefaults.standard.double(forKey: "speechRate")
        return rate > 0 ? Float(rate) : 0.5
    }
    
    func getSelectedVoice() -> AVSpeechSynthesisVoice? {
        // 获取当前语言代码
        let languageCode = getLanguageCode()
        
        // 首先检查是否有保存的具体语音标识符
        if let savedIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier"),
           !savedIdentifier.isEmpty {
            // 尝试通过标识符找到对应的语音
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            if let savedVoice = allVoices.first(where: { $0.identifier == savedIdentifier }) {
                // 检查保存的语音是否与当前语言匹配
                if savedVoice.language.hasPrefix(languageCode) {
                    print("使用已保存的语音: \(savedVoice.name), 语言: \(savedVoice.language)")
                    return savedVoice
                } else {
                    print("已保存的语音(\(savedVoice.language))与当前语言(\(languageCode))不匹配，重新选择")
                    // 如果语音与当前语言不匹配，则不使用保存的语音
                }
            }
        }
        
        // 如果没有保存的标识符或找不到对应语音，则根据语言和性别选择
        let selectedGender = UserDefaults.standard.integer(forKey: "voiceGender")
        let targetGender: AVSpeechSynthesisVoiceGender = selectedGender == 0 ? .male : .female
        
        // 获取所有可用语音
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // 首先尝试找到匹配语言和性别的语音
        let matchingVoices = allVoices.filter { voice in
            voice.language == languageCode && voice.gender == targetGender
        }
        
        // 如果找到匹配的语音，返回第一个
        if let firstMatch = matchingVoices.first {
            print("找到匹配语言和性别的语音: \(firstMatch.name), 语言: \(firstMatch.language)")
            return firstMatch
        }
        
        // 如果没有找到完全匹配的，尝试只匹配语言
        let languageMatches = allVoices.filter { voice in
            voice.language == languageCode
        }
        
        if let firstLanguageMatch = languageMatches.first {
            print("找到匹配语言的语音: \(firstLanguageMatch.name), 语言: \(firstLanguageMatch.language)")
            return firstLanguageMatch
        }
        
        // 如果仍然没有找到，返回系统默认语音
        print("未找到匹配的语音，使用默认语音，语言: \(languageCode)")
        return AVSpeechSynthesisVoice(language: languageCode)
    }
    
    // 获取指定语言的所有可用语音
    func getAvailableVoices(forLanguage languageCode: String? = nil) -> [AVSpeechSynthesisVoice] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        
        if let languageCode = languageCode {
            // 首先尝试精确匹配
            let exactMatches = allVoices.filter { $0.language == languageCode }
            
            if !exactMatches.isEmpty {
                print("找到\(exactMatches.count)个精确匹配语言\(languageCode)的语音")
                return exactMatches
            }
            
            // 如果没有精确匹配，尝试前缀匹配（例如，en-US 可以匹配 en）
            let baseLanguage = languageCode.split(separator: "-").first?.description ?? languageCode
            let prefixMatches = allVoices.filter { voice in
                let voiceBaseLanguage = voice.language.split(separator: "-").first?.description ?? voice.language
                return voiceBaseLanguage == baseLanguage
            }
            
            if !prefixMatches.isEmpty {
                print("找到\(prefixMatches.count)个基础语言\(baseLanguage)匹配的语音")
                return prefixMatches
            }
            
            // 如果仍然没有匹配，打印所有可用语言以便调试
            let availableLanguages = Set(allVoices.map { $0.language })
            print("未找到匹配语言\(languageCode)的语音。可用语言: \(availableLanguages)")
            
            // 如果没有匹配，返回空数组
            return []
        } else {
            // 如果没有指定语言代码，返回当前设置语言的所有语音
            let currentLanguage = getLanguageCode()
            return getAvailableVoices(forLanguage: currentLanguage)
        }
    }
    
    // 获取所有支持的语言
    func getAllSupportedLanguages() -> [String] {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        let languageSet = Set(allVoices.map { $0.language })
        return Array(languageSet).sorted()
    }
    
    // MARK: - 历史记录管理
    
    func saveHistoryItem(totalTime: Int, lapDistance: Int, lapTime: Int, completedLaps: Int) {
        var history = getHistory()
        
        let newItem = TimerHistory(
            date: Date(),
            totalTime: totalTime,
            lapDistance: lapDistance,
            lapTime: lapTime,
            completedLaps: completedLaps
        )
        
        history.append(newItem)
        saveHistory(history)
    }
    
    func getHistory() -> [TimerHistory] {
        if let data = UserDefaults.standard.data(forKey: "timerHistory"),
           let decoded = try? JSONDecoder().decode([TimerHistory].self, from: data) {
            return decoded
        }
        return []
    }
    
    func clearHistory() {
        saveHistory([])
    }
    
    private func saveHistory(_ history: [TimerHistory]) {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "timerHistory")
        }
    }
} 