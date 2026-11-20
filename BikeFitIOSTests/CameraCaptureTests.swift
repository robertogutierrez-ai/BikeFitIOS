import XCTest
@testable import BikeFitIOS

final class CameraCaptureTests: XCTestCase {
    func testSwitchIsOnlyAllowedWhenCameraIsReadyAndIdle() {
        XCTAssertTrue(CameraCapture.canSwitchCamera(ready: true, recording: false, finishing: false, switching: false))
        XCTAssertFalse(CameraCapture.canSwitchCamera(ready: false, recording: false, finishing: false, switching: false))
        XCTAssertFalse(CameraCapture.canSwitchCamera(ready: true, recording: true, finishing: false, switching: false))
        XCTAssertFalse(CameraCapture.canSwitchCamera(ready: true, recording: false, finishing: true, switching: false))
        XCTAssertFalse(CameraCapture.canSwitchCamera(ready: true, recording: false, finishing: false, switching: true))
    }
}
