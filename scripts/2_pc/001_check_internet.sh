#!/bin/bash

# == Check internet connection ==

if echo -e "GET http://google.com HTTP/1.0\n\n" | nc google.com 80 > /dev/null 2>&1; then
    info "Internet: OK"
else
    fail "No internet connection"
fi
