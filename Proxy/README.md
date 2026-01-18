# Proxy Fix
As stated in the main [README.md](https://github.com/brkzlr/SASSFix/blob/master/README.md), we can use a proxy server to achieve a login/achievements fix.

We'll use a free and open source tool called **mitmproxy** which will run on your PC or laptop to achieve this.

## How does this work?
By having mitmproxy active with my script and pointing your iPhone to it, every time the games will try to use the old deprecated API, mitmproxy will automatically change the URL to the correct one depending on the context and forward it:

This will restore previously lost functionality and allow you to login and earn achievements with your Xbox profile.

## Instructions
***Please make sure to follow the instructions below in the exact order they're written. Skipping steps ahead will cause you issues.***
- Install [mitmproxy](https://www.mitmproxy.org).
  - Follow the [instructions here](https://docs.mitmproxy.org/stable/overview/installation/) to make sure the program is installed and running correctly.
- Download the redirection script [SASSIntercept.py](https://github.com/brkzlr/SASSFix/blob/master/Proxy/SASSIntercept.py) by clicking on the small "Download raw file" button next to the **Raw** button.
  - Or use it directly if you cloned/downloaded this repo.
- Run the proxy server by going to the installation location (where the binary is) and run `mitmproxy -s "location of SASSIntercept.py"`.
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
