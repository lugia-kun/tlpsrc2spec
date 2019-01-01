require "rpm/c/types"
require "rpm/c/tag"

module RPM
  lib LibRPM
    type DB = Void*

    enum MireMode
      DEFAULT = 0
      STRCMP = 1
      REGEX = 2
      GLOB = 3
    end

    fun rpmdbCountPackages(DB, UInt8*) : LibC::Int
    fun rpmdbGetIteratorOffset(MatchIterator) : LibC::UInt
    fun rpmdbGetIteratorCount(MatchIterator) : LibC::Int
    fun rpmdbSetIteratorRE(MatchIterator, TagVal, MireMode, UInt8*) : LibC::Int

    fun rpmdbInitIterator(DB, DbiTagVal, Void*, LibC::SizeT) : MatchIterator

    fun rpmdbNextIterator(MatchIterator) : Header
    fun rpmdbFreeIterator(MatchIterator) : Void
  end
end
