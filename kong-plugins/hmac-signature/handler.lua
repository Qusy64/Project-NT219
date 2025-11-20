local kong = kong
local ngx  = ngx
local str  = require "resty.string"
local digest = require "resty.openssl.digest"   -- 👈 THÊM DÒNG NÀY

local HmacHandler = {
  PRIORITY = 900,
  VERSION  = "0.1.2",
}

local function sha256_hex(data)
  local d, err = digest.new("sha256")
  if not d then
    kong.log.err("failed to create sha256 digest: ", err)
    return ""
  end

  local ok, err2 = d:update(data or "")
  if not ok then
    kong.log.err("failed to update sha256 digest: ", err2)
    return ""
  end

  local bin, err3 = d:final()
  if not bin then
    kong.log.err("failed to finalize sha256 digest: ", err3)
    return ""
  end

  return str.to_hex(bin)
end

function HmacHandler:access(conf)
  -- 1) Load thư viện HMAC một cách an toàn
  local ok, openssl_hmac_mod = pcall(require, "resty.openssl.hmac")
  if not ok or not openssl_hmac_mod then
    kong.log.err("failed to load resty.openssl.hmac: ", openssl_hmac_mod)
    return kong.response.exit(500, { message = "HMAC internal error" })
  end

  -- 2) Validate config
  if type(conf.secrets) ~= "table" then
    kong.log.err("plugin misconfigured: conf.secrets is not a table")
    return kong.response.exit(500, { message = "HMAC internal error" })
  end

  -- 3) Lấy request info
  local headers   = kong.request.get_headers()
  local method    = kong.request.get_method()
  local path      = kong.request.get_path()
  local query     = kong.request.get_raw_query() or ""
  local body      = kong.request.get_raw_body() or ""

  local api_key   = headers["x-api-key"] or headers["X-Api-Key"]
  local signature = headers["x-signature"] or headers["X-Signature"]
  local timestamp = headers["x-timestamp"] or headers["X-Timestamp"]
  local nonce     = headers["x-nonce"] or headers["X-Nonce"]

  if not (api_key and signature and timestamp and nonce) then
    return kong.response.exit(401, { message = "Missing HMAC headers" })
  end

  local secret = conf.secrets[api_key]
  if not secret then
    return kong.response.exit(401, { message = "Unknown API key" })
  end

  -- 4) Kiểm tra lệch thời gian
  local now    = os.time()
  local ts_num = tonumber(timestamp)
  local skew   = conf.max_clock_skew or 300

  if not ts_num or math.abs(now - ts_num) > skew then
    return kong.response.exit(401, { message = "Timestamp out of range" })
  end

  -- TODO: kiểm tra nonce chống replay (Redis / shared dict)

  -- 5) Build canonical string
  local body_hash = sha256_hex(body)

  local canonical = table.concat({
    tostring(method or ""),
    tostring(path or ""),
    tostring(query or ""),
    tostring(timestamp or ""),
    tostring(nonce or ""),
    tostring(body_hash or ""),
  }, "\n")

  -- 6) Tính HMAC
  local h, err = openssl_hmac_mod.new(secret, "sha256")
  if not h then
    kong.log.err("failed to create hmac: ", err)
    return kong.response.exit(500, { message = "HMAC internal error" })
  end

  h:update(canonical)
  local computed_bin, err2 = h:final()
  if not computed_bin then
    kong.log.err("failed to finalize hmac: ", err2)
    return kong.response.exit(500, { message = "HMAC internal error" })
  end

  local computed_hex = str.to_hex(computed_bin)

  -- 7) So sánh signature
  if computed_hex:lower() ~= tostring(signature):lower() then
    return kong.response.exit(401, { message = "Invalid HMAC signature" })
  end

  -- 8) Nếu OK, set header forwarding
  kong.service.request.set_header("X-Client-Id", api_key)
end

return HmacHandler
