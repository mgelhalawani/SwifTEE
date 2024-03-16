#
# Copyright (C) 2011-2018 Intel Corporation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#   * Neither the name of Intel Corporation nor the names of its
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#

######## SGX SDK Settings ########

SGX_SDK ?= /opt/intel/sgxsdk
SGX_MODE ?= SIM
SGX_ARCH ?= x64
SGX_DEBUG ?= 1

ifeq ($(shell getconf LONG_BIT), 32)
	SGX_ARCH := x86
else ifeq ($(findstring -m32, $(CXXFLAGS)), -m32)
	SGX_ARCH := x86
endif

ifeq ($(SGX_ARCH), x86)
	SGX_COMMON_CFLAGS := -m32
	SGX_LIBRARY_PATH := $(SGX_SDK)/lib
	SGX_ENCLAVE_SIGNER := $(SGX_SDK)/bin/x86/sgx_sign
	SGX_EDGER8R := $(SGX_SDK)/bin/x86/sgx_edger8r
else
	SGX_COMMON_CFLAGS := -m64
	SGX_LIBRARY_PATH := $(SGX_SDK)/lib64
	SGX_ENCLAVE_SIGNER := $(SGX_SDK)/bin/x64/sgx_sign
	SGX_EDGER8R := $(SGX_SDK)/bin/x64/sgx_edger8r
endif

ifeq ($(SGX_DEBUG), 1)
ifeq ($(SGX_PRERELEASE), 1)
$(error Cannot set SGX_DEBUG and SGX_PRERELEASE at the same time!!)
endif
endif

ifeq ($(SGX_DEBUG), 1)
        SGX_COMMON_CFLAGS += -O0 -g
else
        SGX_COMMON_CFLAGS += -O2
endif

######## App Settings ########

ifneq ($(SGX_MODE), HW)
	Urts_Library_Name := sgx_urts_sim
else
	Urts_Library_Name := sgx_urts
endif

App_Cpp_Files := App/App.cpp
App_Include_Paths := -IInclude -IApp -I$(SGX_SDK)/include

App_C_Flags := $(SGX_COMMON_CFLAGS) -fPIC -Wno-attributes $(App_Include_Paths)

# Three configuration modes - Debug, prerelease, release
#   Debug - Macro DEBUG enabled.
#   Prerelease - Macro NDEBUG and EDEBUG enabled.
#   Release - Macro NDEBUG enabled.
ifeq ($(SGX_DEBUG), 1)
        App_C_Flags += -DDEBUG -UNDEBUG -UEDEBUG
else ifeq ($(SGX_PRERELEASE), 1)
        App_C_Flags += -DNDEBUG -DEDEBUG -UDEBUG
else
        App_C_Flags += -DNDEBUG -UEDEBUG -UDEBUG
endif

App_Cpp_Flags := $(App_C_Flags) -std=c++11
App_Link_Flags := $(SGX_COMMON_CFLAGS) -L$(SGX_LIBRARY_PATH) -l$(Urts_Library_Name) -lpthread 

ifneq ($(SGX_MODE), HW)
	App_Link_Flags += -lsgx_uae_service_sim
else
	App_Link_Flags += -lsgx_uae_service
endif

App_Cpp_Objects := $(App_Cpp_Files:.cpp=.o)

App_Name := app

######## Enclave Settings ########

ifneq ($(SGX_MODE), HW)
	Trts_Library_Name := sgx_trts_sim
	Service_Library_Name := sgx_tservice_sim
else
	Trts_Library_Name := sgx_trts
	Service_Library_Name := sgx_tservice
endif
Crypto_Library_Name := sgx_tcrypto

Enclave_Cpp_Files := Enclave/Enclave.cpp
Enclave_Include_Paths := -IInclude -IEnclave \
	-I$(SGX_SDK)/include -I$(SGX_SDK)/include/tlibc  \
	-I$(SGX_SDK)/include/libcxx	
# 	-I/usr/include/x86_64-linux-gnu/c++/11
#	-I/usr/include/c++/11 
#	-I/usr/include/c++/11/parallel/
#	-I/usr/include/x86_64-linux-gnu/c++/11/bits

CC_BELOW_4_9 := $(shell expr "`$(CC) -dumpversion`" \< "4.9")
ifeq ($(CC_BELOW_4_9), 1)
	Enclave_C_Flags := $(SGX_COMMON_CFLAGS) -fvisibility=hidden -fpie -ffunction-sections -fdata-sections -fstack-protector -nostdinc
else
	Enclave_C_Flags := $(SGX_COMMON_CFLAGS) -nostdinc -fvisibility=hidden -fpie -ffunction-sections -fdata-sections -fstack-protector-strong
endif

Enclave_C_Flags += $(Enclave_Include_Paths)
Enclave_Cpp_Flags := $(Enclave_C_Flags) -std=c++11 -nostdinc++

# To generate a proper enclave, it is recommended to follow below guideline to link the trusted libraries:
#    1. Link sgx_trts with the `--whole-archive' and `--no-whole-archive' options,
#       so that the whole content of trts is included in the enclave.
#    2. For other libraries, you just need to pull the required symbols.
#       Use `--start-group' and `--end-group' to link these libraries.
# Do NOT move the libraries linked with `--start-group' and `--end-group' within `--whole-archive' and `--no-whole-archive' options.
# Otherwise, you may get some undesirable errors.
Enclave_Link_Flags := $(SGX_COMMON_CFLAGS) -Wl,--no-undefined -nostdlib -nodefaultlibs -nostartfiles -L$(SGX_LIBRARY_PATH) \
	-Wl,--whole-archive -l$(Trts_Library_Name) -Wl,--no-whole-archive \
	-Wl,--start-group -lsgx_tstdc -lsgx_tcxx -l$(Crypto_Library_Name) -l$(Service_Library_Name) -Wl,--end-group \
	-Wl,-Bstatic -Wl,-Bsymbolic -Wl,--no-undefined \
	-Wl,-pie,-eenclave_entry -Wl,--export-dynamic  \
	-Wl,--defsym,__ImageBase=0 -Wl,--gc-sections   \
	-Wl,--version-script=Enclave/Enclave.lds

Enclave_Cpp_Objects := $(Enclave_Cpp_Files:.cpp=.o)

Enclave_Name := enclave.so
Signed_Enclave_Name := enclave.signed.so
Enclave_Config_File := Enclave/Enclave.config.xml

ifeq ($(SGX_MODE), HW)
ifeq ($(SGX_DEBUG), 1)
	Build_Mode = HW_DEBUG
else ifeq ($(SGX_PRERELEASE), 1)
	Build_Mode = HW_PRERELEASE
else
	Build_Mode = HW_RELEASE
endif
else
ifeq ($(SGX_DEBUG), 1)
	Build_Mode = SIM_DEBUG
else ifeq ($(SGX_PRERELEASE), 1)
	Build_Mode = SIM_PRERELEASE
else
	Build_Mode = SIM_RELEASE
endif
endif


.PHONY: all run

ifeq ($(Build_Mode), HW_RELEASE)
all: .config_$(Build_Mode)_$(SGX_ARCH) $(App_Name) $(Enclave_Name)
	@echo "The project has been built in release hardware mode."
	@echo "Please sign the $(Enclave_Name) first with your signing key before you run the $(App_Name) to launch and access the enclave."
	@echo "To sign the enclave use the command:"
	@echo "   $(SGX_ENCLAVE_SIGNER) sign -key <your key> -enclave $(Enclave_Name) -out <$(Signed_Enclave_Name)> -config $(Enclave_Config_File)"
	@echo "You can also sign the enclave using an external signing tool."
	@echo "To build the project in simulation mode set SGX_MODE=SIM. To build the project in prerelease mode set SGX_PRERELEASE=1 and SGX_MODE=HW."
else
all: .config_$(Build_Mode)_$(SGX_ARCH) $(App_Name) $(Signed_Enclave_Name) lib/libsgxw.a swiftc
ifeq ($(Build_Mode), HW_DEBUG)
	@echo "The project has been built in debug hardware mode."
else ifeq ($(Build_Mode), SIM_DEBUG)
	@echo "The project has been built in debug simulation mode."
else ifeq ($(Build_Mode), HW_PRERELEASE)
	@echo "The project has been built in pre-release hardware mode."
else ifeq ($(Build_Mode), SIM_PRERELEASE)
	@echo "The project has been built in pre-release simulation mode."
else
	@echo "The project has been built in release simulation mode."
endif
endif

run: all
ifneq ($(Build_Mode), HW_RELEASE)
	@$(CURDIR)/$(App_Name)
	@echo "RUN  =>  $(App_Name) [$(SGX_MODE)|$(SGX_ARCH), OK]"
endif

######## App Objects ########

App/Enclave_u.c: $(SGX_EDGER8R) Enclave/Enclave.edl
	@cd App && $(SGX_EDGER8R) --untrusted ../Enclave/Enclave.edl --search-path ../Enclave --search-path $(SGX_SDK)/include
	@echo "GEN  =>  $@"

App/Enclave_u.o: App/Enclave_u.c
	@$(CC) $(App_C_Flags) -c $< -o $@
	@echo "CC   <=  $<"

App/%.o: App/%.cpp
	@$(CXX) $(App_Cpp_Flags) -c $< -o $@
	@echo "CXX  <=  $<"

$(App_Name): App/Enclave_u.o $(App_Cpp_Objects)
#	@$(CXX) $^ -o $@ $(App_Link_Flags)
	@echo "LINK =>  $@"

.config_$(Build_Mode)_$(SGX_ARCH):
	@rm -f .config_* $(App_Name) $(Enclave_Name) $(Signed_Enclave_Name) $(App_Cpp_Objects) App/Enclave_u.* $(Enclave_Cpp_Objects) Enclave/Enclave_t.*
	@touch .config_$(Build_Mode)_$(SGX_ARCH)

######## Enclave Objects ########

Enclave/Enclave_t.c: $(SGX_EDGER8R) Enclave/Enclave.edl
	@cd Enclave && $(SGX_EDGER8R) --trusted ../Enclave/Enclave.edl --search-path ../Enclave --search-path $(SGX_SDK)/include
	@echo "GEN  =>  $@"

Enclave/Enclave_t.o: Enclave/Enclave_t.c 
	@$(CC) $(Enclave_C_Flags) -c $< -o $@
	@echo "CC   <=  $<"

Enclave/%.o: Enclave/%.cpp
	@echo "C++ => $(CXX) "

	clang -m64 -c -fPIC $< -o $@ \
		-IInclude -IEnclave -I$(SGX_SDK)/include \
		-fvisibility=hidden \
		-fpie \
		-ffunction-sections \
		-fdata-sections \
		-fstack-protector \
		-std=c++11 
		
	@echo "CXX  <=  $^"

lib/libenci.a: Enclave/Enclave_t.o $(Enclave_Cpp_Objects)
	@echo "making ENCI library"
	ar -rsc lib/libenci.a Enclave/Enclave_t.o $(Enclave_Cpp_Objects)
	ranlib lib/libenci.a

Enclave/SwiftEnclave.o: Enclave/SwiftEnclave.swift lib/libenci.a
	swiftc -parse-as-library -c Enclave/SwiftEnclave.swift \
		-cxx-interoperability-mode=default \
    	-emit-clang-header-path Enclave/SwiftInside-Swift.h \
		-o Enclave/SwiftEnclave.o \
		-color-diagnostics \
		-Xcc -fPIC \
		-avoid-emit-module-source-info \
		-L ../lib/ \
		-l enci \
		-Xcc -I -Xcc Enclave/ \
		-g \
		-swift-version 5 \
		-Onone

Enclave/interface.o: Enclave/interface.cpp 
	clang -m64 -c -fPIC -c $< -o $@
	@echo "$(CXX) <= $<"

$(Enclave_Name): Enclave/SwiftEnclave.o Enclave/Enclave_t.o Enclave/interface.o $(Enclave_Cpp_Objects) 
	@echo "creating encalve..."
	@$(CXX) $^ -o $@ -L/home/mainuser/Documents/swift-5.9.1-RELEASE-ubuntu22.04/usr/lib \
		-Wl,--start-group -lswiftDemangle -lIndexStore -llldb -lLTO -Wl,--end-group \
		/home/mainuser/Documents/swift-5.9.1-RELEASE-ubuntu22.04/usr/lib/swift/linux/*.so \
		$(Enclave_Link_Flags)

	@echo "Files => $^"
	@echo "LINK =>  $@"

$(Signed_Enclave_Name): $(Enclave_Name)
	@$(SGX_ENCLAVE_SIGNER) sign -key Enclave/Enclave_private.pem -enclave $(Enclave_Name) -out $@ -config $(Enclave_Config_File)
	@echo "SIGN =>  $@"

lib/libsgxw.a: Enclave/SwiftEnclave.o App/App.o Enclave/Enclave.o
	@echo "making library"
	ar -rsc lib/libsgxw.a Enclave/SwiftEnclave.o App/Enclave_u.o $(App_Cpp_Objects) Enclave/Enclave_t.o $(Enclave_Cpp_Objects) Enclave/interface.o 
	ranlib lib/libsgxw.a
	
swiftc: lib/libsgxw.a
	swiftc Swift/main.swift \
		-emit-executable \
		-L lib/ \
		-l sgxw \
		-Xcc -I -Xcc App/ \
		-Xcc -I -Xcc Enclave/ \
		-L /home/mainuser/Documents/sgxsdk/sdk_libs/ \
		-l$(Urts_Library_Name) \
		-Xcc -I -Xcc /home/mainuser/Documents/sgxsdk/include \
		-o main \
		-DDEBUG \
		-experimental-skip-non-inlinable-function-bodies-without-types \
		-target x86_64-unknown-linux-gnu \
		-color-diagnostics \
		-g \
		-swift-version 5 \
		-Onone \
		-D SWIFT_PACKAGE \
		-D DEBUG \
		-Xcc -fmodule-map-file=/home/mainuser/Documents/ProjectCode/SwifTee/App/module.modulemap \
		-Xcc -fmodule-map-file=/usr/lib/gcc/x86_64-linux-gnu/11/../../../../include/c++/11/module.modulemap \
		-Xcc -fPIC \
		-cxx-interoperability-mode=default

.PHONY: clean

clean:
	@rm -f .config_* $(App_Name) $(Enclave_Name) $(Signed_Enclave_Name) \
		$(App_Cpp_Objects) App/Enclave_u.* $(Enclave_Cpp_Objects) Enclave/Enclave_t.* \
		main main.o \
		Enclave/SwiftInside-Swift.h Enclave/SwiftEnclave.o \
		Enclave/SwiftEnclave.autolink Enclave/SwiftEnclave.swiftdoc \
		Enclave/SwiftEnclave.swiftmodule Enclave/converted.o \
		enclave.signed.so lib/* Enclave/interface.o


