# Swift API

Currently the Shimmer Swift API and Example Projects are released as a Pre-Alpha release

Please refer to our [support policy](https://shimmersensing.com/support/wireless-sensor-networks-documentation/) on Pre-Alpha Releases

Should you require asistance, fixes, new features or updates please contact us on support.

# Prerequisites 
A Shimmer3 with a RN4678 radio and the appropriate [firmware](https://github.com/ShimmerResearch/shimmer3/releases) , we currently recommend using LogAndStream_Shimmer3_BLE_v0.16.004. 

# Quick Start Guide
1) Use ShimmerExamplePlot (both macOS and iOS is supported)
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

https://github.com/ShimmerEngineering/SwiftAPI/assets/9572576/119f2044-e5a7-4531-a07b-85114c07d77b

https://github.com/ShimmerEngineering/SwiftAPI/assets/9572576/8513c3c9-ff07-4ad1-b1db-8ae65d27c981
   
# The Following Applies To All Code Provided in the repository
Copyright (c) 2017, Shimmer Research, Ltd. All rights reserved

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above
   copyright notice, this list of conditions and the following
   disclaimer in the documentation and/or other materials provided
   with the distribution.
 * Neither the name of Shimmer Research, Ltd. nor the names of its
   contributors may be used to endorse or promote products derived
   from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
