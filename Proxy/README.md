# Proxy Fix
As stated in the main [README.md](https://github.com/brkzlr/SASSFix/blob/master/README.md), we can use a proxy server to achieve a login/achievements fix.

We'll use a free and open source tool called **mitmproxy** which will run on your PC or laptop to achieve this.

## Update 2026/05/04
A few days ago, people on Discord reported not being able to login anymore with the Proxy/Patcher fix. Upon investigation it seems that Microsoft has started blocking `XBL2.0` tokens that were being sent to the `activeauth.xboxlive.com` endpoint, effectively breaking SA/SS login flow.

The previous fix was just changing the old deprecated profile and achievement endpoints that have been removed from Microsoft servers to point to the newer versions but the login was untouched as the game could still obtain a valid XboxLive token for use with these endpoints.

**This also means that people using my patcher on iOS SA will also not be able to login anymore as the login was untouched in the patch**. Luckily by using mitmproxy, we can translate XBL2.0 to XBL3.0 and continue to use the newer XboxLive flow when communicating with Microsoft to bypass the block.

To fix the new problem, use the same instructions but make sure to use the ***`SASSInterceptV2.py`*** file and not V1. ***You need to use mitmproxy and the V2 script even if you're using a patched SA***.

## How does this work?
By having mitmproxy active with my script and pointing your iPhone to it, every time the games will try to use the old deprecated API, mitmproxy will automatically change the URL to the correct one depending on the context and forward it:

This will restore previously lost functionality and allow you to login and earn achievements with your Xbox profile.

## Instructions
***Please make sure to follow the instructions below in the exact order they're written. Skipping steps ahead will cause you issues.***
- Install [mitmproxy](https://www.mitmproxy.org).
  - Follow the [instructions here](https://docs.mitmproxy.org/stable/overview/installation/) to make sure the program is installed and running correctly.
- Download the redirection script ~~[SASSIntercept.py](https://github.com/brkzlr/SASSFix/blob/master/Proxy/SASSIntercept.py)~~ [SASSInterceptV2.py](https://github.com/brkzlr/SASSFix/blob/master/Proxy/SASSInterceptV2.py) by clicking on the small "Download raw file" button next to the **Raw** button.
  - Or use it directly if you cloned/downloaded this repo.
- Run the proxy server by going to the installation location (where the binary is) and run `mitmproxy -s "location of SASSInterceptV2.py"`.
  - If on Windows, make sure you include the extension `.py`.
- On your iPhone, setup proxy on your connected network.
  - Go to Wi-Fi settings and press on the big **i** next to your connected Wi-Fi network.
  - Scroll all the way down to **HTTP Proxy** and press on **Configure Proxy**.
  - Choose manual and then put the following:
    - Server: (Internal IP address of your PC/Laptop that runs mitmproxy)
    - Port: 8080
    - Authentication: Off
  - Click on Save then exit.
- On your iPhone, go to http://mitm.it and download the iOS certificate.
  - ***MAKE SURE TO FOLLOW THE ADDITIONAL iOS INSTRUCTIONS THERE IF YOU'RE ON iOS 12+. You have additional steps after installation***
- Boot up the game and enjoy.

Once you're done playing the game, don't forget to turn off the proxy in your Wi-Fi settings so you can use the internet after you shut down mitmproxy on your PC/Laptop.

**You will need to activate mitmproxy and input the iPhone proxy settings again when you want to start playing the game again**, but you won't need to install the iOS certificate again as it will sit there until you remove it.
