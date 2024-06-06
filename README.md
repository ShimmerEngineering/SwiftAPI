# Swift API

# Quick Start Guide
1) Use ShimmerExamplePlot
2) Goto Signing & Capabilities, set to automatically manage signing, set your team
3) Start the active scheme ShimmerExamplePlot
4) Update your Shimmer 3 device to the following https://github.com/ShimmerResearch/shimmer3/releases/tag/LogAndStream_Shimmer3_BLE_v0.16.002 ,please note of the bug noted in known issues below, should the bug occur, just press disconnect and re-connect to the device. This bug should only occur once everytime you switch back/on a device. We are working on a fix for the issue, but if there is urgency please contact us on support.
5) Once the firmware has been updated press scan
6) From the list of scanned devices pick the Shimmer3 device you want to connect to, note that you might have to scan multiple times to find the device
   ![50D3E716-6A75-4F0C-958A-C2AF3A6FB763](https://github.com/ShimmerEngineering/SwiftAPI/assets/2862032/4a8839c0-bfae-432f-a1ac-e73a5953a6ee)
7) Press Connect Shimmer3
8) Once it shows BT State: Connected, configure the device accordingly, we recommend starting with WriteInfoMem IMU Shimmer3
9) Once configured (BT State: Connected), press StartStreaming Shimmer3
10) In the drop down Select Plot, select Low Noise Accelerometer X_Calibrated_m/s2
11) In the drop down Number of Signals, select 3
12) You should now see data from the three axis of the Accelerometer being plotted
   
# Known Issues
1) Currently when using LogAndStream_Shimmer3_BLE_v0.16.002 the first time you connect to a device which has been powered you will require disconnecting from it, should you see the following :- 
LogAndStream_Shimmer3_BLE_v0.16.002 
![F215B9F0-1924-42DC-BE75-27189E26FD97](https://github.com/ShimmerEngineering/SwiftAPI/assets/2862032/66656b2d-85c7-440f-953e-66c6dfcbfa06)
