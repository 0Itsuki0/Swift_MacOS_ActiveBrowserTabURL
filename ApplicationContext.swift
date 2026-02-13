

import SwiftUI
import Carbon
import Cocoa
import ApplicationServices

class BrowserContext {
    static func getActiveAppInfo() {
        // Get the shared workspace instance
        let workspace = NSWorkspace.shared
        
        // Get the frontmost application
        if let frontmostApp = workspace.frontmostApplication {
            let appName = frontmostApp.localizedName ?? "Unknown Name"
            let bundleIdentifier = frontmostApp.bundleIdentifier ?? "Unknown Identifier"
            let processIdentifier = frontmostApp.processIdentifier
            
            print("Current active app:")
            print("Name: \(appName)")
            print("Bundle Identifier: \(bundleIdentifier)")
            print("PID: \(processIdentifier)")
        } else {
            print("Could not determine the frontmost application.")
        }
    }
    
    static func getChromeActiveURL() -> String? {
        let source = """
        tell application "Google Chrome"
            return URL of active tab of front window
        end tell
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            if let output = script.executeAndReturnError(&error).stringValue {
                return output
            } else {
                if let error = error {
                    print("AppleScript error: \(error)")
                }
            }
        }
        return nil
    }
    
    static func getFireFoxActiveURL() -> String? {
        simulateKeyDown(key: CGKeyCode(kVK_ANSI_L), with: .maskCommand)
        simulateKeyDown(key: CGKeyCode(kVK_ANSI_C), with: .maskCommand)
        let url = NSPasteboard.general.string(forType: .string)
        return url
    }
    
    static private func simulateKeyDown(key: CGKeyCode, with flags: CGEventFlags) {
        let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: key,
            keyDown: true
        )
        event?.flags = flags
        event?.post(tap: CGEventTapLocation.cghidEventTap)
    }


    
    static func getSafariActiveURL() -> String? {
        let source = """
        tell application "Safari"
            return URL of current tab of front window
        end tell
        """


        var error: NSDictionary?
        let scriptObject = NSAppleScript(source: source)
        
        if let output = scriptObject?.executeAndReturnError(&error).stringValue {
            return output
        } else if (error != nil) {
            print("error: \(error!)")
        }
        return nil
    }
    
    static func getAllTabInfoForSafari() -> String? {
        let source = """
        set r to ""
        tell application "Safari"
            repeat with w in windows
                if exists current tab of w then
                    repeat with t in tabs of w
                        tell t to set r to r & "Title : " & name & ", URL : " & URL & linefeed
                    end repeat
                end if
            end repeat
        end tell
        return r
        """

        var error: NSDictionary?
        let scriptObject = NSAppleScript(source: source)
        
        if let output = scriptObject?.executeAndReturnError(&error).stringValue {
            return output
        } else if (error != nil) {
            print("error: \(error!)")
        }
        return nil

    }
    
    static func requestAutomationPermission(_ applicationName: String) -> Bool {
        let source = "tell application \"\(applicationName)\" to get front window"
        if let scriptObject = NSAppleScript(source: source) {
            var error: NSDictionary? = nil
            let _ = scriptObject.executeAndReturnError(&error)
            // errAEEventNotPermitted: -1743
            if let error, error[NSAppleScript.errorNumber] as? Int == errAEEventNotPermitted  {
                // Error handling if needed.
                // A common error for the first time is -1743 (not authorized).
                print("Permission denied")
                return false
            } else {
                print("Successfully executed AppleScript command (permission granted or already existed).")
                return true
            }
        }
        return false
    }
    
    static func getActiveURL() -> URL? {
        do {
            let focusedApplication =
                try findFocusedApplication()
            let focusedWindow =
                try getElementValueForAttribute(
                    on: focusedApplication,
                    attribute: kAXMainWindowAttribute
                )

            var child = try getFirstChild(on: focusedWindow)
            var loopCount = 0
            let maxLoopCount = 10
            // need to loop for like 5 times...
            while let _child = child, loopCount < maxLoopCount {
                if let url = try? getURL(on: _child) {
                    print(url)
                    print(loopCount)
                    return url
                }
                child = try? getFirstChild(on: _child)
                loopCount += 1
            }
            
        } catch (let error) {
            print(error)
        }
        return nil

    }

    
    static func getTypeRefForAttribute(
        on element: AXUIElement,
        attribute: String
    ) throws -> CFTypeRef {
        var value: CFTypeRef?

        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        try checkAXError(error)

        guard let value else {
            throw AccessibilityError.generalFailure
        }

        return value
    }

    
    static func getElementValueForAttribute(
        on element: AXUIElement,
        attribute: String
    ) throws -> AXUIElement {
        print(#function)

        guard
            let value = try self.getTypeRefForAttribute(
                on: element,
                attribute: attribute
            ) as! AXUIElement?
        else {
            throw AccessibilityError.generalFailure
        }

        return value
    }

    
    static func findFocusedApplication() throws -> AXUIElement {
        print(#function)

        let focusedAXElement = try self.getElementValueForAttribute(
            on: AXUIElementCreateSystemWide(),
            attribute: kAXFocusedApplicationAttribute
        )
        return focusedAXElement
    }

    
    static func getFirstChild(on element: AXUIElement) throws -> AXUIElement? {
        print(#function)
        let children = (try getTypeRefForAttribute(on: element, attribute: kAXChildrenAttribute)) as? Array<AXUIElement>
        return children?.first
    }
    
    static func getURL(on element: AXUIElement) throws -> URL? {
        let url = try getTypeRefForAttribute(on: element, attribute: kAXURLAttribute) as? URL
        return url
    }
    
    static func checkAXError(_ error: AXError) throws {
        if let error = AccessibilityError(error) {
            throw error
        }
    }
}


