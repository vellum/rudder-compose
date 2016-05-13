//
//  ViewController.swift
//  MrRemote
//
//  Created by David Lu on 4/8/16.
//  Copyright © 2016 David Lu. All rights reserved.
//  Some code cribbed from http://stackoverflow.com/questions/30431782/remote-control-event-in-ios-with-swift
//

import UIKit
import AVFoundation
import AVFoundation.AVAudioSession
import MediaPlayer
import SpeechKit

class ViewController: UIViewController, AVAudioPlayerDelegate, UITextViewDelegate, SKTransactionDelegate {

    // MARK:
    // MARK: volume rocker
    
    var testPlayer: AVAudioPlayer? = nil
    var textView: UITextView? = nil
    var session: AVAudioSession? = nil
    var volumeView: MPVolumeView? = nil
    var maxVolume: CGFloat = 0.99999
    var minVolume: CGFloat = 0.00001
    var initialVolume: CGFloat = 0.0
    
    // MARK:
    // MARK: word selection

    var textIndex: Int = 0
    var words = [String]()

    // MARK:
    // MARK: speechkit
    
    enum SKSState {
        case SKSIdle
        case SKSListening
        case SKSProcessing
    }
    var language: String!
    var recognitionType: String!
    var endpointer: SKTransactionEndOfSpeechDetection!
    var skSession:SKSession?
    var skTransaction:SKTransaction?
    var state = SKSState.SKSIdle
    var toggleRecogButton:UIButton?

    // MARK:
    // MARK: boilerplate
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make my "silent" audio ambient
        // this lets audio from other apps continue in background
        // ~ disabling this because it results in weird play/pause behavior
        /*
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
        } catch {
            print("set avaudiosessioncategory failed")
        }
         */
        
        // register to get volume input by playing an audio sample
        self.testPlayer = self.loadSound("silence")
        self.testPlayer?.numberOfLoops = -1
        self.testPlayer?.play()
        listenVolumeButton()
        
        // disable hud (this replaces the default hud with a custom 0x0 view
        self.volumeView = MPVolumeView(frame: CGRectMake(-1000,-1000,0,0) )
        UIApplication.sharedApplication().windows.first?.addSubview(self.volumeView!)

        // set initial volume (when we intercept volume change events, we'll reset the volume level)
        self.session = AVAudioSession.sharedInstance()
        self.initialVolume = CGFloat(self.session!.outputVolume)

        // set up a text view
        self.textView = UITextView(frame: UIScreen.mainScreen().bounds)
        self.textView?.editable = false//true
        self.textView?.delegate = self
        self.view.addSubview(self.textView!)
        textView!.font = UIFont(name: "Helvetica", size: 24)
        textView!.contentInset = UIEdgeInsetsMake(0,0,0,0);
        // FIXME: style this text it's awful

        // speechkit
        let mainbounds = UIScreen.mainScreen().bounds
        self.toggleRecogButton = UIButton(frame:
            CGRectMake(
                mainbounds.origin.x,
                mainbounds.origin.y + mainbounds.size.height - 60.0,
                //mainbounds.origin.y + mainbounds.size.height/2 - 60.0,
                mainbounds.size.width,
                60.0
            ))
        self.toggleRecogButton?.backgroundColor = UIColor.lightGrayColor()
        self.toggleRecogButton?.setTitle("Dictate", forState: .Normal)
        self.view.addSubview(self.toggleRecogButton!)
        self.toggleRecogButton?.addTarget(self, action: #selector(self.toggleRecognition), forControlEvents: .TouchUpInside)
        
        recognitionType = SKTransactionSpeechTypeDictation
        endpointer = .Short
        language = LANGUAGE
        state = .SKSIdle
        skTransaction = nil
        skSession = SKSession(URL: NSURL(string: SKSServerUrl), appToken: SKSAppKey)
        if (skSession == nil) {
            let alertView = UIAlertController(title: "SpeechKit", message: "Failed to initialize SpeechKit session.", preferredStyle: .Alert)
            let defaultAction = UIAlertAction(title: "OK", style: .Default) { (action) in }
            alertView.addAction(defaultAction)
            presentViewController(alertView, animated: true, completion: nil)
            return
        }
        loadEarcons()
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.keyboardWillShow), name: UIKeyboardWillShowNotification, object: nil)

    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        // launch keyboard
        self.textView?.becomeFirstResponder()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func keyboardWillShow(notification:NSNotification) {
        let userInfo:NSDictionary = notification.userInfo!
        let keyboardFrame:NSValue = userInfo.valueForKey(UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.CGRectValue()
        let keyboardHeight = keyboardRectangle.height
        print(keyboardHeight)
        let mainbounds = UIScreen.mainScreen().bounds
        self.textView?.frame = CGRectMake(mainbounds.origin.x, mainbounds.origin.y, mainbounds.size.width, mainbounds.size.height - keyboardHeight-60)
        self.toggleRecogButton?.frame = CGRectMake(mainbounds.origin.x, mainbounds.size.height - keyboardHeight - 60, mainbounds.size.width, 60)
        
        
    }

    // MARK:
    // MARK: intercept volume controls
    
    func loadSound(filename: NSString) -> AVAudioPlayer? {
        let url = NSBundle.mainBundle().URLForResource(filename as String, withExtension: "caf")
        if let player = try? AVAudioPlayer(contentsOfURL: url!) {
            player.prepareToPlay()
            return player
        }
        return nil
    }

    func listenVolumeButton(){
        let audioSession = AVAudioSession.sharedInstance()
        self.session = audioSession
        do {
            try audioSession.setActive(true)
            audioSession.addObserver(self, forKeyPath: "outputVolume",
                                     options: NSKeyValueObservingOptions.New, context: nil)
        } catch _ {
        }
    }
    
    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        let rc = event!.subtype
        print("rc.rawValue: \(rc.rawValue)")
        if (rc.rawValue == 103){
            self.toggleRecognition()
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume"{
            let delta = self.initialVolume - ( change!["new"] as! CGFloat )
            if (delta != 0){
                let num:NSNumber = NSNumber(float: Float(self.initialVolume))
                MPMusicPlayerController.applicationMusicPlayer().setValue(num, forKeyPath: "volume")
                if ( delta > 0 ) {
                    print("down")
                    self.textIndex += 1
                    if (self.textIndex > self.words.count){
                        self.textIndex = self.words.count
                    }
                    self.selectWordAtIndex(self.textIndex)
                } else if ( delta < 0 ) {
                    print("up")
                    self.textIndex -= 1
                    if (self.textIndex < -1){
                        self.textIndex = -1
                    }
                    self.selectWordAtIndex(self.textIndex)
                }
            }
            // reset volume level?
        }
    }
    
    // MARK:
    // MARK: textviewdelegate
    /*
    func textViewShouldBeginEditing(textView: UITextView) -> Bool {
        return true
    }
    
    func textViewDidBeginEditing(textView: UITextView) {
        print("did begin editing")
    }
    
    func textViewShouldEndEditing(textView: UITextView) -> Bool {
        return true
    }
    
    func textViewDidEndEditing(textView: UITextView) {
        print("did end editing")
    }
    */
    
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        return true
    }
    
    func textViewDidChange(textView: UITextView) {
        self.words = (self.textView?.text.componentsSeparatedByString(" "))!
        self.textIndex = words.count
    }
    
    // MARK:
    // MARK: text selection by volume rocker
    
    func selectAll(){
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.beginningOfDocument)!, toPosition: (textView?.endOfDocument)!)
    }
    
    func selectNadaAtLast(){
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.endOfDocument)!, toPosition: (textView?.endOfDocument)!)
    }
    func selectNadaAtFirst(){
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.beginningOfDocument)!, toPosition: (textView?.beginningOfDocument)!)
    }
    
    func selectRange(range:UITextRange){
        textView?.selectedTextRange = range
    }
    
    func delayedSelection(range:UITextRange){
        //self.selectNadaAtFirst()
        //self.selectRange(range)
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.025 * 1000000000)), dispatch_get_main_queue(), { () -> Void in
            self.selectNadaAtFirst()
        })
        
        var delayMultiplier = 0.026
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delayMultiplier * 1000000000)), dispatch_get_main_queue(), { () -> Void in
            self.selectRange(range)
        })
        
        delayMultiplier = 0.05
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(delayMultiplier * 1000000000)), dispatch_get_main_queue(), { () -> Void in
            self.selectRange(range)
        })
self.selectRange(range)
        
    }
    
    func selectWordAtIndex(index:Int){
        
        if (words.count == 0){
            return
        }
        
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.endOfDocument)!, toPosition: (textView?.endOfDocument)!)
        
        if (index < 0){
            let pos0 = textView?.beginningOfDocument
            let pos1 = pos0
            //textView?.selectedTextRange = textView?.textRangeFromPosition(pos0!, toPosition: pos1!)
            let r:UITextRange = (textView?.textRangeFromPosition(pos0!, toPosition: pos1!))!
            self.delayedSelection(r)
            return
        }
        
        if (index == words.count-1){
            
            self.selectNadaAtLast()
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * 1000000000)), dispatch_get_main_queue(), { () -> Void in
                self.selectAll()
            })
            return
        }
        
        var ind = index
        if ( index == words.count){
            ind = words.count-1
        }
        let curLen = self.words[ind].characters.count
        var startInd = 0
        for i in 0 ..< ind {
            let word = self.words[i]
            startInd += word.characters.count + 1 // + 1 to account for space
        }
        let endInd = startInd + curLen
        let pos0 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: startInd)
        let pos1 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: endInd)
        //textView?.selectedTextRange = textView?.textRangeFromPosition(pos0!, toPosition: pos1!)
        let r:UITextRange = (textView?.textRangeFromPosition(pos0!, toPosition: pos1!))!
        self.delayedSelection(r)
        
    }
    
    func insertText(message:String) {
        //print("inserting text: ")
        //print(message)
        
        let selectedRange: NSRange = (self.textView?.selectedRange)!
        print(selectedRange)
        
        var msg = message
        msg = msg.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if (msg.lowercaseString == "delete" && selectedRange.length>0){
            msg = ""
        }

        let text = textView?.text
        
        let leftRange = text!.startIndex.advancedBy(0)..<(text?.startIndex.advancedBy(selectedRange.location))!
        let leftString = text!.substringWithRange(leftRange)
        
        var totes = ""
        totes = totes.stringByAppendingString(leftString)
        totes = totes.stringByAppendingString(msg)

        if (selectedRange.location + selectedRange.length < text?.characters.count){
            let rightRange = text!.startIndex.advancedBy(selectedRange.location + selectedRange.length)..<(text!.startIndex.advancedBy((text?.characters.count)!-1))
            let rightString = text!.substringWithRange(rightRange)
            
            totes = totes.stringByAppendingString(rightString)
        }
        totes = totes.stringByAppendingString(" ")
        totes = totes.stringByReplacingOccurrencesOfString("  ", withString: " ")
        totes = totes.stringByReplacingOccurrencesOfString(" . ", withString: ". ")
        totes = totes.stringByReplacingOccurrencesOfString(" , ", withString: ", ")
        totes = totes.stringByReplacingOccurrencesOfString(" ! ", withString: "! ")
        totes = totes.stringByReplacingOccurrencesOfString(" ; ", withString: "; ")
        
        
        self.textView!.text = totes
        
        
        //self.becomeFirstResponder()
        
        /*
        // disable hud (this replaces the default hud with a custom 0x0 view
        self.volumeView = MPVolumeView(frame: CGRectMake(-1000,-1000,0,0) )
        UIApplication.sharedApplication().windows.first?.addSubview(self.volumeView!)
        listenVolumeButton()
        */
        
        self.textViewDidChange(self.textView!)
    }

    // MARK:
    // MARK: speechkit - helpers
    
    func log(message: String) {
        //logTextView!.text = logTextView!.text.stringByAppendingFormat("%@\n", message)
        print(message)
    }
    
    func resetTransaction() {
        NSOperationQueue.mainQueue().addOperationWithBlock({
            self.skTransaction = nil
            self.toggleRecogButton?.setTitle("Dictate", forState: .Normal)
            self.toggleRecogButton?.enabled = true
        })
    }
    
    func loadEarcons() {
        let startEarconPath = NSBundle.mainBundle().pathForResource("sk_start", ofType: "pcm")
        let stopEarconPath = NSBundle.mainBundle().pathForResource("sk_stop", ofType: "pcm")
        let errorEarconPath = NSBundle.mainBundle().pathForResource("sk_error", ofType: "pcm")
        let audioFormat = SKPCMFormat()
        audioFormat.sampleFormat = .SignedLinear16
        audioFormat.sampleRate = 16000
        audioFormat.channels = 1
        
        skSession!.startEarcon = SKAudioFile(URL: NSURL(fileURLWithPath: startEarconPath!), pcmFormat: audioFormat)
        skSession!.endEarcon = SKAudioFile(URL: NSURL(fileURLWithPath: stopEarconPath!), pcmFormat: audioFormat)
        skSession!.errorEarcon = SKAudioFile(URL: NSURL(fileURLWithPath: errorEarconPath!), pcmFormat: audioFormat)
    }

    /*
     func startPollingVolume() {
     // Every 50 milliseconds we should update the volume meter in our UI.
     volumePollTimer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self, selector: #selector(SKSASRViewController.pollVolume), userInfo: nil, repeats: true)
     }
     
     func pollVolume() {
     let volumeLevel = skTransaction!.audioLevel
     volumeLevelProgressView!.setProgress(volumeLevel / Float(100), animated: true)
     }
     
     func stopPollingVolume() {
     volumePollTimer!.invalidate()
     volumePollTimer = nil
     volumeLevelProgressView!.setProgress(Float(0), animated: true)
     }
     */
    
    
    // MARK: - ASR Actions
    func toggleRecognition() {
        switch state {
        case .SKSIdle:
            recognize()
        case .SKSListening:
            stopRecording()
        case .SKSProcessing:
            cancel()
        }
    }
    
    func recognize() {
        // Start listening to the user.
        toggleRecogButton?.setTitle("Stop", forState: .Normal)
        skTransaction = skSession!.recognizeWithType(recognitionType,
                                                     detection: endpointer,
                                                     language: language,
                                                     delegate: self)
    }
    
    func stopRecording() {
        // Stop recording the user.
        skTransaction!.stopRecording()
        
        // Disable the button until we received notification that the transaction is completed.
        toggleRecogButton?.enabled = false
    }
    
    func cancel() {
        // Cancel the Reco transaction.
        // This will only cancel if we have not received a response from the server yet.
        skTransaction!.cancel()
    }
    
    // MARK: - SKTransactionDelegate
    
    func transactionDidBeginRecording(transaction: SKTransaction!) {
        log("transactionDidBeginRecording")
        
        state = .SKSListening
        //startPollingVolume()
        toggleRecogButton?.setTitle("Listening..", forState: .Normal)
    }
    
    func transactionDidFinishRecording(transaction: SKTransaction!) {
        log("transactionDidFinishRecording")
        
        state = .SKSProcessing
        //stopPollingVolume()
        toggleRecogButton?.setTitle("Processing..", forState: .Normal)
    }
    
    func transaction(transaction: SKTransaction!, didReceiveRecognition recognition: SKRecognition!) {
        log(String(format: "didReceiveRecognition: %@", arguments: [recognition.text]))
        
        state = .SKSIdle
        
        self.insertText(recognition.text)
        
        toggleRecogButton?.setTitle("Dictate", forState: .Normal)
        toggleRecogButton?.enabled = true

    }
    
    func transaction(transaction: SKTransaction!, didReceiveServiceResponse response: [NSObject : AnyObject]!) {
        log(String(format: "didReceiveServiceResponse: %@", arguments: [response]))
    }
    
    func transaction(transaction: SKTransaction!, didFinishWithSuggestion suggestion: String) {
        log("didFinishWithSuggestion")
        
        state = .SKSIdle
        resetTransaction()
    }
    
    func transaction(transaction: SKTransaction!, didFailWithError error: NSError!, suggestion: String) {
        log(String(format: "didFailWithError: %@. %@", arguments: [error.description, suggestion]))
        
        // Something went wrong. Ensure that your credentials are correct.
        // The user could also be offline, so be sure to handle this case appropriately.
        
        state = .SKSIdle
        resetTransaction()
    }
    
}

