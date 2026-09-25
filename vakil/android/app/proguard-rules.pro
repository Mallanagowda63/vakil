# ZEGOCLOUD voice calls (release builds shrink code with R8).
-keep class **.zego.** { *; }

# Razorpay Checkout (wallet recharge).
-keepclassmembers class * { @android.webkit.JavascriptInterface <methods>; }
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/*
-keepclasseswithmembers class * { public void onPayment*(...); }
