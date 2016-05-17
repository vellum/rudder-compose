//
//  TTS2.swift
//  Note To Self
//
//  text to speech using avspeechsynthesizer
//
//  Created by David Lu on 5/15/16.
//  Copyright © 2016 David Lu. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit


class TTS2: NSObject {
    
    var synthesizer: AVSpeechSynthesizer?
    
    override init() {
        synthesizer = AVSpeechSynthesizer()
    }
    
    func speak(text: String){
        // apparently there's a way to pause voiceover speech so you can do your own
        // (but i can't get this to work)
        //UIAccessibilityPostNotification(UIAccessibilityPauseAssistiveTechnologyNotification, UIAcces)
        
        if (synthesizer!.speaking) {
            synthesizer!.stopSpeakingAtBoundary(.Immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer!.speakUtterance(utterance)
    }
    
}