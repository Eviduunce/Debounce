//
//  KeyCodeMapper.swift
//  KCBforMac
//
//  Created by Timo Leisengang on 07.10.25.
//

import Carbon.HIToolbox

/// Maps macOS key codes to human-readable names
class KeyCodeMapper {

    /// Map CGKeyCode to readable string name
    static func keyName(for keyCode: CGKeyCode) -> String {
        // Common keys with readable names
        switch keyCode {
        case UInt16(kVK_ANSI_A): return "A"
        case UInt16(kVK_ANSI_S): return "S"
        case UInt16(kVK_ANSI_D): return "D"
        case UInt16(kVK_ANSI_F): return "F"
        case UInt16(kVK_ANSI_H): return "H"
        case UInt16(kVK_ANSI_G): return "G"
        case UInt16(kVK_ANSI_Z): return "Z"
        case UInt16(kVK_ANSI_X): return "X"
        case UInt16(kVK_ANSI_C): return "C"
        case UInt16(kVK_ANSI_V): return "V"
        case UInt16(kVK_ANSI_B): return "B"
        case UInt16(kVK_ANSI_Q): return "Q"
        case UInt16(kVK_ANSI_W): return "W"
        case UInt16(kVK_ANSI_E): return "E"
        case UInt16(kVK_ANSI_R): return "R"
        case UInt16(kVK_ANSI_Y): return "Y"
        case UInt16(kVK_ANSI_T): return "T"
        case UInt16(kVK_ANSI_1): return "1"
        case UInt16(kVK_ANSI_2): return "2"
        case UInt16(kVK_ANSI_3): return "3"
        case UInt16(kVK_ANSI_4): return "4"
        case UInt16(kVK_ANSI_6): return "6"
        case UInt16(kVK_ANSI_5): return "5"
        case UInt16(kVK_ANSI_Equal): return "Equal"
        case UInt16(kVK_ANSI_9): return "9"
        case UInt16(kVK_ANSI_7): return "7"
        case UInt16(kVK_ANSI_Minus): return "Minus"
        case UInt16(kVK_ANSI_8): return "8"
        case UInt16(kVK_ANSI_0): return "0"
        case UInt16(kVK_ANSI_RightBracket): return "RightBracket"
        case UInt16(kVK_ANSI_O): return "O"
        case UInt16(kVK_ANSI_U): return "U"
        case UInt16(kVK_ANSI_LeftBracket): return "LeftBracket"
        case UInt16(kVK_ANSI_I): return "I"
        case UInt16(kVK_ANSI_P): return "P"
        case UInt16(kVK_ANSI_L): return "L"
        case UInt16(kVK_ANSI_J): return "J"
        case UInt16(kVK_ANSI_Quote): return "Quote"
        case UInt16(kVK_ANSI_K): return "K"
        case UInt16(kVK_ANSI_Semicolon): return "Semicolon"
        case UInt16(kVK_ANSI_Backslash): return "Backslash"
        case UInt16(kVK_ANSI_Comma): return "Comma"
        case UInt16(kVK_ANSI_Slash): return "Slash"
        case UInt16(kVK_ANSI_N): return "N"
        case UInt16(kVK_ANSI_M): return "M"
        case UInt16(kVK_ANSI_Period): return "Period"
        case UInt16(kVK_ANSI_Grave): return "Grave"

        // Special keys
        case UInt16(kVK_Return): return "Return"
        case UInt16(kVK_Tab): return "Tab"
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_Delete): return "Delete"
        case UInt16(kVK_Escape): return "Escape"
        case UInt16(kVK_Command): return "Command"
        case UInt16(kVK_Shift): return "Shift"
        case UInt16(kVK_CapsLock): return "CapsLock"
        case UInt16(kVK_Option): return "Option"
        case UInt16(kVK_Control): return "Control"
        case UInt16(kVK_RightCommand): return "RightCommand"
        case UInt16(kVK_RightShift): return "RightShift"
        case UInt16(kVK_RightOption): return "RightOption"
        case UInt16(kVK_RightControl): return "RightControl"
        case UInt16(kVK_Function): return "Function"

        // Arrow keys
        case UInt16(kVK_LeftArrow): return "LeftArrow"
        case UInt16(kVK_RightArrow): return "RightArrow"
        case UInt16(kVK_DownArrow): return "DownArrow"
        case UInt16(kVK_UpArrow): return "UpArrow"

        // Function keys
        case UInt16(kVK_F1): return "F1"
        case UInt16(kVK_F2): return "F2"
        case UInt16(kVK_F3): return "F3"
        case UInt16(kVK_F4): return "F4"
        case UInt16(kVK_F5): return "F5"
        case UInt16(kVK_F6): return "F6"
        case UInt16(kVK_F7): return "F7"
        case UInt16(kVK_F8): return "F8"
        case UInt16(kVK_F9): return "F9"
        case UInt16(kVK_F10): return "F10"
        case UInt16(kVK_F11): return "F11"
        case UInt16(kVK_F12): return "F12"
        case UInt16(kVK_F13): return "F13"
        case UInt16(kVK_F14): return "F14"
        case UInt16(kVK_F15): return "F15"
        case UInt16(kVK_F16): return "F16"
        case UInt16(kVK_F17): return "F17"
        case UInt16(kVK_F18): return "F18"
        case UInt16(kVK_F19): return "F19"
        case UInt16(kVK_F20): return "F20"

        // Keypad
        case UInt16(kVK_ANSI_Keypad0): return "Keypad0"
        case UInt16(kVK_ANSI_Keypad1): return "Keypad1"
        case UInt16(kVK_ANSI_Keypad2): return "Keypad2"
        case UInt16(kVK_ANSI_Keypad3): return "Keypad3"
        case UInt16(kVK_ANSI_Keypad4): return "Keypad4"
        case UInt16(kVK_ANSI_Keypad5): return "Keypad5"
        case UInt16(kVK_ANSI_Keypad6): return "Keypad6"
        case UInt16(kVK_ANSI_Keypad7): return "Keypad7"
        case UInt16(kVK_ANSI_Keypad8): return "Keypad8"
        case UInt16(kVK_ANSI_Keypad9): return "Keypad9"
        case UInt16(kVK_ANSI_KeypadMultiply): return "KeypadMultiply"
        case UInt16(kVK_ANSI_KeypadPlus): return "KeypadPlus"
        case UInt16(kVK_ANSI_KeypadClear): return "KeypadClear"
        case UInt16(kVK_ANSI_KeypadDivide): return "KeypadDivide"
        case UInt16(kVK_ANSI_KeypadEnter): return "KeypadEnter"
        case UInt16(kVK_ANSI_KeypadMinus): return "KeypadMinus"
        case UInt16(kVK_ANSI_KeypadEquals): return "KeypadEquals"
        case UInt16(kVK_ANSI_KeypadDecimal): return "KeypadDecimal"

        // Other
        case UInt16(kVK_ForwardDelete): return "ForwardDelete"
        case UInt16(kVK_Home): return "Home"
        case UInt16(kVK_End): return "End"
        case UInt16(kVK_PageUp): return "PageUp"
        case UInt16(kVK_PageDown): return "PageDown"
        case UInt16(kVK_Help): return "Help"
        case UInt16(kVK_VolumeUp): return "VolumeUp"
        case UInt16(kVK_VolumeDown): return "VolumeDown"
        case UInt16(kVK_Mute): return "Mute"

        default:
            return "Key\(keyCode)"
        }
    }

    /// Convert key name string back to key code (for configuration)
    static func keyCode(for name: String) -> CGKeyCode? {
        switch name.uppercased() {
        case "A": return UInt16(kVK_ANSI_A)
        case "S": return UInt16(kVK_ANSI_S)
        case "D": return UInt16(kVK_ANSI_D)
        case "F": return UInt16(kVK_ANSI_F)
        case "H": return UInt16(kVK_ANSI_H)
        case "G": return UInt16(kVK_ANSI_G)
        case "Z": return UInt16(kVK_ANSI_Z)
        case "X": return UInt16(kVK_ANSI_X)
        case "C": return UInt16(kVK_ANSI_C)
        case "V": return UInt16(kVK_ANSI_V)
        case "B": return UInt16(kVK_ANSI_B)
        case "Q": return UInt16(kVK_ANSI_Q)
        case "W": return UInt16(kVK_ANSI_W)
        case "E": return UInt16(kVK_ANSI_E)
        case "R": return UInt16(kVK_ANSI_R)
        case "Y": return UInt16(kVK_ANSI_Y)
        case "T": return UInt16(kVK_ANSI_T)
        case "RETURN", "ENTER": return UInt16(kVK_Return)
        case "TAB": return UInt16(kVK_Tab)
        case "SPACE": return UInt16(kVK_Space)
        case "DELETE", "BACKSPACE": return UInt16(kVK_Delete)
        case "ESCAPE", "ESC": return UInt16(kVK_Escape)
        default: return nil
        }
    }
}
