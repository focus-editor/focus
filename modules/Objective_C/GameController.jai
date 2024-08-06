// Separate module that needs to be imported as #import "Objective_C/AppKit"
// :AwfulCopyPasta

init_objective_c_gamecontroller :: () {
    if _sel.collection return;

    init_objective_c_selector_struct(*_sel);
}

GCControllerElement :: struct {
    using nsobject: NSObject;
    collection :: (self: *GCControllerElement) -> *GCControllerElement {
        _func: (obj: *void, selector: *void) -> *GCControllerElement #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.collection);
    }

    isAnalog :: (self: *GCControllerElement) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.isAnalog);
    }

}

GCControllerAxisInput :: struct {
    using gccontrollerelement: GCControllerElement;
    valueChangedHandler :: (self: *GCControllerAxisInput) -> GCControllerAxisValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerAxisValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCControllerAxisInput, valueChangedHandler: GCControllerAxisValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCControllerAxisValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    value :: (self: *GCControllerAxisInput) -> float32 {
        _func: (obj: *void, selector: *void) -> float32 #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.value);
    }

}

GCControllerAxisValueChangedHandler :: *void;


GCControllerButtonInput :: struct {
    using gccontrollerelement: GCControllerElement;
    valueChangedHandler :: (self: *GCControllerButtonInput) -> GCControllerButtonValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerButtonValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCControllerButtonInput, valueChangedHandler: GCControllerButtonValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCControllerButtonValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    pressedChangedHandler :: (self: *GCControllerButtonInput) -> GCControllerButtonValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerButtonValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.pressedChangedHandler);
    }

    setPressedChangedHandler :: (self: *GCControllerButtonInput, pressedChangedHandler: GCControllerButtonValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, pressedChangedHandler: GCControllerButtonValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setPressedChangedHandler_, pressedChangedHandler);
    }

    value :: (self: *GCControllerButtonInput) -> float32 {
        _func: (obj: *void, selector: *void) -> float32 #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.value);
    }

    isPressed :: (self: *GCControllerButtonInput) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.isPressed);
    }

}

GCControllerButtonValueChangedHandler :: *void;

GCControllerDirectionPad :: struct {
    using gccontrollerelement: GCControllerElement;
    valueChangedHandler :: (self: *GCControllerDirectionPad) -> GCControllerDirectionPadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCControllerDirectionPadValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCControllerDirectionPad, valueChangedHandler: GCControllerDirectionPadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCControllerDirectionPadValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    xAxis :: (self: *GCControllerDirectionPad) -> *GCControllerAxisInput {
        _func: (obj: *void, selector: *void) -> *GCControllerAxisInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.xAxis);
    }

    yAxis :: (self: *GCControllerDirectionPad) -> *GCControllerAxisInput {
        _func: (obj: *void, selector: *void) -> *GCControllerAxisInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.yAxis);
    }

    up :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.up);
    }

    down :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.down);
    }

    left :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.left);
    }

    right :: (self: *GCControllerDirectionPad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.right);
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
        _func: (obj: *void, selector: *void) -> *GCController #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.controller);
    }

    valueChangedHandler :: (self: *GCMotion) -> GCMotionValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCMotionValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCMotion, valueChangedHandler: GCMotionValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCMotionValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    gravity :: (self: *GCMotion) -> GCAcceleration {
        _func: (obj: *void, selector: *void) -> GCAcceleration #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.gravity);
    }

    userAcceleration :: (self: *GCMotion) -> GCAcceleration {
        _func: (obj: *void, selector: *void) -> GCAcceleration #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.userAcceleration);
    }

    hasAttitudeAndRotationRate :: (self: *GCMotion) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.hasAttitudeAndRotationRate);
    }

    attitude :: (self: *GCMotion) -> GCQuaternion {
        _func: (obj: *void, selector: *void) -> GCQuaternion #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.attitude);
    }

    rotationRate :: (self: *GCMotion) -> GCRotationRate {
        _func: (obj: *void, selector: *void) -> GCRotationRate #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.rotationRate);
    }

}

GCMotionValueChangedHandler :: *void;

GCGamepad :: struct {
    using nsobject: NSObject;
    saveSnapshot :: (self: *GCGamepad) -> *GCGamepadSnapshot {
        _func: (obj: *void, selector: *void) -> *GCGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.saveSnapshot);
    }

    controller :: (self: *GCGamepad) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.controller);
    }

    valueChangedHandler :: (self: *GCGamepad) -> GCGamepadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCGamepadValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCGamepad, valueChangedHandler: GCGamepadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCGamepadValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    dpad :: (self: *GCGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.dpad);
    }

    buttonA :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonA);
    }

    buttonB :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonB);
    }

    buttonX :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonX);
    }

    buttonY :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonY);
    }

    leftShoulder :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.leftShoulder);
    }

    rightShoulder :: (self: *GCGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.rightShoulder);
    }

}

GCGamepadValueChangedHandler :: *void;

GCGamepadSnapshot :: struct {
    using gcgamepad: GCGamepad;
    initWithSnapshotData :: (self: *GCGamepadSnapshot, data: *NSData) -> *GCGamepadSnapshot {
        _func: (obj: *void, selector: *void, data: *NSData) -> *GCGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.initWithSnapshotData_, data);
    }

    initWithController_snapshotData :: (self: *GCGamepadSnapshot, controller: *GCController, data: *NSData) -> *GCGamepadSnapshot {
        _func: (obj: *void, selector: *void, controller: *GCController, data: *NSData) -> *GCGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.initWithController_snapshotData_, controller, data);
    }

    snapshotData :: (self: *GCGamepadSnapshot) -> *NSData {
        _func: (obj: *void, selector: *void) -> *NSData #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.snapshotData);
    }

    setSnapshotData :: (self: *GCGamepadSnapshot, snapshotData: *NSData) -> () {
        _func: (obj: *void, selector: *void, snapshotData: *NSData) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setSnapshotData_, snapshotData);
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
        _func: (obj: *void, selector: *void) -> *GCExtendedGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.saveSnapshot);
    }

    controller :: (self: *GCExtendedGamepad) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.controller);
    }

    valueChangedHandler :: (self: *GCExtendedGamepad) -> GCExtendedGamepadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCExtendedGamepadValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCExtendedGamepad, valueChangedHandler: GCExtendedGamepadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCExtendedGamepadValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    dpad :: (self: *GCExtendedGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.dpad);
    }

    buttonA :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonA);
    }

    buttonB :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonB);
    }

    buttonX :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonX);
    }

    buttonY :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonY);
    }

    leftThumbstick :: (self: *GCExtendedGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.leftThumbstick);
    }

    rightThumbstick :: (self: *GCExtendedGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.rightThumbstick);
    }

    leftShoulder :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.leftShoulder);
    }

    rightShoulder :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.rightShoulder);
    }

    leftTrigger :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.leftTrigger);
    }

    rightTrigger :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.rightTrigger);
    }

    leftThumbstickButton :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.leftThumbstickButton);
    }

    rightThumbstickButton :: (self: *GCExtendedGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.rightThumbstickButton);
    }

}

GCExtendedGamepadValueChangedHandler :: *void;

GCExtendedGamepadSnapshot :: struct {
    using gcextendedgamepad: GCExtendedGamepad;
    initWithSnapshotData :: (self: *GCExtendedGamepadSnapshot, data: *NSData) -> GCExtendedGamepadSnapshot {
        _func: (obj: *void, selector: *void, data: *NSData) -> GCExtendedGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.initWithSnapshotData_, data);
    }

    initWithController_snapshotData :: (self: *GCExtendedGamepadSnapshot, controller: *GCController, data: *NSData) -> GCExtendedGamepadSnapshot {
        _func: (obj: *void, selector: *void, controller: *GCController, data: *NSData) -> GCExtendedGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.initWithController_snapshotData_, controller, data);
    }

    snapshotData :: (self: *GCExtendedGamepadSnapshot) -> *NSData {
        _func: (obj: *void, selector: *void) -> *NSData #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.snapshotData);
    }

    setSnapshotData :: (self: *GCExtendedGamepadSnapshot, snapshotData: *NSData) -> () {
        _func: (obj: *void, selector: *void, snapshotData: *NSData) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setSnapshotData_, snapshotData);
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
        _func: (obj: *void, selector: *void) -> *GCMicroGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.saveSnapshot);
    }

    controller :: (self: *GCMicroGamepad) -> *GCController {
        _func: (obj: *void, selector: *void) -> *GCController #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.controller);
    }

    valueChangedHandler :: (self: *GCMicroGamepad) -> GCMicroGamepadValueChangedHandler {
        _func: (obj: *void, selector: *void) -> GCMicroGamepadValueChangedHandler #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.valueChangedHandler);
    }

    setValueChangedHandler :: (self: *GCMicroGamepad, valueChangedHandler: GCMicroGamepadValueChangedHandler) -> () {
        _func: (obj: *void, selector: *void, valueChangedHandler: GCMicroGamepadValueChangedHandler) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setValueChangedHandler_, valueChangedHandler);
    }

    dpad :: (self: *GCMicroGamepad) -> *GCControllerDirectionPad {
        _func: (obj: *void, selector: *void) -> *GCControllerDirectionPad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.dpad);
    }

    buttonA :: (self: *GCMicroGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonA);
    }

    buttonX :: (self: *GCMicroGamepad) -> *GCControllerButtonInput {
        _func: (obj: *void, selector: *void) -> *GCControllerButtonInput #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.buttonX);
    }

    reportsAbsoluteDpadValues :: (self: *GCMicroGamepad) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.reportsAbsoluteDpadValues);
    }

    setReportsAbsoluteDpadValues :: (self: *GCMicroGamepad, reportsAbsoluteDpadValues: BOOL) -> () {
        _func: (obj: *void, selector: *void, reportsAbsoluteDpadValues: BOOL) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setReportsAbsoluteDpadValues_, reportsAbsoluteDpadValues);
    }

    allowsRotation :: (self: *GCMicroGamepad) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.allowsRotation);
    }

    setAllowsRotation :: (self: *GCMicroGamepad, allowsRotation: BOOL) -> () {
        _func: (obj: *void, selector: *void, allowsRotation: BOOL) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setAllowsRotation_, allowsRotation);
    }

}

GCMicroGamepadValueChangedHandler :: *void;

GCMicroGamepadSnapshot :: struct {
    using gcmicrogamepad: GCMicroGamepad;
    initWithSnapshotData :: (self: *GCMicroGamepadSnapshot, data: *NSData) -> GCMicroGamepadSnapshot {
        _func: (obj: *void, selector: *void, data: *NSData) -> GCMicroGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.initWithSnapshotData_, data);
    }

    initWithController_snapshotData :: (self: *GCMicroGamepadSnapshot, controller: *GCController, data: *NSData) -> GCMicroGamepadSnapshot {
        _func: (obj: *void, selector: *void, controller: *GCController, data: *NSData) -> GCMicroGamepadSnapshot #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.initWithController_snapshotData_, controller, data);
    }

    snapshotData :: (self: *GCMicroGamepadSnapshot) -> *NSData {
        _func: (obj: *void, selector: *void) -> *NSData #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.snapshotData);
    }

    setSnapshotData :: (self: *GCMicroGamepadSnapshot, snapshotData: *NSData) -> () {
        _func: (obj: *void, selector: *void, snapshotData: *NSData) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setSnapshotData_, snapshotData);
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
    using #as viewController: NSViewController;

    controllerUserInteractionEnabled :: (self: *GCEventViewController) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.controllerUserInteractionEnabled);
    }

    setControllerUserInteractionEnabled :: (self: *GCEventViewController, controllerUserInteractionEnabled: BOOL) -> () {
        _func: (obj: *void, selector: *void, controllerUserInteractionEnabled: BOOL) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setControllerUserInteractionEnabled_, controllerUserInteractionEnabled);
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
    _func: (obj: *void, selector: *void) -> *NSArray(*GCController) #c_call;
    _func = xx objc_msgSend;
    return _func(objc_getClass("GCController"), _sel.controllers);
}

GCController :: struct {
    using #as super: NSObject;

    startWirelessControllerDiscoveryWithCompletionHandler :: (completionHandler: *void) -> () {
        _func: (obj: *void, selector: *void, completionHandler: *void) -> () #c_call;
        _func = xx objc_msgSend;
        _func(objc_getClass("GCController"), _sel.startWirelessControllerDiscoveryWithCompletionHandler_, completionHandler);
    }

    stopWirelessControllerDiscovery :: () -> () {
        _func: (obj: *void, selector: *void) -> () #c_call;
        _func = xx objc_msgSend;
        _func(objc_getClass("GCController"), _sel.stopWirelessControllerDiscovery);
    }

    controllerPausedHandler :: (self: *GCController) -> *void {
        _func: (obj: *void, selector: *void) -> *void #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.controllerPausedHandler);
    }

    setControllerPausedHandler :: (self: *GCController, controllerPausedHandler: *void) -> () {
        _func: (obj: *void, selector: *void, controllerPausedHandler: *void) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setControllerPausedHandler_, controllerPausedHandler);
    }

    handlerQueue :: (self: *GCController) -> dispatch_queue_t {
        _func: (obj: *void, selector: *void) -> dispatch_queue_t #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.handlerQueue);
    }

    setHandlerQueue :: (self: *GCController, handlerQueue: dispatch_queue_t) -> () {
        _func: (obj: *void, selector: *void, handlerQueue: dispatch_queue_t) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setHandlerQueue_, handlerQueue);
    }

    vendorName :: (self: *GCController) -> *NSString {
        _func: (obj: *void, selector: *void) -> *NSString #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.vendorName);
    }

    isAttachedToDevice :: (self: *GCController) -> BOOL {
        _func: (obj: *void, selector: *void) -> BOOL #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.isAttachedToDevice);
    }

    playerIndex :: (self: *GCController) -> GCControllerPlayerIndex {
        _func: (obj: *void, selector: *void) -> GCControllerPlayerIndex #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.playerIndex);
    }

    setPlayerIndex :: (self: *GCController, playerIndex: GCControllerPlayerIndex) -> () {
        _func: (obj: *void, selector: *void, playerIndex: GCControllerPlayerIndex) -> () #c_call;
        _func = xx objc_msgSend;
        _func(self, _sel.setPlayerIndex_, playerIndex);
    }

    gamepad :: (self: *GCController) -> *GCGamepad {
        _func: (obj: *void, selector: *void) -> *GCGamepad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.gamepad);
    }

    microGamepad :: (self: *GCController) -> *GCMicroGamepad {
        _func: (obj: *void, selector: *void) -> *GCMicroGamepad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.microGamepad);
    }

    extendedGamepad :: (self: *GCController) -> *GCExtendedGamepad {
        _func: (obj: *void, selector: *void) -> *GCExtendedGamepad #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.extendedGamepad);
    }

    motion :: (self: *GCController) -> *GCMotion {
        _func: (obj: *void, selector: *void) -> *GCMotion #c_call;
        _func = xx objc_msgSend;
        return _func(self, _sel.motion);
    }

}

GCControllerDidConnectNotification: *NSString #elsewhere;
GCControllerDidDisconnectNotification: *NSString #elsewhere;

#scope_file

_sel: struct {
    collection: Selector;
    isAnalog: Selector;
    valueChangedHandler: Selector;
    setValueChangedHandler_: Selector;
    value: Selector;
    pressedChangedHandler: Selector;
    setPressedChangedHandler_: Selector;
    isPressed: Selector;
    xAxis: Selector;
    yAxis: Selector;
    up: Selector;
    down: Selector;
    left: Selector;
    right: Selector;
    controller: Selector;
    gravity: Selector;
    userAcceleration: Selector;
    hasAttitudeAndRotationRate: Selector;
    attitude: Selector;
    rotationRate: Selector;
    saveSnapshot: Selector;
    dpad: Selector;
    buttonA: Selector;
    buttonB: Selector;
    buttonX: Selector;
    buttonY: Selector;
    leftShoulder: Selector;
    rightShoulder: Selector;
    initWithSnapshotData_: Selector;
    initWithController_snapshotData_: Selector;
    snapshotData: Selector;
    setSnapshotData_: Selector;
    leftThumbstick: Selector;
    rightThumbstick: Selector;
    leftTrigger: Selector;
    rightTrigger: Selector;
    leftThumbstickButton: Selector;
    rightThumbstickButton: Selector;
    reportsAbsoluteDpadValues: Selector;
    setReportsAbsoluteDpadValues_: Selector;
    allowsRotation: Selector;
    setAllowsRotation_: Selector;
    controllerUserInteractionEnabled: Selector;
    setControllerUserInteractionEnabled_: Selector;
    controllers: Selector;
    startWirelessControllerDiscoveryWithCompletionHandler_: Selector;
    stopWirelessControllerDiscovery: Selector;
    controllerPausedHandler: Selector;
    setControllerPausedHandler_: Selector;
    handlerQueue: Selector;
    setHandlerQueue_: Selector;
    vendorName: Selector;
    isAttachedToDevice: Selector;
    playerIndex: Selector;
    setPlayerIndex_: Selector;
    gamepad: Selector;
    microGamepad: Selector;
    extendedGamepad: Selector;
    motion: Selector;
}

GameController_Framework :: #system_library "GameController";

#import "Objective_C";
#import "Objective_C/AppKit";

