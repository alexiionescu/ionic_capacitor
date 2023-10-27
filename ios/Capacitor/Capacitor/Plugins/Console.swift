import Foundation

@objc(CAPConsolePlugin)
public class CAPConsolePlugin: CAPPlugin {
    let log = FileLogger(subsystem: "capacitor", category: "CAPConsole")

    @objc public func log(_ call: CAPPluginCall) {
        let message = call.getString("message") ?? ""
        let level = call.getString("level") ?? "log"
        switch level {
        case "log", "info":
            self.log.info(message)
        case "error":
            self.log.error(message)
        case "warn":
            self.log.warning(message)
        default:
            self.log.debug(message)
            break
        }
        // CAPLog.print("⚡️  [\(level)] - \(message)")
    }
}
