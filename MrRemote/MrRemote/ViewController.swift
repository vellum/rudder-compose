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

// https://stackoverflow.com/questions/24029163/finding-index-of-character-in-swift-string
extension String {
    public func indexOfCharacter(char: Character) -> Int? {
        if let idx = self.characters.indexOf(char) {
            return self.startIndex.distanceTo(idx)
        }
        return nil
    }
}

class ViewController: UIViewController, AVAudioPlayerDelegate, UITextViewDelegate {
    
    var testPlayer: AVAudioPlayer? = nil
    var textView: UITextView? = nil
    
    // not sure i need these
    var session: AVAudioSession? = nil
    var volumeView: MPVolumeView? = nil
    
    // constants... where to put these?
    var maxVolume: CGFloat = 0.99999
    var minVolume: CGFloat = 0.00001
    var initialVolume: CGFloat = 0.0
    
    // vars
    var textIndex: Int = 0
    var words = [String]()
    
    func loadSound(filename: NSString) -> AVAudioPlayer? {
        let url = NSBundle.mainBundle().URLForResource(filename as String, withExtension: "caf")
        if let player = try? AVAudioPlayer(contentsOfURL: url!) {
            player.prepareToPlay()
            return player
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make my silent audio ambient.. this lets audio from other apps continue in background.
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
        } catch {
            print("set avaudiosessioncategory failed")
        }
        
        // enable volume controls by playing a dummy sample
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
        self.textView?.editable = true
        self.textView?.delegate = self
        self.view.addSubview(self.textView!)
        
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func viewWillAppear(animated: Bool) {
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        self.becomeFirstResponder()
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        self.textView?.becomeFirstResponder()
        
    }
    
    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        let rc = event!.subtype
        print("rc.rawValue: \(rc.rawValue)")
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == "outputVolume"{
            //print("got in here")
            //print(change)
            let delta = self.initialVolume - ( change!["new"] as! CGFloat )
            if (delta != 0){
                let num:NSNumber = NSNumber(float: Float(self.initialVolume))
                MPMusicPlayerController.applicationMusicPlayer().setValue(num, forKeyPath: "volume")
                if ( delta > 0 ) {
                    print("down")
                    self.textIndex += 1
                    if (self.textIndex > self.words.count-1){
                        self.textIndex = self.words.count-1
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
            //print(change!["new"])
            
            // reset volume level
            
        }
        
    }
    
    // MARK: ---

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    // MARK: --- textviewdelegate
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
        print("did change")
        
        self.words = (self.textView?.text.componentsSeparatedByString(" "))!
        print(words)
        
        self.textIndex = words.count-1
        
    }
    
    // MARK: ---
    
    func selectAll(){
        textView?.selectedTextRange = textView?.textRangeFromPosition((textView?.beginningOfDocument)!, toPosition: (textView?.endOfDocument)!)
    }
    
    func selectWordAtIndex(index:Int){
        if (index < 0){
            let pos0 = textView?.beginningOfDocument
            let pos1 = pos0
            textView?.selectedTextRange = textView?.textRangeFromPosition(pos0!, toPosition: pos1!)
            return
        }
        
        let curLen = self.words[index].characters.count
        var startInd = 0
        for i in 0 ..< index {
            let word = self.words[i]
            startInd += word.characters.count + 1 // + 1 to account for space
        }
        let endInd = startInd + curLen
        let pos0 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: startInd)
        let pos1 = textView?.positionFromPosition((textView?.beginningOfDocument)!, offset: endInd)
        textView?.selectedTextRange = textView?.textRangeFromPosition(pos0!, toPosition: pos1!)
    }
    
    
}

