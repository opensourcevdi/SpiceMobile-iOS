# IOS App for SPICE mobile remote access

The OSVDI Client is designed as an update of the standard SPICE remote apps to Open Source Virtual Desktop Infrastructure (OSVDI). It allows users to use their smartphone or tablet 
(in desktop mode with a e.g. HDMI connected display) to access desktop environments running in QEMU/KVM virtualization like LibVirt and in the future OpenStack and Proxmox.

(Planned) Features:
* Connect to remote desktops running in QEMU/KVM virtualization orchestrated by the OSVDI
* Connect to available remote desktops at your university
* Use your phone/tablet directly or in desktop mode
* Use audio directly or via a connected headset
* Add a keyboard and/or mouse for more convenient interaction
* Transfer files between the remote desktop and your mobile device
* Copy and paste
* (Use a local printer connected to the mobile client)
* ...

The app provides hardware accelerated remote access to various virtualized desktops on smartphones or tablets (in desktop mode with a connected display). 

One targeted infrastructure is [bwLehrpool](https://www.bwlehrpool.de/), a software suite developed at the computer center of the University of Freiburg offering a state-wide service 
for PC pools for higher education and research institutions in Baden-Württemberg and beyond. It fills a niche for efficient management of large computer pool installations with flexible 
requirements without forcing out existing installations and concepts. Additionally, it responds to new requirements such as orchestrated reconfiguration of pools for larger e-assessments 
or system automation and monitoring. The project is a combination of existing software stacks including standard Linux distributions and hypervisors combined with custom developments 
which are made available as Open Source packages. The system focuses on the fat client concept by creating a flexible Virtual Desktop-like infrastructure offering a broad range of 
user-created software environments by separating and disentangling the tasks of administrators and lecturers traditionally associated with computer pool management.

## Sponsors

The programming of the app was partially funded through the Freiburg SVB funds ("Studentisches Vorschlagsbudget 2026") and bwCloud 3 project sponsored by the state of Baden-Württemberg. Further developments were made possible through the collaboration in the PePP project (FBM2020-VA77-8-01241) funded by the "Foundation for Innovation in Higher Education", and the funds provided through NFDI 46/1 – 501864659 (NFDI4BIOIMAGE), and NFDI 7/1 – 442077441 (DataPLANT) as part of the German National Research Data Infrastructure.
