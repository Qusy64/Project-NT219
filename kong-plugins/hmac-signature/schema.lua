local typedefs = require "kong.db.schema.typedefs"

return {
  name = "hmac-signature",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          {
            secrets = {
              type = "map",
              keys = { type = "string" },     -- api_key
              values = { type = "string" },   -- api_secret
            },
          },
          {
            max_clock_skew = {
              type = "number",
              default = 300,   -- 5 phút
            },
          },
        },
      },
    },
  },
}