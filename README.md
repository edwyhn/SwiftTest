# What On Earth? — SwiftUI starter project

This is a native SwiftUI prototype based on the rules and dashboard description supplied in the conversation.

## Included
- Player setup, rename, add/remove players, and seating order controls (use each row's context menu to move it up/down).
- Two rotating Alien guessers.
- Concept reveal, skip/previous controls, 2:30 timer, pause/resume.
- Per-player scoring, between-turn scoreboard, cheeky mode toggle.
- 430+ family-friendly British-themed concepts plus a separate set of mild cheeky concepts.
- Rules screen and a configurable finish-line score.

## Important prototype notes
- The supplied rules did not specify the physical board's track length, so the finish-line score is a customisable convenience rather than an official rule.
- This first build focuses on Earth Cards and score tracking; it does not digitally deal Translator Cards.
- The cheeky deck is intentionally non-explicit.
- This project has not been compiled in this environment. Open it in Xcode on macOS and resolve any compiler issues before installing.
- The bundle identifier is `com.example.WhatOnEarth`; change it to a unique identifier for signing.
- Minimum deployment target is iOS 17.

## Build and install from Windows
1. Use a trusted cloud Mac service or a Mac you can access.
2. Transfer this entire folder to that Mac.
3. Open `WhatOnEarth.xcodeproj` in Xcode.
4. In the project target's **Signing & Capabilities**, select your Apple Account team and change the bundle identifier to a unique value.
5. Connect your iPhone to the Mac (or use supported wireless device pairing), select it as the run destination, and press Run.
6. For an IPA, use **Product → Archive** when the project is configured for device distribution, then use Xcode's distribution/export workflow. Choose the appropriate development/ad hoc distribution method for your own device.
7. Follow Apple's signing and trust prompts on the iPhone. Sideloading methods depend on the signing type and your Apple account.

An IPA is not simply a zip of Swift files: it must contain a compiled app and a valid signature for the intended installation method.
