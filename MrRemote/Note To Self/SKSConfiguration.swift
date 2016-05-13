//
//  SKSConfiguration.swift
//  SpeechKitSample
//
//  All Nuance Developers configuration parameters can be set here.
//
//  Copyright (c) 2015 Nuance Communications. All rights reserved.
//

import Foundation

var SKSAppKey = "65ffe6c6045a21228c7d0b123c57a6b7b378dead913a3d074ff0a26f7df18de2f074a8f4cec9175a46226c8279123a2c8b18d91c531623a206c61283b79f65a7"
var SKSAppId = "NMDPTRIAL_vellumdavid_gmail_com20160509010149"
var SKSServerHost = "sslsandbox.nmdp.nuancemobility.net"
var SKSServerPort = "443"
var SKSLanguage = "!LANGUAGE!"
var SKSServerUrl = String(format: "nmsps://%@@%@:%@", SKSAppId, SKSServerHost, SKSServerPort)

// Only needed if using NLU/Bolt
var SKSNLUContextTag = "!NLU_CONTEXT_TAG!"


let LANGUAGE = SKSLanguage == "!LANGUAGE!" ? "eng-USA" : SKSLanguage