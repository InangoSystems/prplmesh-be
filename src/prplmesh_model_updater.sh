#!/bin/sh
################################################################################
#
# Copyright (c) 2013-2021 Inango Systems LTD.
#
# Author: Inango Systems LTD. <support@inango-systems.com>
# Creation Date: 10 May 2021
#
# The author may be reached at support@inango-systems.com
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Subject to the terms and conditions of this license, each copyright holder
# and contributor hereby grants to those receiving rights under this license
# a perpetual, worldwide, non-exclusive, no-charge, royalty-free, irrevocable
# (except for failure to satisfy the conditions of this license) patent license
# to make, have made, use, offer to sell, sell, import, and otherwise transfer
# this software, where such license applies only to those patent claims, already
# acquired or hereafter acquired, licensable by such copyright holder or contributor
# that are necessarily infringed by:
#
# (a) their Contribution(s) (the licensed copyrights of copyright holders and
# non-copyrightable additions of contributors, in source or binary form) alone;
# or
#
# (b) combination of their Contribution(s) with the work of authorship to which
# such Contribution(s) was added by such copyright holder or contributor, if,
# at the time the Contribution is added, such addition causes such combination
# to be necessarily infringed. The patent license shall not apply to any other
# combinations which include the Contribution.
#
# Except as expressly stated above, no rights or licenses from any copyright
# holder or contributor is granted under this license, whether expressly, by
# implication, estoppel or otherwise.
#
# DISCLAIMER
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# NOTE
#
# This is part of a management middleware software package called MMX that was developed by Inango Systems Ltd.
#
# This version of MMX provides web and command-line management interfaces.
#
# Please contact us at Inango at support@inango-systems.com if you would like to hear more about
# - other management packages, such as SNMP, TR-069 or Netconf
# - how we can extend the data model to support all parts of your system
# - professional sub-contract and customization services
#
################################################################################

NAME=mmx_model_updater

main() {
    update_cycle "$@"
}


update_cycle() {
    logger -t "$NAME" -p daemon.debug "prplMesh MMX model update cycle"

    current_model_file=$1; shift;
    prev_model=/tmp/mmx_prev_model
    to_update=/tmp/mmx_to_ntf

    > "$to_update"

    [ -f "$current_model_file" ] || touch "$current_model_file"
    mv "$current_model_file" "$prev_model"

    get_ambiorix_model | sort > "$current_model_file"

    find_changed_objects "$prev_model"         "$current_model_file" "$to_update"
    find_changed_objects "$current_model_file" "$prev_model"         "$to_update"
    
    if [ "$(cat $to_update | wc -l)" != "0" ]; then
        cat "$to_update" | sort -u | ambiorix_to_mmx_object_name | xargs -n 1 ntfrsend -i 203 -m 120 -l 3 -p
    fi
}

get_ambiorix_model() {
    # Print current Ambiorix model
    ubus list | grep Controller
}

find_changed_objects() {
    # $1 - path to file with "ubus list" output of prev model state
    # $2 - path to file with "ubus list" output of current model state
    # $3 - path to file for write list of changed MMX model object names into
    # Write into "$3" the MMX objects changed/appeard/disappeared in comparison to prev model

    current_model_file=$1; shift;
    prev_model=$1; shift;
    to_update=$1; shift

    for obj_name_regex in $(sed -e 's/\.\d\+\./.[[:digit:]]\\+./g' -e 's/\d\+$/[[:digit:]]\\+/' "$current_model_file" | sort -u | grep ':digit:'); do
        cur_state=$(grep -x $obj_name_regex "$current_model_file" | md5sum -);
        prev_state=$(grep -x $obj_name_regex "$prev_model" | md5sum -);

        # analyze non-scalar and scalar objects but add to update only non-scalar because scalar objects defined as augment usually
        if [ "$cur_state" != "$prev_state" ]; then
            grep -m 1 -x $obj_name_regex "$current_model_file" | grep '\d$' | sed -e 's/\.\d\+\./.{i}./g' -e 's/.\d\+$/.{i}./' >> "$to_update"
        fi
    done
}

ambiorix_to_mmx_object_name() {
    # :param $1: name of object from prplMesh data model
    # :return: corresponding MMX object name
    sed 's/^[[:space:]]*/Device./' -
}

main "$@"
