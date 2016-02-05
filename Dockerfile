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

FROM kinvey/base_phusion_node
MAINTAINER "Kinvey Inc."

# Add pre-built application directory.
ADD . /opt/kinvey/business-logic-mock-proxy

# Create kinvey:kinvey group:user.
RUN \
 date -u +%F:%H:%M:%S > /etc/container_environment/BL_PROXY_BUILD_TIME && \
 groupadd -g 2010 kinvey && \
 useradd -m -s /usr/sbin/nologin -d /opt/kinvey -g kinvey -u 2010 -c "Kinvey Application User" kinvey && \
 apt-get update && apt-get -y dist-upgrade && \
 apt-get -y install git && \
 mkdir -m 0755 /var/log/kinvey && \
 mkdir -m 0755 /etc/service/business-logic-mock-proxy && \
 chown -R kinvey:kinvey /var/log/kinvey && \
 chown -R kinvey:kinvey /opt/kinvey && \
 chmod 0755 /etc/container_environment && \
 chmod 0644 /etc/container_environment.sh /etc/container_environment.json

ADD bin/blproxy.sh /etc/service/business-logic-mock-proxy/run

RUN \
 chmod 0755 /etc/service/business-logic-mock-proxy/run

# Prepare to run the application.
EXPOSE 2845
WORKDIR /opt/kinvey/business-logic-mock-proxy
RUN \
 npm install