    --[[
        Markdown.lua: Markdown to HTML converter.
        Copyright 2013, Daniel Gruno.
        Licensed under the Apache License v/2.0
    ]]
    
    function split(data)
        data = data:gsub("\r?\n\r?\n", "\n \n")
        return data:gmatch("([^\r\n]+)")
    end
    
    function inline_link(a,b)
        return [[ <a href="]]..b:sub(2,-2)..[[">]]..a:sub(2,-2)..[[</a> ]]
    end
    
    function format(mark, line, anchor)
        local l = ""
        line = line or ""
        line = line:gsub("__(.-)__", "<b>%1</b>")
        line = line:gsub("_(.-)_", "<i>%1</i>")
        line = line:gsub("`(.-)`", "<code>%1</code>")
        line = line:gsub("(%b[])(%b())", inline_link)
        line = line:gsub([[<([a-z]+:.-)>]], [[<a href="%1">%1</a>]])
        if mark and mark:match("^h") then
            line = "<small>" .. line .. "</small>"
        end
        if mark then
            l = ("<%s%s>%s</%s>"):format(mark, (anchor and (" id='%s'"):format(anchor) or ""), line, mark)
            return l
        else
            return line
        end
    end
    
    function makeTOC(tTable)
        local title = tTable[1] and tTable[1].title or nil
        local toc = "<small><h4 style='font-size: 13px;'>" .. (title or "Untitled") .." - Table of Contents:</h4><ol style='border: 1px dashed #666; padding-left: 20px; margin-top: 0px; margin-bottom: 0px;'>"
        local tocLevel = 1
        for k, line in pairs(tTable) do
            if line.level > tocLevel then
                for i = tocLevel+1, line.level do
                    toc = toc .. "<ol style='margin-top: 0px; margin-bottom: 0px;'>\n"
                end
            end
            if line.level < tocLevel then
                for i = line.level+1, tocLevel do
                    toc = toc .. "</ol>\n"
                end
            end
            tocLevel = line.level
            toc = toc .. ([[<li style='font-size: 11px;'><a href="#%s">%s</a></li>]]):format(line.anchor, line.title)
        end
        for i = 1, tocLevel do
            toc = toc .. "</ol>\n"
        end
        toc = toc .. "</small>"
        return toc
    end
    
    function makeList(tTable)
        local title = tTable[1] and tTable[1].title or nil
        local mark = "ol"
        if tTable[1].style == "list" then
            mark = "ul"
        end
        local list = ("<%s>"):format(mark)
        local listLevel = 1
        for k, line in pairs(tTable) do
            if line.level > listLevel then
                for i = listLevel+1, line.level do
                    list = list .. ("<%s style='margin-top: 0px; margin-bottom: 0px;'>\n"):format(mark)
                end
            end
            if line.level < listLevel then
                for i = line.level+1, listLevel do
                    list = list .. ("</%s>\n"):format(mark)
                end
            end
            listLevel = line.level
            list = list .. ([[<li style='font-size: 13px;'>%s</li>]]):format(format(nil, line.title))
        end
        for i = 1, listLevel do
            list = list .. ("</%s>\n"):format(mark)
        end
        return list
    end
    
    function markdown(data)
        local TOC = {}
        local lines = {}
        local pre = ""
        local inPre = false
        local isKbd = false
        local inList = false
        local ignoreReturn = false
        local list = {}
        local soFar = ""
        local prev = ""
        for line in split(data) do
                
            -- <pre> stuff
            if line:match("^   ") and (inPre or prev:match("^[ \t]*$")) then
                inPre = true
                if line:match("^    :::text$") then
                    line = ""
                    isKbd = true
                    ignoreReturn = true
                end
                pre = pre .. (line:match("^    (.-)$") or "") .. (ignoreReturn and "" or "\n")
            elseif line:match("^[ \t]*[-*1-9]%.?[ \t]+") and (inList or prev:match("^[ \t]*$")) then
                local t = "list"
                local level = 0
                el = line:match("^([ \t]*[-*1-9]%.?[ \t]+)")
                while el and (#el > 0) do
                    level = level + 1
                    line = line:sub(#el)
                    if el:match("[1-9]") then
                        t = "numbers"
                    end
                    el = line:match("^([ \t]*[-*1-9]%.?[ \t]+)")
                end
                table.insert(list, { title = line, level = level, type = t })
                inList = true
            elseif inPre then
                inPre = false
                isKbd = false
                output = table.insert(lines, "<pre>\n" .. ((isKbd and "<kbd>" .. pre .. "</kbd>") or ("<code>"..pre.."</code>")) .. "</pre><br/>")
                pre = ""
            elseif inList and not line:match("^[ \t]*$") then
                list[#list].title = list[#list].title .. line
            elseif inList then
                table.insert(lines, makeList(list))
                list = {}
                inList = false
            end
            if not inPre and not inList then
                -- Headers
                if line:match("^#+[ \t]*([^#{}]+)[ \t]*#*") then
                    local level, title, extra = line:match("^(#+)[ \t]*([^#{}]+)[ \t]*#*(.-)$")
                    local anchor = extra:match("{#(.-)}") or (title:gsub("[^a-zA-Z0-9]+", ""):lower())
                    table.insert(lines, format("h"..#level, title, anchor))
                    table.insert(TOC, { title = title, level = #level, anchor = anchor } )
                elseif line:match("^[ \t]*$") then
                    if soFar:match("[^\r\n \t]") then
                        table.insert(lines, format("p", soFar))
                    end
                    soFar = ""
                else
                    soFar = soFar .. line .. " "
                end
            end
            prev = line
            ignoreReturn = false
        end
        if inPre then
            inPre = false
            table.insert(lines, "<pre>\n" .. ((isKbd and "<kbd>" .. pre .. "</kbd>") or ("<code>"..pre.."</code>")) .. "</pre><br/>")
        elseif inList then
            table.insert(lines, makeList(list))
            list = {}
            inList = false
        elseif soFar ~= "" then
            table.insert(lines, format("p", soFar))
        end
        local output = table.concat(lines, "\n")
        output = output:gsub("%[TOC%]", makeTOC(TOC))
        return output
    end
    
    return markdown
