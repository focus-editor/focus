gcc -o libLightweightRenderingView.dylib -shared LightweightRenderingView.m -framework AppKit -framework QuartzCore
install_name_tool -id "@rpath/libLightweightRenderingView.dylib" libLightweightRenderingView.dylib

gcc -c LightweightRenderingView.m
libtool -static -c -o libLightweightRenderingView.a LightweightRenderingView.o