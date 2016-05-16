//
//  TTS.swift
//  Note To Self
//
//  Created by David Lu on 5/15/16.
//  Copyright © 2016 David Lu. All rights reserved.
//

import Foundation
import SpeechKit

class TTS: NSObject, SKTransactionDelegate, SKAudioPlayerDelegate {
    
    var skSession:SKSession?
    var skTransaction:SKTransaction?
    
    override init() {
        
        skTransaction = nil
        skSession = SKSession(URL: NSURL(string: SKSServerUrl), appToken: SKSAppKey)

    }
    
    func speak(text: String){
        resetTransaction()
        skTransaction = skSession!.speakString(text, withVoice: "Samantha", delegate: self)
    }
    
    
    // MARK - SKTransactionDelegate
    
    func transaction(transaction: SKTransaction!, didReceiveAudio audio: SKAudio!) {
        log("didReceiveAudio")
    }
    
    func transaction(transaction: SKTransaction!, didFinishWithSuggestion suggestion: String) {
        log("didFinishWithSuggestion")
    }
    
    func transaction(transaction: SKTransaction!, didFailWithError error: NSError!, suggestion: String) {
        log(String(format: "didFailWithError: %@. %@", arguments: [error.description, suggestion]))
        
        // Something went wrong. Ensure that your credentials are correct.
        // The user could also be offline, so be sure to handle this case appropriately.
        
        resetTransaction()
    }
    
    // MARK - SKAudioPlayerDelegate
    
    func audioPlayer(player: SKAudioPlayer!, willBeginPlaying audio: SKAudio!) {
        log("willBeginPlaying")
        
        // The TTS Audio will begin playing.
    }
    
    func audioPlayer(player: SKAudioPlayer!, didFinishPlaying audio: SKAudio!) {
        log("didFinishPlaying")
        
        // The TTS Audio has finished playing.
    }
    
    func log(message: String) {
        print(message)
    }

    func resetTransaction() {
        NSOperationQueue.mainQueue().addOperationWithBlock({
            self.skTransaction = nil
        })
    }
    
}