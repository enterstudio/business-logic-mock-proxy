#
# Copyright (c) 2015, Kinvey, Inc. All rights reserved.
#
# This software is licensed to you under the Kinvey terms of service located at
# http://www.kinvey.com/terms-of-use. By downloading, accessing and/or using this
# software, you hereby accept such terms of service  (and any agreement referenced
# therein) and agree that you have read, understand and agree to be bound by such
# terms of service and are of legal age to agree to such terms with Kinvey.
#
# This software contains valuable confidential and proprietary information of
# KINVEY, INC and is subject to applicable licensing agreements.
# Unauthorized reproduction, transmission or distribution of this file and its
# contents is a violation of applicable laws.
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