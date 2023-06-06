//
//  main.swift
//  SDVolume
//
//  Created by AJ Foster on 6/1/23.
//

import CoreAudio
import Foundation
import StreamDeck

@main
class SDVolume: PluginDelegate {

    typealias Settings = NoSettings
    
    // MARK: Manifest
    static var name: String = "Volume"
    static var description: String = "Volume Dial for macOS"
    static var category: String?
    static var categoryIcon: String?
    static var author: String = "AJ Foster"
    static var icon: String = "assets/volume"
    static var url: URL? = URL(string: "https://github.com/aj-foster/sd-plugin-volume")
    static var version: String = "0.1"
    static var os: [PluginOS] = [.mac(minimumVersion: "10.15")]
    static var applicationsToMonitor: ApplicationsToMonitor?
    static var software: PluginSoftware = .minimumVersion("6.0")
    static var actions: [any Action.Type] = [RotaryAction.self]

    // MARK: Init
    required init() {
        NSLog("Init: com.aj-foster.sd-plugin-volume")
    }
}

class RotaryAction: EncoderAction {
    // MARK: Manifest
    static var name: String = "Volume"
    static var uuid: String = "com.aj-foster.sd-plugin-volume.dial"
    static var icon: String = "assets/volume"
    static var userTitleEnabled: Bool? = true
    static var encoder: RotaryEncoder? = RotaryEncoder(layout: .indicator,
                                                       stackColor: "#f1184c",
                                                       icon: "assets/dial",
                                                       rotate: "Set Volume",
                                                       push: "Mute or Unmute",
                                                       touch: "Mute or Unmute")

    // MARK: Dial State
    var context: String
    var coordinates: StreamDeck.Coordinates?
    var level: Int?
    var muted: Bool?
    
    lazy var onLevelDidChange: AudioObjectPropertyListenerBlock = {_, _ in
        NSLog("Event: Volume level did change")
        self.level = SystemVolume.get()
        self.setFeedback()
    }
    
    lazy var onMuteDidChange: AudioObjectPropertyListenerBlock = {_, _ in
        NSLog("Event: Mute did change")
        self.muted = SystemVolume.getMute()
        self.setFeedback()
    }

    // MARK: Init
    required init(context: String, coordinates: StreamDeck.Coordinates?) {
        NSLog("Init: com.aj-foster.sd-plugin-volume.dial (\(context))")

        self.level = SystemVolume.get()
        self.muted = SystemVolume.getMute()
        self.context = context
        self.coordinates = coordinates
    }

    // MARK: Dial Callbacks
    func willAppear(device: String, payload: AppearEvent<NoSettings>) {
        NSLog("Will Appear: com.aj-foster.sd-plugin-volume.dial")
        SystemVolume.listen(onLevelDidChange, onMuteDidChange)
        setFeedbackLayout(.indicator)
        setFeedback()
    }

    func dialRotate(device: String, payload: EncoderEvent<NoSettings>) {
        NSLog("Dial Rotate: com.aj-foster.sd-plugin-volume.dial")
        _ = SystemVolume.change(by: payload.ticks)

        self.level = SystemVolume.get()
        self.muted = SystemVolume.getMute()
        setFeedback()
    }

    func dialPress(device: String, payload: EncoderPressEvent<NoSettings>) {
        NSLog("Dial Press: com.aj-foster.sd-plugin-volume.dial")
        guard payload.pressed else { return }
        _ = SystemVolume.setMute(!(self.muted ?? false) )
        self.muted = SystemVolume.getMute()
        setFeedback()
    }

    func touchTap(device: String, payload: TouchTapEvent<NoSettings>) {
        NSLog("Touch Tap: com.aj-foster.sd-plugin-volume.dial")
        _ = SystemVolume.setMute(!(self.muted ?? false) )
        self.muted = SystemVolume.getMute()
        setFeedback()
    }
    
    // MARK: Helpers
    func setFeedback() {
        if self.muted == true {
            StreamDeckPlugin.shared.instances.values.forEach {
                $0.setFeedback([
                    "title"     : "System Volume",
                    "value"     : "Muted",
                    "icon"      : "assets/off.svg",
                    "indicator" : ["value" : self.level ?? 0, "enabled" : false] as [String : Any]
                ])
            }
        } else {
            let value: String = level == nil ? "Unknown" : "\(level!)"

            StreamDeckPlugin.shared.instances.values.forEach {
                $0.setFeedback([
                    "title"     : "System Volume",
                    "value"     : value,
                    "icon"      : "assets/on.svg",
                    "indicator" : ["value" : self.level ?? 0, "enabled" : true] as [String : Any]
                ])
            }
        }
    }
}
