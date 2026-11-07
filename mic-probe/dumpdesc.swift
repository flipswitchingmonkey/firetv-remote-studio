import Foundation
import IOKit.hid
let m = IOHIDManagerCreate(kCFAllocatorDefault, 0)
IOHIDManagerSetDeviceMatching(m, [kIOHIDVendorIDKey: 0x171, kIOHIDProductIDKey: 0x42f] as CFDictionary)
let devs = (IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice>) ?? []
print("devices:", devs.count)
for d in devs {
  for k in [kIOHIDProductKey, kIOHIDTransportKey, kIOHIDPrimaryUsagePageKey, kIOHIDPrimaryUsageKey, kIOHIDMaxInputReportSizeKey, kIOHIDMaxOutputReportSizeKey, kIOHIDMaxFeatureReportSizeKey, kIOHIDReportIntervalKey] {
    print(k, "=", IOHIDDeviceGetProperty(d, k as CFString) ?? "nil")
  }
  if let desc = IOHIDDeviceGetProperty(d, kIOHIDReportDescriptorKey as CFString) as? Data {
    print("descriptor bytes:", desc.count)
    print(desc.map { String(format: "%02x", $0) }.joined(separator: " "))
    try? desc.write(to: URL(fileURLWithPath: "descriptor.bin"))
  }
}
