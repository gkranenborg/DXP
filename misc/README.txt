Please read these instructions carefully to make sure the VM you downloaded starts up properly, so you can use the installed products without problems.

VM version : 


Extracting the files :

After downloading all .7z files, highlight all of them and right click on them to select 7-zip > Extract Files.
A new window will pop up, please select the location where you would like your VM to be created, and click 'OK'.
After a short amount of time, you will see a new folder ( e.g. interstagedemovm52 ) inside the folder you selected above, with several files in it. Remember the location of this folder, as you will need it later.


Starting the VM :

To start the VM, please start VMWare Player on your own machine.
Select 'Open a Virtual Machine' and browse to the the folder created before when you extracted the files.
Select the .vmx file shown inside that folder and click 'Open'. The VMWare player window will show some of the details related to this VM. Note that it will take up 8Gb of RAM when started. If you want to allocate more memory to the VM, click
'Edit virtual machine settings' and make the changes required, then click 'OK'.
Start the VM by clicking 'Play Virtual Machine', and wait for the Fujitsu Welcome screen to show up after a few minutes. (If the startup procedure shows a window asking if you moved or copied the VM, select 'I Copied It'.)

Once this window shows up, several details you will need will be shown, such as the username / password, and the VM's hostname (e.g. interstagedemo) and IP address.


ATTENTION !!!!  --------------------------------------------------------------------------------------------------------------------------


To use all products installed, you MUST use the hostname. Failure to follow the next steps will cause some of the products installed not to function at all !!!
By default, your hosting machine (e.g. laptop) will not be able to use the VM's hostname, therefore you MUST follow the steps below next :

- Using the Windows Explorer, find and open the file : C:\Windows\System32\drivers\etc\hosts
- Add a new line at the bottom looking like this : 192.168.174.143 interstagedemo
- Save and exit the file.

(Note : the IP address in this case is an example. Your IP address is likely different (see the Fujitsu Welcome screen shown in VMWare Player). Make sure to use your VM's IP address, as well as the proper hostname !!!)

------------------------------------------------------------------------------------------------------------------------------------------

Using the product :

Now that the VM is up and running, please open up the browser on your own machine, and use http://interstagedemo (or any other URL as shown in the VM's welcome screen) to access the product.
The web page contains all the links to the various products you need.

(Alternativly you can access any component directly by using the URL in a separate window if you would like. Check the proper URL from the main web page by placing your mouse on top of the link, and the URL will be shown at the 
bottom of the screen.)

Software version information :

The VM you use contains software not only developed by Fujitsu, but also by 3rd parties. To check the version of all software installed, open the main webpage and go to 'Application Information'. A new page will open showing you
the software installed as well as the version for each individual component.