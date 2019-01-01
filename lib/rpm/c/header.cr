require "rpm/c/types"

module RPM
  @[Flags]
  enum HeaderGetFlags : RPMFlags
    DEFAULT = 0
    MINMEM  = (1 << 0)
    EXT     = (1 << 1)
    RAW     = (1 << 2)
    ALLOC   = (1 << 3)
    ARGV    = (1 << 4)
  end

  @[Flags]
  enum HeaderPutFlags : RPMFlags
    DEFAULT = 0
    APPEND  = (1 << 0)
  end

  enum HeaderConvOps
    EXPANDFILELIST   = 0
    COMPRESSFILELIST = 1
    RETROFIT_V3      = 2
  end

  lib LibRPM
    fun headerNew : Header
    fun headerFree(Header) : Header
    fun headerLink(Header) : Header

    fun headerGet(Header, TagVal, TagData, HeaderGetFlags) : LibC::Int
    fun headerGetString(Header, TagVal) : UInt8*
    fun headerGetAsString(Header, TagVal) : UInt8*
    fun headerPut(Header, TagData, HeaderPutFlags) : LibC::Int
    fun headerPutString(Header, TagVal, UInt8*) : LibC::Int
    fun headerPutUint32(Header, TagVal, UInt32*, Count) : LibC::Int

    fun rpmReadPackageFile(Transaction, FD, UInt8*, Header*) : RC
  end
end
