
module RPM
  lib LibRPM
    type FD = Void*

    fun Fopen(UInt8*, UInt8*) : FD
    fun Fclose(FD) : Void
    fun Ferror(FD) : LibC::Int
    fun fdDup(LibC::Int) : FD
    fun Fstrerror(FD) : UInt8*
    fun fdLink(Void*) : FD
  end
end
