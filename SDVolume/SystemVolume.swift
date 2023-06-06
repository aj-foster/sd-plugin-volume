//
//  SystemVolume.swift
//  SDVolume
//
//  Created by AJ Foster on 6/4/23.
//
// This file includes code adapted from
// https://github.com/InerziaSoft/ISSoundAdditions/tree/6f4c22c13d02fe1dc8aae6c6eb20c5c3d53c1e5d/Sources/ISSoundAdditions
// released under the MIT license.
//

import Foundation
import CoreAudio
import AudioToolbox

struct SystemVolume {
    enum SVError: Error {
        case systemError(OSStatus)
        case deviceNotFound
    }
    
    public static func get() -> Int? {
        guard let deviceID = try? defaultOutputDevice() else { return nil }
        var propertyAddress = volumePropertyAddress()
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return nil }
        
        var volume: Float = 0
        var volumeSize = UInt32(MemoryLayout.size(ofValue: volume))
        
        let error = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &volumeSize, &volume)
        guard error == noErr else { return nil }
        
        return fromSystemLevel(volume)
    }
    
    public static func set(to level: Int) -> Bool {
        guard let deviceID = try? defaultOutputDevice() else { return false }
        var propertyAddress = volumePropertyAddress()
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return false }
        
        var canChangeVolume = DarwinBoolean(true)
        let canChangeVolumeError = AudioObjectIsPropertySettable(deviceID, &propertyAddress, &canChangeVolume)
        
        guard canChangeVolumeError == noErr else { return false }
        guard canChangeVolume.boolValue else { return false }
        
        var normalizedLevel = toSystemLevel(level)
        let normalizedLevelSize = UInt32(MemoryLayout.size(ofValue: normalizedLevel))
        
        let setError = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, normalizedLevelSize, &normalizedLevel)
        guard setError == noErr else { return false }
        
        return true
    }
    
    public static func change(by delta: Int) -> Bool {
        if let currentValue = get() {
            return set(to: currentValue + delta)
        } else {
            return false
        }
    }
    
    public static func getMute() -> Bool? {
        guard let deviceID = try? defaultOutputDevice() else { return nil }
        var propertyAddress = mutePropertyAddress()
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return nil }

        var isMuted: UInt32 = 0
        var isMutedSize = UInt32(MemoryLayout.size(ofValue: isMuted))
        
        let error = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &isMutedSize, &isMuted)
        guard error == noErr else { return nil }
        
        return isMuted == 1
    }
    
    public static func setMute(_ muted: Bool) -> Bool {
        guard let deviceID = try? defaultOutputDevice() else { return false }
        var propertyAddress = mutePropertyAddress()
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return false }
        
        var muted: UInt = muted ? 1 : 0
        let mutedSize = UInt32(MemoryLayout.size(ofValue: muted))
        
        var canMute = DarwinBoolean(true)
        let canMuteError = AudioObjectIsPropertySettable(deviceID, &propertyAddress, &canMute)
        guard canMuteError == noErr else { return false }
        
        let setError = AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, mutedSize, &muted)
        guard setError == noErr else { return false }

        return true
    }
    
    private static func defaultOutputDevice() throws -> AudioDeviceID? {
        var result = kAudioObjectUnknown
        var resultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
          mSelector: kAudioHardwarePropertyDefaultOutputDevice,
          mScope: kAudioObjectPropertyScopeGlobal,
          mElement: kAudioObjectPropertyElementMain
        )
        
        guard AudioObjectHasProperty(AudioObjectID(kAudioObjectSystemObject), &propertyAddress) else { return nil }
        
        let error = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &resultSize, &result)
        
        guard error == noErr else { throw SVError.systemError(error) }
        guard result != kAudioDeviceUnknown else { throw SVError.deviceNotFound }
        
        return result
    }
    
    private static func mutePropertyAddress() -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
    
    private static func volumePropertyAddress() -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
    
    private static func toSystemLevel(_ level: Int) -> Float {
        let clamped = min(max(0, level), 100)
        return Float(clamped) / 100.0
    }
    
    private static func fromSystemLevel(_ level: Float) -> Int {
        let scaled = level * 100.0
        let rounded = Int(round(scaled))
        return min(max(0, rounded), 100)
    }
}
