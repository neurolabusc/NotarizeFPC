# Notarizing Command Line Tools with FreePascal

[FreePascal](https://www.freepascal.org) is a terrific cross-platform compiler. While often seen as an ancient computer language, it provides better string manipulation than C, an elegant object-oriented method, and unique memory management. C compilers like gcc and Clang-LLVM are tuned for large projects with complex memory demands, and therefore simple programs are hampered by [much slower execution time than Pascal](https://github.com/bdrung/startup-time). The nature of Pascal inherently aids faster compilation than languages like C. What makes FPC revolutionary is the ability to use either FPC itself or LLVM for compilation. This allows one to develop with the speed of Pascal, and create very fast small projects. For large projects, one can develop with the speed and ease of Pascal, but compile with LLVM to rival the performance of Fortran and C code in these domains. Therefore, it is two compilers in one, giving you the best of both worlds in a single language. The primary disadvantage of Pascal is that it is not popular, so there are fewer examples for how someone else has previously solved a similar problem to you. On the other hand, this lack of popularity is also its strength. The fantastic [productivity](https://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.651.684&rep=rep1&type=pdf) can provide the Pascal developer with a competitive advantage. 

While Pascal fills a unique niche as a cross platform programming language, distributing applications to macOS requires solving the issue of application notarization. While this issue is not unique to FreePascal users, many C projects can be compiled with XCode which streamlines this process. 

MacOS 10.15 expects command line tools should be [notarized](https://mjtsai.com/blog/2019/06/17/notarizing-command-line-tools-for-macos-10-15/). All native code for ARM-based `Apple Silicon` CPUs [must be code signed](http://www.rahulgaitonde.org/blog/2020/11/12/apple-m1-and-the-ultimate-closed-system-part-1/). Apple provides some [documentation](https://developer.apple.com/documentation/security/notarizing_your_app_before_distribution), but most of this assumes projects managed using Xcode (example [here](https://scriptingosx.com/2019/09/notarize-a-command-line-tool/)). This creates a barrier for cross-platform projects that do not rely on XCode. Stéphane Sudre provides an outstanding graphcial tool named [Packages](http://s.sudre.free.fr/Software/Packages/about.html) that can aid this process ( [example here](https://eclecticlight.co/2020/08/27/building-and-notarizing-command-tools-as-universal-binaries/)). In contrast, this repository provides a minimum shell script for installing exectuables. 

Assuming you have a working Terminal application you will need to complete the following steps:
 1. You will need an Apple developer account. With the account you will need to generate `Developer ID Installer` and `Developer ID Application` certificates and install them on your computer.
  - You can check which certificates are installed on your computer by running the terminal command `security find-identity -p basic -v`. This should list `Developer ID Installer: My Name` and `Developer ID Application: My Name`. **You will only do this once.**
 2. [Generate](https://support.apple.com/en-us/HT204397) an app specific password via [https://appleid.apple.com](https://appleid.apple.com). **You will only do this once.** 
 3. Run the notarize.bash script. **The first time you do this want to edit the Info.plist with your personal CFBundleName, CFBundleExecutable and CFBundleIdentifier values. You will also need to personalize the bash script with your user name, Installer ID, Application ID and app specific password.** The script will execute the following steps:
  - Compile your executable and append a Info.plist section to your executable. 
  - Generate a disk image.
  - Upload your disk image to Apple. Wait for a response (which can take a few minutes).
  - Assuming success, staple your ticket to your disk image.
  
  
## Create a universal binary

The script notarize.sh will create a universal binary, here is an explanation for this. 

Old macOS computers use Intel x86-64 CPUs, while the latest computers use ARM-based `Apple Silicon` CPUs. If we want our executable to run natively on both systems, we should compile for each, and use lipo to merge these two into a single universal binary. This assumes you have [compiled FPC for both Intel and Apple CPUs ](https://wiki.freepascal.org/macOS_Big_Sur_changes_for_developers#ARM64.2FAArch64.2FApple_Silicon_Support):

 ```
fpc ./hello.pas -oexeX86 -Px86_64
fpc ./hello.pas -oexeARM -Paarch64
strip ./exeARM; strip ./exeX86
lipo -create -output exe exeARM exeX86
 ```
 
 Alternatively, you may want to [build FPC with LLVM support](https://wiki.freepascal.org/LLVM). The standard FPC compiler has only been recently adapted to support Apple Silicon CPUs, and optimization is currently limited. In contrast, Apple has invested years optimizing LLVM for their iPhones and iPads.
  
## Appending your Info.plist

The script notarize.sh will create attach a Info.plist to the executable, here is an explanation for this. 

Here we consider a very simple command line tool that we would traditionally compile with the command
 ```
 g++ -I. hello.cpp -o hello
 ```
Apple notarization expects a XML file named 'Info.plist' (it may not be required unless you use features like the [camera](https://stackoverflow.com/questions/55518922/missing-info-plist-file-for-c-command-line-tool-application-within-xcode)). For graphical applications distributed as an .app bundle, this file is distributed as a stand-alone file. However, command line tools do not have app bundles, so we need to insert this XML file directly into our executable. Consider a minimal Info.plist (individual projects will need to modify the CFBundleName, CFBundleExecutable and CFBundleIdentifier):
 ```
 <?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>hello</string>
	<key>CFBundleIdentifier</key>
	<string>com.mycompany.hello</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>hello</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
</dict>
</plist>
```
 We can inject this into our application by telling the linker to add this as a section:
```
g++ -sectcreate __TEXT __info_plist Info.plist -I. hello.cpp -o hello
```  
Alternatively, many people use CMake to compile C applications. Unfortunately, searching the web for instructions for combining Info.plist files using CMake provides a lot of false leads. In the past, most instructions focused on inserting Info.plist files into application bundles. In contrast, we want to inject the file directly into our executable. To solve this, you will want to modify the `CMakeLists.txt` file  that is in the same folder as the source code and Info.plist file to include:
``` 
if(APPLE)
    message("--   Adding Apple plist")
    set_target_properties(hello PROPERTIES LINK_FLAGS "-Wl,-sectcreate,__TEXT,__info_plist,${CMAKE_SOURCE_DIR}/Info.plist")
endif()
``` 
This sample project includes both a CMake file that includes this.

## Edit notarize.sh script

You will need update the script with your private values.
``` 
COMPANY_NAME=mycompany
APP_NAME=hello
APP_SPECIFIC_PASSWORD=abcd-efgh-ijkl-mnop
APPLE_ID_USER=myname@gmail.com
APPLE_ID_INSTALL="Developer ID Installer: My Name"
APPLE_ID_APP="Developer ID Application: My Name"
``` 

## Run

From the comman line, change directory (`cd`) to the directory containing notarize.sh and run using `./notarize.sh`.  If the process was successful you will have the notarized package `hello.pkg`.

## References

Apple has not provided clear documentation or tools for users who do not use XCode to automate the process (and even that has changed over the years). Unfortunately, notarization requirements and details have changed over time. This makes searching for instructions perilous, as methods that worked in the past may no longer work.

 - Examples of tools that do not work as expected in late 2020 (`productbuild`) and those that [do (`pkgbuild`)](https://developer.apple.com/forums/thread/669188). Unfortunately, when Apple's code-signing and notarization tools do not work as expected, there is little documentation to help, and older documentation is often misleading.
 - scriptingosx from [2019](https://scriptingosx.com/2019/09/notarize-a-command-line-tool/) describes using XCode.
 - eclecticlight from [2019](https://eclecticlight.co/2019/06/13/building-and-delivering-command-tools-for-catalina/) and [2020](https://eclecticlight.co/2020/08/27/building-and-notarizing-command-tools-as-universal-binaries/) describes using [Packages](http://s.sudre.free.fr/Software/Packages/about.html).

