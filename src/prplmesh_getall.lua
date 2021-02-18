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
require("ubus")


--[[
    @brief Write errors to stderr
--]]
local function error(message)
    io.stderr:write("[ERROR] " .. tostring(msg) .. "\n")
end


--[[
    @brief  Function for getting indexes from UBus via list
            function provided by Ambiorix library.

    @param  path String contains to object in Data Model.
            Example: Controller.Network.Device.{i}

    @return  Table which contains list of indexes for path otherwise false.
--]]
local function get_indexes(path)

    local _ubus_connection
    local devices
    local instances
    local result = {}

    _ubus_connection = ubus.connect()
    if not _ubus_connection then
        error("Ubus sock conn fail")
        return false
    end

    -- Retrieve output from list method via path from UBus
    instance = _ubus_connection:call(path, "list", { })
    if not instance then
        error(path .. " not found in UBus")
        _ubus_connection:close()
        return false
    end

    if not instance then
        error("Failed to get intance table from UBus, path: " .. path)
        return false
    end

    -- Fill up path instance indexes in table.
    for k, v in pairs(instance["instances"]) do
        result[k] = v["index"]
    end

    _ubus_connection:close()

    return result
--get_indexes()
end


--[[
    @brief  Function splits object path string into list of root and sub-objects.
            Example: Controller.Network.Device.{i}.Radio.{i}
                     Will be converted in table:
                        Controller.Network.Device
                        Radio

    @param  path String contains to object in Data Model.
            Example: Controller.Network.Device.{i}.Radio.{i}

    @return Table which contains list of required arguments otherwise false.
--]]
local function get_dm_table(path)

    if not path then
        error("Bad path.")
        return false
    end

    local parsed_args = {}

    for match in string.gmatch(path, "(.-)[.]{i}[.]?") do
        table.insert(parsed_args, match);
    end

    return parsed_args
--get_dm_table
end


--[[
    @brief Calculate table size.

    @param data Table with data.
    @return Table size otherwise false.
--]]
local function get_table_size(data)

    if not data or tostring(type(data)) ~= "table" then
        error("Bad data: " .. tostring(data))
        return false
    end

    local size = 0;

    for _ in pairs(data) do
        size = size + 1
    end

    return size
--get_table_size()
end


--[[
    @brief  Calculate path to object.
            Example: Controller.Network.Device.1.Radio

    @param  root_path String with root object path.
            Example: Controller.Network.Device

    @param  obj_path String with path to object.
            Example: Radio

    @param  idx Integer index

    @return Path to object (ex: Controller.Network.Device.1.Radio)
            otherwise false.
--]]
local function get_obj_path(root_path, obj_path, idx)

    if ((type(root_path)~= "string" or type(obj_path)) ~= "string") then
        error "Bad arguments given"
        return false
    end

    if (type(idx) ~= "number") or idx <= 0 then
        error("Bad index, idx: " .. tostring(idx))
        return false
    end
    local out

    out = root_path .. "." .. tostring(idx) .. "." .. obj_path

    return out
--get_obj_path()
end


--[[
    @brief  Clears file.

    @param  path String with path to file.
    @return True on success otherwise false.
--]]
local function clear_mmx_out(path)

    file = io.open(path, "w")
    if not file then
        error("Failed to open file: " .. path)
        return false
    end

    io.close(file)

    return true
--clear_mmx_out()
end


--[[
    @brief  Write data to file.

    @param  path String with path to file.
    @param  data String with data in mmx format.
            Example: 1,1,1;

    @return True on success otherwise false.
--]]
local function write_mmx_out(path, data)

    local file = io.open(path, "a+")

    if not file then
        error("Failed to open file: " .. path)
        return false
    end

    io.output(file)
    io.write(data)

    io.close(file)

    return true
--write_mmx_out()
end


--[[
    @brief  Read data from file.

    @param  path String with path to file.
    @return mmx-style string on success otherwise false.
--]]
local function read_mmx_out(path)

    local file = io.open(path, "r")
    if not file then
        error("Failed to open file: " .. path)
        return false
    end

    io.input(file)
    local out = io.read()
    io.close(file)

    return out
--read_mmx_out()
end


--[[
    @brief  Create specific B-tree root object..

    @param  root_path String with path to root object.
    @param  last Name of the last object for processing.
    @param  path Path to file for saving results.
    @return Table for root object otherwise false.
--]]
local function tree_create(root_path, last, path)

    if type(root_path) ~= "string" then
        error("Bad argument given")
        return false
    end

    root = {
        name = root_path,
        path = root_path,
        idx_tbl,
        mmx_out,
        visited = false,
        last,
        k = {}
    }

    root.idx_tbl = get_indexes(root_path)

    local tmp = ""
    if root.name == last then
        for count, idx in pairs(root.idx_tbl) do
            tmp = tostring(idx) .. ";"
            write_mmx_out(path, tmp)
        end
    end

    root.mmx_out = tmp
    return root
--create_tree()
end


--[[
    @brief  Create empty node for specific B-tree.

    @return Table for empty node.
--]]
local function node_create_empty()
    local node = {
        id,
        name,
        path,
        idx_tbl,
        mmx_out,
        visited = false,
        last,
        k = {}
    }
    return node
end


--[[
    @brief  Add node to specific B-tree.

    @param  root String with path to root object.
    @param  node_name Name of the next object for processing.
    @return True on success otherwise false.
--]]
local function tree_add_node(root, node_name)

    if not root or type(root) ~= "table" then
        error("Bad root object: " .. tostring(root))
        return false
    end

    local idx_tbl_size = get_table_size(root.idx_tbl)
    if  not idx_tbl_size or root_tbl_size == 0 then
        error("Bad " .. root.path .. " index table size, idx_tbl_size: " .. tostring(idx_tbl_size))
        return false
    end

    -- Recursively add node to the k table
    for count, idx in pairs(root.idx_tbl) do
        if not root.k[count] then
            local node = node_create_empty()
            node.name = node_name
            node.path = get_obj_path(root.path, node_name, root.idx_tbl[count])
            node.idx_tbl = get_indexes(node.path)
            node.mmx_out = root.mmx_out .. tostring(idx) .. ","
            node.last = root.last

            -- Prepare specific mmx out string for the last object
            if node.name == node.last and node.idx_tbl then
                local tmp = {}
                local res = ""
                for cnt,idx in pairs(node.idx_tbl) do
                    tmp[cnt] = node.mmx_out .. tostring(idx) .. ";"
                end
                for cnt,val in pairs(tmp) do
                    res = tostring(res) .. val
                end
                node.mmx_out = res
            end

            root.k[count] = node
        end

        k_size = get_table_size(root.k)
        -- If current k table full - create new k table on the next level
        if idx_tbl_size == k_size and root.k[count].name ~= node_name then
            tree_add_node(root.k[count], node_name)
        end
    end

    return true
    --tree_add_node
end


--[[
    @brief  Specific depth-first search for searching
            mmx string for the last object and wtrite
            it to file.

    @param  root String with path to root object.
    @param  path Path to file.
--]]
local function dfs(root, path)
    if root and root.idx_tbl then
        for count, idx in pairs(root.idx_tbl) do
            dfs(root.k[idx], path)
            if root.name == root.last and not root.visited then
                root.visited = true
                write_mmx_out(path, root.mmx_out)
            end
        end
    end
end


--[[
    @brief  Get mmx string for given path.

    @param  path String with raw path to last object.
    @return  mmx style string for last object otherwise false.
--]]
local function get_mmx_out(path)


    local mmx_out_file = "/tmp/getall"
    local dm_table = {}
    local dm_size = 0

    clear_mmx_out(mmx_out_file)

    dm_table = get_dm_table(path)
    if not dm_table then
        error("Failed to get Data Model table")
        return false
    end

    dm_size = get_table_size(dm_table)
    if not dm_size or dm_size == 0 then
        error("Failed to get Data Model table size")
        return false
    end

    local root
    for idx_tbl in pairs(dm_table) do
        if idx_tbl == 1 then
            root = tree_create(dm_table[idx_tbl], dm_table[dm_size], mmx_out_file)
        else
            root.last = dm_table[dm_size]
            tree_add_node(root, dm_table[idx_tbl])
        end
    end

    dfs(root, mmx_out_file)

    read_result = read_mmx_out(mmx_out_file)
    if not read_result then
        error("Failed to read " .. mmx_out_file)
        return false
    end

    local mmx = tostring(ing.ResCode.SUCCESS) .. ";" .. read_mmx_out(mmx_out_file)
    os.remove(mmx_out_file)

    return mmx
--get_mmx_out
end


function main(args)

    if args[1] then
        mmx_string = get_mmx_out(args[1])
        if not mmx_string then
            return ing.ResCode.FAIL
        else
            print(mmx_string)
        end
    end
end

main(arg)
