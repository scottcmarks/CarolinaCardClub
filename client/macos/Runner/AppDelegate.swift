import Cocoa
import FlutterMacOS
import Network

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    primeLocalNetworkPath()
  }

  // On macOS Sequoia, BSD sockets (used by dart:io) do not trigger or benefit from
  // the Local Network Privacy dialog. Network.framework NWConnection does. We read
  // the saved server IP and open an NWConnection to it so the OS establishes an
  // allowed network path for that host — after which dart:io connections to the
  // same address succeed.
  private func primeLocalNetworkPath() {
    var host = "127.0.0.1"
    var port: UInt16 = 5109

    if let json = UserDefaults.standard.string(forKey: "flutter.ccc_app_settings"),
       let data = json.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      host = obj["serverIp"] as? String ?? host
      port = UInt16(obj["serverPort"] as? Int ?? Int(port))
    }

    let conn = NWConnection(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: port)!,
      using: .tcp
    )
    conn.stateUpdateHandler = { state in
      // We only care about triggering the path — cancel after any state change.
      if state != .setup { conn.cancel() }
    }
    conn.start(queue: .global())
  }
}
