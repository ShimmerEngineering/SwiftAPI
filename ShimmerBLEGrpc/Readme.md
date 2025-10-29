# Getting Started
To run the BLE gRPC server, set the active scheme at the top-middle of Xcode to ShimmerBLEGrpc, target My Mac
Then, select the Start button at the top-left of Xcode to start the app
Then, open the Shimmer-Java-Android-API ShimmerGRPC.java class from: https://github.com/ShimmerEngineering/Shimmer-Java-Android-API/blob/master/ShimmerDriverPC/src/main/java/com/shimmerresearch/pcDriver/ShimmerGRPC.java
Set the name of the device you want to connect to, in Line 101 of the class. This is e.g. "Shimmer3-XXXX". 
Note that this is not the Bluetooth Mac address, as MacOS BLE is limited to using Bluetooth device names.
Then, run ShimmerGRPC.java

# Changelog
v1.0.0
- Initial Release

v1.0.1
- Improve logging in ShimmerServer
- Improve thread safety in ShimmerBLEService
