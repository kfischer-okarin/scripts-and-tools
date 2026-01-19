#!/usr/bin/env swift
// is-mic-on: Check if any audio input device is currently in use on macOS
// Usage: is-mic-on [-q]
//   -q  Quiet mode, suppress stdout (exit code only)
// Exit 0 if microphone is in use, exit 1 if not

import CoreAudio
import Foundation

let quiet = CommandLine.arguments.contains("-q") || CommandLine.arguments.contains("--quiet")

func getDefaultInputDevice() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &deviceID
    )

    return status == noErr ? deviceID : nil
}

func isDeviceRunningSomewhere(_ deviceID: AudioDeviceID) -> Bool {
    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &size,
        &isRunning
    )

    return status == noErr && isRunning != 0
}

func main() {
    guard let deviceID = getDefaultInputDevice() else {
        if !quiet { print("no-input-device") }
        exit(1)
    }

    if isDeviceRunningSomewhere(deviceID) {
        if !quiet { print("in-use") }
        exit(0)
    } else {
        if !quiet { print("not-in-use") }
        exit(1)
    }
}

main()
