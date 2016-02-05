#!/bin/bash
#
# Copyright 2016 Kinvey, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# `/sbin/setuser kinvey` runs the given command as the user `kinvey`.
# If you omit that part, the command will be run as root.
cd /opt/kinvey/business-logic-mock-proxy
exec /sbin/setuser kinvey /usr/bin/node /opt/kinvey/business-logic-mock-proxy >> /var/log/blmockproxy.log 2>&1