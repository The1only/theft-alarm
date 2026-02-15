#!/usr/bin/env swift
import IOKit.pwr_mgt
import Foundation

var assertionID: IOPMAssertionID = 0

print("Creating sleep prevention assertion...")
let reasonForActivity = "Testing alarm sleep prevention" as CFString
let result = IOPMAssertionCreateWithName(
    "NoIdleSleepAssertion" as CFString,
    IOPMAssertionLevel(kIOPMAssertionLevelOn),
    reasonForActivity,
    &assertionID
)

if result == kIOReturnSuccess {
    print("✅ Sleep prevention enabled successfully (ID: \(assertionID))")
    print("🛌 Your Mac should NOT sleep now. Run 'pmset -g assertions' to verify")
    print("Press any key to disable and exit...")
    _ = readLine()
    
    let releaseResult = IOPMAssertionRelease(assertionID)
    if releaseResult == kIOReturnSuccess {
        print("😴 Sleep prevention disabled")
    } else {
        print("❌ Failed to release assertion: \(releaseResult)")
    }
} else {
    print("❌ Failed to create sleep assertion: \(result)")
}