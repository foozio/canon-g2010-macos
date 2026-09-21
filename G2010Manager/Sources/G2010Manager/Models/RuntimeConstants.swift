import Foundation

/// Single source of truth for machine-identity constants (TASK-011).
/// Port/queue/label/serial literals lived in 4+ places across shell and Swift
/// with no shared owner — reference these instead of re-stating values.
/// Printer identity itself is overridable at runtime (PRINTSERVER_DEVICE_URI
/// for the pipeline, G2010_DEVICE_URI / G2010_SCANNER_DEVICE for the app);
/// the serial below is the default, not the only supported device.
public enum RuntimeConstants {
    public static let agentLabel = "com.foozio.g2010.printserver"
    public static let ippPort: UInt16 = 8632
    public static let queueName = "G2010IPP"
    public static let ippURI = "ipp://localhost:8632/ipp/print"
    public static let printerSerial = "0C7A8F"
    public static let deviceURI = "usb://Canon/G2010%20series?serial=" + printerSerial
    public static let scannerDevice = "pixma:04A9183A_" + printerSerial
}
