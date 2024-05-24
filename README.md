# TAILMON v1.0.12
Asus-Merlin Tailscale Installer, Configurator and Monitor
![image](https://github.com/ViktorJp/TAILMON/assets/97465574/81efa3a6-f465-499b-84d7-bec694ce2c4c)


**Executive Summary:** **Tailscale** is a free and open source service, based on WireGuard®, that helps users build no-hassle virtual private networks. Once you’ve created a Tailscale network (tailnet), you can securely access services and devices on that tailnet from anywhere in the world.  **TAILMON** is a posix shell script that assists with the install, configuration and monitoring of Tailscale, running on your Asus-Merlin FW router.

**Use-case:** **TAILMON** allows you to download and install Tailscale via Entware onto your router, in order to join your router to your Tailscale network (tailnet). When joined, you can optionally designate your router to become an exit node, and/or advertise access to your subnet in order to allow access to devices running on your network… think NAS devices, TVs, Raspberry Pi’s, Ubuntu servers, security cameras.  Once installed, you can monitor your Tailscale service and connection with TAILMON, which will optionally restart the service/connection should something bring it down. To make life easier, TAILMON can continue running/monitoring in the background using the SCREEN utility.
