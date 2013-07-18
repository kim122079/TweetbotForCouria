Tweetbot for Couria
===================
This is just an example extension for Couria and it may be too simple to be useful. So don't expect too much from it. ;P

Generally, a Couria extension has these files:

1. /Library/MobileSubstrate/DynamicLibraries/__$My_Couria_Extension_$__.dylib
2. /Library/MobileSubstrate/DynamicLibraries/__$My_Couria_Extension_$__.plist
3. /Library/Application Support/Couria/Extensions/__$Bundle_Identifier_Of_The_Application_Which_My_Extension_Is_For$__/Extension.plist

The 3rd file listed above is optional and it is used to add extra preferences into Couria preferences. Only simple PreferenceLoader plist is supported and you should create your own preference bundle if you need more control and flexibility.
