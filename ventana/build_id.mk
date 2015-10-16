#
# Copyright (C) 2008 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# BUILD_ID is usually used to specify the branch name
# (like "MAIN") or a branch name and a release candidate
# (like "CRB01").  It must be a single word, and is
# capitalized by convention.

export BUILD_ID=A5100

# BUILD_NUMBER Format: date-hash[+], e.g. 20151003-abcd+
BUILD_NUMBER:=$(shell date +%Y%m%d)-$(shell git rev-parse HEAD | cut -c -4)

# repo status takes a while to run, and this file is included every time
# make is run including the "lunch" command which runs make 10+ times
ifneq (,$(filter droid otagenerate,$(MAKECMDGOALS)))
ifneq (,$(shell git status -s)$(shell repo status))
	BUILD_NUMBER:=$(BUILD_NUMBER)+
endif
endif

export BUILD_NUMBER
