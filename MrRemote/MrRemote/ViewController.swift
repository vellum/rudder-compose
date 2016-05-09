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

class ViewController: UIViewController, AVAudioPlayerDelegate, UITextViewDelegate {
    
    var testPlayer: AVAudioPlayer? = nil
    
    var textView: UITextView? = nil
    
    // not sure i need this
    var session: AVAudioSession? = nil
    var volumeView: MPVolumeView? = nil
    
    // constants... where to put these?
    var maxVolume: CGFloat = 0.99999
    var minVolume: CGFloat = 0.00001
    var initialVolume: CGFloat = 0.0
    
    
    
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
        
        // make my silent audio ambient; this lets audio from other apps continue in background.
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
        } catch {
            print("set avaudiosessioncategory failed")
        }
        
        
        self.testPlayer = self.loadSound("silence")
        self.testPlayer?.numberOfLoops = -1
        self.testPlayer?.play()
        listenVolumeButton()
        
        // disable hud (this replaces the default hud with a custom 0x0 view
        self.volumeView = MPVolumeView(frame: CGRectMake(-1000,-1000,0,0) )
        UIApplication.sharedApplication().windows.first?.addSubview(self.volumeView!)
        
        self.session = AVAudioSession.sharedInstance()
        self.initialVolume = CGFloat(self.session!.outputVolume)

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
                } else if ( delta < 0 ) {
                    print("up")
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
        
        // TBD
        // if we inserted text mid string
        // else (we inserted text at end of string)
        
        
    }
    
    
}

