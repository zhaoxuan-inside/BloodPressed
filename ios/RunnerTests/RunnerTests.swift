import Foundation
import XCTest

class RunnerTests: XCTestCase {

  func testCapturePermissionsHaveUsageDescriptions() throws {
    for key in [
      "NSCameraUsageDescription",
      "NSPhotoLibraryUsageDescription",
      "NSMicrophoneUsageDescription",
      "NSSpeechRecognitionUsageDescription",
    ] {
      let description = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: key) as? String, key)
      XCTAssertFalse(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, key)
    }
  }

}
