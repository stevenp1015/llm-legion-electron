import AppKit

let arg = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "generic"

let pattern: NSHapticFeedbackManager.FeedbackPattern
switch arg {
case "alignment":
    pattern = .alignment
case "levelChange":
    pattern = .levelChange
default:
    pattern = .generic
}

NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
