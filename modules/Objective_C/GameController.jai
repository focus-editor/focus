// :AwfulCopyPasta

GCControllerElement :: struct {
    using nsobject: NSObject;
    collection :: (self: *GCControllerElement) -> *GCControllerElement {
        _func: (obj: *void, selector: *void) -> *GCControllerElement #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.collection);
    }

    isAnalog :: (self: *GCControllerElement) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.isAnalog);
    }

}

GCControllerAxisInput :: struct {
    using gccontrollerelement: GCControllerElement;
    valueChangedHandler :: (self: *GCControllerAxisInput) -> GCControllerAxisValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerAxisValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCControllerAxisInput, valueChangedHandler: GCControllerAxisValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCControllerAxisValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    value :: (self: *GCControllerAxisInput) -> float32 {
        _func: (obj: *void, selector: *void) -> float32 #foreign;
        _func = xx objc_msgSend_fpret;
        return _func(self, __selectors.value);
    }

}

GCControllerAxisValueChangedHandler :: *void;

GCControllerButtonInput :: struct {
    using gccontrollerelement: GCControllerElement;
    valueChangedHandler :: (self: *GCControllerButtonInput) -> GCControllerButtonValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerButtonValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCControllerButtonInput, valueChangedHandler: GCControllerButtonValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCControllerButtonValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    pressedChangedHandler :: (self: *GCControllerButtonInput) -> GCControllerButtonValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerButtonValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.pressedChangedHandler);
    }

    setPressedChangedHandler :: (self: *GCControllerButtonInput, pressedChangedHandler: GCControllerButtonValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, pressedChangedHandler: GCControllerButtonValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setPressedChangedHandler_, pressedChangedHandler);
    }

    value :: (self: *GCControllerButtonInput) -> float32 {
        _func: (obj: *void, selector: *void) -> float32 #foreign;
        _func = xx objc_msgSend_fpret;
        return _func(self, __selectors.value);
    }

    isPressed :: (self: *GCControllerButtonInput) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.isPressed);
    }

}

GCControllerButtonValueChangedHandler :: *void;

GCControllerDirectionPad :: struct {
    using gccontrollerelement: GCControllerElement;
    valueChangedHandler :: (self: *GCControllerDirectionPad) -> GCControllerDirectionPadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerDirectionPadValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCControllerDirectionPad, valueChangedHandler: GCControllerDirectionPadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCControllerDirectionPadValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    xAxis :: (self: *GCControllerDirectionPad) -> *GCControllerAxisInput {
        _func: (obj: *void, selector: *void) -> *GCControllerAxisInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.xAxis);
    }

    yAxis :: (self: *GCControllerDirectionPad) -> *GCControllerAxisInput {
        _func: (obj: *void, selector: *void) -> *GCControllerAxisInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.yAxis);
    }

    up :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.up);
    }

    down :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.down);
    }

    left :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.left);
    }

    right :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.right);
    }

}

GCControllerDirectionPadValueChangedHandler :: *void;

GCAcceleration :: struct {
    x: float64;
    y: float64;
    z: float64;
}

GCRotationRate :: struct {
    x: float64;
    y: float64;
    z: float64;
}

GCEulerAngles :: struct {
    pitch: float64;
    yaw: float64;
    roll: float64;
}

GCQuaternion :: struct {
    x: float64;
    y: float64;
    z: float64;
    w: float64;
}



GCMotion :: struct {
    using nsobject: NSObject;
    controller :: (self: *GCMotion) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.controller);
    }

    valueChangedHandler :: (self: *GCMotion) -> GCMotionValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCMotionValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCMotion, valueChangedHandler: GCMotionValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCMotionValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    gravity :: (self: *GCMotion) -> GCAcceleration {
        _func: (obj: *void, selector: *void) -> GCAcceleration #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.gravity);
    }

    userAcceleration :: (self: *GCMotion) -> GCAcceleration {
        _func: (obj: *void, selector: *void) -> GCAcceleration #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.userAcceleration);
    }

    hasAttitudeAndRotationRate :: (self: *GCMotion) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.hasAttitudeAndRotationRate);
    }

    attitude :: (self: *GCMotion) -> GCQuaternion {
        _func: (obj: *void, selector: *void) -> GCQuaternion #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.attitude);
    }

    rotationRate :: (self: *GCMotion) -> GCRotationRate {
        _func: (obj: *void, selector: *void) -> GCRotationRate #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.rotationRate);
    }

}

GCMotionValueChangedHandler :: *void;

GCGamepad :: struct {
    using nsobject: NSObject;
    saveSnapshot :: (self: *GCGamepad) -> *GCGamepadSnapshot {
        _func: (obj: *void, selector: *void) -> *GCGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.saveSnapshot);
    }

    controller :: (self: *GCGamepad) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.controller);
    }

    valueChangedHandler :: (self: *GCGamepad) -> GCGamepadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCGamepadValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCGamepad, valueChangedHandler: GCGamepadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCGamepadValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    dpad :: (self: *GCGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.dpad);
    }

    buttonA :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonA);
    }

    buttonB :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonB);
    }

    buttonX :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonX);
    }

    buttonY :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonY);
    }

    leftShoulder :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.leftShoulder);
    }

    rightShoulder :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.rightShoulder);
    }

}

GCGamepadValueChangedHandler :: *void;

GCGamepadSnapshot :: struct {
    using gcgamepad: GCGamepad;
    initWithSnapshotData :: (self: *GCGamepadSnapshot, data: *NSData) -> *GCGamepadSnapshot {
        _func: (obj: *void, selector: *void, data: *NSData) -> *GCGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.initWithSnapshotData_, data);
    }

    initWithController_snapshotData :: (self: *GCGamepadSnapshot, controller: *GCController, data: *NSData) -> *GCGamepadSnapshot {
        _func: (obj: *void, selector: *void, controller: *GCController, data: *NSData) -> *GCGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.initWithController_snapshotData_, controller, data);
    }

    snapshotData :: (self: *GCGamepadSnapshot) -> *NSData {
        _func: (obj: *void, selector: *void) -> *NSData #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.snapshotData);
    }

    setSnapshotData :: (self: *GCGamepadSnapshot, snapshotData: *NSData) -> () {
        _func: (obj: *void, selector: *void, snapshotData: *NSData) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setSnapshotData_, snapshotData);
    }

}

GCGamepadSnapShotDataV100 :: struct {
    version: u16;
    size: u16;
    dpadX: float32;
    dpadY: float32;
    buttonA: float32;
    buttonB: float32;
    buttonX: float32;
    buttonY: float32;
    leftShoulder: float32;
    rightShoulder: float32;
}

GCGamepadSnapShotDataV100FromNSData :: (snapshotData: *GCGamepadSnapShotDataV100, data: *NSData) -> BOOL #foreign GameController_Framework;

NSDataFromGCGamepadSnapShotDataV100 :: (snapshotData: *GCGamepadSnapShotDataV100) -> *NSData #foreign GameController_Framework;

GCExtendedGamepad :: struct {
    using nsobject: NSObject;
    saveSnapshot :: (self: *GCExtendedGamepad) -> *GCExtendedGamepadSnapshot {
        _func: (obj: *void, selector: *void) -> *GCExtendedGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.saveSnapshot);
    }

    controller :: (self: *GCExtendedGamepad) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.controller);
    }

    valueChangedHandler :: (self: *GCExtendedGamepad) -> GCExtendedGamepadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCExtendedGamepadValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCExtendedGamepad, valueChangedHandler: GCExtendedGamepadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCExtendedGamepadValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    dpad :: (self: *GCExtendedGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.dpad);
    }

    buttonA :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonA);
    }

    buttonB :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonB);
    }

    buttonX :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonX);
    }

    buttonY :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonY);
    }

    leftThumbstick :: (self: *GCExtendedGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.leftThumbstick);
    }

    rightThumbstick :: (self: *GCExtendedGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.rightThumbstick);
    }

    leftShoulder :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.leftShoulder);
    }

    rightShoulder :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.rightShoulder);
    }

    leftTrigger :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.leftTrigger);
    }

    rightTrigger :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.rightTrigger);
    }

    leftThumbstickButton :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.leftThumbstickButton);
    }

    rightThumbstickButton :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.rightThumbstickButton);
    }

}

GCExtendedGamepadValueChangedHandler :: *void;

GCExtendedGamepadSnapshot :: struct {
    using gcextendedgamepad: GCExtendedGamepad;
    initWithSnapshotData :: (self: *GCExtendedGamepadSnapshot, data: *NSData) -> GCExtendedGamepadSnapshot {
        _func: (obj: *void, selector: *void, data: *NSData) -> GCExtendedGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.initWithSnapshotData_, data);
    }

    initWithController_snapshotData :: (self: *GCExtendedGamepadSnapshot, controller: *GCController, data: *NSData) -> GCExtendedGamepadSnapshot {
        _func: (obj: *void, selector: *void, controller: *GCController, data: *NSData) -> GCExtendedGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.initWithController_snapshotData_, controller, data);
    }

    snapshotData :: (self: *GCExtendedGamepadSnapshot) -> *NSData {
        _func: (obj: *void, selector: *void) -> *NSData #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.snapshotData);
    }

    setSnapshotData :: (self: *GCExtendedGamepadSnapshot, snapshotData: *NSData) -> () {
        _func: (obj: *void, selector: *void, snapshotData: *NSData) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setSnapshotData_, snapshotData);
    }

}

GCExtendedGamepadSnapShotDataV100 :: struct {
    version: u16;
    size: u16;
    dpadX: float32;
    dpadY: float32;
    buttonA: float32;
    buttonB: float32;
    buttonX: float32;
    buttonY: float32;
    leftShoulder: float32;
    rightShoulder: float32;
    leftThumbstickX: float32;
    leftThumbstickY: float32;
    rightThumbstickX: float32;
    rightThumbstickY: float32;
    leftTrigger: float32;
    rightTrigger: float32;
}

GCExtendedGamepadSnapShotDataV100FromNSData :: (snapshotData: *GCExtendedGamepadSnapShotDataV100, data: *NSData) -> BOOL #foreign GameController_Framework;

NSDataFromGCExtendedGamepadSnapShotDataV100 :: (snapshotData: *GCExtendedGamepadSnapShotDataV100) -> *NSData #foreign GameController_Framework;

GCMicroGamepad :: struct {
    using nsobject: NSObject;
    saveSnapshot :: (self: *GCMicroGamepad) -> *GCMicroGamepadSnapshot {
        _func: (obj: *void, selector: *void) -> *GCMicroGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.saveSnapshot);
    }

    controller :: (self: *GCMicroGamepad) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.controller);
    }

    valueChangedHandler :: (self: *GCMicroGamepad) -> GCMicroGamepadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCMicroGamepadValueChangedHandler #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCMicroGamepad, valueChangedHandler: GCMicroGamepadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCMicroGamepadValueChangedHandler) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setValueChangedHandler_, valueChangedHandler);
    }

    dpad :: (self: *GCMicroGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.dpad);
    }

    buttonA :: (self: *GCMicroGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonA);
    }

    buttonX :: (self: *GCMicroGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.buttonX);
    }

    reportsAbsoluteDpadValues :: (self: *GCMicroGamepad) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.reportsAbsoluteDpadValues);
    }

    setReportsAbsoluteDpadValues :: (self: *GCMicroGamepad, reportsAbsoluteDpadValues: BOOL) -> () {
        _func: (obj: *void, selector: *void, reportsAbsoluteDpadValues: BOOL) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setReportsAbsoluteDpadValues_, reportsAbsoluteDpadValues);
    }

    allowsRotation :: (self: *GCMicroGamepad) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.allowsRotation);
    }

    setAllowsRotation :: (self: *GCMicroGamepad, allowsRotation: BOOL) -> () {
        _func: (obj: *void, selector: *void, allowsRotation: BOOL) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setAllowsRotation_, allowsRotation);
    }

}

GCMicroGamepadValueChangedHandler :: *void;

GCMicroGamepadSnapshot :: struct {
    using gcmicrogamepad: GCMicroGamepad;
    initWithSnapshotData :: (self: *GCMicroGamepadSnapshot, data: *NSData) -> GCMicroGamepadSnapshot {
        _func: (obj: *void, selector: *void, data: *NSData) -> GCMicroGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.initWithSnapshotData_, data);
    }

    initWithController_snapshotData :: (self: *GCMicroGamepadSnapshot, controller: *GCController, data: *NSData) -> GCMicroGamepadSnapshot {
        _func: (obj: *void, selector: *void, controller: *GCController, data: *NSData) -> GCMicroGamepadSnapshot #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.initWithController_snapshotData_, controller, data);
    }

    snapshotData :: (self: *GCMicroGamepadSnapshot) -> *NSData {
        _func: (obj: *void, selector: *void) -> *NSData #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.snapshotData);
    }

    setSnapshotData :: (self: *GCMicroGamepadSnapshot, snapshotData: *NSData) -> () {
        _func: (obj: *void, selector: *void, snapshotData: *NSData) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setSnapshotData_, snapshotData);
    }

}

anon_struct_5 :: struct {
    version: u16;
    size: u16;
    dpadX: float32;
    dpadY: float32;
    buttonA: float32;
    buttonX: float32;
}

GCMicroGamepadSnapShotDataV100 :: anon_struct_5;

GCMicroGamepadSnapShotDataV100FromNSData :: (snapshotData: *GCMicroGamepadSnapShotDataV100, data: *NSData) -> BOOL #foreign GameController_Framework;

NSDataFromGCMicroGamepadSnapShotDataV100 :: (snapshotData: *GCMicroGamepadSnapShotDataV100) -> *NSData #foreign GameController_Framework;

// GCControllerDidConnectNotification: *NSString;

// GCControllerDidDisconnectNotification: *NSString;

GCEventViewController :: struct {
    using nsviewcontroller: NSViewController;
    controllerUserInteractionEnabled :: (self: *GCEventViewController) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.controllerUserInteractionEnabled);
    }

    setControllerUserInteractionEnabled :: (self: *GCEventViewController, controllerUserInteractionEnabled: BOOL) -> () {
        _func: (obj: *void, selector: *void, controllerUserInteractionEnabled: BOOL) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setControllerUserInteractionEnabled_, controllerUserInteractionEnabled);
    }

}

using GCControllerPlayerIndex :: enum NSInteger {
    GCControllerPlayerIndexUnset :: 0xFFFFFFFFFFFFFFFF;
    GCControllerPlayerIndex1 :: 0;
    GCControllerPlayerIndex2 :: 1;
    GCControllerPlayerIndex3 :: 2;
    GCControllerPlayerIndex4 :: 3;
}

// factored out of CGController struct due to circular dependencies error
GCController_controllers :: () -> *NSArray(*GCController) {
    _func: (obj: *void, selector: *void) -> *NSArray(*GCController) #foreign;
    _func = xx objc_msgSend;
    return _func(objc_getClass("GCController"), __selectors.controllers);
}

GCController :: struct {
    using nsobject: NSObject;
    

    startWirelessControllerDiscoveryWithCompletionHandler :: (completionHandler: *void) -> () {
        _func: (obj: *void, selector: *void, completionHandler: *void) -> () #foreign;
        _func = xx objc_msgSend;
        _func(objc_getClass("GCController"), __selectors.startWirelessControllerDiscoveryWithCompletionHandler_, completionHandler);
    }

    stopWirelessControllerDiscovery :: () -> () {
        _func: (obj: *void, selector: *void) -> () #foreign;
        _func = xx objc_msgSend;
        _func(objc_getClass("GCController"), __selectors.stopWirelessControllerDiscovery);
    }

    controllerPausedHandler :: (self: *GCController) -> *void {
        _func: (obj: *void, selector: *void) -> *void #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.controllerPausedHandler);
    }

    setControllerPausedHandler :: (self: *GCController, controllerPausedHandler: *void) -> () {
        _func: (obj: *void, selector: *void, controllerPausedHandler: *void) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setControllerPausedHandler_, controllerPausedHandler);
    }

    handlerQueue :: (self: *GCController) -> dispatch_queue_t {
        _func: (obj: *void, selector: *void) -> dispatch_queue_t #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.handlerQueue);
    }

    setHandlerQueue :: (self: *GCController, handlerQueue: dispatch_queue_t) -> () {
        _func: (obj: *void, selector: *void, handlerQueue: dispatch_queue_t) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setHandlerQueue_, handlerQueue);
    }

    vendorName :: (self: *GCController) -> *NSString {
        _func: (obj: *void, selector: *void) -> *NSString #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.vendorName);
    }

    isAttachedToDevice :: (self: *GCController) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.isAttachedToDevice);
    }

    playerIndex :: (self: *GCController) -> GCControllerPlayerIndex {
        _func: (obj: *void, selector: *void) -> GCControllerPlayerIndex #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.playerIndex);
    }

    setPlayerIndex :: (self: *GCController, playerIndex: GCControllerPlayerIndex) -> () {
        _func: (obj: *void, selector: *void, playerIndex: GCControllerPlayerIndex) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, __selectors.setPlayerIndex_, playerIndex);
    }

    gamepad :: (self: *GCController) -> *GCGamepad {
        _func: (obj: *void, selector: *void) -> *GCGamepad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.gamepad);
    }

    microGamepad :: (self: *GCController) -> *GCMicroGamepad {
        _func: (obj: *void, selector: *void) -> *GCMicroGamepad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.microGamepad);
    }

    extendedGamepad :: (self: *GCController) -> *GCExtendedGamepad {
        _func: (obj: *void, selector: *void) -> *GCExtendedGamepad #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.extendedGamepad);
    }

    motion :: (self: *GCController) -> *GCMotion {
        _func: (obj: *void, selector: *void) -> *GCMotion #foreign;
        _func = xx objc_msgSend;
        return _func(self, __selectors.motion);
    }

}

GameController_Framework :: #system_library "GameController";

init_objective_c_gamecontroller :: () {
    if __selectors.collection return;

    init_objective_c_selector_struct(*__selectors);
}

#scope_file

_Generated_Selectors :: struct {
    collection: *void = ---;
    isAnalog: *void = ---;
    valueChangedHandler: *void = ---;
    setValueChangedHandler_: *void = ---;
    value: *void = ---;
    pressedChangedHandler: *void = ---;
    setPressedChangedHandler_: *void = ---;
    isPressed: *void = ---;
    xAxis: *void = ---;
    yAxis: *void = ---;
    up: *void = ---;
    down: *void = ---;
    left: *void = ---;
    right: *void = ---;
    controller: *void = ---;
    gravity: *void = ---;
    userAcceleration: *void = ---;
    hasAttitudeAndRotationRate: *void = ---;
    attitude: *void = ---;
    rotationRate: *void = ---;
    saveSnapshot: *void = ---;
    dpad: *void = ---;
    buttonA: *void = ---;
    buttonB: *void = ---;
    buttonX: *void = ---;
    buttonY: *void = ---;
    leftShoulder: *void = ---;
    rightShoulder: *void = ---;
    initWithSnapshotData_: *void = ---;
    initWithController_snapshotData_: *void = ---;
    snapshotData: *void = ---;
    setSnapshotData_: *void = ---;
    leftThumbstick: *void = ---;
    rightThumbstick: *void = ---;
    leftTrigger: *void = ---;
    rightTrigger: *void = ---;
    leftThumbstickButton: *void = ---;
    rightThumbstickButton: *void = ---;
    reportsAbsoluteDpadValues: *void = ---;
    setReportsAbsoluteDpadValues_: *void = ---;
    allowsRotation: *void = ---;
    setAllowsRotation_: *void = ---;
    controllerUserInteractionEnabled: *void = ---;
    setControllerUserInteractionEnabled_: *void = ---;
    controllers: *void = ---;
    startWirelessControllerDiscoveryWithCompletionHandler_: *void = ---;
    stopWirelessControllerDiscovery: *void = ---;
    controllerPausedHandler: *void = ---;
    setControllerPausedHandler_: *void = ---;
    handlerQueue: *void = ---;
    setHandlerQueue_: *void = ---;
    vendorName: *void = ---;
    isAttachedToDevice: *void = ---;
    playerIndex: *void = ---;
    setPlayerIndex_: *void = ---;
    gamepad: *void = ---;
    microGamepad: *void = ---;
    extendedGamepad: *void = ---;
    motion: *void = ---;
}

__selectors: _Generated_Selectors;
