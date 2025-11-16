-- LayoutLedger Serialization Functions
LayoutLedger.Serialize = {}

local serializer = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub:GetLibrary("LibDeflate")

function LayoutLedger.Serialize.Encode(data)
    -- Serialize the data table into a string
    local serializedData = serializer:Serialize(data)

    -- Compress using LibDeflate (CompressDeflate, not Compress)
    local compressedData = LibDeflate:CompressDeflate(serializedData)

    -- Encode for printing/copy-paste (makes it printable ASCII)
    local encodedData = LibDeflate:EncodeForPrint(compressedData)

    return encodedData
end

function LayoutLedger.Serialize.Decode(encodedString)
    if not encodedString or encodedString == "" then
        print("LayoutLedger: DEBUG Decode - Empty string")
        return nil
    end

    print("LayoutLedger: DEBUG Decode - String length:", #encodedString)

    -- Decode from print format
    local compressedData = LibDeflate:DecodeForPrint(encodedString)
    if not compressedData then
        print("LayoutLedger: DEBUG Decode - DecodeForPrint failed (invalid base64 or corrupted data)")
        return nil
    end

    print("LayoutLedger: DEBUG Decode - DecodeForPrint success, compressed size:", #compressedData)

    -- Decompress using LibDeflate (DecompressDeflate, not Decompress)
    local decompressedData = LibDeflate:DecompressDeflate(compressedData)
    if not decompressedData then
        print("LayoutLedger: DEBUG Decode - DecompressDeflate failed (corrupted compression)")
        return nil
    end

    print("LayoutLedger: DEBUG Decode - DecompressDeflate success, decompressed size:", #decompressedData)

    -- Deserialize back to table
    local success, data = serializer:Deserialize(decompressedData)
    if success then
        print("LayoutLedger: DEBUG Decode - Deserialize success")
        return data
    else
        print("LayoutLedger: DEBUG Decode - Deserialize failed:", tostring(data))
        return nil
    end
end
