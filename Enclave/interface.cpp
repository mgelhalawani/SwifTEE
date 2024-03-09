#include "interface.h"

#include "SwiftInside-Swift.h"

int interface_printf_helloworld() {
    auto value = SwiftEnclave::printer();
    return value;
}


