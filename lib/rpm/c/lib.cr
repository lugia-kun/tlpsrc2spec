
require "rpm/c/types"

module RPM
  lib LibRPM
    $rpmversion = RPMVERSION : UInt8*
    $rpmEVR : UInt8*

    fun rpmReadConficFiles(UInt8*, UInt8*) : LibC::Int
    fun rpmvercomp(UInt8*, UInt8*) : LibC::Int
  end
end
