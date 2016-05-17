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
    // MARK: DIY SELECTION
    var shouldAllowManualEdit: Bool = true
    
    // MARK:
    // MARK: volume rocker
    
    var testPlayer: AVAudioPlayer? = nil
    var textView: UITextView? = nil
    var clearField: UIView? = nil
    var session: AVAudioSession? = nil
    var volumeView: MPVolumeView? = nil
    var maxVolume: CGFloat = 0.99999
    var minVolume: CGFloat = 0.00001
    var initialVolume: CGFloat = 0.0
    
    // MARK:
    // MARK: word selection

    var textIndex: Int = 0
    var words = [String]()
    var thetext: String = ""
    var stringSelectedRange: NSRange? = nil

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

    var tts:TTS2?
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
        testPlayer = loadSound("silence")
        testPlayer?.numberOfLoops = -1
        testPlayer?.play()
        listenVolumeButton()
        
        // disable hud (this replaces the default hud with a custom 0x0 view
        volumeView = MPVolumeView(frame: CGRectMake(-1000,-1000,0,0) )
        UIApplication.sharedApplication().windows.first?.addSubview(volumeView!)

        // set initial volume (when we intercept volume change events, we'll reset the volume level)
        session = AVAudioSession.sharedInstance()
        initialVolume = CGFloat(session!.outputVolume)

        // set up a text view
        let b = UIScreen.mainScreen().bounds
        let m:CGFloat = 18.0
        textView = UITextView(frame: CGRectMake(m, 0, b.size.width-m*2, b.size.height-60))
        textView?.delegate = self
        textView!.font = UIFont(name: "IowanOldStyle-Roman", size: 24)
        textView!.contentInset = UIEdgeInsetsMake(18,0,0,0);
        textView?.editable = true
        textView?.userInteractionEnabled = true
        let lgr =  UISwipeGestureRecognizer(target: self, action: #selector(selectPrev))
        let rgr = UISwipeGestureRecognizer(target: self, action: #selector(selectNext))
        lgr.direction = .Left
        rgr.direction = .Right
        textView?.addGestureRecognizer(lgr)
        textView?.addGestureRecognizer(rgr)
        textView?.accessibilityTraits = (textView?.accessibilityTraits)! | UIAccessibilityTraitAllowsDirectInteraction
        //textView?.isAccessibilityElement = false
        view.addSubview(textView!)
        
        if (!shouldAllowManualEdit){
            textView?.editable = false
        }

        // speechkit
        let mainbounds = UIScreen.mainScreen().bounds
        toggleRecogButton = UIButton(frame:
            CGRectMake(
                mainbounds.origin.x,
                mainbounds.origin.y + mainbounds.size.height - 60.0,
                mainbounds.size.width,
                60.0
            ))
        toggleRecogButton?.backgroundColor = UIColor.lightGrayColor()
        toggleRecogButton?.setTitle("Dictate", forState: .Normal)
        view.addSubview(toggleRecogButton!)
        toggleRecogButton?.addTarget(self, action: #selector(toggleRecognition), forControlEvents: .TouchUpInside)
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
        
        tts = TTS2()
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(keyboardWillShow), name: UIKeyboardWillShowNotification, object: nil)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        textView?.becomeFirstResponder()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func keyboardWillShow(notification:NSNotification) {
        // redo layout when keyboard is launched
        let userInfo:NSDictionary = notification.userInfo!
        let keyboardFrame:NSValue = userInfo.valueForKey(UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.CGRectValue()
        let keyboardHeight = keyboardRectangle.height
        let mainbounds = UIScreen.mainScreen().bounds
        let m:CGFloat = 18.0
        textView?.frame = CGRectMake(mainbounds.origin.x+m, mainbounds.origin.y, mainbounds.size.width-m*2, mainbounds.size.height - keyboardHeight-60)
        toggleRecogButton?.frame = CGRectMake(mainbounds.origin.x, mainbounds.size.height - keyboardHeight - 60, mainbounds.size.width, 60)
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
        session = audioSession
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
            toggleRecognition()
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume"{
            let delta = initialVolume - ( change!["new"] as! CGFloat )
            if (delta != 0){
                let num:NSNumber = NSNumber(float: Float(initialVolume))
                MPMusicPlayerController.applicationMusicPlayer().setValue(num, forKeyPath: "volume")
                if ( delta > 0 ) {
                    print("down")
                    selectNext()
                } else if ( delta < 0 ) {
                    print("up")
                    selectPrev()
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
        let attr = textView.attributedText
        let text = attr.string
        words = (text.componentsSeparatedByString(" "))
        textIndex = words.count
    }
    
    // MARK:
    // MARK: text selection by volume rocker
    
    func selectPrev(){
        textIndex -= 1
        if (textIndex < -1){
            textIndex = -1
        }
        selectWordAtIndex(textIndex)
    }
    
    func selectNext(){
        textIndex += 1
        if (textIndex > words.count){
            textIndex = words.count
        }
        selectWordAtIndex(textIndex)
    }
    
    func selectAll(){
        print("selectall()")
        var message = ""
        message = message.stringByAppendingString((textView?.attributedText.string)!)
        selectStringRange(NSMakeRange(0, message.characters.count))
        message = message.stringByAppendingString("... selected")
        tts?.speak(message)
    }
    
    func selectNadaAtLast(){
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.endOfDocument)!, toPosition: (textView?.endOfDocument)!)
    }
    
    func selectNadaAtFirst(){
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.beginningOfDocument)!, toPosition: (textView?.beginningOfDocument)!)
    }
    
    func selectStringRange(range:NSRange){
        stringSelectedRange = range
        print(stringSelectedRange)
        
        if ( self.shouldAllowManualEdit ){
            let pos0 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: range.location)
            let pos1 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: range.location + range.length)
            let tvrange = textView?.textRangeFromPosition(pos0!, toPosition: pos1!)
            selectRange(tvrange!)
        } else {
            
        }
    }
    
    func selectRange(range:UITextRange){
        textView?.selectedTextRange = range
    }
    
    func selectWordAtIndex(index:Int){
        
        if (words.count == 0){
            return
        }
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.endOfDocument)!, toPosition: (textView?.endOfDocument)!)
        if (index < 0){
            selectStringRange(NSMakeRange(0, 0))
            let word = "insertion point at beginning of document"
            tts?.speak(word)
            return
        }
        if (index == words.count-1){
            selectAll()
            return
        }
        var ind = index
        if ( index == words.count){
            ind = words.count-1
        }
        let curLen = words[ind].characters.count
        var startInd = 0
        for i in 0 ..< ind {
            let word = words[i]
            startInd += word.characters.count + 1 // + 1 to account for space
        }
        //let endInd = startInd + curLen
        //let pos0 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: startInd)
        //let pos1 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: endInd)
        //let r:UITextRange = (textView?.textRangeFromPosition(pos0!, toPosition: pos1!))!
        //selectRange(r)
        selectStringRange(NSMakeRange(startInd, curLen))
        
        if (ind == words.count-1){
            let word = "insertion point at end of document"
            tts?.speak(word)
        } else {
            var word = words[ind]
            word = word.stringByAppendingString("... selected")
            tts?.speak(word)
        }
    }

    func insertText(message:String) {
        let selectedRange: NSRange = stringSelectedRange!//(textView?.selectedRange)!
        var msg = message
        msg = msg.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        if (msg.lowercaseString == "delete" && selectedRange.length>0){
            msg = ""
        }
        let text = thetext
        
        // FIXME: use string range instead of selected range
        let leftRange = text.startIndex.advancedBy(0)..<(text.startIndex.advancedBy(selectedRange.location))
        let leftString = text.substringWithRange(leftRange)
        var totes = ""
        totes = totes.stringByAppendingString(leftString)
        totes = totes.stringByAppendingString(msg)
        
        if (selectedRange.location + selectedRange.length < text.characters.count) {
            let rightRange = text.startIndex.advancedBy(selectedRange.location + selectedRange.length)..<(text.startIndex.advancedBy((text.characters.count)-1))
            let rightString = text.substringWithRange(rightRange)
            
            totes = totes.stringByAppendingString(rightString)
        }
        totes = totes.stringByAppendingString(" ")
        totes = totes.stringByReplacingOccurrencesOfString("  ", withString: " ")
        totes = totes.stringByReplacingOccurrencesOfString(" . ", withString: ". ")
        totes = totes.stringByReplacingOccurrencesOfString(" , ", withString: ", ")
        totes = totes.stringByReplacingOccurrencesOfString(" ! ", withString: "! ")
        totes = totes.stringByReplacingOccurrencesOfString(" ; ", withString: "; ")
        
        thetext = totes
        let attributed: NSAttributedString = NSAttributedString(string: totes)
        textView?.attributedText = attributed
        //textView!.text = totes
        
        self.selectStringRange(NSMakeRange(attributed.length-1, 0))
        textViewDidChange(textView!)
        tts?.speak(message)
        
        
    }

    // MARK:
    // MARK: speechkit - helpers
    
    func log(message: String) {
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
        //toggleRecogButton?.enabled = false
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
        insertText(recognition.text)
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
    
    func transaction(transaction: SKTransaction!, didReceiveAudio audio: SKAudio!) {
        skSession!.audioPlayer.playAudio(audio)
    }

}

