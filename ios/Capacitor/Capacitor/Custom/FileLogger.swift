import Foundation
import os
#if canImport(UIKit)
import UIKit
#endif
import ZIPFoundation

public class FileLogger {
    static private var fileHandle: FileHandle?
    static private let noData: Data = .init()
    private let RFC3339DateFormatter = DateFormatter()
#if DEBUG
    private let log: Logger?
#endif
    let category: String
    static private var format: String = "%s %+7s T:%x %+5s %s\n"
    static private var maxCategory = 7
    public init(subsystem: String, category: String) {
#if DEBUG
        log = Logger(subsystem: subsystem, category: category)
#endif
        self.category = category
        if category.count >= Self.maxCategory {
            Self.maxCategory = category.count + 1
            Self.format = "%s %+\(Self.maxCategory)s T:%x %+5s %s\n"
        }
        
        RFC3339DateFormatter.locale = Locale(identifier: "en_US_POSIX")
        RFC3339DateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        if Self.fileHandle == nil {
            RFC3339DateFormatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
            let fm = FileManager.default
            if let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
                //print("Documents base path: \(docsDir)")
                let logsDir = docsDir.appendingPathComponent("logs")
                if !fm.fileExists(atPath: logsDir.path) {
                    try! fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
                }
                if let allZipFiles = try? fm.subpathsOfDirectory(atPath: logsDir.path).filter({ $0.hasSuffix(".\(subsystem).log.zip") }),
                   let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date()) {
                    for logZipFile in allZipFiles {
                        let fileUrl = logsDir.appendingPathComponent(logZipFile)
                        if let attributes = try? fm.attributesOfItem(atPath: fileUrl.path) {
                            if let modifiedDate = attributes[.modificationDate] as? Date {
                                if modifiedDate < oneYearAgo {
                                    try! fm.removeItem(at: fileUrl)
                                }
                            }
                        }
                    }
                }
                if let allLogFiles = try? fm.subpathsOfDirectory(atPath: docsDir.path).filter({ $0.hasSuffix(".\(subsystem).log") }) {
                    for logFile in allLogFiles {
                        let fileUrl = docsDir.appendingPathComponent(logFile)
                        let zipFileUrl = logsDir.appendingPathComponent(logFile).appendingPathExtension("zip")
                        do {
                            try fm.zipItem(at: fileUrl, to: zipFileUrl, compressionMethod: .deflate)
                            try fm.removeItem(at: fileUrl)
                        }
                        catch {
                            print("Failed to zip log file '\(fileUrl.path)': \(error.localizedDescription)")
                        }
                    }
                }
#if canImport(UIKit)
                let deviceName = UIDevice.current.name
#else
                let deviceName = Host.current().localizedName ?? "mac"
#endif
                let baseFileName = "\(deviceName)-\(RFC3339DateFormatter.string(from: Date()))"
                let logFilePath = docsDir.appendingPathComponent(baseFileName).appendingPathExtension("\(subsystem).log").path
                if !fm.fileExists(atPath: logFilePath) {
                    fm.createFile(atPath: logFilePath,  contents:Data(" ".utf8), attributes: nil)
                }
                Self.fileHandle = .init(forWritingAtPath: logFilePath)
                
                // #if DEBUG
                // let consFilePath = docsDir.appendingPathComponent(baseFileName).appendingPathExtension("console.log").path
                // if !fm.fileExists(atPath: consFilePath) {
                //     fm.createFile(atPath: consFilePath,  contents:Data(" ".utf8), attributes: nil)
                // }
                // let cstrConsFilePath = consFilePath.utf8CString
                // let _ = cstrConsFilePath.withUnsafeBufferPointer {
                //     return freopen($0.baseAddress, "a+", stdout)
                // }
                // #endif
            }
        }
        RFC3339DateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    private func writeLogLine(_ level: String, message: String) {
        let threadId = Thread.current.isMainThread ? 0 : 1
        if let timestamp = (RFC3339DateFormatter.string(from: Date()) as NSString).utf8String,
           let cstrCat = (category as NSString).utf8String,
           let lvl = (level as NSString).utf8String,
           let msg = (message as NSString).utf8String {
            let logline = String(format: Self.format, timestamp, cstrCat, threadId, lvl, msg)
            if let contents = logline.data(using: .utf8) {
                do {
                    try Self.fileHandle?.write(contentsOf: contents)
                }
                catch {}
            }
        }
    }
    
    public func debug(_ message: String) {
        log?.debug("\(message)")
#if DEBUG
        writeLogLine("DEBUG", message: message)
#endif
    }
    
    public func info(_ message: String) {
        log?.info("\(message)")
        writeLogLine("INFO", message: message)
    }
    
    public func notice(_ message: String) {
        log?.notice("\(message)")
        writeLogLine("NOTE", message: message)
    }
    
    public func warning(_ message: String) {
        log?.warning("\(message)")
        writeLogLine("WARN", message: message)
    }
    
    public func error(_ message: String) {
        log?.error("\(message)")
        writeLogLine("ERROR", message: message)
    }
    
    public func critical(_ message: String) {
        log?.critical("\(message)")
        writeLogLine("CRIT", message: message)
    }
    
    public func fault(_ message: String) {
        log?.fault("\(message)")
        writeLogLine("FAULT", message: message)
    }
}
