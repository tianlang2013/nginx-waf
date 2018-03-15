local get_headers = ngx.req.get_headers
local ua = ngx.var.http_user_agent
local uri = ngx.var.request_uri
local url = ngx.var.host .. uri
local redirect_candidate = ngx.var.uri
local args_remainder = ngx.null
local args = ngx.var.args
local rulematch = ngx.re.find

local redis = require 'resty.redis'
local red = redis.new()
local CCcount = 3 
local CCseconds = 300 
local RedisIP = '127.0.0.1'
local RedisPORT = 6379
local blackseconds = 86400000
if ua == nil then
    ua = "unknown"
end
-- if (uri == "/wp-admin.php") then
--    CCcount=20
--    CCseconds=60
-- end
local AGENTRULE = {[1]='okhttp', [2]="safri"}
local USER_AGENT = ngx.var.http_user_agent
        if USER_AGENT ~= nil then
            for _,rule in pairs( AGENTRULE) do 
                if rule ~="" and rulematch(USER_AGENT,rule,"jo") then
			ngx.exit(503)
                        return true
                end
            end
        end

red:set_timeout(100)
local ok, err = red.connect(red, RedisIP, RedisPORT)
if ok then
    red.connect(red, RedisIP, RedisPORT)
    function getClientIp()
        IP = ngx.req.get_headers()["X-Real-IP"]
        if IP == nil then
            IP = ngx.req.get_headers()["x_forwarded_for"]
        end
        if IP == nil then
            IP  = ngx.var.remote_addr
        end
        if IP == nil then
            IP  = "unknown"
        end
        return IP
    end
    local token = getClientIp() .. "." .. ngx.md5(url .. ua)
    local req = red:exists(token)
    if req == 0 then
        red:incr(token)
        red:expire(token,CCseconds)
    else
        local times = tonumber(red:get(token))
        if times >= CCcount then
            local blackReq = red:exists("black." .. token)
            if (blackReq == 0) then
                red:set("black." .. token,1)
                red:expire("black." .. token,blackseconds)
                red:expire(token,blackseconds)
                ngx.exit(503)
            else
                ngx.exit(503)
            end
            return true
        else
            red:incr(token)
        end
    end
    return true
end
