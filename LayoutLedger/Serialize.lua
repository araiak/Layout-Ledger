-- LayoutLedger Serialization Functions
LayoutLedger.Serialize = {}

local serializer = LibStub("AceSerializer-3.0")
local deflate = LibStub("LibDeflate")

function LayoutLedger.Serialize.Encode(data)
    local serializedData = serializer:Serialize(data)
    local compressedData = deflate:Compress(serializedData)
    return C_EncodingUtil.Base64Encode(compressedData)
end

function LayoutLedger.Serialize.Decode(encodedString)
    local decodedString = C_EncodingUtil.Base64Decode(encodedString)
    if not decodedString then return nil end

    local decompressedData = deflate:Decompress(decodedString)
    if not decompressedData then return nil end

    local success, data = serializer:Deserialize(decompressedData)
    if success then
        return data
    else
        return nil
    end
end
