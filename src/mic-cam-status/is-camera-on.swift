#!/usr/bin/env swift
// is-camera-on: Check if any camera is currently in use on macOS
// Usage: is-camera-on [-q]
//   -q  Quiet mode, suppress stdout (exit code only)
// Exit 0 if camera is in use, exit 1 if not

import CoreMediaIO
import Foundation

let quiet = CommandLine.arguments.contains("-q") || CommandLine.arguments.contains("--quiet")

func getAllCameraDevices() -> [CMIOObjectID] {
    var address = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )

    var size: UInt32 = 0
    var status = CMIOObjectGetPropertyDataSize(
        CMIOObjectID(kCMIOObjectSystemObject),
        &address,
        0,
        nil,
        &size
    )

    guard status == noErr else { return [] }

    let count = Int(size) / MemoryLayout<CMIOObjectID>.size
    var deviceIDs = [CMIOObjectID](repeating: 0, count: count)

    status = CMIOObjectGetPropertyData(
        CMIOObjectID(kCMIOObjectSystemObject),
        &address,
        0,
        nil,
        size,
        &size,
        &deviceIDs
    )

    guard status == noErr else { return [] }
    return deviceIDs
}

func isCamera(_ deviceID: CMIOObjectID) -> Bool {
    // Check if the device has streams (cameras have streams, other devices might not)
    var streamAddress = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )

    return CMIOObjectHasProperty(deviceID, &streamAddress)
}

func isDeviceRunning(_ deviceID: CMIOObjectID) -> Bool {
    var address = CMIOObjectPropertyAddress(
        mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
        mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
        mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
    )

    guard CMIOObjectHasProperty(deviceID, &address) else { return false }

    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)

    let status = CMIOObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        size,
        &size,
        &isRunning
    )

    return status == noErr && isRunning != 0
}

func main() {
    let devices = getAllCameraDevices()

    if devices.isEmpty {
        if !quiet { print("no-camera") }
        exit(1)
    }

    for deviceID in devices {
        if isCamera(deviceID) && isDeviceRunning(deviceID) {
            if !quiet { print("in-use") }
            exit(0)
        }
    }

    if !quiet { print("not-in-use") }
    exit(1)
}

main()
