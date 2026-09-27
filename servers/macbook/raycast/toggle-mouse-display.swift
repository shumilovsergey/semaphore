#!/usr/bin/env swift

import AppKit
import CoreGraphics

let mouse = NSEvent.mouseLocation
let screens = NSScreen.screens

guard screens.count >= 2 else {
    print("Only one display found")
    exit(1)
}

// NSScreen и CG используют разное направление Y,
// но для определения экрана здесь достаточно frame.contains().
guard let currentIndex = screens.firstIndex(where: { $0.frame.contains(mouse) }) else {
    print("Could not determine current display")
    exit(1)
}

let targetIndex = (currentIndex + 1) % screens.count
let target = screens[targetIndex].frame

// NSEvent coordinates -> CG coordinates
let mainHeight = NSScreen.screens[0].frame.height

let targetX = target.midX
let targetY = mainHeight - target.midY

CGWarpMouseCursorPosition(
    CGPoint(x: targetX, y: targetY)
)
