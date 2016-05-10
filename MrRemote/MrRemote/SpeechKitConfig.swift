//
//  SpeechKitConfig.swift
//  MrRemote
//
//  Created by David Lu on 5/9/16.
//  Copyright © 2016 David Lu. All rights reserved.
//

import Foundation

var SKSAppKey = "!APPKEY!"
var SKSAppId = "!APPID!"
var SKSServerHost = "!HOST!"
var SKSServerPort = "!PORT!"

var SKSLanguage = "!LANGUAGE!"

var SKSServerUrl = String(format: "nmsps://%@@%@:%@", SKSAppId, SKSServerHost, SKSServerPort)

// Only needed if using NLU/Bolt
var SKSNLUContextTag = "!NLU_CONTEXT_TAG!"


let LANGUAGE = SKSLanguage == "!LANGUAGE!" ? "eng-USA" : SKSLanguage