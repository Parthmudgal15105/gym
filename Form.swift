import Cocoa
import WebKit
class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKScriptMessageHandler, WKNavigationDelegate {
 var window: NSWindow!
 private let journalDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Gym", isDirectory: true)
 private var journalURL: URL { journalDirectory.appendingPathComponent("journal.json") }
 private var trustedPageURL: URL?

 private func secureJournalDirectory() throws {
  try FileManager.default.createDirectory(at: journalDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: journalDirectory.path)
 }
 private func isTrustedMainFrame(_ frame: WKFrameInfo) -> Bool {
  guard frame.isMainFrame, let trustedPageURL, let url = frame.request.url, url.isFileURL else { return false }
  return url.standardizedFileURL.path == trustedPageURL.standardizedFileURL.path
 }

 func applicationDidFinishLaunching(_ notification: Notification) {
  try? secureJournalDirectory()
  let iconURL = Bundle.main.url(forResource: "Gym", withExtension: "icns") ?? {
   let execDir = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath().deletingLastPathComponent()
   let candidate = execDir.appendingPathComponent("Gym.icns")
   return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
  }()
  if let iconURL = iconURL, let icon = NSImage(contentsOf: iconURL) { NSApp.applicationIconImage = icon }
  let config = WKWebViewConfiguration()
  config.websiteDataStore = .default()
  config.userContentController.add(self, name:"exportHistory")
  config.userContentController.add(self, name:"saveJournal")
  if let data = try? Data(contentsOf: journalURL),
     let object = try? JSONSerialization.jsonObject(with: data),
     let safeData = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed]),
     let json = String(data: safeData, encoding: .utf8) {
   config.userContentController.addUserScript(WKUserScript(source: "window.GYM_NATIVE_BACKUP = " + json + ";", injectionTime: .atDocumentStart, forMainFrameOnly: true))
  }
  let recoveryURL = journalDirectory.appendingPathComponent("legacy-recovery.json")
  if let data = try? Data(contentsOf: recoveryURL),
     let object = try? JSONSerialization.jsonObject(with: data), object is [Any],
     let safeData = try? JSONSerialization.data(withJSONObject: object),
     let json = String(data: safeData, encoding: .utf8) {
   config.userContentController.addUserScript(WKUserScript(source: "window.GYM_LEGACY_RECOVERY = " + json + ";", injectionTime: .atDocumentStart, forMainFrameOnly: true))
  }
  let web = WKWebView(frame: .zero, configuration: config)
  web.uiDelegate = self
  web.navigationDelegate = self
  window = NSWindow(contentRect:NSRect(x:0,y:0,width:1280,height:850),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
  // Keep the window alive after Close so Dock/Spotlight reopen can reuse it safely.
  window.isReleasedWhenClosed = false
  window.title = "Gym — Workout Calendar"
  window.minSize = NSSize(width:650,height:650)
  window.contentView = web
  window.center()
  let htmlURL: URL? = {
   if let bundleURL = Bundle.main.url(forResource: "index", withExtension: "html") {
    return bundleURL
   }
   if let bundleSubdirURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "dist") {
    return bundleSubdirURL
   }
   let execURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
   let execDir = execURL.resolvingSymlinksInPath().deletingLastPathComponent()
   let candidates = [
    execDir.appendingPathComponent("dist/index.html"),
    execDir.appendingPathComponent("index.html"),
    execDir.appendingPathComponent("../Resources/index.html").standardized,
    execDir.appendingPathComponent("../Resources/dist/index.html").standardized,
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("dist/index.html"),
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("index.html")
   ]
   for candidate in candidates {
    if FileManager.default.fileExists(atPath: candidate.path) {
     return candidate
    }
   }
   return nil
  }()
  guard let url = htmlURL else {
   let alert = NSAlert()
   alert.messageText = "Could not find index.html"
   alert.informativeText = "Unable to locate index.html in the application bundle resources or relative to the executable path. Please ensure dist/index.html exists."
   alert.alertStyle = .critical
   alert.runModal()
   NSApp.terminate(nil)
   return
  }
  trustedPageURL = url
  web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
  window.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps:true)
  let menu = NSMenu()
  let item = NSMenuItem(); menu.addItem(item)
  let submenu = NSMenu(); submenu.addItem(withTitle:"Quit Gym",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"); item.submenu=submenu; NSApp.mainMenu=menu
 }
 func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
  guard isTrustedMainFrame(message.frameInfo), let text = message.body as? String else { return }
  if message.name == "saveJournal" {
   guard let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], json["version"] as? Int == 3 else { return }
   do {
    try secureJournalDirectory()
    if let previous = try? Data(contentsOf: journalURL), previous != data {
     let backup = journalDirectory.appendingPathComponent("journal-previous.json")
     try previous.write(to: backup, options: .atomic)
     try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
    }
    try data.write(to: journalURL, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journalURL.path)
   } catch { NSLog("Gym local journal backup failed: %@", error.localizedDescription) }
   return
  }
  let panel = NSSavePanel(); panel.nameFieldStringValue = "gym-journal.json"
  if panel.runModal() == .OK, let url = panel.url { do { try text.write(to:url,atomically:true,encoding:.utf8) } catch { let alert=NSAlert();alert.messageText="Could not export history";alert.informativeText=error.localizedDescription;alert.runModal() } }
 }
 func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
  guard navigationAction.targetFrame?.isMainFrame == true,
        let trustedPageURL,
        let destination = navigationAction.request.url,
        destination.isFileURL,
        destination.standardizedFileURL.path == trustedPageURL.standardizedFileURL.path else {
   decisionHandler(.cancel); return
  }
  decisionHandler(.allow)
 }
 func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) { guard isTrustedMainFrame(frame) else { completionHandler(nil); return };let panel=NSOpenPanel();panel.allowsMultipleSelection=false;completionHandler(panel.runModal() == .OK ? panel.urls : nil) }
 func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {
  guard let window = window else { return false }
  window.makeKeyAndOrderFront(nil)
  sender.activate(ignoringOtherApps:true)
  return true
 }
 func webView(_ webView:WKWebView,runJavaScriptConfirmPanelWithMessage message:String,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping(Bool)->Void){guard isTrustedMainFrame(frame) else { completionHandler(false); return };let alert=NSAlert();alert.messageText=message;alert.addButton(withTitle:"Delete");alert.addButton(withTitle:"Cancel");completionHandler(alert.runModal() == .alertFirstButtonReturn)}
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate=delegate
app.setActivationPolicy(.regular)
app.run()
