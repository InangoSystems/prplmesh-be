#!/usr/bin/lua
--[[
################################################################################
#
# Copyright (c) 2013-2021 Inango Systems LTD.
#
# Author: Inango Systems LTD. <support@inango-systems.com>
# Creation Date: 20 Jan 2021
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
--]]

require("mmx/ing_utils")
require("prplmesh-be-utils")


--[[
    @brief  Function for converting CMD arguments to key-value table.

    @param  args Command Line arguments.
            Example: Device.WiFi.DataElements.Network.AccessPoint 1 -pname SSID -pvalue WiFi

    @return Table which contains list of parameters and values otherwise false.
--]]
local function parse_args(args)
    local ap_param_tbl = {}
    local param_idx = 2

    local empty_param = false
    while param_idx <= #args do
        empty_param = false
        if args[param_idx] == "-pname" and args[param_idx+2] == "-pvalue" then

            if args[param_idx + 1] and args[param_idx + 3] ~= "-pname" then
                ap_param_tbl[ args[param_idx + 1] ] = args[param_idx + 3]
            else
                empty_param = true
                ap_param_tbl[ args[param_idx + 1] ] = ""
            end

            if args[param_idx + 3] == nil then
                break
            end

            param_idx = param_idx + (empty_param and 3 or 4)
        else
            error("Invalid arguments")
            return false
        end
    end

    return ap_param_tbl
--parse_args()
end


--[[
    @brief  Function for getting indexes from UBus via list
            function provided by Ambiorix library.

    @param  path String contains path to object in Data Model.
            Example: Device.WiFi.DataElements.Network.AccessPoint.1
    @param  ap_params Table which contains list of parameters and value.

    @return True on success otherwise false.
--]]
local function set_data(path, ap_params)

    if not path or not ap_params then
        error("Bad path or ap_params.")
        return false
    end

    local data = {parameters = ap_params}

    local ret = call_ubus(path, "_set", data)
    if not ret then
        error("Failed to set data.")
        return false
    end

    return true
--set_data()
end


--[[
    @brief  Function for applying AccessPoint parameters.

    @return True on success otherwise false.
--]]
local function apply()

    local ret = call_ubus("Device.WiFi.DataElements.Network", "AccessPointCommit", {})
    if not ret then
        error("Failed to apply data.")
        return false
    end

    return true
--apply()
end


function main(args)

    local ret = tostring(ing.ResCode.FAIL) .. ";" .. tostring(ing.StatCode.OK) .. ";"

    if #args < 2 then
        error("Wrong arguments: " .. tostring(#args))
        print(ret)
        return ret
    end

    local ap_path = args[1]

    local ap_params = parse_args(args)
    if not ap_params then
        error("Failed to parse parameters")
        print(ret)
        return ret
    end

    local success = set_data(ap_path, ap_params)
    if not success then
        error("Failed to set data for: " .. tostring(ap_path))
        print(ret)
        return ret
    end

    success = apply()
    if not success then
        error("Failed to commit changes for: " .. tostring(ap_path))
        print(ret)
        return ret
    end

    print(tostring(ing.ResCode.SUCCESS) .. ";" .. tostring(ing.StatCode.OK) .. ";")
--main()
end

main(arg)
