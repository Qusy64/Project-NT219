local kong = kong
local ngx  = ngx
local str    = require "resty.string"
local digest = require "resty.openssl.digest"
local hmac   = require "resty.openssl.hmac"

local HmacHandler = {
  PRIORITY = 900,
  VERSION  = "0.1.0",
}

-- SHA256 hex helper
local function sha256_hex(data)
  local d = digest.new("sha256")
  d:update(data or "")
  local bin = d:final()
  return str.to_hex(bin)
end

-- Lấy shared dict dùng cho chống replay
local function get_replay_dict()
  -- ưu tiên dùng "kong", nếu không có thì dùng "kong_cache"
  local dict = ngx.shared.kong or ngx.shared.kong_cache
  if not dict then
    kong.log.warn("[hmac-signature] no shared dict (kong/kong_cache); replay protection disabled")
  end
  return dict
end

-- Replay protection
local function check_replay(api_key, ts, nonce, skew)
  local dict = get_replay_dict()
  if not dict then
    -- Không có shared dict → bó tay, cho qua (nhưng log warning)
    return true
  end

  local key = string.format("hmac-replay:%s:%s:%s", api_key, ts, nonce)

  local exists, err = dict:get(key)
  if exists then
    kong.log.info("[hmac-signature] replay detected for key: ", key)
    return false, "Replay detected (nonce already used)"
  end

  local ttl = skew or 300
  local ok, err2 = dict:set(key, true, ttl)
  if not ok then
    kong.log.err("[hmac-signature] failed to store nonce: ", err2)
  else
    kong.log.debug("[hmac-signature] stored nonce key=", key, " ttl=", ttl)
  end

  return true
end

function HmacHandler:access(conf)
  -- Read headers
  local headers   = kong.request.get_headers()
  local method    = kong.request.get_method()
  local path      = kong.request.get_path()
  local query     = kong.request.get_raw_query() or ""
  local body      = kong.request.get_raw_body() or ""

  local api_key   = headers["x-api-key"]    or headers["X-Api-Key"]
  local signature = headers["x-signature"]  or headers["X-Signature"]
  local timestamp = headers["x-timestamp"]  or headers["X-Timestamp"]
  local nonce     = headers["x-nonce"]      or headers["X-Nonce"]

  if not (api_key and signature and timestamp and nonce) then
    return kong.response.exit(401, { message = "Missing HMAC headers" })
  end

  local secret = conf.secrets[api_key]
  if not secret then
    return kong.response.exit(401, { message = "Unknown API key" })
  end

  -- Timestamp check
  local now  = os.time()
  local ts   = tonumber(timestamp)
  local skew = conf.max_clock_skew or 300

  if not ts or math.abs(now - ts) > skew then
    return kong.response.exit(401, { message = "Timestamp out of range" })
  end

  -- Build canonical request
  local canonical = table.concat({
    method,
    path,
    query,
    timestamp,
    nonce,
    sha256_hex(body),
  }, "\n")

  -- Compute HMAC
  local hm = hmac.new(secret, "sha256")
  hm:update(canonical)
  local computed = str.to_hex(hm:final())

  -- Compare signatures
  if computed:lower() ~= tostring(signature):lower() then
    return kong.response.exit(401, { message = "Invalid HMAC signature" })
  end

  -- Replay protection
  local ok_replay, replay_err = check_replay(api_key, timestamp, nonce, skew)
  if not ok_replay then
    return kong.response.exit(401, { message = replay_err })
  end

  -- Debug header để biết chắc plugin đã chạy
  kong.response.set_header("X-HMAC-Plugin", "ok")
  kong.response.set_header("X-HMAC-Timestamp", timestamp)
  kong.response.set_header("X-HMAC-Nonce", nonce)

  -- OK → forward
  kong.service.request.set_header("X-Client-Id", api_key)
end

return HmacHandler
