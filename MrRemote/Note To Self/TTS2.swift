//
//  TTS2.swift
//  Note To Self
//
//  Created by David Lu on 5/15/16.
//  Copyright © 2016 David Lu. All rights reserved.
//

import Foundation
import AVFoundation

class TTS2: NSObject {
    var synthesizer: AVSpeechSynthesizer?
    
    override init() {
        synthesizer = AVSpeechSynthesizer()
    }
    
    func speak(text: String){
        if (synthesizer!.speaking) {
            synthesizer!.stopSpeakingAtBoundary(.Immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer!.speakUtterance(utterance)
    }
}